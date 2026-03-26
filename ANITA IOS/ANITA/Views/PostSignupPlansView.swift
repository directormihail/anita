//
//  PostSignupPlansView.swift
//  ANITA
//
//  Shown right after account creation (before entering the app).
//

import SwiftUI
import UIKit

struct PostSignupPlansView: View {
    @StateObject private var storeKitService = StoreKitService.shared
    @State private var databaseSubscription: Subscription?
    @State private var isRestoring = false
    @State private var showMonthlyTrialConfirmation = false
    @State private var pendingMonthlyTrialProductId: String?
    
    private let networkService = NetworkService.shared
    let onContinue: () -> Void

    private let monthlyProductId = "com.anita.pro.monthly"
    
    // Determine current plan - prioritize database subscription over StoreKit. Free or Premium.
    private var currentPlan: String {
        if let subscription = databaseSubscription, subscription.status == "active" {
            return (subscription.plan == "premium" || subscription.plan == "pro" || subscription.plan == "ultimate") ? "premium" : "free"
        }
        if storeKitService.isPurchased("com.anita.pro.monthly") || storeKitService.isPurchased("com.anita.pro.lifetime") {
            return "premium"
        }
        return "free"
    }
    
    private var hasMonthlyEntitlement: Bool {
        storeKitService.isPurchased(monthlyProductId)
    }
    
    /// User's currency from database (profiles.currency_code), synced to UserDefaults.
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
    
    private var cancelAnytimeSubtitle: String {
        AppL10n.t("plans.monthly_fully_protected")
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 14) {
                    Text(AppL10n.t("upgrade.title"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.98))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    Text(cancelAnytimeSubtitle)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                .padding(.top, 18)
                .padding(.bottom, 10)
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 18) {
                            FreePlanCard(isCurrentPlan: currentPlan == "free", price: formatSubscriptionPrice(0))
                            
                            SubscriptionPlanCard(
                                planType: .pro,
                                isCurrentPlan: currentPlan == "premium",
                                isCreatingCheckout: storeKitService.isLoading,
                                price: formatSubscriptionPrice(4.99),
                                onCheckout: { requestMonthlyTrialPurchase(productId: monthlyProductId) }
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Restore Purchases (required for App Store review)
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
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .foregroundColor(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .disabled(storeKitService.isLoading || isRestoring)
                        .padding(.top, 8)

                        if currentPlan == "premium" || hasMonthlyEntitlement {
                            Button(action: openSubscriptionManagement) {
                                Text(AppL10n.t("settings.cancel_subscription"))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.75))
                                    .underline()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                        
                        Text(AppL10n.t("plans.cancel_subscription_hint"))
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                        
                        Text(AppL10n.t("plans.subscription_terms"))
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 2)
                        
                        Text(AppL10n.t("plans.disclaimer_financial"))
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 6)
                        
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
                                if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
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
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                        
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
                        }
                        
                        Button(action: onContinue) {
                            Text(AppL10n.t("common.next"))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .liquidGlass(cornerRadius: 14)
                        }
                        .buttonStyle(PremiumButtonStyle())
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                        .padding(.bottom, 30)
                    }
                    .padding(.top, 14)
                }
            }
        }
        .task {
            await loadSubscriptionFromDatabase()
        }
        .alert(
            AppL10n.t("plans.monthly_trial_alert_title"),
            isPresented: $showMonthlyTrialConfirmation
        ) {
            Button(AppL10n.t("plans.monthly_trial_alert_start")) {
                guard let productId = pendingMonthlyTrialProductId else { return }
                Task { await purchasePlan(productId: productId) }
            }
            Button(AppL10n.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(AppL10n.t("plans.monthly_trial_alert_body"))
        }
    }
    
    private func loadSubscriptionFromDatabase() async {
        let userId = UserManager.shared.userId
        do {
            let response = try await networkService.getSubscription(userId: userId)
            await MainActor.run {
                databaseSubscription = response.subscription
            }
        } catch {
            // Non-fatal
            print("[PostSignupPlansView] Error loading subscription: \(error.localizedDescription)")
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
        } catch StoreKitError.userCancelled {
            // User cancelled
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

    private func requestMonthlyTrialPurchase(productId: String) {
        pendingMonthlyTrialProductId = productId
        showMonthlyTrialConfirmation = true
    }

    private func openSubscriptionManagement() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
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
        await MainActor.run { isRestoring = false }
    }
}

