//
//  UpgradeView.swift
//  ANITA
//
//  Upgrade/Subscription view with in-app purchase options
//

import SwiftUI
import StoreKit

struct UpgradeView: View {
    @StateObject private var storeKitService = StoreKitService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showSuccessAlert = false
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Upgrade to Premium")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Unlock all features and get the most out of ANITA")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    
                    // Subscription Plans
                    if storeKitService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(.vertical, 40)
                    } else if storeKitService.products.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No subscription plans available")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 16) {
                            ForEach(storeKitService.products, id: \.id) { product in
                                SubscriptionPlanCard(
                                    product: product,
                                    isPurchased: storeKitService.isPurchased(product.id),
                                    isPurchasing: isPurchasing && selectedProduct?.id == product.id,
                                    onPurchase: {
                                        Task {
                                            await purchaseProduct(product)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Restore Purchases
                    Button(action: {
                        Task {
                            await storeKitService.restorePurchases()
                        }
                    }) {
                        Text("Restore Purchases")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 20)
                    
                    // Error message
                    if let error = purchaseError {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)
                    }
                }
            }
        }
        .alert("Purchase Successful", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your subscription has been activated!")
        }
        .task {
            await storeKitService.loadProducts()
            await storeKitService.updatePurchasedProducts()
        }
    }
    
    private func purchaseProduct(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        
        do {
            let transaction = try await storeKitService.purchase(product)
            if transaction != nil {
                showSuccessAlert = true
            }
        } catch {
            if let storeKitError = error as? StoreKitError {
                purchaseError = storeKitError.localizedDescription
            } else {
                purchaseError = error.localizedDescription
            }
        }
        
        isPurchasing = false
    }
}

struct SubscriptionPlanCard: View {
    let product: Product
    let isPurchased: Bool
    let isPurchasing: Bool
    let onPurchase: () -> Void
    
    var planName: String {
        if product.id.contains("ultimate") {
            return "Ultimate"
        } else if product.id.contains("pro") {
            return "Pro"
        }
        return "Premium"
    }
    
    var planFeatures: [String] {
        if product.id.contains("ultimate") {
            return [
                "Unlimited replies",
                "Automatic weekly & monthly reports",
                "Progress sharing",
                "Voice commands",
                "Access to experimental features"
            ]
        } else {
            return [
                "Unlimited replies",
                "Advanced analytics",
                "Priority support",
                "Custom AI training"
            ]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(planName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(product.displayPrice)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                if isPurchased {
                    Text("Current Plan")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            // Features
            VStack(alignment: .leading, spacing: 12) {
                ForEach(planFeatures, id: \.self) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                        
                        Text(feature)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            
            // Purchase Button
            if !isPurchased {
                Button(action: onPurchase) {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Subscribe")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundColor(.white)
                }
                .liquidGlass(cornerRadius: 12)
                .disabled(isPurchasing)
            }
        }
        .padding(20)
        .liquidGlass(cornerRadius: 16)
    }
}

#Preview {
    UpgradeView()
}

