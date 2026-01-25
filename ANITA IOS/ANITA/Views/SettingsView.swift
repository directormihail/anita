//
//  SettingsView.swift
//  ANITA
//
//  Settings view with professional finance app design
//

import SwiftUI
import UniformTypeIdentifiers
import AuthenticationServices

struct SettingsView: View {
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var notificationService = NotificationService.shared
    @State private var showPrivacyPolicy = false
    @State private var privacyPolicy: PrivacyResponse?
    @State private var showAuthSheet = false
    @State private var authEmail = ""
    @State private var authPassword = ""
    @State private var isSignUp = false
    @State private var authError: String?
    
    // Profile
    @State private var profileName: String = ""
    @State private var isSavingName = false
    
    // Preferences
    @State private var selectedCurrency: String = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    @State private var dateFormat: String = UserDefaults.standard.string(forKey: "anita_date_format") ?? "MM/DD/YYYY"
    @State private var numberFormat: String = {
        let currency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        switch currency {
        case "EUR":
            return "1.234,56"
        case "USD", "GBP", "CAD", "AUD", "NZD", "SGD", "HKD":
            return "1,234.56"
        default:
            return "1,234.56"
        }
    }()
    @State private var emailNotifications: Bool = UserDefaults.standard.bool(forKey: "anita_email_notifications")
    
    // Backend URL
    @State private var backendURL: String = UserDefaults.standard.string(forKey: "backendURL") ?? Config.backendURL
    @State private var showBackendURLAlert = false
    @State private var backendURLError: String?
    
    // Subscription
    @State private var subscriptionPlan: String? = nil
    @State private var isLoadingSubscription = false
    @State private var showUpgradeView = false
    
    // Data export/import
    @State private var showExportSuccess = false
    @State private var showImportPicker = false
    @State private var showClearDataConfirm = false
    @State private var showTestOnboardingConfirm = false
    @State private var showTestOnboardingRequiresAuth = false
    
    // Notification preview
    @State private var showNotificationPreview = false
    
    private let networkService = NetworkService.shared
    private let supabaseService = SupabaseService.shared
    
