//
//  PostSignupPlansView.swift
//  ANITA
//
//  Shown right after account creation (before entering the app).
//

import SwiftUI

struct PostSignupPlansView: View {
    @StateObject private var storeKitService = StoreKitService.shared
    @State private var isCreatingCheckout = false
    @State private var checkoutError: String?
    @State private var databaseSubscription: Subscription?
    @State private var showSafariView = false
    @State private var checkoutURL: URL?
    
    private let networkService = NetworkService.shared
    let onContinue: () -> Void
    
    // Determine current plan - prioritize database subscription over StoreKit
    private var currentPlan: String {
        if let subscription = databaseSubscription, subscription.status == "active" {
            return subscription.plan
        }
        if storeKitService.isPurchased("com.anita.ultimate.monthly") {
            return "ultimate"
        } else if storeKitService.isPurchased("com.anita.pro.monthly") {
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
                                isCreatingCheckout: isCreatingCheckout,
                                price: "$4.99",
                                onCheckout: { Task { await createCheckoutSession(plan: "pro") } }
                            )
                            
                            SubscriptionPlanCard(
                                planType: .ultimate,
                                isCurrentPlan: currentPlan == "ultimate",
                                isCreatingCheckout: isCreatingCheckout,
                                price: "$9.99",
                                onCheckout: { Task { await createCheckoutSession(plan: "ultimate") } }
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        if let error = checkoutError {
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
        .sheet(isPresented: $showSafariView) {
            if let url = checkoutURL {
                SafariView(url: url)
                    .onDisappear {
                        Task { await loadSubscriptionFromDatabase() }
                    }
            }
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
    
    private func createCheckoutSession(plan: String) async {
        await MainActor.run {
            isCreatingCheckout = true
            checkoutError = nil
        }
        
        let userId = UserManager.shared.userId
        let userEmail = UserManager.shared.currentUser?.email
        
        do {
            let response = try await networkService.createCheckoutSession(
                plan: plan,
                userId: userId,
                userEmail: userEmail
            )
            
            if let urlString = response.url, let url = URL(string: urlString) {
                await MainActor.run {
                    checkoutURL = url
                    showSafariView = true
                    isCreatingCheckout = false
                }
            } else {
                await MainActor.run {
                    checkoutError = "Failed to create checkout session. Please try again."
                    isCreatingCheckout = false
                }
            }
        } catch {
            await MainActor.run {
                checkoutError = error.localizedDescription
                isCreatingCheckout = false
            }
        }
    }
}

