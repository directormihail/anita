//
//  ANITAApp.swift
//  ANITA
//
//  Created for ANITA iOS App
//

import SwiftUI
import UserNotifications
import PostHog

@main
struct ANITAApp: App {
    @AppStorage("anita_preferred_language_code") private var preferredLanguageCode: String = "en"
    
    init() {
        // PostHog analytics (US cloud)
        let posthogConfig = PostHogConfig(apiKey: Config.posthogAPIKey, host: Config.posthogHost)
        PostHogSDK.shared.setup(posthogConfig)
        
        // Initialize notification service (permission is requested on welcome chat screen after registration)
        Task { @MainActor in
            NotificationService.shared.checkAuthorizationStatus()
        }
        
        // Configure navigation bar appearance globally for transparent glassy effect
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithTransparentBackground()
        navBarAppearance.backgroundColor = UIColor.clear
        navBarAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        navBarAppearance.shadowColor = UIColor.clear // Remove shadow line
        
        // Set for all navigation bar styles
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        if #available(iOS 15.0, *) {
            UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        }
        
        // Configure navigation bar button colors
        UINavigationBar.appearance().tintColor = UIColor(red: 0.4, green: 0.49, blue: 0.92, alpha: 1.0)
        
        // Make navigation bar transparent
        UINavigationBar.appearance().isTranslucent = true
        
        // Configure tab bar appearance globally for transparent glassy effect
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = UIColor.clear
        tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        tabBarAppearance.shadowColor = UIColor.clear
        
        // Selected item
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0.4, green: 0.49, blue: 0.92, alpha: 1.0)
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.4, green: 0.49, blue: 0.92, alpha: 1.0)
        ]
        
        // Normal item
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(white: 0.8, alpha: 1.0)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(white: 0.8, alpha: 1.0)
        ]
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().isTranslucent = true
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, Locale(identifier: AppL10n.localeIdentifier(for: preferredLanguageCode)))
        }
    }
}

