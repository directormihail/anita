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
                // Customize tab bar appearance to match webapp
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor.black
                appearance.shadowColor = UIColor.clear
                
                // Selected item
                appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0.4, green: 0.49, blue: 0.92, alpha: 1.0)
                appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                    .foregroundColor: UIColor(red: 0.4, green: 0.49, blue: 0.92, alpha: 1.0)
                ]
                
                // Normal item
                appearance.stackedLayoutAppearance.normal.iconColor = UIColor(white: 0.8, alpha: 1.0)
                appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                    .foregroundColor: UIColor(white: 0.8, alpha: 1.0)
                ]
                
                UITabBar.appearance().standardAppearance = appearance
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