    let currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "BRL", "MXN", "SGD", "HKD", "NZD", "ZAR"]
    let dateFormats = [
        ("MM/DD/YYYY", "MM/DD/YYYY (US)"),
        ("DD/MM/YYYY", "DD/MM/YYYY (UK/EU)"),
        ("YYYY-MM-DD", "YYYY-MM-DD (ISO)")
    ]
    let numberFormats = [
        ("1,234.56", "1,234.56 (US/UK)"),
        ("1.234,56", "1.234,56 (EU)"),
        ("1 234,56", "1 234,56 (FR/CA)")
    ]
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Fixed safe area bar - smooth gradient from transparent (bottom) to darker (top/status bar)
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0),
                            Color.black.opacity(0.5),
                            Color.black.opacity(0.9),
                            Color.black
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 0.5)
                    .frame(maxWidth: .infinity)
                    
                    ScrollView {
                        VStack(spacing: 28) {
                    // Profile Section
                    SettingsCategorySection(title: AppL10n.t("settings.profile"), icon: "person.fill") {
                            VStack(spacing: 0) {
                                if userManager.isAuthenticated, let user = userManager.currentUser {
                                // Profile Header
                                HStack(spacing: 16) {
                                    ZStack {
                                        // Glass circle background with gradient
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(white: 0.2).opacity(0.4),
                                                        Color(white: 0.15).opacity(0.3)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 64, height: 64)
                                            .overlay {
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [
                                                                Color.white.opacity(0.25),
                                                                Color.white.opacity(0.1)
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 1.5
                                                    )
                                            }
                                        
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 26, weight: .semibold))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.95),
                                                        Color.white.opacity(0.85)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(profileName.isEmpty ? (user.email ?? "User") : profileName)
                                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white.opacity(0.95))
                                        
                                        HStack(spacing: 6) {
                                            Text(subscriptionPlan?.capitalized ?? "Free")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white.opacity(0.7))
                                            Text("Plan")
                                                .font(.system(size: 14, weight: .regular))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 20)
                                
                                PremiumDivider()
                                    .padding(.leading, 100)
                                
                                // Name Field
                                SettingsRowWithIcon(
                                    icon: "person.text.rectangle",
                                    iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                    title: "Name",
                                    value: nil,
                                    showChevron: false
                                ) {
                                    HStack {
                                        TextField("Enter your name", text: $profileName)
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(.white.opacity(0.9))
                                            .onChange(of: profileName) { _, newValue in
                                                saveNameDebounced(newValue)
                                            }
                                        
                                        if isSavingName {
                                            ProgressView()
                                                .tint(.white.opacity(0.6))
                                                .scaleEffect(0.8)
                                        }
                                    }
                                }
                                
                                PremiumDivider()
                                    .padding(.leading, 92)
                                
                                // Email (read-only)
                                SettingsRowWithIcon(
                                    icon: "envelope.fill",
                                    iconColor: .white.opacity(0.6),
                                    title: "Email",
                                    value: user.email ?? "No email",
                                    showChevron: false
                                ) {}
                                
                                if let createdAt = user.createdAt {
                                    PremiumDivider()
                                        .padding(.leading, 92)
                                    
                                    SettingsRowWithIcon(
                                        icon: "calendar",
                                        iconColor: .white.opacity(0.6),
                                        title: "Member Since",
                                        value: formatJoinDate(createdAt),
                                        showChevron: false
                                    ) {}
                                }
                                
                                PremiumDivider()
                                    .padding(.leading, 92)
                                
                                // Logout Button
                                Button(action: {
                                    userManager.signOut()
                                }) {
                                    SettingsRowWithIcon(
                                        icon: "arrow.right.square",
                                        iconColor: .red.opacity(0.8),
                                        title: "Logout",
                                        value: nil,
                                        showChevron: false
                                    ) {}
                                }
                            } else {
                                Button(action: {
                                    showAuthSheet = true
                                }) {
                                    SettingsRowWithIcon(
                                        icon: "person.badge.plus",
                                        iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                        title: "Sign In / Sign Up",
                                        value: nil,
                                        showChevron: true
                                    ) {}
                                }
                                .buttonStyle(PremiumSettingsButtonStyle())
                            }
                        }
                    }
                    .onAppear {
                        loadProfile()
                        loadSubscription()
                        loadPreferences()
                        // Load backend URL
                        backendURL = UserDefaults.standard.string(forKey: "backendURL") ?? Config.backendURL
                    }
                    
                    // Preferences Section
                    SettingsCategorySection(title: AppL10n.t("settings.preferences"), icon: "slider.horizontal.3") {
                        VStack(spacing: 0) {
                            // Currency
                            Menu {
                                ForEach(currencies, id: \.self) { currency in
                                    Button(action: {
                                        saveCurrency(currency)
                                    }) {
                                        HStack {
                                            Text(currency)
                                            if selectedCurrency == currency {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                SettingsRowWithIcon(
                                    icon: "dollarsign.circle.fill",
                                    iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                    title: "Currency",
                                    value: selectedCurrency,
                                    showChevron: true
                                ) {}
                            }
                            
                            PremiumDivider()
                                .padding(.leading, 76)
                            
                            // Date Format
                            Menu {
                                ForEach(dateFormats, id: \.0) { format, label in
                                    Button(action: {
                                        saveDateFormat(format)
                                    }) {
                                        HStack {
                                            Text(label)
                                            if dateFormat == format {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                SettingsRowWithIcon(
                                    icon: "calendar.badge.clock",
                                    iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                    title: "Date Format",
                                    value: dateFormats.first(where: { $0.0 == dateFormat })?.1 ?? dateFormat,
                                    showChevron: true
                                ) {}
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                            
                            PremiumDivider()
                                .padding(.leading, 76)
                            
                            // Number Format (read-only, automatically set based on currency)
                            SettingsRowWithIcon(
                                icon: "number",
                                iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                title: "Number Format",
                                value: numberFormats.first(where: { $0.0 == numberFormat })?.1 ?? numberFormat,
                                showChevron: false
                            ) {}
                        }
                    }
                    
                    // Development Section
                    SettingsCategorySection(title: AppL10n.t("settings.development"), icon: "wrench.and.screwdriver.fill") {
                        VStack(spacing: 0) {
                            Button(action: {
                                showBackendURLAlert = true
                            }) {
                                SettingsRowWithIcon(
                                    icon: "server.rack",
                                    iconColor: Color.orange.opacity(0.8),
                                    title: "Backend URL",
                                    value: backendURL,
                                    showChevron: true
                                ) {}
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                            
                            PremiumDivider()
                                .padding(.leading, 76)

                            Button(action: {
                                if userManager.isAuthenticated {
                                    showTestOnboardingConfirm = true
                                } else {
                                    showTestOnboardingRequiresAuth = true
                                }
                            }) {
                                SettingsRowWithIcon(
                                    icon: "sparkles",
                                    iconColor: Color.orange.opacity(0.8),
                                    title: "Test Onboarding",
                                    value: nil,
                                    showChevron: true
                                ) {}
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("For iPhone: Use your Mac's IP address")
                                    .font(.system(size: 11, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)
                                Text("Example: http://192.168.1.100:3001")
                                    .font(.system(size: 11, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 8)
                            }
                        }
                    }
                    
                    // Subscription Section
                    SettingsCategorySection(title: AppL10n.t("settings.subscription"), icon: "crown.fill") {
                        VStack(spacing: 0) {
                            Button(action: {
                                showUpgradeView = true
                            }) {
                                SettingsRowWithIcon(
                                    icon: "crown.fill",
                                    iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                    title: "Manage Subscription",
                                    value: subscriptionPlan?.capitalized ?? "Free",
                                    showChevron: true
                                ) {}
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                        }
                    }
                    
                    // Notifications Section
                    SettingsCategorySection(title: AppL10n.t("settings.notifications"), icon: "bell.fill") {
                        VStack(spacing: 0) {
                            HStack {
                                SettingsRowWithIcon(
                                    icon: "envelope.badge",
                                    iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                    title: "Email Notifications",
                                    value: nil,
                                    showChevron: false
                                ) {
                                    Toggle("", isOn: Binding(
                                        get: { emailNotifications },
                                        set: { saveEmailNotifications($0) }
                                    ))
                                    .tint(Color(red: 0.4, green: 0.49, blue: 0.92))
                                }
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.leading, 60)
                            
                            HStack {
                                SettingsRowWithIcon(
                                    icon: "bell.badge.fill",
                                    iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                    title: "Push Notifications",
                                    value: nil,
                                    showChevron: false
                                ) {
                                    Toggle("", isOn: Binding(
                                        get: { notificationService.pushNotificationsEnabled },
                                        set: { enabled in
                                            notificationService.pushNotificationsEnabled = enabled
                                            if enabled {
                                                notificationService.requestAuthorization()
                                            }
                                        }
                                    ))
                                    .tint(Color(red: 0.4, green: 0.49, blue: 0.92))
                                }
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.leading, 60)
                            
                            Button(action: {
                                notificationService.sendTestNotification()
                            }) {
                                SettingsRowWithIcon(
                                    icon: "bell.badge",
                                    iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                    title: "Test Notification",
                                    value: nil,
                                    showChevron: true
                                ) {}
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.leading, 60)
                            
                            Button(action: {
                                showNotificationPreview = true
                            }) {
                                SettingsRowWithIcon(
                                    icon: "eye.fill",
                                    iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                    title: "View All Notifications",
                                    value: nil,
                                    showChevron: true
                                ) {}
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                        }
                    }
                    
                    // Privacy & Data Section
                    SettingsCategorySection(title: AppL10n.t("settings.privacy_data"), icon: "lock.shield.fill") {
                        VStack(spacing: 0) {
                            Button(action: {
                                exportData()
                            }) {
                                SettingsRowWithIcon(
                                    icon: "arrow.down.circle.fill",
                                    iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                    title: "Export Data",
                                    value: nil,
                                    showChevron: true
                                ) {}
                            }
                            
                            PremiumDivider()
                                .padding(.leading, 76)
                            
                            Button(action: {
                                showImportPicker = true
                            }) {
                                SettingsRowWithIcon(
                                    icon: "arrow.up.circle.fill",
                                    iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                    title: "Import Data",
                                    value: nil,
                                    showChevron: true
                                ) {}
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                            
                            PremiumDivider()
                                .padding(.leading, 76)
                            
                            Button(action: {
                                showClearDataConfirm = true
                            }) {
                                SettingsRowWithIcon(
                                    icon: "trash.fill",
                                    iconColor: .red.opacity(0.8),
                                    title: "Clear All Data",
                                    value: nil,
                                    showChevron: true
                                ) {}
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                        }
                    }
                    
                    // Information Section
                    SettingsCategorySection(title: AppL10n.t("settings.information"), icon: "info.circle.fill") {
                        VStack(spacing: 0) {
                            Button(action: {
                                loadPrivacyPolicy()
                            }) {
                                SettingsRowWithIcon(
                                    icon: "doc.text.fill",
                                    iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                    title: "Privacy Policy",
                                    value: nil,
                                    showChevron: true
                                ) {}
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                            
                            PremiumDivider()
                                .padding(.leading, 76)
                            
                            Link(destination: URL(string: "https://anita.app")!) {
                                SettingsRowWithIcon(
                                    icon: "safari.fill",
                                    iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                    title: "Visit Website",
                                    value: nil,
                                    showChevron: true
                                ) {}
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                        }
                    }
                    
                    // About Section
                    SettingsCategorySection(title: AppL10n.t("settings.about"), icon: "app.badge.fill") {
                        VStack(spacing: 0) {
                            SettingsRowWithIcon(
                                icon: "info.circle",
                                iconColor: .white.opacity(0.6),
                                title: "Version",
                                value: "1.0.0",
                                showChevron: false
                            ) {}
                            
                            PremiumDivider()
                                .padding(.leading, 76)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ANITA - Your Personal Finance AI Assistant")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 14)
                            }
                        }
                    }
                    
                    Spacer(minLength: 100)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPrivacyPolicy) {
            if let policy = privacyPolicy {
                PrivacyPolicyView(policy: policy)
            }
        }
        .sheet(isPresented: $showUpgradeView) {
            UpgradeView()
        }
        .sheet(isPresented: $showNotificationPreview) {
            NotificationPreviewView()
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
                            try await userManager.signIn(email: authEmail, password: authPassword)
                            await MainActor.run {
                                showAuthSheet = false
                                authEmail = ""
                                authPassword = ""
                                authError = nil
                                loadProfile()
                            }
                        } catch {
                            await MainActor.run {
                                authError = error.localizedDescription
                            }
                        }
                    }
                },
                onSignUp: {
                    Task {
                        do {
                            try await userManager.signUp(email: authEmail, password: authPassword)
                            await MainActor.run {
                                showAuthSheet = false
                                authEmail = ""
                                authPassword = ""
                                authError = nil
                                loadProfile()
                            }
                        } catch {
                            await MainActor.run {
                                authError = error.localizedDescription
                            }
                        }
                    }
                },
                onSignInWithApple: { idToken, nonce in
                    Task {
                        do {
                            try await userManager.signInWithApple(idToken: idToken, nonce: nonce)
                            await MainActor.run {
                                showAuthSheet = false
                                authEmail = ""
                                authPassword = ""
                                authError = nil
                                loadProfile()
                            }
                        } catch {
                            await MainActor.run {
                                authError = error.localizedDescription
                            }
                        }
                    }
                }
            )
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importData(from: url)
                }
            case .failure(let error):
                print("Import error: \(error.localizedDescription)")
            }
        }
        .alert("Clear All Data", isPresented: $showClearDataConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("Are you sure you want to clear all data? This action cannot be undone.")
        }
        .alert("Backend URL", isPresented: $showBackendURLAlert) {
            TextField("Backend URL", text: $backendURL)
                .autocapitalization(.none)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {
                // Reset to saved value
                backendURL = UserDefaults.standard.string(forKey: "backendURL") ?? Config.backendURL
            }
            Button("Save") {
                saveBackendURL()
            }
        } message: {
            Text("Enter your backend server URL.\n\nFor iPhone: Use your Mac's IP address (e.g., http://192.168.178.45:3001)\nFor Simulator: Use http://localhost:3001")
        }
        .alert("Test Onboarding", isPresented: $showTestOnboardingConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Start") {
                userManager.resetOnboardingForTesting()
            }
        } message: {
            Text("This will reset onboarding so you can go through it again.")
        }
        .alert("Sign in required", isPresented: $showTestOnboardingRequiresAuth) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please sign in first to test onboarding.")
        }
        .alert("Export Successful", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your data has been exported successfully.")
        }
    }
    
    // MARK: - Helper Functions
    
    func loadProfile() {
        guard userManager.currentUser != nil else { return }
        profileName = UserDefaults.standard.string(forKey: "anita_profile_name") ?? ""
    }
    
    func saveNameDebounced(_ name: String) {
        UserDefaults.standard.set(name, forKey: "anita_profile_name")
        // TODO: Save to Supabase profile table
    }
    
    func formatJoinDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMMM yyyy"
            return displayFormatter.string(from: date)
        }
        return "Recently"
    }
    
    func loadSubscription() {
        guard userManager.isAuthenticated else { return }
        
        Task {
            do {
                let response = try await networkService.getSubscription(userId: userManager.userId)
                await MainActor.run {
                    subscriptionPlan = response.subscription.plan
                }
            } catch {
                print("Error loading subscription: \(error)")
            }
        }
    }
    
    func loadPreferences() {
        selectedCurrency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        dateFormat = UserDefaults.standard.string(forKey: "anita_date_format") ?? "MM/DD/YYYY"
        numberFormat = UserDefaults.standard.string(forKey: "anita_number_format") ?? getNumberFormatForCurrency(selectedCurrency)
        emailNotifications = UserDefaults.standard.bool(forKey: "anita_email_notifications")
        
        // Sync from Supabase if authenticated
        if userManager.isAuthenticated {
            Task {
                await syncPreferencesFromSupabase()
            }
        }
    }
    
    func syncPreferencesFromSupabase() async {
        guard supabaseService.isAuthenticated else { return }
        let userId = userManager.userId
        
        do {
            let baseUrl = Config.supabaseURL.hasSuffix("/") ? String(Config.supabaseURL.dropLast()) : Config.supabaseURL
            let url = URL(string: "\(baseUrl)/rest/v1/profiles?id=eq.\(userId)&select=currency_code,date_format,number_format,email_notifications")!
            
            var request = URLRequest(url: url)
            request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            if let token = supabaseService.getAccessToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let profile = json.first {
                
                if let currencyCode = profile["currency_code"] as? String, !currencyCode.isEmpty {
                    await MainActor.run {
                        self.selectedCurrency = currencyCode
                        UserDefaults.standard.set(currencyCode, forKey: "anita_user_currency")
                        let newNumberFormat = getNumberFormatForCurrency(currencyCode)
                        self.numberFormat = newNumberFormat
                        UserDefaults.standard.set(newNumberFormat, forKey: "anita_number_format")
                    }
                }
                
                if let dateFormat = profile["date_format"] as? String, !dateFormat.isEmpty {
                    await MainActor.run {
                        self.dateFormat = dateFormat
                        UserDefaults.standard.set(dateFormat, forKey: "anita_date_format")
                    }
                }
                
                if let numberFormat = profile["number_format"] as? String, !numberFormat.isEmpty {
                    await MainActor.run {
                        self.numberFormat = numberFormat
                        UserDefaults.standard.set(numberFormat, forKey: "anita_number_format")
                    }
                }
                
                if let emailNotifications = profile["email_notifications"] as? Bool {
                    await MainActor.run {
                        self.emailNotifications = emailNotifications
                        UserDefaults.standard.set(emailNotifications, forKey: "anita_email_notifications")
                    }
                }
            }
        } catch {
            print("[SettingsView] Error syncing preferences from Supabase: \(error)")
        }
    }
    
    func saveCurrency(_ currency: String) {
        selectedCurrency = currency
        UserDefaults.standard.set(currency, forKey: "anita_user_currency")
        
        let newNumberFormat = getNumberFormatForCurrency(currency)
        numberFormat = newNumberFormat
        UserDefaults.standard.set(newNumberFormat, forKey: "anita_number_format")
        
        savePreferencesToSupabase(currency: currency, numberFormat: newNumberFormat)
    }
    
    func saveDateFormat(_ format: String) {
        dateFormat = format
        UserDefaults.standard.set(format, forKey: "anita_date_format")
        savePreferencesToSupabase(dateFormat: format)
    }
    
    func saveNumberFormat(_ format: String) {
        numberFormat = format
        UserDefaults.standard.set(format, forKey: "anita_number_format")
        savePreferencesToSupabase(numberFormat: format)
    }
    
    func saveEmailNotifications(_ enabled: Bool) {
        emailNotifications = enabled
        UserDefaults.standard.set(enabled, forKey: "anita_email_notifications")
        savePreferencesToSupabase(emailNotifications: enabled)
    }
    
    func saveBackendURL() {
        // Validate URL format
        guard let url = URL(string: backendURL),
              let scheme = url.scheme,
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            backendURLError = "Invalid URL format. Use http:// or https://"
            return
        }
        
        // Save to UserDefaults
        UserDefaults.standard.set(backendURL, forKey: "backendURL")
        
        // Update NetworkService
        networkService.updateBaseURL(backendURL)
        
        print("[SettingsView] Backend URL saved: \(backendURL)")
    }
    
    func savePreferencesToSupabase(currency: String? = nil, dateFormat: String? = nil, numberFormat: String? = nil, emailNotifications: Bool? = nil) {
        guard supabaseService.isAuthenticated else { return }
        let userId = userManager.userId
        
        Task {
            do {
                let baseUrl = Config.supabaseURL.hasSuffix("/") ? String(Config.supabaseURL.dropLast()) : Config.supabaseURL
                let url = URL(string: "\(baseUrl)/rest/v1/profiles?id=eq.\(userId)")!
                
                var request = URLRequest(url: url)
                request.httpMethod = "PATCH"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("return=representation", forHTTPHeaderField: "Prefer")
                
                if let token = supabaseService.getAccessToken() {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                
                var updateData: [String: Any] = [:]
                if let currency = currency {
                    updateData["currency_code"] = currency
                    updateData["currency_symbol"] = getCurrencySymbol(currency)
                }
                if let dateFormat = dateFormat {
                    updateData["date_format"] = dateFormat
                }
                if let numberFormat = numberFormat {
                    updateData["number_format"] = numberFormat
                }
                if let emailNotifications = emailNotifications {
                    updateData["email_notifications"] = emailNotifications
                }
                
                updateData["updated_at"] = ISO8601DateFormatter().string(from: Date())
                
                request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                    print("[SettingsView] Failed to save to Supabase")
                    return
                }
            } catch {
                print("[SettingsView] Error saving to Supabase: \(error)")
            }
        }
    }
    
    func getNumberFormatForCurrency(_ currency: String) -> String {
        switch currency {
        case "EUR":
            return "1.234,56"
        case "USD", "GBP", "CAD", "AUD", "NZD", "SGD", "HKD":
            return "1,234.56"
        default:
            return "1,234.56"
        }
    }
    
    func getCurrencySymbol(_ currency: String) -> String {
        switch currency {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        case "CAD": return "C$"
        case "AUD": return "A$"
        case "CHF": return "CHF"
        case "CNY": return "¥"
        case "INR": return "₹"
        case "BRL": return "R$"
        case "MXN": return "MX$"
        case "SGD": return "S$"
        case "HKD": return "HK$"
        case "NZD": return "NZ$"
        case "ZAR": return "R"
        default: return "$"
        }
    }
    
    func clearAllData() {
        // Clear local data
        UserDefaults.standard.removeObject(forKey: "anita_profile_name")
        UserDefaults.standard.removeObject(forKey: "anita_user_currency")
        UserDefaults.standard.removeObject(forKey: "anita_date_format")
        UserDefaults.standard.removeObject(forKey: "anita_number_format")
        UserDefaults.standard.removeObject(forKey: "anita_email_notifications")
        
        // Reset preferences to defaults
        selectedCurrency = "USD"
        dateFormat = "MM/DD/YYYY"
        numberFormat = "1,234.56"
        emailNotifications = true
        
        // Clear from Supabase if authenticated
        if userManager.isAuthenticated {
            Task {
                // TODO: Implement API call to clear data from Supabase
                print("Clearing all data from Supabase...")
            }
        }
    }
    
    func exportData() {
        // Collect all local data
        var exportData: [String: Any] = [:]
        
        // User preferences
        exportData["preferences"] = [
            "currency": selectedCurrency,
            "dateFormat": dateFormat,
            "numberFormat": numberFormat,
            "emailNotifications": emailNotifications
        ]
        
        // Profile
        if let profileName = UserDefaults.standard.string(forKey: "anita_profile_name") {
            exportData["profile"] = ["name": profileName]
        }
        
        // Convert to JSON
        if let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            
            // Save to file
            let fileName = "anita_export_\(Date().timeIntervalSince1970).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            do {
                try jsonString.write(to: url, atomically: true, encoding: .utf8)
                
                // Share the file
                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    rootViewController.present(activityVC, animated: true)
                    showExportSuccess = true
                }
            } catch {
                print("Error exporting data: \(error)")
            }
        }
    }
    
    func importData(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Import preferences
                if let prefs = json["preferences"] as? [String: Any] {
                    if let currency = prefs["currency"] as? String {
                        saveCurrency(currency)
                    }
                    if let dateFormat = prefs["dateFormat"] as? String {
                        saveDateFormat(dateFormat)
                    }
                    if let numberFormat = prefs["numberFormat"] as? String {
                        saveNumberFormat(numberFormat)
                    }
                    if let emailNotifications = prefs["emailNotifications"] as? Bool {
                        saveEmailNotifications(emailNotifications)
                    }
                }
                
                // Import profile
                if let profile = json["profile"] as? [String: Any],
                   let name = profile["name"] as? String {
                    UserDefaults.standard.set(name, forKey: "anita_profile_name")
                    profileName = name
                }
                
                print("Data imported successfully")
            }
        } catch {
            print("Error importing data: \(error)")
        }
    }
    
    func loadPrivacyPolicy() {
        Task {
            do {
                let policy = try await networkService.getPrivacyPolicy()
                await MainActor.run {
                    privacyPolicy = policy
                    showPrivacyPolicy = true
                }
            } catch {
                print("Error loading privacy policy: \(error)")
            }
        }
    }
}

