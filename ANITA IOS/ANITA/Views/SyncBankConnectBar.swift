//
//  SyncBankConnectBar.swift
//  ANITA
//
//  Premium-only bank linking CTA (Chat welcome, Settings).
//  Same chrome as `ChatUpgradeBanner`: dark base + subtle paywall-blue wash, soft rim, icon orb.
//

import SwiftUI

extension Notification.Name {
    static let anitaBankSyncCompleted = Notification.Name("anitaBankSyncCompleted")
}

enum BankLinkFlow {
    @MainActor
    static func run(
        subscriptionManager: SubscriptionManager,
        userManager: UserManager,
        onNeedsPremium: @escaping () -> Void,
        isConnecting: Binding<Bool>,
        errorMessage: Binding<String?>,
        onRefresh: @escaping () -> Void
    ) async {
        await subscriptionManager.refresh()
        guard subscriptionManager.isPremium else {
            onNeedsPremium()
            return
        }
        guard userManager.isAuthenticated, let uid = userManager.currentUser?.id, !uid.isEmpty else {
            errorMessage.wrappedValue = AppL10n.t("bank.sync_sign_in_required")
            return
        }
        errorMessage.wrappedValue = nil
        isConnecting.wrappedValue = true
        do {
            let linked = try await BankConnectionTester.shared.startTestFlow(
                userId: uid,
                userEmail: userManager.currentUser?.email
            )
            if linked {
                UserManager.shared.setTransactionDataSource("bank")
                do {
                    try await NetworkService.shared.deleteManualTransactionsOnBankLink(userId: uid)
                } catch {
                    print("[BankLinkFlow] deleteManualTransactionsOnBankLink failed: \(error.localizedDescription)")
                }
                isConnecting.wrappedValue = false
                onRefresh()
                BankSessionSyncController.shared.schedule(userId: uid, trigger: .afterBankLinkSuccess) {
                    onRefresh()
                }
            } else {
                isConnecting.wrappedValue = false
            }
        } catch {
            isConnecting.wrappedValue = false
            errorMessage.wrappedValue = error.localizedDescription
        }
    }
}

// MARK: - Presentation

enum SyncBankConnectPresentation {
    /// Chat welcome: self-contained tinted card + horizontal margin.
    case card
    /// Inside `SettingsCategorySection` glass: one flat row (matches `SettingsRowWithIcon`), no nested panel.
    case settingsGrouped
}

// MARK: - Sync bank (chat card vs settings row)

struct SyncBankConnectBar: View {
    let isVisible: Bool
    @Binding var isConnecting: Bool
    let onNeedsPremium: () -> Void
    let onRefresh: () -> Void
    var presentation: SyncBankConnectPresentation = .card
    
    /// Matches `ChatUpgradeBanner` / premium paywall blues.
    private let paywallBlueTop = Color(red: 0.11, green: 0.62, blue: 1.0)
    private let paywallBlueBottom = Color(red: 0.20, green: 0.47, blue: 1.0)
    /// Same accent as subscription row icons in Settings.
    private let settingsIconAccent = Color(red: 0.4, green: 0.49, blue: 0.92)
    
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var userManager = UserManager.shared
    @State private var errorMessage: String?
    @State private var showDeleteManualConfirm = false
    
    private var isCard: Bool { presentation == .card }
    
    var body: some View {
        if isVisible {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showDeleteManualConfirm = true
                } label: {
                    HStack(alignment: .center, spacing: isCard ? 10 : 16) {
                        if isCard {
                            chatIconOrb
                        } else {
                            settingsIconOrb
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AppL10n.t("bank.sync_bank"))
                                .font(.system(size: isCard ? 15 : 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(isCard ? 0.86 : 0.95))
                                .lineLimit(1)
                                .allowsTightening(true)
                                .minimumScaleFactor(0.85)
                            
                            if isConnecting {
                                Text(AppL10n.t("finance.loading"))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.45))
                            } else {
                                Text(AppL10n.t("bank.sync_bank_hint"))
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(isCard ? 0.5 : 0.55))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if isConnecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.85)))
                                .scaleEffect(0.95)
                        } else {
                            Text(AppL10n.t("bank.link_now"))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.95))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .padding(.horizontal, isCard ? 14 : 12)
                                .padding(.vertical, isCard ? 10 : 8)
                                .background(linkCapsuleBackground)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(SyncBankRowContainerModifier(
                        isCard: isCard,
                        paywallBlueTop: paywallBlueTop,
                        paywallBlueBottom: paywallBlueBottom
                    ))
                }
                .buttonStyle(SyncBankRowButtonStyle())
                .disabled(isConnecting)
                .opacity(isConnecting ? 0.92 : 1)
                .accessibilityLabel("\(AppL10n.t("bank.sync_bank")), \(AppL10n.t("bank.link_now"))")
                
                if let err = errorMessage, !err.isEmpty {
                    Text(err)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.orange.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, isCard ? 4 : 20)
                }
            }
            .padding(.horizontal, isCard ? 20 : 0)
            .padding(.bottom, isCard ? 2 : 0)
            .alert(
                AppL10n.t("bank.connect_deletes_manual_title"),
                isPresented: $showDeleteManualConfirm
            ) {
                Button(AppL10n.t("common.cancel"), role: .cancel) {}
                Button(AppL10n.t("bank.connect_deletes_manual_continue")) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task {
                        await BankLinkFlow.run(
                            subscriptionManager: subscriptionManager,
                            userManager: userManager,
                            onNeedsPremium: onNeedsPremium,
                            isConnecting: $isConnecting,
                            errorMessage: $errorMessage,
                            onRefresh: onRefresh
                        )
                    }
                }
            } message: {
                Text(
                    "\(AppL10n.t("bank.connect_deletes_manual_intro"))\n\n\(AppL10n.t("bank.connect_deletes_manual_warning"))"
                )
            }
        }
    }
    
    @ViewBuilder
    private var linkCapsuleBackground: some View {
        if isCard {
            Capsule()
                .fill(Color.white.opacity(0.14))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
        } else {
            Capsule()
                .fill(settingsIconAccent.opacity(0.18))
                .overlay(
                    Capsule()
                        .stroke(settingsIconAccent.opacity(0.35), lineWidth: 1)
                )
        }
    }
    
    /// Same orb treatment as `ChatUpgradeBanner` crown chip; icon uses paywall blue (Premium card style).
    private var chatIconOrb: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 40, height: 40)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
            
            Image(systemName: "link.badge.plus")
                .font(.system(size: 17, weight: .semibold))
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
        }
        .frame(width: 40, height: 40)
    }
    
    /// Matches `SettingsRowWithIcon` glass circle + crown-row accent (no second card inside the section).
    private var settingsIconOrb: some View {
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
            
            Image(systemName: "link.badge.plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            settingsIconAccent.opacity(0.95),
                            settingsIconAccent.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: - Row chrome (card vs flat settings row)

private struct SyncBankRowContainerModifier: ViewModifier {
    let isCard: Bool
    let paywallBlueTop: Color
    let paywallBlueBottom: Color
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if isCard {
            content
                .frame(height: 64)
                .padding(.leading, 14)
                .padding(.trailing, 16)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(white: 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                }
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
        } else {
            content
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.clear)
        }
    }
}

/// Same press feedback as chat task rows / upgrade banner interactions.
private struct SyncBankRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
