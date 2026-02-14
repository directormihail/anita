//
//  PostSignupPlansView.swift
//  ANITA
//
//  Shown right after account creation (before entering the app).
//

import SwiftUI

struct PostSignupPlansView: View {
    @StateObject private var storeKitService = StoreKitService.shared
    @State private var databaseSubscription: Subscription?
    
    private let networkService = NetworkService.shared
    let onContinue: () -> Void
    
    // Determine current plan - prioritize database subscription over StoreKit. Only Free/Premium now; legacy "ultimate" → "pro".
    private var currentPlan: String {
        if let subscription = databaseSubscription, subscription.status == "active" {
            return (subscription.plan == "pro" || subscription.plan == "ultimate") ? "pro" : "free"
        }
        if storeKitService.isPurchased("com.anita.pro.monthly") {
            return "pro"
        }
        return "free"
    }
    
    private var cancelAnytimeSubtitle: String {
        let lang = AppL10n.currentLanguageCode()
        switch lang {
        case "de":
            return "Du kannst jederzeit kündigen."
        case "fr":
            return "Tu peux annuler ton abonnement à tout moment."
        case "es":
            return "Puedes cancelar tu suscripción en cualquier momento."
        case "it":
            return "Puoi annullare l’abbonamento in qualsiasi momento."
        case "pl":
            return "Możesz anulować subskrypcję w dowolnym momencie."
        case "ru":
            return "Вы можете отменить подписку в любое время."
        case "tr":
            return "Aboneliğini istediğin zaman iptal edebilirsin."
        case "uk":
            return "Ви можете скасувати підписку в будь-який час."
        default:
            return "Cancel your subscription anytime."
        }
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
                            FreePlanCard(isCurrentPlan: currentPlan == "free")
                            
                            SubscriptionPlanCard(
                                planType: .pro,
                                isCurrentPlan: currentPlan == "pro",
                                isCreatingCheckout: storeKitService.isLoading,
                                price: storeKitService.getProduct("com.anita.pro.monthly")?.displayPrice ?? "€4.99",
                                onCheckout: { Task { await purchasePlan(productId: "com.anita.pro.monthly") } }
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        if let error = storeKitService.errorMessage {
                            Text(error)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.red.opacity(0.9))
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
                storeKitService.errorMessage = AppL10n.t("plans.checkout_error")
            }
            return
        }
        
        await MainActor.run {
            storeKitService.errorMessage = nil
        }
        
        do {
            _ = try await storeKitService.purchase(product)
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
}

