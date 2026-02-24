//
//  ContentView.swift
//  ANITA
//
//  Main navigation view matching webapp design with bottom navigation
//

import SwiftUI

enum AuthViewState {
    case welcome
    case onboarding
    case login
    case signUp
}

private let hasShownFirstLaunchNotificationPromptKey = "anita_has_shown_first_launch_notification_prompt"

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var userManager = UserManager.shared
    @State private var selectedTab = 0
    @State private var authViewState: AuthViewState = .welcome
    @State private var showFirstLaunchNotificationPrompt = false
    
    var body: some View {
        Group {
            if !authViewModel.hasCompletedInitialAuthCheck {
                // Don't show login until we've tried restoring session from Keychain
                loadingView
            } else if userManager.recoveryModeNeedsPassword {
                // Opened from password reset link; user must set new password
                ResetPasswordView()
            } else if authViewModel.isAuthenticated {
                if userManager.shouldShowPostSignupPlans {
                    PostSignupPlansView {
                        userManager.completePostSignupPlans()
                    }
                } else if userManager.hasCompletedOnboarding {
                    mainContentView
                        .onAppear {
                            if !UserDefaults.standard.bool(forKey: hasShownFirstLaunchNotificationPromptKey) {
                                showFirstLaunchNotificationPrompt = true
                            }
                        }
                        .sheet(isPresented: $showFirstLaunchNotificationPrompt) {
                            FirstLaunchNotificationSheet(
                                onEnable: {
                                    UserDefaults.standard.set(true, forKey: hasShownFirstLaunchNotificationPromptKey)
                                    showFirstLaunchNotificationPrompt = false
                                    NotificationService.shared.pushNotificationsEnabled = true
                                },
                                onNotNow: {
                                    UserDefaults.standard.set(true, forKey: hasShownFirstLaunchNotificationPromptKey)
                                    showFirstLaunchNotificationPrompt = false
                                }
                            )
                        }
                } else {
                    OnboardingView { survey in
                        userManager.completeOnboarding(survey: survey)
                    }
                }
            } else {
                authContentView
            }
        }
        .task {
            await authViewModel.checkAuthStatus()
        }
        .onChange(of: authViewModel.isAuthenticated) { _, newValue in
            // When user signs out, reset to welcome page
            if !newValue {
                withAnimation {
                    authViewState = .welcome
                    selectedTab = 0
                }
            }
        }
        .onOpenURL { url in
            handleAuthURL(url)
        }
        .dismissKeyboardOnTap()
    }
    
    /// Shown while restoring session from Keychain so we don't flash the login screen for logged-in users.
    private var loadingView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.4, green: 0.49, blue: 0.92)))
                .scaleEffect(1.2)
        }
    }
    
    private var mainContentView: some View {
        ZStack {
            // Black background matching webapp
            Color.black
                .ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                ChatView()
                    .tabItem {
                        Label(AppL10n.t("tab.chat"), systemImage: "message.fill")
                    }
                    .tag(0)
                
                FinanceView()
                    .tabItem {
                        Label(AppL10n.t("tab.finance"), systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(1)
                
                SettingsView(selectedTab: $selectedTab)
                    .tabItem {
                        Label(AppL10n.t("tab.settings"), systemImage: "gearshape.fill")
                    }
                    .tag(2)
            }
            .accentColor(Color(red: 0.4, green: 0.49, blue: 0.92)) // #667eea purple accent
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToFinanceTab"))) { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedTab = 1
                }
            }
            .onAppear {
                // Customize tab bar appearance with transparent liquid glass effect
                let appearance = UITabBarAppearance()
                appearance.configureWithTransparentBackground()
                
                // Fully transparent background
                appearance.backgroundColor = UIColor.clear
                
                // Use ultra thin material for liquid glass blur effect
                appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
                
                // Remove shadow for clean transparent look
                appearance.shadowColor = UIColor.clear
                
                // Selected item styling
                appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0.4, green: 0.49, blue: 0.92, alpha: 1.0)
                appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                    .foregroundColor: UIColor(red: 0.4, green: 0.49, blue: 0.92, alpha: 1.0)
                ]
                
                // Schedule daily transaction reminder (refreshes message when app opens)
                Task { @MainActor in
                    NotificationService.shared.scheduleDailyTransactionReminder()
                }
                // Preload XP so Finance tab and sidebar show Level card immediately
                Task { await XPStore.shared.refresh() }
                
                // Normal item styling with slight transparency
                appearance.stackedLayoutAppearance.normal.iconColor = UIColor(white: 0.8, alpha: 0.8)
                appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                    .foregroundColor: UIColor(white: 0.8, alpha: 0.8)
                ]
                
                // Apply appearance settings
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().isTranslucent = true
                UITabBar.appearance().backgroundColor = UIColor.clear
                UITabBar.appearance().barTintColor = UIColor.clear
                
                // Apply to scroll edge appearance for iOS 15+
                if #available(iOS 15.0, *) {
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                }
            }
        }
    }
    
    private var authContentView: some View {
        Group {
            switch authViewState {
            case .welcome:
                WelcomeView(
                    onShowLogin: {
                        withAnimation {
                            authViewState = .login
                        }
                    },
                    onShowSignUp: {
                        withAnimation {
                            authViewState = .onboarding
                        }
                    }
                )
                
            case .onboarding:
                OnboardingView { survey in
                    // Pre-auth onboarding: save locally + apply language, then proceed to account creation.
                    userManager.savePreAuthOnboarding(survey: survey)
                    withAnimation {
                        authViewState = .signUp
                    }
                }
                
            case .login:
                LoginView(
                    onAuthSuccess: {
                        Task {
                            await authViewModel.checkAuthStatus()
                        }
                    },
                    onBack: {
                        withAnimation {
                            authViewState = .welcome
                        }
                    }
                )
                
            case .signUp:
                SignUpView(
                    onAuthSuccess: {
                        Task {
                            await authViewModel.checkAuthStatus()
                        }
                    },
                    onBack: {
                        withAnimation {
                            authViewState = .welcome
                        }
                    }
                )
            }
        }
    }
    
    /// Handle anita:// URL from password reset link (e.g. anita://auth/callback#access_token=...&refresh_token=...&type=recovery).
    private func handleAuthURL(_ url: URL) {
        guard url.scheme == "anita", let fragment = url.fragment, !fragment.isEmpty else { return }
        let params = parseFragment(fragment)
        guard params["type"] == "recovery",
              let accessToken = params["access_token"], !accessToken.isEmpty,
              let refreshToken = params["refresh_token"], !refreshToken.isEmpty else { return }
        Task {
            await userManager.setRecoverySession(accessToken: accessToken, refreshToken: refreshToken)
        }
    }
    
    private func parseFragment(_ fragment: String) -> [String: String] {
        var result: [String: String] = [:]
        for part in fragment.split(separator: "&") {
            let pair = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if pair.count == 2, let key = String(pair[0]).removingPercentEncoding, let value = String(pair[1]).removingPercentEncoding {
                result[key] = value
            }
        }
        return result
    }
}

// MARK: - First launch notification prompt (shown once when user opens the app for the first time)
struct FirstLaunchNotificationSheet: View {
    var onEnable: () -> Void
    var onNotNow: () -> Void
    
    private let accentColor = Color(red: 0.4, green: 0.49, blue: 0.92)
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 28) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(accentColor)
                    Text(AppL10n.t("first_launch_notification.title"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Text(AppL10n.t("first_launch_notification.body"))
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    VStack(spacing: 14) {
                        Button(action: onEnable) {
                            Text(AppL10n.t("first_launch_notification.enable"))
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .background(accentColor)
                        .cornerRadius(14)
                        Button(action: onNotNow) {
                            Text(AppL10n.t("first_launch_notification.not_now"))
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}
