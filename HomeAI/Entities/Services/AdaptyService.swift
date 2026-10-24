import Adapty
import AdServices
import AppsFlyerLib
import FBSDKCoreKit
import FirebaseCore
import FirebaseCrashlytics
import StoreKit

public class AdaptyService: NSObject {

    static public let shared = AdaptyService()

    private var products: [AdaptyPaywallProduct] = []
    private var currentFlow: AdaptyFlow?
    private var cachedProfile: AdaptyProfile?
    private var didSetMetaAttribution = false
    private var didCompleteInitialUserLoad = false
    private var pendingUserReadyContinuations: [CheckedContinuation<Void, Never>] = []
    private var activationTask: Task<Void, Never>?

    public var hasActiveSubscription: Bool {
        #if DEBUG
        if AppQA.enabled { return AppQA.premium }
        #endif
        return isPremium(cachedProfile)
    }

    @MainActor
    public var userID: String {
        cachedProfile?.profileId ?? ""
    }

    // MARK: - Start Adapty

    @MainActor
    public func start(id: String) {
        Adapty.delegate = self
        activationTask = Task { @MainActor in
            await self.activateSDK(apiKey: id)
        }
    }

    @MainActor
    private func activateSDK(apiKey: String) async {
        do {
            var builder = AdaptyConfiguration.builder(withAPIKey: apiKey)
            #if DEBUG
            builder = builder.with(logLevel: .verbose)
            #else
            builder = builder.with(logLevel: .warn)
            #endif
            try await Adapty.activate(with: builder.build())
            let profile = try await Adapty.getProfile()
            apply(profile)
            await bindAmplitudeIdentifierIfAvailable()
            await bindAppsFlyerIdentifierIfAvailable()
        } catch {
            #if DEBUG
            print("[Adapty] activate failed: \(error.localizedDescription)")
            #endif
            ErrorReporter.report(error, operation: "adapty_activate", details: .init(provider: "adapty"))
        }
        fetchASAAttribution()
        markInitialUserLoadCompleted()
        AmplitudeService.shared.logEvent(.adaptyProfileId(id: userID))
    }

    /// Чекає activate + перший профіль (або timeout).
    @MainActor
    public func awaitUserReady(timeoutSeconds: TimeInterval = 8) async {
        #if DEBUG
        if AppQA.enabled { return }
        #endif
        if didCompleteInitialUserLoad { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            pendingUserReadyContinuations.append(continuation)

            if didCompleteInitialUserLoad {
                let waiters = pendingUserReadyContinuations
                pendingUserReadyContinuations.removeAll()
                waiters.forEach { $0.resume() }
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds) { [weak self] in
                self?.markInitialUserLoadCompleted()
            }
        }
    }

    @MainActor
    public func hasActiveSubscriptionWhenReady(timeoutSeconds: TimeInterval = 8) async -> Bool {
        await awaitUserReady(timeoutSeconds: timeoutSeconds)
        return hasActiveSubscription
    }

    /// Before telling a user they need Pro: wait for the first profile, and if it still says "free", fetch the
    /// latest one once (the cached profile can be stale or missing right after launch / a renewal).
    @MainActor
    public func confirmedSubscriptionStatus() async -> Bool {
        if hasActiveSubscription { return true }
        await awaitUserReady(timeoutSeconds: 8)
        if hasActiveSubscription { return true }
        do {
            apply(try await Adapty.getProfile())
        } catch {
            ErrorReporter.report(error, operation: "adapty_profile_refresh", details: .init(provider: "adapty"))
        }
        return hasActiveSubscription
    }

    @MainActor
    private func markInitialUserLoadCompleted() {
        guard !didCompleteInitialUserLoad else { return }
        didCompleteInitialUserLoad = true
        if FirebaseApp.app() != nil {
            Crashlytics.crashlytics().setUserID(userID)
        }
        SentryService.shared.setUserId(userID)
        let waiters = pendingUserReadyContinuations
        pendingUserReadyContinuations.removeAll()
        waiters.forEach { $0.resume() }
    }

    /// Продукти + готовий UI-стан для paywall (бейджі, ціни, заголовки).
    @MainActor
    func fetchPaywallPresentation(
        placementID: String,
        completion: @escaping (Result<PaywallProductsLoadResult, Error>) -> Void
    ) {
        // A failed reload must not leave a previously displayed product purchasable.
        products = []
        currentFlow = nil
        Task { @MainActor in
            await self.activationTask?.value
            do {
                let flow = try await Adapty.getFlow(placementId: placementID)
                let fetchedProducts = try await Adapty.getPaywallProducts(flow: flow)
                let products = WeeklyPaywallProducts.onlyWeekly(from: fetchedProducts)
                guard let presentation = PaywallProductsPresentation.make(from: products) else {
                    ErrorReporter.report(AdaptyServiceError.insufficientProducts, operation: "paywall_load",
                                         details: .init(provider: "adapty", extra: ["placement": placementID]))
                    completion(.failure(AdaptyServiceError.insufficientProducts))
                    return
                }
                self.currentFlow = flow
                self.products = products
                completion(.success(PaywallProductsLoadResult(products: products, presentation: presentation)))
            } catch {
                ErrorReporter.report(error, operation: "paywall_load",
                                     details: .init(provider: "adapty", extra: ["placement": placementID]))
                completion(.failure(error))
            }
        }
    }

