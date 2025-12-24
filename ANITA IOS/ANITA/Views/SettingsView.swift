//
//  SettingsView.swift
//  ANITA
//
//  Settings view matching webapp design
//

import SwiftUI

struct SettingsView: View {
    @State private var backendURL: String = UserDefaults.standard.string(forKey: "backendURL") ?? "http://localhost:3001"
    @State private var showBackendURLAlert = false
    @State private var healthStatus: String?
    @State private var isCheckingHealth = false
    @State private var showPrivacyPolicy = false
    @State private var privacyPolicy: PrivacyResponse?
    
    private let networkService = NetworkService.shared
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Settings")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 8)
                    }
                    
                    // Backend Configuration
                    SettingsSection(title: "Backend Configuration") {
                        VStack(spacing: 0) {
                            SettingsRow(
                                title: "Backend URL",
                                value: backendURL,
                                showChevron: false
                            ) {
                                TextField("http://localhost:3001", text: $backendURL)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            
                            Divider()
                                .background(Color(white: 0.2))
                                .padding(.leading, 20)
                            
                            Button(action: {
                                UserDefaults.standard.set(backendURL, forKey: "backendURL")
                                networkService.updateBaseURL(backendURL)
                                showBackendURLAlert = true
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Save URL")
                                        .font(.body)
                                        .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                                    Spacer()
                                }
                                .padding(.vertical, 16)
                            }
                        }
                    }
                    
                    // Connection Status
                    SettingsSection(title: "Connection Status") {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Health Check")
                                    .font(.body)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if isCheckingHealth {
                                    ProgressView()
                                        .tint(Color(red: 0.4, green: 0.49, blue: 0.92))
                                } else if let status = healthStatus {
                                    HStack(spacing: 8) {
                                        Image(systemName: status == "ok" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(status == "ok" ? .green : .red)
                                        Text(status == "ok" ? "Connected" : "Error")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            
                            Divider()
                                .background(Color(white: 0.2))
                                .padding(.leading, 20)
                            
                            Button(action: {
                                checkHealth()
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Check Connection")
                                        .font(.body)
                                        .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                                    Spacer()
                                }
                                .padding(.vertical, 16)
                            }
                        }
                    }
                    
                    // Subscription
                    SettingsSection(title: "Subscription") {
                        VStack(spacing: 0) {
                            Button(action: {
                                createCheckoutSession(plan: "pro")
                            }) {
                                SettingsRow(
                                    title: "Pro Plan",
                                    value: "$4.99/month",
                                    showChevron: true
                                ) {}
                            }
                            
                            Divider()
                                .background(Color(white: 0.2))
                                .padding(.leading, 20)
                            
                            Button(action: {
                                createCheckoutSession(plan: "ultimate")
                            }) {
                                SettingsRow(
                                    title: "Ultimate Plan",
                                    value: "$9.99/month",
                                    showChevron: true
                                ) {}
                            }
                        }
                    }
                    
                    // Information
                    SettingsSection(title: "Information") {
                        VStack(spacing: 0) {
                            Button(action: {
                                loadPrivacyPolicy()
                            }) {
                                SettingsRow(
                                    title: "Privacy Policy",
                                    value: nil,
                                    showChevron: true
                                ) {}
                            }
                            
                            Divider()
                                .background(Color(white: 0.2))
                                .padding(.leading, 20)
                            
                            Link(destination: URL(string: "https://anita.app")!) {
                                SettingsRow(
                                    title: "Visit Website",
                                    value: nil,
                                    showChevron: true
                                ) {}
                            }
                        }
                    }
                    
                    // About
                    SettingsSection(title: "About") {
                        VStack(spacing: 0) {
                            SettingsRow(
                                title: "Version",
                                value: "1.0.0",
                                showChevron: false
                            ) {}
                            
                            Divider()
                                .background(Color(white: 0.2))
                                .padding(.leading, 20)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ANITA - Your Personal Finance AI Assistant")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                            }
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Backend URL Saved", isPresented: $showBackendURLAlert) {
            Button("OK") { }
        } message: {
            Text("Please restart the app for the new URL to take effect.")
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            if let policy = privacyPolicy {
                PrivacyPolicyView(policy: policy)
            }
        }
    }
    
    private func checkHealth() {
        isCheckingHealth = true
        healthStatus = nil
        
        Task {
            do {
                let response = try await networkService.checkHealth()
                await MainActor.run {
                    healthStatus = response.status
                    isCheckingHealth = false
                }
            } catch {
                await MainActor.run {
                    healthStatus = "error"
                    isCheckingHealth = false
                }
            }
        }
    }
    
    private func loadPrivacyPolicy() {
        Task {
            do {
                let policy = try await networkService.getPrivacyPolicy()
                await MainActor.run {
                    privacyPolicy = policy
                    showPrivacyPolicy = true
                }
            } catch {
                // Handle error
            }
        }
    }
    
    private func createCheckoutSession(plan: String) {
        let userId = UserDefaults.standard.string(forKey: "userId") ?? UUID().uuidString
        UserDefaults.standard.set(userId, forKey: "userId")
        
        Task {
            do {
                let response = try await networkService.createCheckoutSession(
                    plan: plan,
                    userId: userId,
                    userEmail: nil
                )
                
                if let urlString = response.url, let url = URL(string: urlString) {
                    await MainActor.run {
                        UIApplication.shared.open(url)
                    }
                }
            } catch {
                // Handle error
            }
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.gray)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 8)
            
            content
                .background(Color(white: 0.1))
                .cornerRadius(12)
                .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    let value: String?
    let showChevron: Bool
    let content: Content
    
    init(title: String, value: String?, showChevron: Bool, @ViewBuilder content: () -> Content) {
        self.title = title
        self.value = value
        self.showChevron = showChevron
        self.content = content()
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .font(.body)
                    .foregroundColor(.gray)
            }
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            
            content
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct PrivacyPolicyView: View {
    let policy: PrivacyResponse
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Privacy Policy")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Data Collection")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(policy.dataCollection)
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Data Usage")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(policy.dataUsage)
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Data Sharing")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(policy.dataSharing)
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                        
                        if let url = URL(string: policy.privacyPolicy) {
                            Link("Full Privacy Policy", destination: url)
                                .font(.headline)
                                .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                        }
                        
                        Text("Contact: \(policy.contact)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                }
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
