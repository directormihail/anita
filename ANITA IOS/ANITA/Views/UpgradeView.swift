//
//  UpgradeView.swift
//  ANITA
//
//  Upgrade/Subscription view with in-app purchase options
//

import SwiftUI
import StoreKit
import SafariServices
import UIKit

struct UpgradeView: View {
    @StateObject private var storeKitService = StoreKitService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showSuccessAlert = false
    @State private var databaseSubscription: Subscription?
    @State private var isLoadingSubscription = false
    @State private var isRestoring = false
    
    private let networkService = NetworkService.shared
    
    // Determine current plan - prioritize database subscription over StoreKit
    private var currentPlan: String {
        // First check database subscription
        if let subscription = databaseSubscription, subscription.status == "active" {
            return subscription.plan
        }
        // Fallback to StoreKit if database not loaded yet
        if storeKitService.isPurchased("com.anita.ultimate.monthly") {
            return "ultimate"
        } else if storeKitService.isPurchased("com.anita.pro.monthly") {
            return "pro"
        }
        return "free"
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
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                            Text(AppL10n.t("common.back"))
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .liquidGlass(cornerRadius: 12)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header with premium styling
                        VStack(spacing: 14) {
                            Text(AppL10n.t("plans.upgrade_header"))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.98),
                                            Color.white.opacity(0.9)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color.white.opacity(0.1), radius: 2, x: 0, y: 1)
                                .tracking(-0.5)
                            
