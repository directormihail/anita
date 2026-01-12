//
//  ContentView.swift
//  ANITA
//
//  Main navigation view matching webapp design with bottom navigation
//

import SwiftUI

enum AuthViewState {
    case welcome
    case login
    case signUp
}

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var selectedTab = 0
    @State private var authViewState: AuthViewState = .welcome
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                mainContentView
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
    }
    
    private var mainContentView: some View {
        ZStack {
            // Black background matching webapp
            Color.black
                .ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                ChatView()
                    .tabItem {
                        Label("Chat", systemImage: "message.fill")
                    }
                    .tag(0)
                
                FinanceView()
                    .tabItem {
                        Label("Finance", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(1)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
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
                            authViewState = .signUp
                        }
                    }
                )
                
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
}

#Preview {
    ContentView()
}
