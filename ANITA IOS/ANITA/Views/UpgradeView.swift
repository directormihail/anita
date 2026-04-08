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

private enum BillingOption: Hashable {
    case monthly
    case lifetime
}

struct UpgradeView: View {
    let onSkip: (() -> Void)?
    @StateObject private var storeKitService = StoreKitService.shared
    @Environment(\.dismiss) private var dismiss

    private enum ActiveAlert: Identifiable {
        case purchaseSuccess
        case monthlyTrialConfirmation
        
        var id: Int {
            switch self {
            case .purchaseSuccess: return 1
            case .monthlyTrialConfirmation: return 2
            }
        }
    }
    
    @State private var activeAlert: ActiveAlert?
    @State private var pendingMonthlyTrialProductId: String?
    @State private var databaseSubscription: Subscription?
    @State private var isLoadingSubscription = false
    @State private var isRestoring = false
    @State private var selectedBillingOption: BillingOption = .monthly

    init(onSkip: (() -> Void)? = nil) {
        self.onSkip = onSkip
    }

    private func selectionHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.prepare()
        impact.impactOccurred()
    }

    private func syncSelectedBillingOptionToEntitlements() {
        if hasLifetimeEntitlement {
            selectedBillingOption = .lifetime
        } else if hasMonthlyEntitlement {
            selectedBillingOption = .monthly
        }
    }
    
    private let networkService = NetworkService.shared
    private let userManager = UserManager.shared
    
    // Determine current plan for this app account.
    // For authenticated users, trust backend account state only (prevents cross-account leakage
    // from Apple ID entitlements on the same device). For guests, fall back to local entitlements.
    private var currentPlan: String {
        if userManager.isAuthenticated {
            guard let subscription = databaseSubscription else { return "free" }
            guard subscription.status == "active" else { return "free" }
            return (subscription.plan == "premium" || subscription.plan == "pro" || subscription.plan == "ultimate") ? "premium" : "free"
        }
        if storeKitService.isPurchased(StoreKitService.monthlyProductID) || storeKitService.isLifetimePurchased() {
            return "premium"
        }
        return "free"
    }

    private var isPremiumActive: Bool { currentPlan == "premium" }

    private var hasMonthlyEntitlement: Bool { storeKitService.isPurchased(StoreKitService.monthlyProductID) }
    private var hasLifetimeEntitlement: Bool { storeKitService.isLifetimePurchased() }
    private var shouldUseBackendForPlanState: Bool { userManager.isAuthenticated }
    private var showMonthlyPurchasedState: Bool { shouldUseBackendForPlanState ? false : hasMonthlyEntitlement }
    private var showLifetimePurchasedState: Bool { shouldUseBackendForPlanState ? false : hasLifetimeEntitlement }

    /// If the backend says the user is premium but StoreKit entitlements aren't loaded yet,
    /// disable both CTAs to avoid re-purchasing.
    private var premiumFallbackIsCurrent: Bool {
        currentPlan == "premium" && !hasMonthlyEntitlement && !hasLifetimeEntitlement
    }

    private var isMonthlyCurrentPlan: Bool { hasMonthlyEntitlement || premiumFallbackIsCurrent }
    private var isLifetimeCurrentPlan: Bool { hasLifetimeEntitlement || premiumFallbackIsCurrent }
    private var isSelectedPlanCurrent: Bool {
        if shouldUseBackendForPlanState {
            return isPremiumActive
        }
        switch effectiveBillingOption {
        case .monthly:
            return isMonthlyCurrentPlan
        case .lifetime:
            return isLifetimeCurrentPlan
        }
    }

    private var usesLifetimeTerms: Bool {
        // If the user already has Premium, show terms based on what they own.
        if isPremiumActive {
            if shouldUseBackendForPlanState {
                return selectedBillingOption == .lifetime
            }
            return hasLifetimeEntitlement
        }
        // If not premium yet, show terms based on what they selected to buy.
        return selectedBillingOption == .lifetime
    }

    private var effectiveBillingOption: BillingOption { selectedBillingOption }

    private var selectedProductIdForContinue: String {
        effectiveBillingOption == .monthly ? StoreKitService.monthlyProductID : StoreKitService.lifetimeProductID
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
        formatter.locale = AnitaCurrencyDisplay.locale(forCurrencyCode: userCurrency)
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
    
    /// Premium price in user's chosen currency (same as database / rest of app).
    private var premiumPriceString: String {
        formatSubscriptionPrice(9.99)
    }

    /// Lifetime price in user's chosen currency.
    private var lifetimePriceString: String {
        formatSubscriptionPrice(29.99)
    }
    
    var body: some View {
        ZStack {
            // Futuristic fintech background (neon + subtle grid)
            UpgradeNeonBackground()
            
            VStack(spacing: 0) {
                // Navigation Bar with Back Button
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(12)
                        .liquidGlass(cornerRadius: 14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AppL10n.t("common.back"))
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Header with premium styling
                        VStack(spacing: 14) {
                            HStack(spacing: 10) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.91, green: 0.72, blue: 0.2).opacity(0.95),
                                                Color(red: 0.91, green: 0.72, blue: 0.2).opacity(0.75)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: Color(red: 0.91, green: 0.72, blue: 0.2).opacity(0.35), radius: 12, x: 0, y: 0)
                                
                                Text(AppL10n.t("plans.premium"))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 999)
                                            .fill(Color.white.opacity(0.06))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 999)
                                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                            )
                                    )
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            
                            Text(AppL10n.t("plans.upgrade_header"))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.98),
                                    Color.white.opacity(0.86)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color.white.opacity(0.08), radius: 2, x: 0, y: 1)
                                .tracking(-0.5)
                            
                            Text(AppL10n.t("plans.upgrade_subheader"))
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.68))
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                                .padding(.horizontal, 8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // Subscription window (Premium on top, then Monthly vs Lifetime)
                        VStack(spacing: 12) {
                            PremiumFeaturesCard()

                            HStack(alignment: .top, spacing: 12) {
                                PaymentOptionCard(
                                    title: AppL10n.t("plans.period_monthly"),
                                    price: premiumPriceString,
                                    priceSuffix: AppL10n.t("plans.per_month"),
                                    description: AppL10n.t("plans.monthly_fully_protected"),
                                    option: .monthly,
                                    selectedOption: effectiveBillingOption,
                                    isPurchased: showMonthlyPurchasedState,
                                    isLocked: storeKitService.isLoading,
                                    onSelect: { selectionHaptic(); selectedBillingOption = .monthly }
                                )

                                PaymentOptionCard(
                                    title: AppL10n.t("plans.period_lifetime"),
                                    price: lifetimePriceString,
                                    priceSuffix: AppL10n.t("plans.one_time"),
                                    description: AppL10n.t("plans.lifetime_pay_once_forever"),
                                    option: .lifetime,
                                    selectedOption: effectiveBillingOption,
                                    isPurchased: showLifetimePurchasedState,
                                    isLocked: storeKitService.isLoading,
                                    onSelect: { selectionHaptic(); selectedBillingOption = .lifetime }
                                )
                            }

                            Button(action: {
                                // Monthly is configured in App Store Connect with a 3-day free trial.
                                // We show a clear pre-confirmation message so users know what will happen.
                                if selectedProductIdForContinue == StoreKitService.monthlyProductID {
                                    pendingMonthlyTrialProductId = selectedProductIdForContinue
                                    activeAlert = .monthlyTrialConfirmation
                                } else {
                                    Task { await purchasePlan(productId: selectedProductIdForContinue) }
                                }
                            }) {
                                ZStack {
                                    if storeKitService.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.9)
                                    } else {
                                        Text(isSelectedPlanCurrent ? AppL10n.t("plans.current") : AppL10n.t("plans.continue"))
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isSelectedPlanCurrent || storeKitService.isLoading)
                            .allowsHitTesting(!isSelectedPlanCurrent && !storeKitService.isLoading)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.11, green: 0.62, blue: 1.0),
                                        Color(red: 0.20, green: 0.47, blue: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                            .shadow(color: Color.blue.opacity(0.18), radius: 16, x: 0, y: 8)
                            .padding(.top, 2)

                            // Optional skip for flows that allow continuing without purchase (same size as Continue).
                            if onSkip != nil {
                                Button {
                                    onSkip?()
                                    dismiss()
                                } label: {
                                    Text(AppL10n.t("common.skip"))
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.92))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                        )
                                )
                                .padding(.top, 10)
                            }
                        }
                        .frame(maxWidth: 520)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                        
                        // Subscription management — soft card so it feels part of the flow
                        VStack(spacing: 0) {
                            Button(action: {
                                Task { await restorePurchases() }
                            }) {
                                HStack(spacing: 10) {
                                    if isRestoring {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.75)))
                                    }
                                    Text(AppL10n.t("plans.restore_purchases"))
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .underline()
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                                .foregroundColor(.white.opacity(0.78))
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            .disabled(storeKitService.isLoading || isRestoring)
                            
                            if shouldUseBackendForPlanState ? isPremiumActive : hasMonthlyEntitlement {
                                Rectangle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 1)
                                    .padding(.horizontal, 20)
                                
                                Button(action: openSubscriptionManagement) {
                                    HStack(spacing: 10) {
                                        Text(AppL10n.t("settings.cancel_subscription"))
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.78))
                                            .underline()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        // Legal & subscription terms — natural footer
                        VStack(spacing: 10) {
                            Text(AppL10n.t(usesLifetimeTerms ? "plans.lifetime_purchase_hint" : "plans.cancel_subscription_hint"))
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.48))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                            
                            Text(AppL10n.t(usesLifetimeTerms ? "plans.lifetime_purchase_terms" : "plans.subscription_terms"))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.38))
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                            
                            Text(AppL10n.t("plans.disclaimer_financial"))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.38))
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                            
                            // Required: functional links to Privacy Policy and Terms of Use (EULA)
                            HStack(spacing: 16) {
                                Button(action: {
                                    if let url = URL(string: "https://privacy-policy-anita.vercel.app/") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Text(AppL10n.t("settings.privacy_policy"))
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.75))
                                        .underline()
                                }
                                .buttonStyle(.plain)
                                Text("·")
                                    .foregroundColor(.white.opacity(0.4))
                                Button(action: {
                                    if let url = URL(string: "https://terns-of-use-ykct.vercel.app/") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Text(AppL10n.t("settings.terms_of_use"))
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.75))
                                        .underline()
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 6)
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
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(
                                                isSandboxHint ? Color.orange.opacity(0.35) : Color.red.opacity(0.25),
                                                lineWidth: 1
                                            )
                                    )
                            )
                            .padding(.bottom, 10)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .alert(item: $activeAlert) { alertType in
            switch alertType {
            case .purchaseSuccess:
                return Alert(
                    title: Text(AppL10n.t("plans.purchase_success_title")),
                    message: Text(AppL10n.t("plans.purchase_success_body")),
                    dismissButton: .default(Text(AppL10n.t("plans.ok"))) {
                        Task {
                            await loadSubscriptionFromDatabase()
                            dismiss()
                        }
                    }
                )
            case .monthlyTrialConfirmation:
                return Alert(
                    title: Text(AppL10n.t("plans.monthly_trial_alert_title")),
                    message: Text(AppL10n.t("plans.monthly_trial_alert_body")),
                    primaryButton: .default(Text(AppL10n.t("plans.monthly_trial_alert_start"))) {
                        guard let productId = pendingMonthlyTrialProductId else { return }
                        Task { await purchasePlan(productId: productId) }
                    },
                    secondaryButton: .cancel(Text(AppL10n.t("common.cancel")))
                )
            }
        }
        .task {
            await loadSubscriptionFromDatabase()
        }
        .onAppear {
            Task {
                await storeKitService.loadProducts()
                await MainActor.run {
                    syncSelectedBillingOptionToEntitlements()
                }
            }
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
        // If StoreKit thinks this product is already purchased, treat this as a restore instead of a new purchase.
        if storeKitService.isPurchased(productId) {
            await restorePurchases()
            await MainActor.run {
                storeKitService.errorMessage = nil
                activeAlert = .purchaseSuccess
            }
            return
        }

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
                activeAlert = .purchaseSuccess
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

// MARK: - Premium card + payment option cards

private struct PremiumFeaturesCard: View {
    private struct FeatureItem: Identifiable {
        let id: String
        let icon: String
        let c1: Color
        let c2: Color
        let text: String
    }

    private var features: [FeatureItem] {
        [
            FeatureItem(
                id: "full_ai",
                icon: "brain.head.profile",
                c1: Color(red: 0.33, green: 0.52, blue: 1.00),
                c2: Color(red: 0.33, green: 0.52, blue: 1.00),
                text: AppL10n.t("plans.feature.full_ai")
            ),
            FeatureItem(
                id: "spending_limits",
                icon: "chart.bar.xaxis",
                c1: Color(red: 0.00, green: 0.80, blue: 1.00),
                c2: Color(red: 0.00, green: 0.80, blue: 1.00),
                text: AppL10n.t("plans.feature.spending_limits")
            ),
            FeatureItem(
                id: "saving_goals",
                icon: "flag.fill",
                c1: Color(red: 0.11, green: 0.93, blue: 0.62),
                c2: Color(red: 0.11, green: 0.93, blue: 0.62),
                text: AppL10n.t("plans.feature.saving_goals")
            ),
            FeatureItem(
                id: "assets",
                icon: "banknote.fill",
                c1: Color(red: 1.00, green: 0.82, blue: 0.33),
                c2: Color(red: 1.00, green: 0.82, blue: 0.33),
                text: AppL10n.t("plans.feature.assets")
            ),
            FeatureItem(
                id: "full_budget",
                icon: "rectangle.stack.fill",
                c1: Color(red: 1.00, green: 0.30, blue: 0.52),
                c2: Color(red: 1.00, green: 0.30, blue: 0.52),
                text: AppL10n.t("plans.feature.full_budget")
            ),
            FeatureItem(
                id: "bank_connection",
                icon: "building.columns.fill",
                c1: Color(red: 0.12, green: 0.58, blue: 1.00),
                c2: Color(red: 0.12, green: 0.58, blue: 1.00),
                text: AppL10n.t("plans.feature.bank_connection")
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.11, green: 0.62, blue: 1.0).opacity(0.98),
                                Color.white.opacity(0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(AppL10n.t("plans.premium"))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 0.11, green: 0.62, blue: 1.0))

                Spacer()
            }
            .padding(.bottom, 1)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(features) { feature in
                    IconFeatureRow(
                        icon: feature.icon,
                        c1: feature.c1,
                        c2: feature.c2,
                        text: feature.text
                    )
                }
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

/// Shared height so Monthly + Lifetime plan tiles align; fits title, trial row, price, and two-line footer.
private let paymentOptionCardHeight: CGFloat = 168

private struct PaymentOptionCard: View {
    let title: String
    let price: String
    let priceSuffix: String
    let description: String
    let option: BillingOption
    let selectedOption: BillingOption
    let isPurchased: Bool
    let isLocked: Bool
    let onSelect: () -> Void

    /// Locks pill row height on both options so prices and footers line up.
    private let trialSlotHeight: CGFloat = 22

    private var isSelected: Bool { selectedOption == option }
    private var showPurchasedBadge: Bool { isPurchased && isSelected }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.78))
                            .lineLimit(1)
                            .minimumScaleFactor(0.88)

                        ZStack(alignment: .leading) {
                            if option == .monthly {
                                Text(AppL10n.t("plans.monthly_trial_badge"))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.92))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color(red: 0.16, green: 0.17, blue: 0.20))
                                    )
                            }
                        }
                        .frame(height: trialSlotHeight, alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ZStack(alignment: .center) {
                        Image(systemName: isSelected ? "circle.fill" : "circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSelected ? .white.opacity(0.95) : .white.opacity(0.55))

                        if showPurchasedBadge {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(.green.opacity(0.95))
                                .offset(y: -0.25)
                        }
                    }
                    .padding(.top, 1)
                    .accessibilityHidden(true)
                }
                .padding(.bottom, 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(price)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(priceSuffix)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.58))
                }
                .padding(.bottom, 4)

                Text(description)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.52))
                    .lineLimit(2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .padding(.top, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // Spacers are not tappable by default; shape the full label so the entire card selects the plan.
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .frame(height: paymentOptionCardHeight)
        // Nearly-opaque base so the screen vignette / backdrop never bleeds through as curved “smudges”.
        .background {
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
            let base = Color(red: 0.09, green: 0.10, blue: 0.12)
            ZStack {
                shape.fill(base)
                if isSelected {
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.20, green: 0.76, blue: 1.0).opacity(0.28),
                                Color(red: 0.08, green: 0.52, blue: 1.0).opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                } else {
                    shape.fill(Color.white.opacity(0.04))
                }
            }
            .overlay {
                shape.strokeBorder(
                    isSelected ? Color.blue.opacity(0.50) : Color.white.opacity(0.10),
                    lineWidth: 1
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: isSelected ? Color.black.opacity(0.28) : .clear, radius: 6, x: 0, y: 3)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isSelected)
    }
}

