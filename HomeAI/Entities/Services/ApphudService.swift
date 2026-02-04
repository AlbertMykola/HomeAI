import StoreKit
import ApphudSDK
import AdServices
import FBSDKCoreKit

public class ApphudService: NSObject {

    static public let shared = ApphudService()
    
    private var products: [ApphudProduct] = []
    private var currentPaywall: ApphudPaywall?
        
    public var hasActiveSubscription: Bool {
        Apphud.hasActiveSubscription()
    }
    
    @MainActor
    public var userID: String {
        Apphud.userID()
    }
    
    // MARK: - Start Apphud
    @MainActor
    public func start(id: String) {
        Apphud.start(apiKey: id)
        let idfv = UIDevice.current.identifierForVendor?.uuidString
        Apphud.setDeviceIdentifiers(idfa: nil, idfv: idfv)
        Apphud.deferPlacements()
        fetchASAAttribution()
        setMetaAttributionForCAPI()
        AmplitudeService.shared.logEvent(.apphudUserId(id: Apphud.userID()))
    }
    
    @MainActor
    public func fetchPaywallProducts(placementID: String, completion: @escaping ([ApphudProduct]?, Error?) -> Void) {
        Apphud.fetchPlacements { [weak self] placements, error in
            if let placement = placements.first(where: { $0.identifier == placementID }) {
                if let paywall = placement.paywall {
                    self?.currentPaywall = paywall
                    self?.products = paywall.products
                    completion(paywall.products, nil)
                } else {
                    completion(nil, error)
                }
            } else {
                completion(nil, error)
            }
        }
    }
    
    func isValidProductIndex(_ index: Int) -> Result<ApphudProduct, Error> {
        guard index < products.count else {
            let indexError = NSError(
                domain: "com.apphud.error",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid product index"])
            return .failure(indexError)
        }
        return .success(products[index])
    }
    
    func paywallShown() {
        guard let paywall = currentPaywall else { return }
        Apphud.paywallShown(paywall)
    }
    
    func paywallClosed() {
        guard let paywall = currentPaywall else { return }
        Apphud.paywallClosed(paywall)
    }
    
    @MainActor
    public func buyProduct(index: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard index >= 0, index < products.count else {
            let indexError = NSError(
                domain: "com.apphud.error",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid product index"]
            )
            completion(.failure(indexError))
            return
        }
          
        let apphudProduct = products[index]
          
        Apphud.purchase(apphudProduct) { result in
            if let subscription = result.subscription, subscription.isActive() {
                completion(.success(true))
            } else if let purchase = result.nonRenewingPurchase, purchase.isActive() {
                completion(.success(false))
            } else {
                let error = result.error ?? NSError(
                    domain: "com.apphud.error",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Purchase failed"]
                )
                completion(.failure(error))
            }
        }
    }
    
    public func getApphudProduct(for productId: String) -> ApphudProduct? {
        return products.first { $0.productId == productId }
    }
    
    public func restore() async throws -> String {
        do {
            let success = await Apphud.restorePurchases()
            return success == nil ? "Purchases restored successfully" : "Failed to restore purchases"
        }
    }
    
    func fetchASAAttribution() {
        if #available(iOS 14.3, *) {
            Task {
                if let asaToken = try? AAAttribution.attributionToken() {
                    Apphud.setAttribution(data: ApphudAttributionData(rawData: [:]), from: .appleAdsAttribution, identifer: asaToken, callback: nil)
                }
            }
        }
    }
    
    @MainActor
    private func setMetaAttributionForCAPI() {
        let extInfo = _AppEventsDeviceInfo.shared.encodedDeviceInfo
        let anonId = AppEvents.shared.anonymousID

        let data: [String: Any] = ["extinfo": extInfo ?? ""]

        Apphud.setAttribution(
            data: ApphudAttributionData(rawData: data),
            from: .facebook,
            identifer: anonId,
            callback: { result in
                print("setMetaAttributionForCAPI", result)
                // опційно: лог у консоль/Amplitude, якщо треба
            }
        )
    }
}