                            Text(AppL10n.t("plans.upgrade_subheader"))
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.65))
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                                .padding(.horizontal, 8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // Subscription Plans - Always show all plans (Apple In-App Purchase)
                        VStack(spacing: 24) {
                            // Free Plan - Always visible
                            FreePlanCard(isCurrentPlan: currentPlan == "free")
                            
                            // Pro Plan
                            SubscriptionPlanCard(
                                planType: .pro,
                                isCurrentPlan: currentPlan == "pro",
                                isCreatingCheckout: storeKitService.isLoading,
                                price: storeKitService.getProduct("com.anita.pro.monthly")?.displayPrice ?? "$4.99",
                                onCheckout: {
                                    Task { await purchasePlan(productId: "com.anita.pro.monthly") }
                                }
                            )
                            
                            // Ultimate Plan
                            SubscriptionPlanCard(
                                planType: .ultimate,
                                isCurrentPlan: currentPlan == "ultimate",
                                isCreatingCheckout: storeKitService.isLoading,
                                price: storeKitService.getProduct("com.anita.ultimate.monthly")?.displayPrice ?? "$9.99",
                                onCheckout: {
                                    Task { await purchasePlan(productId: "com.anita.ultimate.monthly") }
                                }
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Restore Purchases
                        Button(action: {
                            Task { await restorePurchases() }
                        }) {
                            HStack(spacing: 8) {
                                if isRestoring {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.8)))
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                Text(AppL10n.t("plans.restore_purchases"))
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }
                        .disabled(storeKitService.isLoading || isRestoring)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        
                        // Error message
                        if let error = storeKitService.errorMessage {
                            Text(error)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.red.opacity(0.9))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .liquidGlass(cornerRadius: 12)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 10)
                        }
                    }
                }
            }
        }
        .alert(AppL10n.t("plans.purchase_success_title"), isPresented: $showSuccessAlert) {
            Button(AppL10n.t("plans.ok")) {
                Task {
                    await loadSubscriptionFromDatabase()
                    dismiss()
                }
            }
        } message: {
            Text(AppL10n.t("plans.purchase_success_body"))
        }
        .task {
            await loadSubscriptionFromDatabase()
        }
    }
    
    private func loadSubscriptionFromDatabase() async {
        isLoadingSubscription = true
        let userId = UserManager.shared.userId
        
        do {
            let response = try await networkService.getSubscription(userId: userId)
            await MainActor.run {
                databaseSubscription = response.subscription
                isLoadingSubscription = false
            }
        } catch {
            print("[UpgradeView] Error loading subscription: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingSubscription = false
            }
        }
    }
    
    /// Purchase a subscription via Apple In-App Purchase
    private func purchasePlan(productId: String) async {
        guard let product = storeKitService.getProduct(productId) else {
            await MainActor.run {
                storeKitService.errorMessage = AppL10n.t("plans.checkout_error")
            }
            return
        }
        
        await MainActor.run {
            storeKitService.errorMessage = nil
        }
        
        do {
            _ = try await storeKitService.purchase(product)
            await MainActor.run {
                showSuccessAlert = true
            }
            await loadSubscriptionFromDatabase()
        } catch StoreKitError.userCancelled {
            // User cancelled - no error to show
        } catch StoreKitError.pending {
            await MainActor.run {
                storeKitService.errorMessage = AppL10n.t("plans.pending")
            }
        } catch {
            await MainActor.run {
                storeKitService.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Restore previous Apple purchases and sync with backend
    private func restorePurchases() async {
        await MainActor.run {
            isRestoring = true
            storeKitService.errorMessage = nil
        }
        
        await storeKitService.restorePurchases()
        await loadSubscriptionFromDatabase()
        
        await MainActor.run {
            isRestoring = false
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
        VStack(alignment: .leading, spacing: 22) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(white: 0.2).opacity(0.3),
                                            Color(white: 0.15).opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.2),
                                                    Color.white.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                }
                            
                            Image(systemName: "circle.fill")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Text(AppL10n.t("plans.free"))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                            .tracking(-0.3)
                    }
                    
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("$0")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .digit3D(baseColor: .white.opacity(0.85))
                        Text(AppL10n.t("plans.per_month"))
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .padding(.leading, 2)
                }
                
                Spacer()
                
                if isCurrentPlan {
                    Text(AppL10n.t("plans.current"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.25),
                                    Color.green.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        }
                        .cornerRadius(10)
                }
            }
            
            // Features
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(text: AppL10n.t("plans.feature.replies_20"), accentColor: .white.opacity(0.4))
                FeatureRow(text: AppL10n.t("plans.feature.basic_expense"), accentColor: .white.opacity(0.4))
            }
            .padding(.top, 6)
            
            // Button
            Button(action: {}) {
                Text(isCurrentPlan ? AppL10n.t("plans.current") : AppL10n.t("plans.free"))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundColor(.white.opacity(0.5))
            }
            .liquidGlass(cornerRadius: 14)
            .disabled(true)
        }
        .padding(26)
        .liquidGlass(cornerRadius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct SubscriptionPlanCard: View {
    let planType: PlanType
    let isCurrentPlan: Bool
    let isCreatingCheckout: Bool
    let price: String
    let onCheckout: () -> Void
    
    var planName: String {
        switch planType {
        case .pro:
            return AppL10n.t("plans.pro")
        case .ultimate:
            return AppL10n.t("plans.ultimate")
        case .free:
            return AppL10n.t("plans.free")
        }
    }
    
    var planFeatures: [String] {
        switch planType {
        case .pro:
            return [
                AppL10n.t("plans.feature.replies_50"),
                AppL10n.t("plans.feature.full_budget"),
                AppL10n.t("plans.feature.financial_goals"),
                AppL10n.t("plans.feature.smart_insights"),
                AppL10n.t("plans.feature.faster_ai")
            ]
        case .ultimate:
            return [
                AppL10n.t("plans.feature.unlimited_replies"),
                AppL10n.t("plans.feature.advanced_analytics"),
                AppL10n.t("plans.feature.priority_support"),
                AppL10n.t("plans.feature.custom_ai"),
                AppL10n.t("plans.feature.all_pro")
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
        VStack(alignment: .leading, spacing: 22) {
            // Most Popular Badge
            if showMostPopular {
                HStack {
                    Spacer()
                    Text(AppL10n.t("plans.most_popular"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.7),
                                    Color.purple.opacity(0.7)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.blue.opacity(0.4),
                                            Color.purple.opacity(0.4)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                        .cornerRadius(10)
                }
                .padding(.bottom, 6)
            }
            
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            accentColor.opacity(0.25),
                                            accentColor.opacity(0.15)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    accentColor.opacity(0.4),
                                                    accentColor.opacity(0.2)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                }
                            
                            Image(systemName: planIcon)
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            accentColor.opacity(0.95),
                                            accentColor.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        Text(planName)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                            .tracking(-0.3)
                    }
                    
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(price)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .digit3D(baseColor: .white.opacity(0.85))
                        Text(AppL10n.t("plans.per_month"))
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .padding(.leading, 2)
                }
                
                Spacer()
                
                if isCurrentPlan {
                    Text(AppL10n.t("plans.current"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.25),
                                    Color.green.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        }
                        .cornerRadius(10)
                }
            }
            
            // Features
            VStack(alignment: .leading, spacing: 16) {
                ForEach(planFeatures, id: \.self) { feature in
                    FeatureRow(text: feature, accentColor: accentColor)
                }
            }
            .padding(.top, 6)
            
            // Checkout Button
            if !isCurrentPlan {
                Button(action: {
                    // Haptic feedback for button tap
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                    
                    // Trigger checkout
                    onCheckout()
                }) {
                    HStack(spacing: 12) {
                        if isCreatingCheckout {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("\(AppL10n.t("plans.upgrade_to")) \(planName)")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .allowsHitTesting(!isCreatingCheckout)
                .background(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.3),
                            accentColor.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.7),
                                    accentColor.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .allowsHitTesting(false)
                )
                .cornerRadius(14)
                .disabled(isCreatingCheckout)
                .opacity(isCreatingCheckout ? 0.7 : 1.0)
                .scaleEffect(isCreatingCheckout ? 0.98 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCreatingCheckout)
            } else {
                Button(action: {}) {
                    Text(AppL10n.t("plans.current"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(PlainButtonStyle())
                .liquidGlass(cornerRadius: 14)
                .disabled(true)
            }
        }
        .padding(26)
        .liquidGlass(cornerRadius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.5),
                            accentColor.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: planType == .ultimate ? 1.5 : 1
                )
                .allowsHitTesting(false)
        )
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            accentColor.opacity(planType == .ultimate ? 0.1 : 0.06),
                            accentColor.opacity(planType == .ultimate ? 0.05 : 0.02)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .allowsHitTesting(false)
        )
    }
}

struct FeatureRow: View {
    let text: String
    var accentColor: Color = .green
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.95),
                            accentColor.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 20, height: 20)
            
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(2)
        }
        .alignmentGuide(.leading) { _ in 0 }
    }
}

