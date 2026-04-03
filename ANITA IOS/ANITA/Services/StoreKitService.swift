//
//  StoreKitService.swift
//  ANITA
//
//  StoreKit service for managing in-app purchases
//

import Foundation
import StoreKit

@MainActor
class StoreKitService: ObservableObject {
    static let shared = StoreKitService()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    /// Auto-renewable monthly Premium — unchanged; must match App Store Connect.
    static let monthlyProductID = "com.anita.pro.monthly"

    /// Non-consumable lifetime Unlock — create this exact ID in App Store Connect (In‑App Purchases).
    static let lifetimeProductID = "com.anita.pro.lifetime.v2"

    /// Earlier lifetime ID only for entitlement checks / restore (product may no longer be sold).
    private static let legacyLifetimeProductID = "com.anita.pro.lifetime"
    
    private init() {
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    /// Load monthly subscription and lifetime IAP separately so a missing or failing lifetime load never blocks monthly.
    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        var byId: [String: Product] = [:]

        do {
            let monthly = try await Product.products(for: [Self.monthlyProductID])
            for p in monthly { byId[p.id] = p }
        } catch {
            print("[StoreKit] Monthly product load failed: \(error)")
        }

        do {
            let lifetime = try await Product.products(for: [Self.lifetimeProductID])
            for p in lifetime { byId[p.id] = p }
        } catch {
            print("[StoreKit] Lifetime product load failed: \(error)")
        }

        products = byId.values.sorted { $0.price < $1.price }
        isLoading = false

        if byId[Self.monthlyProductID] == nil {
            errorMessage = AppL10n.t("plans.sandbox_hint")
        } else {
            errorMessage = nil
        }
    }
    
    /// Purchase a product
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            await updatePurchasedProducts()
            await transaction.finish()
            
            // Verify with backend before returning so SubscriptionManager.refresh() sees the new subscription
            let userId = UserManager.shared.userId
            if !userId.isEmpty {
                await verifyAndUpdateSubscription(transaction: transaction, product: product)
            }
            
            return transaction
        case .userCancelled:
            throw StoreKitError.userCancelled
        case .pending:
            throw StoreKitError.pending
        @unknown default:
            throw StoreKitError.unknown
        }
    }
    
    /// Verify transaction with backend and update subscription status
    private func verifyAndUpdateSubscription(transaction: StoreKit.Transaction, product: Product) async {
        let userId = UserManager.shared.userId
        guard !userId.isEmpty else {
            print("[StoreKit] User not authenticated, skipping subscription update")
            return
        }
        
        await verifySubscriptionWithBackend(
            userId: userId,
            transactionId: String(transaction.id),
            productId: product.id
        )
    }
    
    /// Verify subscription with backend API (uses same URL as Settings → Backend URL)
    private func verifySubscriptionWithBackend(userId: String, transactionId: String, productId: String) async {
        _ = try? await SupabaseService.shared.getCurrentUser()
        let baseUrl = NetworkService.shared.getCurrentBaseURL()
        let baseUrlTrimmed = baseUrl.hasSuffix("/") ? String(baseUrl.dropLast()) : baseUrl
        guard let url = URL(string: "\(baseUrlTrimmed)/api/v1/verify-ios-subscription") else {
            print("[StoreKit] Invalid backend URL: \(baseUrlTrimmed)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        if let token = SupabaseService.shared.getAccessToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let requestBody: [String: Any] = [
                "userId": userId,
                "transactionId": transactionId,
                "productId": productId
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            var (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    _ = try? await SupabaseService.shared.getCurrentUser()
                    if let token = SupabaseService.shared.getAccessToken(), !token.isEmpty {
                        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }
                    (data, response) = try await URLSession.shared.data(for: request)
                }
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let subscription = json["subscription"] as? [String: Any],
                       let plan = subscription["plan"] as? String {
                        print("[StoreKit] Subscription verified and updated: \(plan)")
                    } else {
                        print("[StoreKit] Subscription verified but response format unexpected")
                    }
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("[StoreKit] Failed to verify subscription: HTTP \(httpResponse.statusCode) - \(errorMessage)")
                }
            }
        } catch {
            print("[StoreKit] Error verifying subscription with backend: \(error.localizedDescription)")
        }
    }
    
    /// Restore purchases (Apple) and sync subscription state to backend
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            await verifyCurrentEntitlementsWithBackend()
            isLoading = false
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            isLoading = false
            print("Error restoring purchases: \(error)")
        }
    }
    
    /// Update the list of purchased products from App Store
    func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchasedIDs.insert(transaction.productID)
            } catch {
                print("Error verifying transaction: \(error)")
            }
        }
        
        purchasedProductIDs = purchasedIDs
    }
    
    /// After restore, sync each current entitlement to backend so subscription status is correct
    private func verifyCurrentEntitlementsWithBackend() async {
        let userId = UserManager.shared.userId
        guard !userId.isEmpty else { return }
        
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                await verifySubscriptionWithBackend(
                    userId: userId,
                    transactionId: String(transaction.id),
                    productId: transaction.productID
                )
            } catch {
                print("[StoreKit] Error verifying entitlement for backend: \(error)")
            }
        }
    }
    
    /// Check if a product is purchased
    func isPurchased(_ productID: String) -> Bool {
        return purchasedProductIDs.contains(productID)
    }

    /// Lifetime via current or legacy Product ID (restore still returns the ID used at purchase time).
    func isLifetimePurchased() -> Bool {
        purchasedProductIDs.contains(Self.lifetimeProductID)
            || purchasedProductIDs.contains(Self.legacyLifetimeProductID)
    }
    
    /// Get product by ID
    func getProduct(_ productID: String) -> Product? {
        return products.first { $0.id == productID }
    }
    
    /// Verify transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreKitError: LocalizedError {
    case userCancelled
    case pending
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Purchase was cancelled"
        case .pending:
            return "Purchase is pending approval"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
