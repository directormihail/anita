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
    
    // Determine current plan - prioritize database subscription over StoreKit. Free or Premium.
    private var currentPlan: String {
        if let subscription = databaseSubscription, subscription.status == "active" {
            return (subscription.plan == "premium" || subscription.plan == "pro" || subscription.plan == "ultimate") ? "premium" : "free"
        }
        if storeKitService.isPurchased("com.anita.pro.monthly") {
            return "premium"
        }
        return "free"
    }
    
    /// User's currency from database (profiles.currency_code), synced to UserDefaults.
    private var userCurrency: String {
        UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    }
    
    /// Format a subscription price in the user's chosen currency (same as rest of app).
    private func formatSubscriptionPrice(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = userCurrency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
    
    /// Premium price in user's chosen currency (same as database / rest of app).
    private var premiumPriceString: String {
        formatSubscriptionPrice(4.99)
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
                            // Free Plan - Always visible (price in user's currency)
                            FreePlanCard(isCurrentPlan: currentPlan == "free", price: formatSubscriptionPrice(0))
                            
                            // Pro Plan (price in user's currency when StoreKit unavailable)
                            SubscriptionPlanCard(
                                planType: .pro,
                                isCurrentPlan: currentPlan == "premium",
                                isCreatingCheckout: storeKitService.isLoading,
                                price: premiumPriceString,
                                onCheckout: {
                                    Task { await purchasePlan(productId: "com.anita.pro.monthly") }
                                }
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Subscription management — soft card so it feels part of the flow
                        VStack(spacing: 0) {
                            Button(action: {
                                Task { await restorePurchases() }
                            }) {
                                HStack(spacing: 10) {
                                    if isRestoring {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.8)))
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 15, weight: .medium))
                                    }
                                    Text(AppL10n.t("plans.restore_purchases"))
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .contentShape(Rectangle())
                                .foregroundColor(.white.opacity(0.78))
                            }
                            .buttonStyle(.plain)
                            .disabled(storeKitService.isLoading || isRestoring)
                            
                            if currentPlan != "free" {
                                Rectangle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 1)
                                    .padding(.horizontal, 20)
                                
                                Button(action: openSubscriptionManagement) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "gearshape")
                                            .font(.system(size: 15, weight: .medium))
                                        Text(AppL10n.t("settings.cancel_subscription"))
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .contentShape(Rectangle())
                                    .foregroundColor(.white.opacity(0.68))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Legal & subscription terms — natural footer
                        VStack(spacing: 10) {
                            Text(AppL10n.t("plans.cancel_subscription_hint"))
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.48))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                            
                            Text(AppL10n.t("plans.subscription_terms"))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.38))
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                            
                            Text(AppL10n.t("plans.disclaimer_financial"))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.38))
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 18)
                        .padding(.bottom, 20)
                        
                        // Error or Sandbox hint
                        if let error = storeKitService.errorMessage {
                            let isSandboxHint = (error == AppL10n.t("plans.sandbox_hint"))
                            HStack(alignment: .top, spacing: 10) {
                                if isSandboxHint {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 18))
                                        .foregroundColor(.orange.opacity(0.95))
                                }
                                Text(error)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(isSandboxHint ? Color.white.opacity(0.9) : Color.red.opacity(0.9))
                            }
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
        .onAppear {
            Task { await storeKitService.loadProducts() }
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
                storeKitService.errorMessage = storeKitService.products.isEmpty
                    ? AppL10n.t("plans.sandbox_hint")
                    : AppL10n.t("plans.checkout_error")
            }
            return
        }
        
        await MainActor.run {
            storeKitService.errorMessage = nil
        }
        
        do {
            _ = try await storeKitService.purchase(product)
            await SubscriptionManager.shared.refresh()
            await loadSubscriptionFromDatabase()
            await MainActor.run {
                showSuccessAlert = true
            }
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
        await SubscriptionManager.shared.refresh()
        await loadSubscriptionFromDatabase()
        await MainActor.run {
            isRestoring = false
        }
    }
    
    /// Opens Apple's subscription management page so the user can cancel or manage their subscription anytime.
    private func openSubscriptionManagement() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }
}

enum PlanType {
    case free
    case pro
}

