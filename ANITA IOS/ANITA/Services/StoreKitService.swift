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
    
    // Product IDs - these should match your App Store Connect product IDs
    private let productIDs = [
        "com.anita.pro.monthly"  // Pro Plan - €4.99/month
    ]
    
    private init() {
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    /// Load available products from App Store
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let products = try await Product.products(for: productIDs)
            self.products = products.sorted { $0.price < $1.price }
            isLoading = false
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            isLoading = false
            print("Error loading products: \(error)")
        }
    }
    
    /// Purchase a product
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            // Update UI immediately so the screen doesn't freeze
            await updatePurchasedProducts()
            await transaction.finish()
            
            // Verify with backend in the background (don't block the main thread)
            let userId = UserManager.shared.userId
            if !userId.isEmpty {
                Task {
                    await verifyAndUpdateSubscription(transaction: transaction, product: product)
                }
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
        
        do {
            let requestBody: [String: Any] = [
                "userId": userId,
                "transactionId": transactionId,
                "productId": productId
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
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
    
    /// Restore purchases
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            isLoading = false
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            isLoading = false
            print("Error restoring purchases: \(error)")
        }
    }
    
    /// Update the list of purchased products
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
    
    /// Check if a product is purchased
    func isPurchased(_ productID: String) -> Bool {
        return purchasedProductIDs.contains(productID)
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