// MARK: - Category Section View

struct SettingsCategorySection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 10)
            
            content
                .liquidGlass(cornerRadius: 16)
                .padding(.horizontal, 20)
        }
    }
}

// MARK: - Settings Row with Icon

struct SettingsRowWithIcon<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String?
    let showChevron: Bool
    let content: Content
    
    init(icon: String, iconColor: Color, title: String, value: String?, showChevron: Bool, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.value = value
        self.showChevron = showChevron
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with premium glass effect
            ZStack {
                // Glass circle background with gradient
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
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                iconColor.opacity(0.95),
                                iconColor.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Title
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
            
            Spacer()
            
            // Value
            if let value = value {
                Text(value)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .digit3D(baseColor: .white.opacity(0.6))
            }
            
            // Chevron
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            content
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.clear)
    }
}

// MARK: - Premium Divider

struct PremiumDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.1),
                        Color.white.opacity(0.05),
                        Color.white.opacity(0.1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 0.5)
    }
}

// MARK: - Premium Button Style

struct PremiumSettingsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Privacy Policy View

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

// MARK: - Auth Sheet

struct AuthSheet: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var isSignUp: Bool
    @Binding var error: String?
    let onSignIn: () -> Void
    let onSignUp: () -> Void
    let onSignInWithApple: (String, String?) -> Void
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
                    
                    // Divider with "or"
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                        Text("or")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    
                    // Apple Sign-In Button
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                    guard let identityToken = appleIDCredential.identityToken,
                                          let idTokenString = String(data: identityToken, encoding: .utf8) else {
                                        print("Apple Sign-In: Failed to get identity token")
                                        return
                                    }
                                    
                                    // Nonce is optional for Supabase - pass nil for native iOS Sign-In
                                    onSignInWithApple(idTokenString, nil)
                                } else {
                                    print("Apple Sign-In: Failed to get Apple ID credential")
                                }
                            case .failure(let error):
                                print("Apple Sign-In failed: \(error.localizedDescription)")
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)
                    
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

// MARK: - Note: Subscription Plan Components are defined in UpgradeView.swift
// Using PlanType, FreePlanCard, SubscriptionPlanCard, and FeatureRow from UpgradeView

#Preview("Settings") {
    SettingsView()
}
