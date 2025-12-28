//
//  UpgradeView.swift
//  ANITA
//
//  Upgrade/Subscription view with in-app purchase options
//

import SwiftUI
import StoreKit
import UIKit

struct UpgradeView: View {
    @StateObject private var storeKitService = StoreKitService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showSuccessAlert = false
    
    // Determine current plan
    private var currentPlan: String {
        if storeKitService.isPurchased("com.anita.ultimate.monthly") {
            return "ultimate"
        } else if storeKitService.isPurchased("com.anita.pro.monthly") {
            return "pro"
        }
        return "free"
    }
    
    // Get Pro product
    private var proProduct: Product? {
        storeKitService.products.first { $0.id.contains("pro") }
    }
    
    // Get Ultimate product
    private var ultimateProduct: Product? {
        storeKitService.products.first { $0.id.contains("ultimate") }
    }
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Navigation Bar with Back Button
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
                
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
                        .padding(.horizontal, 20)
                        
                        // Subscription Plans - Always show all plans
                        VStack(spacing: 16) {
                            // Free Plan - Always visible
                            FreePlanCard(isCurrentPlan: currentPlan == "free")
                            
                            // Pro Plan - Show with product or placeholder
                            if let proProduct = proProduct {
                                SubscriptionPlanCard(
                                    product: proProduct,
                                    planType: .pro,
                                    isCurrentPlan: currentPlan == "pro",
                                    isPurchasing: isPurchasing && selectedProduct?.id == proProduct.id,
                                    onPurchase: {
                                        Task {
                                            await purchaseProduct(proProduct)
                                        }
                                    }
                                )
                            } else {
                                // Placeholder Pro Plan when StoreKit products not loaded
                                SubscriptionPlanPlaceholder(
                                    planType: .pro,
                                    isCurrentPlan: currentPlan == "pro",
                                    isLoading: storeKitService.isLoading
                                )
                            }
                            
                            // Ultimate Plan - Show with product or placeholder
                            if let ultimateProduct = ultimateProduct {
                                SubscriptionPlanCard(
                                    product: ultimateProduct,
                                    planType: .ultimate,
                                    isCurrentPlan: currentPlan == "ultimate",
                                    isPurchasing: isPurchasing && selectedProduct?.id == ultimateProduct.id,
                                    onPurchase: {
                                        Task {
                                            await purchaseProduct(ultimateProduct)
                                        }
                                    }
                                )
                            } else {
                                // Placeholder Ultimate Plan when StoreKit products not loaded
                                SubscriptionPlanPlaceholder(
                                    planType: .ultimate,
                                    isCurrentPlan: currentPlan == "ultimate",
                                    isLoading: storeKitService.isLoading
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Restore Purchases
                        Button(action: {
                            Task {
                                await storeKitService.restorePurchases()
                                // Refresh purchased products after restore
                                await storeKitService.updatePurchasedProducts()
                            }
                        }) {
                            HStack {
                                if storeKitService.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                                        .scaleEffect(0.8)
                                }
                                Text("Restore Purchases")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                        .disabled(storeKitService.isLoading)
                        
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
        .onChange(of: storeKitService.products) { _ in
            // Refresh when products are loaded
            Task {
                await storeKitService.updatePurchasedProducts()
            }
        }
        .onChange(of: storeKitService.purchasedProductIDs) { _ in
            // Refresh UI when purchase status changes
        }
    }
    
    private func purchaseProduct(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        selectedProduct = product
        
        do {
            let transaction = try await storeKitService.purchase(product)
            if transaction != nil {
                // Refresh purchased products to update UI
                await storeKitService.updatePurchasedProducts()
                
                // Show success alert
                await MainActor.run {
                    showSuccessAlert = true
                }
            }
        } catch {
            await MainActor.run {
                if let storeKitError = error as? StoreKitError {
                    switch storeKitError {
                    case .userCancelled:
                        purchaseError = nil // Don't show error for user cancellation
                    case .pending:
                        purchaseError = "Purchase is pending approval. You'll be notified when it's complete."
                    case .unknown:
                        purchaseError = "An error occurred. Please try again."
                    }
                } else {
                    purchaseError = error.localizedDescription
                }
            }
        }
        
        await MainActor.run {
            isPurchasing = false
            selectedProduct = nil
        }
    }
}

enum PlanType {
    case free
    case pro
    case ultimate
}

struct FreePlanCard: View {
    let isCurrentPlan: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.7))
                        Text("Free")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("$0")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        Text("/month")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                if isCurrentPlan {
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
                FeatureRow(text: "20 replies per month", accentColor: .gray.opacity(0.6))
                FeatureRow(text: "Basic expense analysis", accentColor: .gray.opacity(0.6))
            }
            
            // Button
            Button(action: {}) {
                Text(isCurrentPlan ? "Current Plan" : "Free Plan")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundColor(.white.opacity(0.6))
            }
            .liquidGlass(cornerRadius: 12)
            .disabled(true)
        }
        .padding(20)
        .liquidGlass(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
        )
    }
}

