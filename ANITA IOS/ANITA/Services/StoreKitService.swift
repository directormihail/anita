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
        "com.anita.pro.monthly",      // Pro Plan - $4.99/month
        "com.anita.ultimate.monthly"  // Ultimate Plan - $9.99/month
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
            
            // Update purchased products
            await updatePurchasedProducts()
            
            // Finish the transaction
            await transaction.finish()
            
            return transaction
        case .userCancelled:
            throw StoreKitError.userCancelled
        case .pending:
            throw StoreKitError.pending
        @unknown default:
            throw StoreKitError.unknown
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

