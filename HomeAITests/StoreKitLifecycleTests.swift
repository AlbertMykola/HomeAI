import XCTest
import StoreKit
import StoreKitTest
@testable import HomeAI

/// Native StoreKit checks with local products. Adapty's server-side entitlement is a separate live check.
@MainActor
final class StoreKitLifecycleTests: XCTestCase {
    private func makeSession() throws -> SKTestSession {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("RehomelyQA.storekit")
        let config: [String: Any] = [
            "identifier": "RehomelyLocalQA", "nonRenewingSubscriptions": [], "products": [],
            "settings": ["_failTransactionsEnabled": false, "_locale": "en_US", "_storefront": "USA", "_timeRate": 0],
            "subscriptionGroups": [[
                "id": "qa-pro", "name": "QA Pro", "localizations": [],
                "subscriptions": [[
                    "adHocOffers": [], "codeOffers": [], "displayPrice": "9.99", "familyShareable": false,
                    "groupNumber": 1, "internalID": "qa-yearly", "localizations": [[
                        "description": "Local simulator subscription", "displayName": "Rehomely QA Pro", "locale": "en_US"
                    ]], "productID": "com.albert.apps.design.ai.qa.yearly", "recurringSubscriptionPeriod": "P1Y",
                    "referenceName": "QA Yearly", "subscriptionGroupID": "qa-pro", "type": "RecurringSubscription",
                    "introductoryOffer": ["displayPrice": "0", "internalID": "qa-trial", "numberOfPeriods": 1,
                                          "paymentMode": "free", "subscriptionPeriod": "P3D"]
                ]]
            ]], "version": ["major": 3, "minor": 0]
        ]
        try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys]).write(to: url)
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.locale = Locale(identifier: "en_US")
        session.storefront = "USA"
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    func testLocalTrialPurchaseFinishRestoreAndExpiration() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let updates = consumeTransactionUpdates()
        defer { updates.cancel() }
        let id = "com.albert.apps.design.ai.qa.yearly"
        let products = try await Product.products(for: [id])
        let product = try XCTUnwrap(products.first)
        XCTAssertEqual(product.price, Decimal(string: "9.99"))
        XCTAssertEqual(product.subscription?.introductoryOffer?.paymentMode, .freeTrial)
        XCTAssertEqual(product.subscription?.introductoryOffer?.period.value, 3)
        XCTAssertEqual(product.subscription?.introductoryOffer?.period.unit, .day)
        let result = try await product.purchase()
        guard case .success(.verified(let transaction)) = result else { return XCTFail("Local purchase was not verified") }
        XCTAssertEqual(transaction.productID, id)
        await transaction.finish()
        try await AppStore.sync()
        var restored = false
        for await item in Transaction.currentEntitlements {
            if case .verified(let transaction) = item, transaction.productID == id { restored = true }
        }
        XCTAssertTrue(restored, "The active local subscription must be restorable")
        try session.expireSubscription(productIdentifier: id)
        let deadline = Date().addingTimeInterval(15)
        while await hasActiveEntitlement(id), Date() < deadline { try await Task.sleep(nanoseconds: 100_000_000) }
        let active = await hasActiveEntitlement(id)
        XCTAssertFalse(active)
    }

    @available(iOS 17.0, *)
    func testLocalCancellationDoesNotCreateAnEntitlement() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let updates = consumeTransactionUpdates()
        defer { updates.cancel() }
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: StoreKitPurchaseAPI())
        let id = "com.albert.apps.design.ai.qa.yearly"
        let products = try await Product.products(for: [id])
        let product = try XCTUnwrap(products.first)
        do {
            let result = try await product.purchase()
            guard case .userCancelled = result else { return XCTFail("Expected a quiet user cancellation") }
        } catch StoreKitError.userCancelled {
            // Error injection may surface the typed cancellation as a thrown error.
        }
        var active = false
        for await item in Transaction.currentEntitlements {
            if case .verified(let transaction) = item, transaction.productID == id { active = true }
        }
        XCTAssertFalse(active)
    }

    private func hasActiveEntitlement(_ id: String) async -> Bool {
        for await item in Transaction.currentEntitlements {
            if case .verified(let transaction) = item, transaction.productID == id,
               let expiration = transaction.expirationDate, expiration > Date() { return true }
        }
        return false
    }

    private func consumeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
            }
        }
    }
}