struct SubscriptionPlanCard: View {
    let product: Product
    let planType: PlanType
    let isCurrentPlan: Bool
    let isPurchasing: Bool
    let onPurchase: () -> Void
    
    var planName: String {
        switch planType {
        case .pro:
            return "Pro"
        case .ultimate:
            return "Ultimate"
        case .free:
            return "Free"
        }
    }
    
    var planFeatures: [String] {
        switch planType {
        case .pro:
            return [
                "50 replies per month",
                "Full budget analysis",
                "Financial goals",
                "Smart insights",
                "Faster AI responses"
            ]
        case .ultimate:
            return [
                "Unlimited replies",
                "Advanced analytics",
                "Priority support",
                "Custom AI training",
                "All Pro features"
            ]
        case .free:
            return []
        }
    }
    
    var showMostPopular: Bool {
        planType == .pro
    }
    
    var accentColor: Color {
        switch planType {
        case .pro:
            return Color.blue
        case .ultimate:
            return Color.purple
        case .free:
            return Color.gray
        }
    }
    
    var planIcon: String {
        switch planType {
        case .pro:
            return "star.fill"
        case .ultimate:
            return "crown.fill"
        case .free:
            return "circle.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Most Popular Badge
            if showMostPopular {
                HStack {
                    Spacer()
                    Text("Most Popular")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                }
            }
            
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Image(systemName: planIcon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(accentColor.opacity(0.9))
                        Text(planName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text(product.displayPrice)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                if isCurrentPlan {
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
                    FeatureRow(text: feature)
                }
            }
            
            // Purchase Button
            if !isCurrentPlan {
                Button(action: {
                    // Haptic feedback for button tap
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    // Trigger purchase
                    onPurchase()
                }) {
                    HStack(spacing: 8) {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 14))
                            Text("Upgrade to \(planName)")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .liquidGlass(cornerRadius: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(accentColor.opacity(0.6), lineWidth: 2)
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accentColor.opacity(0.15))
                )
                .disabled(isPurchasing)
                .opacity(isPurchasing ? 0.7 : 1.0)
                .scaleEffect(isPurchasing ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPurchasing)
            } else {
                Button(action: {}) {
                    Text("Current Plan")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
                .liquidGlass(cornerRadius: 12)
                .disabled(true)
            }
        }
        .padding(20)
        .liquidGlass(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColor.opacity(0.4), lineWidth: planType == .ultimate ? 1.5 : 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            accentColor.opacity(planType == .ultimate ? 0.08 : 0.04),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

struct FeatureRow: View {
    let text: String
    var accentColor: Color = .green
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(accentColor)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

struct SubscriptionPlanPlaceholder: View {
    let planType: PlanType
    let isCurrentPlan: Bool
    let isLoading: Bool
    
    var planName: String {
        switch planType {
        case .pro:
            return "Pro"
        case .ultimate:
            return "Ultimate"
        case .free:
            return "Free"
        }
    }
    
    var placeholderPrice: String {
        switch planType {
        case .pro:
            return "$4.99"
        case .ultimate:
            return "$9.99"
        case .free:
            return "$0"
        }
    }
    
    var planFeatures: [String] {
        switch planType {
        case .pro:
            return [
                "50 replies per month",
                "Full budget analysis",
                "Financial goals",
                "Smart insights",
                "Faster AI responses"
            ]
        case .ultimate:
            return [
                "Unlimited replies",
                "Advanced analytics",
                "Priority support",
                "Custom AI training",
                "All Pro features"
            ]
        case .free:
            return []
        }
    }
    
    var showMostPopular: Bool {
        planType == .pro
    }
    
    var accentColor: Color {
        switch planType {
        case .pro:
            return Color.blue
        case .ultimate:
            return Color.purple
        case .free:
            return Color.gray
        }
    }
    
    var planIcon: String {
        switch planType {
        case .pro:
            return "star.fill"
        case .ultimate:
            return "crown.fill"
        case .free:
            return "circle.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Most Popular Badge
            if showMostPopular {
                HStack {
                    Spacer()
                    Text("Most Popular")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                }
            }
            
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Image(systemName: planIcon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(accentColor.opacity(0.9))
                        Text(planName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    if isLoading {
                        HStack(spacing: 4) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Loading...")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(placeholderPrice)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            Text("/month")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                if isCurrentPlan {
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
                    FeatureRow(text: feature, accentColor: accentColor.opacity(0.8))
                }
            }
            
            // Button
            Button(action: {}) {
                if isLoading {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Loading...")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundColor(.white)
                } else if isCurrentPlan {
                    Text("Current Plan")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text("Upgrade to \(planName)")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .liquidGlass(cornerRadius: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accentColor.opacity(0.3), lineWidth: 1)
            )
            .disabled(true)
        }
        .padding(20)
        .liquidGlass(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColor.opacity(0.4), lineWidth: planType == .ultimate ? 1.5 : 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            accentColor.opacity(planType == .ultimate ? 0.08 : 0.04),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .opacity(isLoading ? 0.7 : 1.0)
    }
}

#Preview {
    UpgradeView()
}