struct SubscriptionPlanPlaceholder: View {
    let planType: PlanType
    let isCurrentPlan: Bool
    let isLoading: Bool
    
    var planName: String {
        switch planType {
        case .pro:
            return AppL10n.t("plans.pro")
        case .ultimate:
            return AppL10n.t("plans.ultimate")
        case .free:
            return AppL10n.t("plans.free")
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
                AppL10n.t("plans.feature.replies_50"),
                AppL10n.t("plans.feature.full_budget"),
                AppL10n.t("plans.feature.financial_goals"),
                AppL10n.t("plans.feature.smart_insights"),
                AppL10n.t("plans.feature.faster_ai")
            ]
        case .ultimate:
            return [
                AppL10n.t("plans.feature.unlimited_replies"),
                AppL10n.t("plans.feature.advanced_analytics"),
                AppL10n.t("plans.feature.priority_support"),
                AppL10n.t("plans.feature.custom_ai"),
                AppL10n.t("plans.feature.all_pro")
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
                    Text(AppL10n.t("plans.most_popular"))
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
                            Text(AppL10n.t("plans.loading"))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(placeholderPrice)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .digit3D(baseColor: .white.opacity(0.8))
                            Text(AppL10n.t("plans.per_month"))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                if isCurrentPlan {
                    Text(AppL10n.t("plans.current"))
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
                        Text(AppL10n.t("plans.loading"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundColor(.white)
                } else if isCurrentPlan {
                    Text(AppL10n.t("plans.current"))
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text("\(AppL10n.t("plans.upgrade_to")) \(planName)")
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

// MARK: - Safari View Wrapper

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safariVC = SFSafariViewController(url: url)
        safariVC.preferredControlTintColor = .systemBlue
        return safariVC
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
}

#Preview {
    UpgradeView()
}