    func paywallShown() {
        guard let flow = currentFlow else { return }
        Task {
            try? await Adapty.logShowFlow(flow)
        }
    }

    func paywallClosed() {}

    @MainActor
    public func buyProduct(index: Int, completion: @escaping (Result<PaywallPurchaseOutcome, Error>) -> Void) {
        guard index >= 0, index < products.count else {
            completion(.failure(AdaptyServiceError.invalidProductIndex))
            return
        }

        let product = products[index]
        guard product.paywallIsWeeklySubscription else {
            completion(.failure(AdaptyServiceError.insufficientProducts))
            return
        }

        Task { @MainActor in
            do {
                // Persist the AppsFlyer ID on the Adapty profile before a purchase can
                // produce an S2S event. The regular attribution callback is async and
                // may otherwise race with the StoreKit purchase.
                await self.activationTask?.value
                await self.bindAmplitudeIdentifierIfAvailable()
                await self.bindAppsFlyerIdentifierIfAvailable()
                let purchaseResult = try await Adapty.makePurchase(product: product)
                switch purchaseResult {
                case .userCancelled:
                    completion(.failure(AdaptyServiceError.purchaseCancelled))
                case .pending:
                    completion(.failure(AdaptyServiceError.purchasePending))
                case let .success(profile, transactionResult):
                    self.apply(profile)
                    if self.isPremium(profile) {
                        var startedFreeTrial: Bool?
                        var transactionVerified = false
                        if case let .verified(transaction) = transactionResult {
                            transactionVerified = true
                            let isFreeTrial = transaction.offerType == .introductory &&
                                (transaction.price.map { $0 == 0 } ?? product.paywallHasFreeTrial)
                            startedFreeTrial = isFreeTrial
                            let revenue = transaction.price ?? product.price
                            let currencyCode: String?
                            if #available(iOS 16.0, *) {
                                currencyCode = transaction.currency?.identifier ?? product.currencyCode
                            } else {
                                currencyCode = transaction.currencyCode ?? product.currencyCode
                            }

                            AppsFlyerService.shared.logSKANSubscription(
                                isTrial: isFreeTrial,
                                revenue: revenue,
                                currencyCode: currencyCode,
                                productId: product.vendorProductId
                            )
                        }
                        completion(.success(PaywallPurchaseOutcome(
                            startedFreeTrial: startedFreeTrial,
                            transactionVerified: transactionVerified
                        )))
                    } else {
                        ErrorReporter.report(AdaptyServiceError.purchaseFailed, operation: "purchase",
                                             details: .init(provider: "adapty", extra: [
                                                "product_id": product.vendorProductId,
                                                "expected_access_level": Constants.Keys.adaptyAccessLevel,
                                                "active_access_levels": profile.accessLevels
                                                    .filter { $0.value.isActive }.keys.sorted().joined(separator: ",")
                                             ]))
                        completion(.failure(AdaptyServiceError.purchaseFailed))
                    }
                }
            } catch {
                let errorChain = Self.purchaseErrorChain(error)
                #if DEBUG
                print("[Purchase] product=\(product.vendorProductId) errors=\(errorChain)")
                #endif
                if Self.isPurchaseCancelled(error) {
                    completion(.failure(AdaptyServiceError.purchaseCancelled))
                } else {
                    ErrorReporter.report(error, operation: "purchase", details: .init(provider: "adapty", extra: [
                        "product_id": product.vendorProductId,
                        "purchase_error_chain": errorChain
                    ]))
                    completion(.failure(error))
                }
            }
        }
    }

    /// A/11 Profile: renewal date / cancelled-but-active / billing retry, from the cached profile.
    struct ProStatus {
        let expiresAt: Date?
        let willRenew: Bool
        let billingIssue: Bool
    }

    var proStatus: ProStatus? {
        guard let level = cachedProfile?.accessLevels[Constants.Keys.adaptyAccessLevel], level.isActive else { return nil }
        return ProStatus(expiresAt: level.expiresAt, willRenew: level.willRenew,
                         billingIssue: level.billingIssueDetectedAt != nil || level.isInGracePeriod)
    }

    /// The same preferred weekly product offered by the paywall.
    var cachedWeeklyPrice: String? {
        guard let index = WeeklyPaywallProducts.selection(from: products).preferredIndex else { return nil }
        return products[index].localizedPrice
    }

    public func restore() async throws -> String {
        let profile: AdaptyProfile
        do {
            profile = try await Adapty.restorePurchases()
        } catch {
            ErrorReporter.report(error, operation: "restore", details: .init(provider: "adapty"))
            throw error
        }
        await MainActor.run { apply(profile) }
        return "Purchases restored successfully"
    }

    func fetchASAAttribution() {
        if #available(iOS 14.3, *) {
            Task {
                let fetch = await AppleSearchAdsAttributionService.shared.fetchAttribution()
                if let token = fetch.token {
                    try? await Adapty.updateExternalAttribution(
                        ["token": token],
                        provider: .appleAds
                    )
                }
                AmplitudeService.shared.logAppleSearchAdsAttribution(fetch.result)
            }
        }
    }

    func setAppsFlyerAttribution(rawData: [AnyHashable: Any] = [:]) {
        Task { @MainActor in
            await self.activationTask?.value
            await self.bindAppsFlyerIdentifierIfAvailable()
            let safe = Self.jsonSafeAttribution(rawData)
            guard !safe.isEmpty else { return }
            try? await Adapty.updateExternalAttribution(safe, provider: .appsflyer)
        }
    }

    @MainActor
    private func bindAmplitudeIdentifierIfAvailable() async {
        guard let deviceID = AmplitudeService.shared.deviceID, !deviceID.isEmpty else { return }
        do {
            try await Adapty.setIntegrationIdentifier(.amplitudeDeviceId(deviceID))
        } catch {
            #if DEBUG
            print("[Adapty] Amplitude device ID binding failed: \(error.localizedDescription)")
            #endif
            ErrorReporter.report(error, operation: "adapty_identifier", details: .init(provider: "adapty",
                                 extra: ["integration": "amplitude"]))
        }
    }

    @MainActor
    private func bindAppsFlyerIdentifierIfAvailable() async {
        let uid = AppsFlyerLib.shared().getAppsFlyerUID()
        guard !uid.isEmpty else { return }
        do {
            try await Adapty.setIntegrationIdentifier(.appsflyerId(uid))
        } catch {
            #if DEBUG
            print("[Adapty] AppsFlyer ID binding failed: \(error.localizedDescription)")
            #endif
            ErrorReporter.report(error, operation: "adapty_identifier", details: .init(provider: "adapty",
                                 extra: ["integration": "appsflyer"]))
        }
    }

    private static func jsonSafeAttribution(_ raw: [AnyHashable: Any]) -> [AnyHashable: Any] {
        var out: [String: Any] = [:]
        out.reserveCapacity(raw.count)
        for (key, value) in raw {
            if value is NSNull { continue }
            let stringKey = key as? String ?? String(describing: key)
            if let nested = value as? [AnyHashable: Any] {
                out[stringKey] = jsonSafeAttribution(nested)
            } else if JSONSerialization.isValidJSONObject([stringKey: value]) {
                out[stringKey] = value
            } else {
                out[stringKey] = String(describing: value)
            }
        }
        return out
    }

    @MainActor
    public func setMetaAttributionForCAPIIfNeeded() {
        guard !didSetMetaAttribution else { return }
        didSetMetaAttribution = true
        let anonId = AppEvents.shared.anonymousID
        guard !anonId.isEmpty else { return }
        Task {
            try? await Adapty.setIntegrationIdentifier(.facebookAnonymousId(anonId))
        }
    }

    // MARK: - Profile

    @MainActor
    private func apply(_ profile: AdaptyProfile) {
        cachedProfile = profile
        Crashlytics.crashlytics().setUserID(profile.profileId)
        SentryService.shared.setUserId(profile.profileId)
        LocalNotificationService.shared.sync(requestPermissionIfNeeded: false)
    }

    private func isPremium(_ profile: AdaptyProfile?) -> Bool {
        profile?.accessLevels[Constants.Keys.adaptyAccessLevel]?.isActive ?? false
    }

    private static func isPurchaseCancelled(_ error: Error) -> Bool {
        if let adaptyError = error as? AdaptyError {
            return adaptyError.adaptyErrorCode == .paymentCancelled
        }
        return false
    }

    /// Preserve Apple's nested error codes without logging account data or receipt payloads.
    private static func purchaseErrorChain(_ error: Error) -> String {
        var current: NSError? = error as NSError
        var visited = Set<ObjectIdentifier>()
        var codes: [String] = []
        while let next = current, codes.count < 8, visited.insert(ObjectIdentifier(next)).inserted {
            codes.append("\(next.domain):\(next.code)")
            current = next.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return codes.joined(separator: " > ")
    }
}

// MARK: - AdaptyDelegate

extension AdaptyService: AdaptyDelegate {
    public nonisolated func didLoadLatestProfile(_ profile: AdaptyProfile) {
        Task { @MainActor in
            self.apply(profile)
        }
    }
}