// MARK: - Subscription window (legacy components)

private struct MonthlySubscriptionWindowCard: View {
    let isCurrentPlan: Bool
    let isCreatingCheckout: Bool
    let price: String
    let onCheckout: () -> Void

    private let accent: Color = Color(red: 0.4, green: 0.49, blue: 0.92) // main app accent
    private let accent2: Color = Color(red: 0.4, green: 0.49, blue: 0.92) // keep identical (single-color icons)
    
    private struct FeatureItem: Identifiable {
        let id: String
        let icon: String
        let c1: Color
        let c2: Color
        let text: String
    }
    
    private var features: [FeatureItem] {
        [
            FeatureItem(
                id: "full_ai",
                icon: "brain.head.profile",
                c1: Color(red: 0.33, green: 0.52, blue: 1.00), // royal blue
                c2: Color(red: 0.33, green: 0.52, blue: 1.00),
                text: AppL10n.t("plans.feature.full_ai")
            ),
            FeatureItem(
                id: "spending_limits",
                icon: "chart.bar.xaxis",
                c1: Color(red: 0.00, green: 0.80, blue: 1.00), // cyan
                c2: Color(red: 0.00, green: 0.80, blue: 1.00),
                text: AppL10n.t("plans.feature.spending_limits")
            ),
            FeatureItem(
                id: "saving_goals",
                icon: "flag.fill",
                c1: Color(red: 0.11, green: 0.93, blue: 0.62), // mint green
                c2: Color(red: 0.11, green: 0.93, blue: 0.62),
                text: AppL10n.t("plans.feature.saving_goals")
            ),
            FeatureItem(
                id: "assets",
                icon: "banknote.fill",
                c1: Color(red: 1.00, green: 0.82, blue: 0.33), // gold
                c2: Color(red: 1.00, green: 0.82, blue: 0.33),
                text: AppL10n.t("plans.feature.assets")
            ),
            FeatureItem(
                id: "full_budget",
                icon: "rectangle.stack.fill",
                c1: Color(red: 1.00, green: 0.30, blue: 0.52), // pink-coral
                c2: Color(red: 1.00, green: 0.30, blue: 0.52),
                text: AppL10n.t("plans.feature.full_budget")
            ),
            FeatureItem(
                id: "bank_connection",
                icon: "building.columns.fill",
                c1: Color(red: 0.12, green: 0.58, blue: 1.00), // deep sky
                c2: Color(red: 0.12, green: 0.58, blue: 1.00),
                text: AppL10n.t("plans.feature.bank_connection")
            )
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Title row
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accent2)
                
                Text(AppL10n.t("plans.premium"))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(AppL10n.t("plans.period_monthly"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 999)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 999)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            )
                    )
            }
            
            // Price row
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(price)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppL10n.t("plans.per_month"))
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Features
            VStack(alignment: .leading, spacing: 10) {
                ForEach(features) { feature in
                    IconFeatureRow(
                        icon: feature.icon,
                        c1: feature.c1,
                        c2: feature.c2,
                        text: feature.text
                    )
                }
            }
            .padding(.top, 4)
            
            // CTA
            if !isCurrentPlan {
                Button(action: {
                    onCheckout()
                }) {
                    ZStack {
                        if isCreatingCheckout {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(AppL10n.t("plans.continue"))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isCreatingCheckout)
                .allowsHitTesting(!isCreatingCheckout)
                .background(
                    LinearGradient(
                        colors: [
                            accent,
                            accent2
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: Color(red: 0.2, green: 0.55, blue: 1.0).opacity(0.14), radius: 14, x: 0, y: 8)
            } else {
                Button(action: {}) {
                    Text(AppL10n.t("plans.current"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .contentShape(Rectangle())
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .disabled(true)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct LifetimeSubscriptionWindowCard: View {
    let isCurrentPlan: Bool
    let isCreatingCheckout: Bool
    let price: String
    let onCheckout: () -> Void

    private let accent: Color = Color(red: 0.4, green: 0.49, blue: 0.92) // main app accent
    private let accent2: Color = Color(red: 0.4, green: 0.49, blue: 0.92) // keep identical (single-color icons)

    private struct FeatureItem: Identifiable {
        let id: String
        let icon: String
        let c1: Color
        let c2: Color
        let text: String
    }

    private var features: [FeatureItem] {
        [
            FeatureItem(
                id: "full_ai",
                icon: "brain.head.profile",
                c1: Color(red: 0.33, green: 0.52, blue: 1.00),
                c2: Color(red: 0.33, green: 0.52, blue: 1.00),
                text: AppL10n.t("plans.feature.full_ai")
            ),
            FeatureItem(
                id: "spending_limits",
                icon: "chart.bar.xaxis",
                c1: Color(red: 0.00, green: 0.80, blue: 1.00),
                c2: Color(red: 0.00, green: 0.80, blue: 1.00),
                text: AppL10n.t("plans.feature.spending_limits")
            ),
            FeatureItem(
                id: "saving_goals",
                icon: "flag.fill",
                c1: Color(red: 0.11, green: 0.93, blue: 0.62),
                c2: Color(red: 0.11, green: 0.93, blue: 0.62),
                text: AppL10n.t("plans.feature.saving_goals")
            ),
            FeatureItem(
                id: "assets",
                icon: "banknote.fill",
                c1: Color(red: 1.00, green: 0.82, blue: 0.33),
                c2: Color(red: 1.00, green: 0.82, blue: 0.33),
                text: AppL10n.t("plans.feature.assets")
            ),
            FeatureItem(
                id: "full_budget",
                icon: "rectangle.stack.fill",
                c1: Color(red: 1.00, green: 0.30, blue: 0.52),
                c2: Color(red: 1.00, green: 0.30, blue: 0.52),
                text: AppL10n.t("plans.feature.full_budget")
            ),
            FeatureItem(
                id: "bank_connection",
                icon: "building.columns.fill",
                c1: Color(red: 0.12, green: 0.58, blue: 1.00),
                c2: Color(red: 0.12, green: 0.58, blue: 1.00),
                text: AppL10n.t("plans.feature.bank_connection")
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Title row
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accent2)

                Text(AppL10n.t("plans.premium"))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Text(AppL10n.t("plans.period_lifetime"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 999)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 999)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            )
                    )
            }

            // Price row
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(price)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppL10n.t("plans.one_time"))
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            // Features
            VStack(alignment: .leading, spacing: 10) {
                ForEach(features) { feature in
                    IconFeatureRow(
                        icon: feature.icon,
                        c1: feature.c1,
                        c2: feature.c2,
                        text: feature.text
                    )
                }
            }
            .padding(.top, 4)

            // CTA
            if !isCurrentPlan {
                Button(action: {
                    onCheckout()
                }) {
                    ZStack {
                        if isCreatingCheckout {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(AppL10n.t("plans.continue"))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isCreatingCheckout)
                .allowsHitTesting(!isCreatingCheckout)
                .background(
                    LinearGradient(
                        colors: [
                            accent,
                            accent2
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: Color(red: 0.2, green: 0.55, blue: 1.0).opacity(0.14), radius: 14, x: 0, y: 8)
            } else {
                Button(action: {}) {
                    Text(AppL10n.t("plans.current"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .contentShape(Rectangle())
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .disabled(true)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct FreeTierPreviewCard: View {
    let isCurrentPlan: Bool

    private let accent: Color = Color(red: 0.4, green: 0.49, blue: 0.92) // main app accent
    private let accent2: Color = Color(red: 0.4, green: 0.49, blue: 0.92) // keep identical (single-color icons)
    
    private struct FeatureItem: Identifiable {
        let id: String
        let icon: String
        let c1: Color
        let c2: Color
        let text: String
    }
    
    private var features: [FeatureItem] {
        [
            FeatureItem(
                id: "basic_expense",
                icon: "wallet.pass.fill",
                c1: Color(red: 0.11, green: 0.93, blue: 0.62), // mint
                c2: Color(red: 0.11, green: 0.93, blue: 0.62),
                text: AppL10n.t("plans.feature.basic_expense")
            ),
            FeatureItem(
                id: "category_analytics",
                icon: "chart.pie.fill",
                c1: Color(red: 0.33, green: 0.52, blue: 1.00), // blue
                c2: Color(red: 0.33, green: 0.52, blue: 1.00),
                text: AppL10n.t("plans.feature.category_analytics")
            ),
            FeatureItem(
                id: "basic_functions",
                icon: "square.grid.2x2.fill",
                c1: Color(red: 1.00, green: 0.52, blue: 0.18), // orange
                c2: Color(red: 1.00, green: 0.52, blue: 0.18),
                text: AppL10n.t("plans.feature.basic_functions")
            )
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(accent2)
                    .opacity(0.85)
                
                Text(AppL10n.t("plans.free"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.86))
                
                Spacer()
                
                if isCurrentPlan {
                    Text(AppL10n.t("plans.current"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 999)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 999)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(features) { feature in
                    IconFeatureRow(
                        icon: feature.icon,
                        c1: feature.c1,
                        c2: feature.c2,
                        text: feature.text
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// Fintech list row with a real feature icon (no arrows/checkmarks)
private struct IconFeatureRow: View {
    let icon: String
    let c1: Color
    let c2: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                // Monochrome (not colorful) to keep a clean fintech look
                .foregroundColor(.white.opacity(0.82))
                .frame(width: 26, alignment: .leading)
            
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.92))
                .lineSpacing(1.5)
        }
        .padding(.vertical, 1)
    }
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
                            
                            Image(systemName: "circle.grid.3x3.fill")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .shadow(color: Color.white.opacity(0.08), radius: 14, x: 0, y: 0)
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
                                            Color.white.opacity(0.10),
                                            Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        }
                        .cornerRadius(10)
                }
            }
            
            // Features
            VStack(alignment: .leading, spacing: 14) {
                FeatureRow(text: AppL10n.t("plans.feature.basic_expense"), accentColor: .white.opacity(0.4))
                FeatureRow(text: AppL10n.t("plans.feature.category_analytics"), accentColor: .white.opacity(0.4))
                FeatureRow(text: AppL10n.t("plans.feature.basic_functions"), accentColor: .white.opacity(0.4))
            }
            .padding(.top, 8)
            
            // Button
            Button(action: {}) {
                Text(isCurrentPlan ? AppL10n.t("plans.current") : AppL10n.t("plans.free"))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .contentShape(Rectangle())
                    .foregroundColor(.white.opacity(0.58))
            }
            .buttonStyle(.plain)
            .liquidGlass(cornerRadius: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.14),
                                Color.blue.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            )
            .disabled(true)
        }
        .padding(26)
        .frame(maxWidth: .infinity)
        .liquidGlass(cornerRadius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.white.opacity(0.05), radius: 18, x: 0, y: 12)
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
                AppL10n.t("plans.feature.bank_connection")
            ]
        case .free:
            return []
        }
    }
    
    var showMostPopular: Bool {
        planType == .pro
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
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                )
                        )
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
                                .shadow(color: Color.white.opacity(0.07), radius: 18, x: 0, y: 0)
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
                
                // In this app, "Pro" is the monthly subscription with a 3-day free trial.
                if planType == .pro {
                    Text(AppL10n.t("plans.monthly_trial_badge"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                        .padding(.bottom, 6)
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
                                    Color.white.opacity(0.10),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        }
                        .cornerRadius(10)
                }
            }
            
            // Features
            VStack(alignment: .leading, spacing: 14) {
                ForEach(planFeatures, id: \.self) { feature in
                    FeatureRow(text: feature, accentColor: accentColor)
                }
            }
            .padding(.top, 8)
            
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
                            Image(systemName: "arrow.up.right.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            accentColor.opacity(0.95),
                                            accentColor.opacity(0.65)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .contentShape(Rectangle())
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .allowsHitTesting(!isCreatingCheckout)
                .background(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.28),
                            Color(red: 0.16, green: 0.76, blue: 1.0).opacity(0.22)
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
                                    Color(red: 0.16, green: 0.76, blue: 1.0).opacity(0.85),
                                    accentColor.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .allowsHitTesting(false)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            Color(red: 0.16, green: 0.76, blue: 1.0).opacity(0.35),
                            style: StrokeStyle(lineWidth: 1, dash: [7, 4])
                        )
                        .allowsHitTesting(false)
                )
                .cornerRadius(14)
                .disabled(isCreatingCheckout)
                .opacity(isCreatingCheckout ? 0.7 : 1.0)
                .scaleEffect(isCreatingCheckout ? 0.98 : 1.0)
                .shadow(color: accentColor.opacity(0.18), radius: 26, x: 0, y: 12)
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
                            Color.white.opacity(planType == .pro ? 0.22 : 0.16),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: planType == .pro ? 1.6 : 1.0
                )
                .allowsHitTesting(false)
        )
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(planType == .pro ? 0.08 : 0.04),
                            Color.white.opacity(planType == .pro ? 0.03 : 0.015)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .allowsHitTesting(false)
        )
        .shadow(
            color: Color.white.opacity(planType == .pro ? 0.08 : 0.05),
            radius: planType == .pro ? 34 : 26,
            x: 0,
            y: planType == .pro ? 16 : 12
        )
    }
}

struct FeatureRow: View {
    let text: String
    var accentColor: Color = .green
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .frame(width: 20, height: 20)
            
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.92))
                .lineSpacing(1.5)
        }
        .alignmentGuide(.leading) { _ in 0 }
        .padding(.vertical, 1)
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
        formatter.locale = AnitaCurrencyDisplay.locale(forCurrencyCode: userCurrency)
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
            return formatSubscriptionPrice(9.99)
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
                AppL10n.t("plans.feature.bank_connection")
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
                        .background(Color.white.opacity(0.08))
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
    
    /// Same blues as Upgrade `Continue` / premium accents (`PremiumFeaturesCard`).
    private let paywallBlueTop = Color(red: 0.11, green: 0.62, blue: 1.0)
    private let paywallBlueBottom = Color(red: 0.20, green: 0.47, blue: 1.0)
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            paywallBlueTop.opacity(0.98),
                            Color.white.opacity(0.82)
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
                                colors: [paywallBlueTop, paywallBlueBottom],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(white: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    paywallBlueTop.opacity(0.20),
                                    paywallBlueBottom.opacity(0.11)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
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

// MARK: - Futuristic fintech background

private struct UpgradeNeonBackground: View {
    var body: some View {
        ZStack {
            // Minimal black background (fintech-like, no heavy color blobs)
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Vignette to focus attention on the cards
            RadialGradient(
                colors: [
                    Color.white.opacity(0.04),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 820
            )
            .ignoresSafeArea()
        }
    }
}

private struct UpgradeNeonGrid: View {
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let step: CGFloat = 34
                let verticalColor = Color(red: 0.16, green: 0.76, blue: 1.0).opacity(0.10)
                let horizontalColor = Color(red: 0.16, green: 0.76, blue: 1.0).opacity(0.09)
                
                for x in stride(from: 0, through: size.width, by: step) {
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(p, with: .color(verticalColor), style: StrokeStyle(lineWidth: 1))
                }
                
                for y in stride(from: 0, through: size.height, by: step) {
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(p, with: .color(horizontalColor), style: StrokeStyle(lineWidth: 1))
                }
                
                // A few diagonal "wire" accents
                let accentColor = Color(red: 0.91, green: 0.72, blue: 0.2).opacity(0.12)
                for i in 0..<6 {
                    let inset = CGFloat(i) * 40
                    var p = Path()
                    p.move(to: CGPoint(x: inset, y: 0))
                    p.addLine(to: CGPoint(x: 0, y: inset))
                    context.stroke(p, with: .color(accentColor), style: StrokeStyle(lineWidth: 1))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

#Preview {
    UpgradeView()
}

