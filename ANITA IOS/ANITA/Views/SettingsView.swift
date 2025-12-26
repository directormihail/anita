//
//  SettingsView.swift
//  ANITA
//
//  Settings view matching webapp design
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var userManager = UserManager.shared
    @State private var backendURL: String = UserDefaults.standard.string(forKey: "backendURL") ?? Config.backendURL
    @State private var showBackendURLAlert = false
    @State private var healthStatus: String?
    @State private var isCheckingHealth = false
    @State private var showPrivacyPolicy = false
    @State private var privacyPolicy: PrivacyResponse?
    @State private var showAuthSheet = false
    @State private var authEmail = ""
    @State private var authPassword = ""
    @State private var isSignUp = false
    @State private var authError: String?
    @State private var isTestingSupabase = false
    @State private var supabaseTestResult: String?
    
    private let networkService = NetworkService.shared
    private let supabaseService = SupabaseService.shared
    
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
                    
                    // Authentication
                    SettingsSection(title: "Authentication") {
                        VStack(spacing: 0) {
                            if userManager.isAuthenticated, let user = userManager.currentUser {
                                SettingsRow(
                                    title: "Signed in as",
                                    value: user.email ?? user.id,
                                    showChevron: false
                                ) {}
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.leading, 20)
                                
                                Button(action: {
                                    userManager.signOut()
                                }) {
                                    HStack {
                                        Spacer()
                                        Text("Sign Out")
                                            .font(.body)
                                            .foregroundColor(.red)
                                        Spacer()
                                    }
                                    .padding(.vertical, 16)
                                }
                            } else {
                                Button(action: {
                                    showAuthSheet = true
                                }) {
                                    HStack {
                                        Spacer()
                                        Text("Sign In / Sign Up")
                                            .font(.body)
                                            .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                                        Spacer()
                                    }
                                    .padding(.vertical, 16)
                                }
                            }
                        }
                    }
                    
                    // Supabase Status
                    SettingsSection(title: "Supabase Status") {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Configuration")
                                    .font(.body)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if Config.isConfigured {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Configured")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.yellow)
                                        Text("Not Configured")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.leading, 20)
                            
                            HStack {
                                if isTestingSupabase {
                                    ProgressView()
                                        .tint(Color(red: 0.4, green: 0.49, blue: 0.92))
                                    Text("Testing...")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                } else if let result = supabaseTestResult {
                                    HStack(spacing: 8) {
                                        Image(systemName: result == "Success" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(result == "Success" ? .green : .red)
                                        Text(result)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.leading, 20)
                            
                            Button(action: {
                                testSupabaseConnection()
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Test Connection")
                                        .font(.body)
                                        .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                                    Spacer()
                                }
                                .padding(.vertical, 16)
                            }
                        }
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
                                .background(Color.white.opacity(0.1))
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
                                        Text(status == "ok" ? "Connected" : status == "error" ? "Failed" : status)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            
                            // Show backend URL and helpful message
                            VStack(alignment: .leading, spacing: 4) {
                                if !backendURL.isEmpty {
                                    Text("Backend: \(backendURL)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                if healthStatus == "error" {
                                    Text("💡 Make sure backend is running: cd 'ANITA backend' && npm run dev")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                        .padding(.top, 4)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
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
                                .background(Color.white.opacity(0.1))
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
                                .background(Color.white.opacity(0.1))
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
                                .background(Color.white.opacity(0.1))
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
        .sheet(isPresented: $showAuthSheet) {
            AuthSheet(
                email: $authEmail,
                password: $authPassword,
                isSignUp: $isSignUp,
                error: $authError,
                onSignIn: {
                    Task {
                        do {
                            print("[Settings] Attempting sign in with email: \(authEmail)")
                            try await userManager.signIn(email: authEmail, password: authPassword)
                            await MainActor.run {
                                showAuthSheet = false
                                authEmail = ""
                                authPassword = ""
                                authError = nil
                            }
                        } catch {
                            print("[Settings] Sign in error: \(error)")
                            await MainActor.run {
                                authError = error.localizedDescription
                            }
                        }
                    }
                },
                onSignUp: {
                    Task {
                        do {
                            print("[Settings] Attempting sign up with email: \(authEmail)")
                            try await userManager.signUp(email: authEmail, password: authPassword)
                            await MainActor.run {
                                showAuthSheet = false
                                authEmail = ""
                                authPassword = ""
                                authError = nil
                            }
                        } catch {
                            print("[Settings] Sign up error: \(error)")
                            await MainActor.run {
                                authError = error.localizedDescription
                            }
                        }
                    }
                }
            )
        }
    }
    
    private func checkHealth() {
        isCheckingHealth = true
        healthStatus = nil
        
        print("[Settings] Checking health at: \(backendURL)/health")
        
        Task {
            do {
                let response = try await networkService.checkHealth()
                print("[Settings] Health check successful: \(response.status)")
                await MainActor.run {
                    healthStatus = response.status
                    isCheckingHealth = false
                }
            } catch {
                print("[Settings] Health check failed: \(error.localizedDescription)")
                if let networkError = error as? NetworkError {
                    print("[Settings] Network error details: \(networkError)")
                }
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
    
    private func testSupabaseConnection() {
        guard Config.isConfigured else {
            supabaseTestResult = "Not Configured"
            return
        }
        
        isTestingSupabase = true
        supabaseTestResult = nil
        
        Task {
            do {
                let success = try await supabaseService.testConnection()
                await MainActor.run {
                    isTestingSupabase = false
                    supabaseTestResult = success ? "Success" : "Failed"
                }
            } catch {
                await MainActor.run {
                    isTestingSupabase = false
                    supabaseTestResult = "Error: \(error.localizedDescription)"
                }
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
                .liquidGlass(cornerRadius: 12)
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
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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

struct AuthSheet: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var isSignUp: Bool
    @Binding var error: String?
    let onSignIn: () -> Void
    let onSignUp: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                    
                    if let error = error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button(action: {
                        if isSignUp {
                            onSignUp()
                        } else {
                            onSignIn()
                        }
                    }) {
                        Text(isSignUp ? "Sign Up" : "Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0.4, green: 0.49, blue: 0.92))
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        isSignUp.toggle()
                        error = nil
                    }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.subheadline)
                            .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                    }
                }
                .padding()
            }
            .navigationTitle(isSignUp ? "Sign Up" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
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