struct FreePlanCard: View {
    let isCurrentPlan: Bool
    /// Price string in user's currency (e.g. "$0", "€0")
    var price: String = "$0"
    
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
                FeatureRow(text: AppL10n.t("plans.feature.basic_expense"), accentColor: .white.opacity(0.4))
                FeatureRow(text: AppL10n.t("plans.feature.category_analytics"), accentColor: .white.opacity(0.4))
                FeatureRow(text: AppL10n.t("plans.feature.basic_functions"), accentColor: .white.opacity(0.4))
            }
            .padding(.top, 6)
            
            // Button
            Button(action: {}) {
                Text(isCurrentPlan ? AppL10n.t("plans.current") : AppL10n.t("plans.free"))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .contentShape(Rectangle())
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
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
            return AppL10n.t("plans.premium")
        case .free:
            return AppL10n.t("plans.free")
        }
    }
    
    var planFeatures: [String] {
        switch planType {
        case .pro:
            return [
                AppL10n.t("plans.feature.full_ai"),
                AppL10n.t("plans.feature.spending_limits"),
                AppL10n.t("plans.feature.saving_goals"),
                AppL10n.t("plans.feature.assets"),
                AppL10n.t("plans.feature.full_budget"),
                AppL10n.t("plans.feature.premium_fun")
            ]
        case .free:
            return []
        }
    }
    
    var showMostPopular: Bool {
        false
    }
    
    private static let premiumGold = Color(red: 0.91, green: 0.72, blue: 0.2)
    
    var accentColor: Color {
        switch planType {
        case .pro:
            return Self.premiumGold
        case .free:
            return Color.gray
        }
    }
    
    var planIcon: String {
        switch planType {
        case .pro:
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
                    .contentShape(Rectangle())
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
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
                        .contentShape(Rectangle())
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
                    lineWidth: planType == .pro ? 1.5 : 1
                )
                .allowsHitTesting(false)
        )
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            accentColor.opacity(planType == .pro ? 0.1 : 0.06),
                            accentColor.opacity(planType == .pro ? 0.05 : 0.02)
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
    
    /// User's currency from database (same as UpgradeView / FinanceView).
    private var userCurrency: String {
        UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    }
    
    private func formatSubscriptionPrice(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = userCurrency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
    
    var planName: String {
        switch planType {
        case .pro:
            return AppL10n.t("plans.premium")
        case .free:
            return AppL10n.t("plans.free")
        }
    }
    
    var placeholderPrice: String {
        switch planType {
        case .pro:
            return formatSubscriptionPrice(4.99)
        case .free:
            return formatSubscriptionPrice(0)
        }
    }
    
    var planFeatures: [String] {
        switch planType {
        case .pro:
            return [
                AppL10n.t("plans.feature.full_ai"),
                AppL10n.t("plans.feature.spending_limits"),
                AppL10n.t("plans.feature.saving_goals"),
                AppL10n.t("plans.feature.assets"),
                AppL10n.t("plans.feature.full_budget"),
                AppL10n.t("plans.feature.premium_fun")
            ]
        case .free:
            return []
        }
    }
    
    var showMostPopular: Bool {
        false
    }
    
    private static let premiumGold = Color(red: 0.91, green: 0.72, blue: 0.2)
    
    var accentColor: Color {
        switch planType {
        case .pro:
            return Self.premiumGold
        case .free:
            return Color.gray
        }
    }
    
    var planIcon: String {
        switch planType {
        case .pro:
            return "crown.fill"
        case .free:
            return "circle.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Most Popular Badge (hidden - single Premium plan)
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
                .stroke(accentColor.opacity(0.4), lineWidth: planType == .pro ? 1.5 : 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            accentColor.opacity(planType == .pro ? 0.08 : 0.04),
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

// MARK: - Premium gate (paywall) for locked features

struct PremiumGateView: View {
    var onUpgrade: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.91, green: 0.72, blue: 0.2),
                            Color(red: 0.91, green: 0.72, blue: 0.2).opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(AppL10n.t("paywall.upgrade_to_use"))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            Button(action: onUpgrade) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                    Text(AppL10n.t("paywall.upgrade_button"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.91, green: 0.72, blue: 0.2).opacity(0.4),
                                    Color(red: 0.91, green: 0.72, blue: 0.2).opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(red: 0.91, green: 0.72, blue: 0.2).opacity(0.6), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .liquidGlass(cornerRadius: 20)
        .padding(.horizontal, 20)
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

