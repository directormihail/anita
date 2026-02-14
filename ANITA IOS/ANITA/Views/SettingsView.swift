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
    @State private var nameSaveSuccess = false
    @FocusState private var isNameFieldFocused: Bool
    
    // Preferences
    @State private var selectedCurrency: String = "EUR"
    @State private var emailNotifications: Bool = UserDefaults.standard.bool(forKey: "anita_email_notifications")
    @State private var currentLanguageCode: String = AppL10n.currentLanguageCode()
    @State private var languageRefreshTrigger = UUID()
    
    // Subscription (display name from SubscriptionManager — database-backed)
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showUpgradeView = false
    
    // Data export/import
    @State private var showExportSuccess = false
    @State private var showImportPicker = false
    @State private var showClearDataConfirm = false
    
    // Test onboarding
    @State private var showTestOnboardingConfirm = false
    @State private var showTestOnboardingSignInRequired = false
    
    // Backend URL (for iPhone → laptop IP)
    @State private var showBackendURLSheet = false
    @State private var backendURLText: String = ""
    
    private let networkService = NetworkService.shared
    private let supabaseService = SupabaseService.shared
    
    let currencies = ["EUR", "CHF"]
    
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
                                        Text(profileName.isEmpty ? (user.email ?? AppL10n.t("settings.name")) : profileName)
                                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white.opacity(0.95))
                                        
                                        HStack(spacing: 6) {
                                            Text(subscriptionManager.subscriptionDisplayName)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white.opacity(0.7))
                                            Text(AppL10n.t("plans.current").components(separatedBy: " ").last ?? "Plan")
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
                                    title: AppL10n.t("settings.name"),
                                    value: nil,
                                    showChevron: false
                                ) {
                                    HStack(spacing: 8) {
                                        TextField(AppL10n.t("settings.enter_name"), text: $profileName)
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(.white.opacity(0.9))
                                            .focused($isNameFieldFocused)
                                            .onChange(of: profileName) { _, newValue in
                                                saveNameLocallyOnly(newValue)
                                            }
                                            .onSubmit {
                                                saveNameToServerImmediately(profileName)
                                            }
                                            .submitLabel(.done)
                                        
                                        if isSavingName {
                                            ProgressView()
                                                .tint(.white.opacity(0.5))
                                                .scaleEffect(0.75)
                                        } else if isNameFieldFocused && userManager.isAuthenticated {
                                            Spacer(minLength: 4)
                                            Button(action: {
                                                saveNameToServerImmediately(profileName)
                                            }) {
                                                Image(systemName: nameSaveSuccess ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                                                    .font(.system(size: 18))
                                                    .foregroundColor(nameSaveSuccess ? .green.opacity(0.9) : Color.white.opacity(0.45))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                
                                PremiumDivider()
                                    .padding(.leading, 92)
                                
                                // Email (read-only)
                                SettingsRowWithIcon(
                                    icon: "envelope.fill",
                                    iconColor: .white.opacity(0.6),
                                    title: AppL10n.t("settings.email"),
                                    value: user.email ?? AppL10n.t("settings.no_email"),
                                    showChevron: false
                                ) {}
                                
                                PremiumDivider()
                                    .padding(.leading, 92)
                                
                                // Logout Button
                                Button(action: {
                                    userManager.signOut()
                                }) {
                                    SettingsRowWithIcon(
                                        icon: "arrow.right.square",
                                        iconColor: .red.opacity(0.8),
                                        title: AppL10n.t("settings.logout"),
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
                                        title: AppL10n.t("settings.sign_in_up"),
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
                        loadPreferences()
                        Task { await subscriptionManager.refresh() }
                    }
                    
                    // Preferences Section
                    SettingsCategorySection(title: AppL10n.t("settings.preferences"), icon: "slider.horizontal.3") {
                        VStack(spacing: 0) {
                            // Language
                            Menu {
                                let languages: [(code: String, name: String)] = [
                                    ("en", "English"),
                                    ("de", "Deutsch")
                                ]
                                
                                ForEach(languages, id: \.code) { lang in
                                    Button(action: {
                                        AppL10n.setLanguageCode(lang.code)
                                        currentLanguageCode = lang.code
                                        languageRefreshTrigger = UUID()
                                        // Trigger UI refresh
                                        NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)
                                    }) {
                                        HStack {
                                            Text(lang.name)
                                            if currentLanguageCode == lang.code {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                SettingsRowWithIcon(
                                    icon: "globe",
                                    iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                    title: AppL10n.t("settings.language"),
                                    value: {
                                        let languages: [String: String] = [
                                            "en": "English",
                                            "de": "Deutsch"
                                        ]
                                        return languages[currentLanguageCode] ?? currentLanguageCode.uppercased()
                                    }(),
                                    showChevron: true
                                ) {}
                            }
                            .id(languageRefreshTrigger)
                            
                            PremiumDivider()
                                .padding(.leading, 76)
                            
                            // Currency
                            Menu {
                                ForEach(currencies, id: \.self) { currency in
                                    Button(action: {
                                        saveCurrency(currency)
                                    }) {
                                        HStack {
                                            Text(currency == "EUR" ? "€ Euro" : "CHF Swiss Franc")
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
                                    title: AppL10n.t("settings.currency"),
                                    value: selectedCurrency == "EUR" ? "€ Euro" : "CHF Swiss Franc",
                                    showChevron: true
                                ) {}
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
                                    title: AppL10n.t("settings.manage_subscription"),
                                    value: subscriptionManager.subscriptionDisplayName,
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
                                    title: AppL10n.t("settings.email_notifications"),
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
                                    title: AppL10n.t("settings.push_notifications"),
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
                                    title: AppL10n.t("settings.test_notification"),
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
                                    title: AppL10n.t("settings.export_data"),
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
                                    title: AppL10n.t("settings.import_data"),
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
                                    title: AppL10n.t("settings.clear_all_data"),
                                    value: nil,
                                    showChevron: true
                                ) {}
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                        }
                    }
                    
                    // Development Section (Backend URL / Server IP)
                    SettingsCategorySection(title: AppL10n.t("settings.development"), icon: "network") {
                        VStack(spacing: 0) {
                            Button(action: {
                                backendURLText = UserDefaults.standard.string(forKey: "backendURL") ?? ""
                                if backendURLText.isEmpty {
                                    backendURLText = Config.backendURL
                                }
                                showBackendURLSheet = true
                            }) {
                                HStack {
                                    SettingsRowWithIcon(
                                        icon: "server.rack",
                                        iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                        title: AppL10n.t("settings.backend_url"),
                                        value: {
                                            let url = UserDefaults.standard.string(forKey: "backendURL")?.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if let u = url, !u.isEmpty { return u }
                                            return Config.backendURL
                                        }(),
                                        showChevron: true
                                    ) {}
                                }
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
                                    title: AppL10n.t("settings.privacy_policy"),
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
                                    title: AppL10n.t("settings.visit_website"),
                                    value: nil,
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
                                    showTestOnboardingSignInRequired = true
                                }
                            }) {
                                SettingsRowWithIcon(
                                    icon: "arrow.counterclockwise.circle.fill",
                                    iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                    title: AppL10n.t("settings.test_onboarding"),
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
                                title: AppL10n.t("settings.version"),
                                value: "1.0.0",
                                showChevron: false
                            ) {}
                            
                            PremiumDivider()
                                .padding(.leading, 76)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(AppL10n.t("settings.about_description"))
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
        .onChange(of: showUpgradeView) { _, isShowing in
            if !isShowing {
                Task { await subscriptionManager.refresh() }
            }
        }
        .sheet(isPresented: $showBackendURLSheet) {
            BackendURLSheet(
                urlText: $backendURLText,
                onSave: {
                    let trimmed = backendURLText.trimmingCharacters(in: .whitespacesAndNewlines)
                    var finalURL: String?
                    if trimmed.isEmpty {
                        UserDefaults.standard.removeObject(forKey: "backendURL")
                        NetworkService.shared.updateBaseURL("")
                    } else {
                        var url = trimmed
                        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
                            url = "http://" + url
                        }
                        if url.hasSuffix("/") {
                            url = String(url.dropLast())
                        }
                        finalURL = url
                        UserDefaults.standard.set(url, forKey: "backendURL")
                        NetworkService.shared.updateBaseURL(url)
                    }
                    NotificationCenter.default.post(name: NSNotification.Name("BackendURLUpdated"), object: finalURL)
                    showBackendURLSheet = false
                },
                onCancel: {
                    showBackendURLSheet = false
                }
            )
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
        .alert(AppL10n.t("settings.clear_data_title"), isPresented: $showClearDataConfirm) {
            Button(AppL10n.t("common.cancel"), role: .cancel) {}
            Button(AppL10n.t("settings.clear"), role: .destructive) {
                clearAllData()
            }
        } message: {
            Text(AppL10n.t("settings.clear_data_message"))
        }
        .alert(AppL10n.t("settings.export_successful"), isPresented: $showExportSuccess) {
            Button(AppL10n.t("plans.ok"), role: .cancel) {}
        } message: {
            Text(AppL10n.t("settings.export_success_message"))
        }
        .alert(AppL10n.t("settings.test_onboarding_title"), isPresented: $showTestOnboardingConfirm) {
            Button(AppL10n.t("common.cancel"), role: .cancel) {}
            Button(AppL10n.t("settings.test_onboarding")) {
                userManager.resetOnboardingForTesting()
            }
        } message: {
            Text(AppL10n.t("settings.test_onboarding_message"))
        }
        .alert(AppL10n.t("settings.test_onboarding_title"), isPresented: $showTestOnboardingSignInRequired) {
            Button(AppL10n.t("plans.ok"), role: .cancel) {}
        } message: {
            Text(AppL10n.t("settings.sign_in_required_message"))
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LanguageChanged"))) { _ in
            // Refresh the view when language changes
            currentLanguageCode = AppL10n.currentLanguageCode()
            languageRefreshTrigger = UUID()
        }
        .onAppear {
            currentLanguageCode = AppL10n.currentLanguageCode()
        }
    }
    
    // MARK: - Helper Functions
    
    func loadProfile() {
        guard userManager.currentUser != nil else { return }
        // Per-account name so it doesn't flow between accounts
        let fromOnboarding = userManager.getOnboardingSurvey()?.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fromPrefs = userManager.getProfileName()
        profileName = (fromOnboarding?.isEmpty == false ? fromOnboarding : nil) ?? fromPrefs ?? ""
    }
    
    /// Only update local storage when typing (no server). Use the Save button to persist to database.
    func saveNameLocallyOnly(_ name: String) {
        userManager.setProfileName(name)
    }
    
    /// Saves name to database when user taps the Save (arrow) button. After success, name persists and shows when scrolling between pages; AI will use it from DB.
    func saveNameToServerImmediately(_ name: String) {
        guard userManager.isAuthenticated else { return }
        userManager.setProfileName(name)
        Task {
            await MainActor.run { isSavingName = true; nameSaveSuccess = false }
            do {
                try await userManager.saveProfileNameToSupabase(name)
                await MainActor.run {
                    isSavingName = false
                    nameSaveSuccess = true
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run { nameSaveSuccess = false }
            } catch {
                print("[SettingsView] Failed to save name to database: \(error)")
                await MainActor.run { isSavingName = false }
            }
        }
    }
    
    /// Opens Apple's subscription management page so the user can cancel or manage their subscription anytime.
    func openSubscriptionManagement() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }
    
    func loadPreferences() {
        let saved = UserDefaults.standard.string(forKey: userManager.prefKey("anita_user_currency"))
        selectedCurrency = (saved == "CHF" || saved == "EUR") ? saved! : "EUR"
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
            let url = URL(string: "\(baseUrl)/rest/v1/profiles?id=eq.\(userId)&select=currency_code,date_format,number_format,email_notifications,display_name,name,full_name")!
            
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
                
                // Profile name from database (so Settings shows same name across devices)
                let dbName = (profile["display_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? (profile["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? (profile["full_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let name = dbName, !name.isEmpty {
                    await MainActor.run {
                        self.userManager.setProfileName(name)
                        self.profileName = name
                    }
                }
                
                if let currencyCode = profile["currency_code"] as? String, (currencyCode == "EUR" || currencyCode == "CHF") {
                    await MainActor.run {
                        self.selectedCurrency = currencyCode
                        UserDefaults.standard.set(currencyCode, forKey: self.userManager.prefKey("anita_user_currency"))
                        UserDefaults.standard.set("1.234,56", forKey: self.userManager.prefKey("anita_number_format"))
                    }
                }
                
                if let dateFormat = profile["date_format"] as? String, !dateFormat.isEmpty {
                    await MainActor.run {
                        UserDefaults.standard.set(dateFormat, forKey: self.userManager.prefKey("anita_date_format"))
                    }
                }
                
                if let numberFormat = profile["number_format"] as? String, !numberFormat.isEmpty {
                    await MainActor.run {
                        UserDefaults.standard.set(numberFormat, forKey: self.userManager.prefKey("anita_number_format"))
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
        UserDefaults.standard.set(currency, forKey: userManager.prefKey("anita_user_currency"))
        let newNumberFormat = getNumberFormatForCurrency(currency)
        UserDefaults.standard.set(newNumberFormat, forKey: userManager.prefKey("anita_number_format"))
        savePreferencesToSupabase(currency: currency, numberFormat: newNumberFormat)
    }
    
    func saveEmailNotifications(_ enabled: Bool) {
        emailNotifications = enabled
        UserDefaults.standard.set(enabled, forKey: "anita_email_notifications")
        savePreferencesToSupabase(emailNotifications: enabled)
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
        (currency == "CHF" || currency == "EUR") ? "1.234,56" : "1.234,56"
    }
    
    func getCurrencySymbol(_ currency: String) -> String {
        switch currency {
        case "EUR": return "€"
        case "CHF": return "CHF"
        default: return "€"
        }
    }
    
    func clearAllData() {
        // Clear current account's local data only (per-account keys)
        userManager.setProfileName("")
        UserDefaults.standard.removeObject(forKey: userManager.prefKey("anita_user_currency"))
        UserDefaults.standard.removeObject(forKey: userManager.prefKey("anita_date_format"))
        UserDefaults.standard.removeObject(forKey: userManager.prefKey("anita_number_format"))
        UserDefaults.standard.removeObject(forKey: "anita_email_notifications")
        
        selectedCurrency = "EUR"
        UserDefaults.standard.set("EUR", forKey: userManager.prefKey("anita_user_currency"))
        UserDefaults.standard.set("MM/DD/YYYY", forKey: userManager.prefKey("anita_date_format"))
        UserDefaults.standard.set("1.234,56", forKey: userManager.prefKey("anita_number_format"))
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
        
        // User preferences (per-account keys)
        let dateFormat = UserDefaults.standard.string(forKey: userManager.prefKey("anita_date_format")) ?? "MM/DD/YYYY"
        let numberFormat = UserDefaults.standard.string(forKey: userManager.prefKey("anita_number_format")) ?? getNumberFormatForCurrency(selectedCurrency)
        exportData["preferences"] = [
            "currency": selectedCurrency,
            "dateFormat": dateFormat,
            "numberFormat": numberFormat,
            "emailNotifications": emailNotifications
        ]
        
        if let profileName = userManager.getProfileName() {
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
                        UserDefaults.standard.set(dateFormat, forKey: userManager.prefKey("anita_date_format"))
                        savePreferencesToSupabase(dateFormat: dateFormat)
                    }
                    if let numberFormat = prefs["numberFormat"] as? String {
                        UserDefaults.standard.set(numberFormat, forKey: userManager.prefKey("anita_number_format"))
                        savePreferencesToSupabase(numberFormat: numberFormat)
                    }
                    if let emailNotifications = prefs["emailNotifications"] as? Bool {
                        saveEmailNotifications(emailNotifications)
                    }
                }
                
                // Import profile (per-account)
                if let profile = json["profile"] as? [String: Any],
                   let name = profile["name"] as? String {
                    userManager.setProfileName(name)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
                        Text(AppL10n.t("settings.privacy_policy"))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(AppL10n.t("privacy.data_collection"))
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(policy.dataCollection)
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(AppL10n.t("privacy.data_usage"))
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(policy.dataUsage)
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(AppL10n.t("privacy.data_sharing"))
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(policy.dataSharing)
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                        
                        if let url = URL(string: policy.privacyPolicy) {
                            Link(AppL10n.t("privacy.full_policy"), destination: url)
                                .font(.headline)
                                .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                        }
                        
                        Text("\(AppL10n.t("privacy.contact")): \(policy.contact)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                }
            }
            .navigationTitle(AppL10n.t("settings.privacy_policy"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) {
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
                        Text(isSignUp ? AppL10n.t("signup.signup") : AppL10n.t("welcome.sign_in"))
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
                        Text(AppL10n.t("auth.or").lowercased())
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
                        Text(isSignUp ? AppL10n.t("auth.already_have_account") : AppL10n.t("auth.dont_have_account"))
                            .font(.subheadline)
                            .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                    }
                }
                .padding()
            }
            .navigationTitle(isSignUp ? AppL10n.t("signup.signup") : AppL10n.t("login.login"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("common.cancel")) {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
        }
    }
}

// MARK: - Backend URL Sheet (Server IP for iPhone → laptop)

struct BackendURLSheet: View {
    @Binding var urlText: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text(AppL10n.t("settings.backend_url_hint"))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    TextField(AppL10n.t("settings.backend_url_example"), text: $urlText)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(.white)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(14)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    
                    Text(AppL10n.t("settings.backend_url_example"))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .navigationTitle(AppL10n.t("settings.backend_url_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(AppL10n.t("common.cancel")) {
                        onCancel()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.save")) {
                        onSave()
                    }
                    .fontWeight(.semibold)
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
