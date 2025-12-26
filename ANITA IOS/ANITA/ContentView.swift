//
//  ContentView.swift
//  ANITA
//
//  Main navigation view matching webapp design with bottom navigation
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
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
}

#Preview {
    ContentView()
}
