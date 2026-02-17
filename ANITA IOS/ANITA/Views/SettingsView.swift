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
    @State private var showTermsOfUse = false
    @State private var showSupportSheet = false
    @State private var showFeedbackSheet = false
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
    
    // Data export
    @State private var showExportSuccess = false
    @State private var showExporting = false
    @State private var exportSummaryMessage: String?
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
                        }
                    }
                    
                    // Privacy & Data Section
                    SettingsCategorySection(title: AppL10n.t("settings.privacy_data"), icon: "lock.shield.fill") {
                        VStack(spacing: 0) {
                            Button(action: {
                                Task { await exportData() }
                            }) {
                                HStack {
                                    SettingsRowWithIcon(
                                        icon: "arrow.down.circle.fill",
                                        iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                        title: AppL10n.t("settings.export_data"),
                                        value: nil,
                                        showChevron: true
                                    ) {}
                                    if showExporting {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                }
                            }
                            .disabled(showExporting)
                            
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
                    
                    // Information Section
                    SettingsCategorySection(title: AppL10n.t("settings.information"), icon: "info.circle.fill") {
                        VStack(spacing: 0) {
                            Button(action: {
                                showPrivacyPolicy = true
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
                            
                            Button(action: {
                                showTermsOfUse = true
                            }) {
                                SettingsRowWithIcon(
                                    icon: "doc.plaintext.fill",
                                    iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                    title: AppL10n.t("settings.terms_of_use"),
                                    value: nil,
                                    showChevron: true
                                ) {}
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                            
                            PremiumDivider()
                                .padding(.leading, 76)
                            
                            Button(action: { showSupportSheet = true }) {
                                SettingsRowWithIcon(
                                    icon: "questionmark.circle.fill",
                                    iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                    title: AppL10n.t("settings.support"),
                                    value: nil,
                                    showChevron: true
                                ) {}
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                            
                            PremiumDivider()
                                .padding(.leading, 76)
                            
                            Button(action: { showFeedbackSheet = true }) {
                                SettingsRowWithIcon(
                                    icon: "bubble.left.and.bubble.right.fill",
                                    iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                    title: AppL10n.t("settings.feedback"),
                                    value: nil,
                                    showChevron: true
                                ) {}
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
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
            LegalDocumentSheetView(mode: .privacy)
        }
        .sheet(isPresented: $showTermsOfUse) {
            LegalDocumentSheetView(mode: .terms)
        }
        .sheet(isPresented: $showSupportSheet) {
            SupportSheet(userId: userManager.currentUser?.id ?? "")
        }
        .sheet(isPresented: $showFeedbackSheet) {
            FeedbackSheet(userId: userManager.currentUser?.id ?? "")
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
        .alert(AppL10n.t("settings.clear_data_title"), isPresented: $showClearDataConfirm) {
            Button(AppL10n.t("common.cancel"), role: .cancel) {}
            Button(AppL10n.t("settings.clear"), role: .destructive) {
                clearAllData()
            }
        } message: {
            Text(AppL10n.t("settings.clear_data_message"))
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ExportSheetDismissed"))) { notification in
            if let u = notification.userInfo,
               let tc = u["transactionCount"] as? Int,
               let cc = u["conversationCount"] as? Int {
                exportSummaryMessage = String(format: AppL10n.t("settings.export_success_summary"), tc, cc)
            } else {
                exportSummaryMessage = nil
            }
            showExportSuccess = true
        }
        .alert(AppL10n.t("settings.export_successful"), isPresented: $showExportSuccess) {
            Button(AppL10n.t("plans.ok"), role: .cancel) {}
        } message: {
            let hint = AppL10n.t("settings.export_success_message")
            if let summary = exportSummaryMessage {
                Text("\(summary)\n\n\(hint)")
            } else {
                Text(hint)
            }
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
        var saved = UserDefaults.standard.string(forKey: userManager.prefKey("anita_user_currency"))
        if saved == nil, let global = UserDefaults.standard.string(forKey: "anita_user_currency"), (global == "CHF" || global == "EUR") {
            saved = global
        }
        selectedCurrency = (saved == "CHF" || saved == "EUR") ? saved! : "EUR"
        // Keep global key in sync so FinanceView, UpgradeView, Chat, etc. use the same currency
        UserDefaults.standard.set(selectedCurrency, forKey: "anita_user_currency")
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
                        UserDefaults.standard.set(currencyCode, forKey: "anita_user_currency")
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
        UserDefaults.standard.set(currency, forKey: "anita_user_currency")
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
        let uid = userManager.userId
        guard userManager.isAuthenticated, !uid.isEmpty else {
            if !uid.isEmpty {
                userManager.clearKeyedStorage(for: uid)
            }
            resetLocalUIState()
            return
        }
        Task {
            do {
                try await networkService.clearUserData(userId: uid)
                await MainActor.run {
                    userManager.clearKeyedStorage(for: uid)
                    userManager.signOut()
                    resetLocalUIState()
                }
            } catch {
                await MainActor.run {
                    userManager.clearKeyedStorage(for: uid)
                    userManager.signOut()
                    resetLocalUIState()
                }
                print("Error clearing remote data: \(error)")
            }
        }
    }
    
    private func resetLocalUIState() {
        selectedCurrency = "EUR"
        profileName = ""
        emailNotifications = false
    }
    
    func exportData() async {
        await MainActor.run { showExporting = true }
        defer { Task { @MainActor in showExporting = false } }
        
        var payload: [String: Any] = [:]
        
        // Preferences
        let dateFormat = UserDefaults.standard.string(forKey: userManager.prefKey("anita_date_format")) ?? "MM/DD/YYYY"
        let numberFormat = UserDefaults.standard.string(forKey: userManager.prefKey("anita_number_format")) ?? getNumberFormatForCurrency(selectedCurrency)
        payload["preferences"] = [
            "currency": selectedCurrency,
            "dateFormat": dateFormat,
            "numberFormat": numberFormat,
            "emailNotifications": emailNotifications
        ]
        
        if let name = userManager.getProfileName() {
            payload["profile"] = ["name": name]
        }
        
        payload["exportedAt"] = ISO8601DateFormatter().string(from: Date())
        
        // Fetch transactions (all) and conversations from backend
        var transactionCount = 0
        var conversationCount = 0
        let uid = userManager.userId
        if !uid.isEmpty {
            do {
                let txnResponse = try await networkService.getTransactions(userId: uid, month: nil, year: nil)
                let txns = txnResponse.transactions.map { t in
                    ["id": t.id, "type": t.type, "amount": t.amount, "category": t.category, "description": t.description, "date": t.date]
                }
                payload["transactions"] = txns
                transactionCount = txns.count
            } catch {
                payload["transactionsError"] = error.localizedDescription
            }
            do {
                let convResponse = try await networkService.getConversations(userId: uid)
                let convs = convResponse.conversations.map { c in
                    ["id": c.id, "title": c.title ?? "", "updatedAt": c.updated_at]
                }
                payload["conversations"] = convs
                conversationCount = convs.count
            } catch {
                payload["conversationsError"] = error.localizedDescription
            }
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        
        // Human-readable filename so it's easy to find in Files app (e.g. anita_export_2025-02-17_14-30.json)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let fileName = "anita_export_\(dateFormatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try jsonString.write(to: url, atomically: true, encoding: .utf8)
            print("[Export] File written: \(fileName) — preferences, profile, \(transactionCount) transactions, \(conversationCount) conversations")
            await MainActor.run {
                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                activityVC.completionWithItemsHandler = { _, _, _, _ in
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ExportSheetDismissed"),
                        object: nil,
                        userInfo: ["transactionCount": transactionCount, "conversationCount": conversationCount]
                    )
                }
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    rootViewController.present(activityVC, animated: true)
                }
            }
        } catch {
            print("Error exporting data: \(error)")
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
                        if let full = policy.fullText, !full.isEmpty {
                            Text(full)
                                .font(.body)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
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

// MARK: - Terms of Use View

struct TermsOfUseView: View {
    let terms: TermsResponse
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(terms.fullText)
                            .font(.body)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if let url = URL(string: terms.termsOfUseUrl) {
                            Link(AppL10n.t("terms.full_terms"), destination: url)
                                .font(.headline)
                                .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                        }
                        
                        Text("\(AppL10n.t("privacy.contact")): \(terms.contact)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                }
            }
            .navigationTitle(AppL10n.t("settings.terms_of_use"))
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

// MARK: - Legal document sheet for Auth (loads from API, fallback to Safari)

struct LegalDocumentSheetView: View {
    enum Mode { case privacy, terms }
    let mode: Mode
    @Environment(\.dismiss) var dismiss
    @State private var policy: PrivacyResponse?
    @State private var terms: TermsResponse?
    @State private var loading = true
    @State private var loadFailed = false
    
    private let basePrivacyURL = "https://anita.app/privacy"
    private let baseTermsURL = "https://anita.app/terms"
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                if loading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                        Text(AppL10n.t("common.loading"))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else if loadFailed {
                    VStack(spacing: 24) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 44))
                            .foregroundColor(.gray)
                        Text(mode == .privacy ? "Privacy Policy could not be loaded." : "Terms of Use could not be loaded.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button(action: openInSafari) {
                            HStack {
                                Image(systemName: "safari")
                                Text("Open in Safari")
                            }
                            .font(.headline)
                            .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if mode == .privacy, let p = policy {
                    ScrollView {
                        legalContent(privacy: p)
                    }
                } else if mode == .terms, let t = terms {
                    ScrollView {
                        legalContent(terms: t)
                    }
                }
            }
            .navigationTitle(mode == .privacy ? AppL10n.t("settings.privacy_policy") : AppL10n.t("settings.terms_of_use"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) { dismiss() }
                        .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
            .onAppear { load() }
        }
    }
    
    private func load() {
        loading = true
        loadFailed = false
        Task {
            do {
                if mode == .privacy {
                    let p = try await NetworkService.shared.getPrivacyPolicy()
                    await MainActor.run { policy = p; loading = false }
                } else {
                    let t = try await NetworkService.shared.getTermsOfUse()
                    await MainActor.run { terms = t; loading = false }
                }
            } catch {
                await MainActor.run { loadFailed = true; loading = false }
            }
        }
    }
    
    private func openInSafari() {
        let urlString = mode == .privacy ? basePrivacyURL : baseTermsURL
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
    
    @ViewBuilder
    private func legalContent(privacy: PrivacyResponse) -> some View {
        let text = privacy.fullText ?? [privacy.dataCollection, privacy.dataUsage, privacy.dataSharing].joined(separator: "\n\n")
        Text(text)
            .font(.body)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
    }
    
    @ViewBuilder
    private func legalContent(terms: TermsResponse) -> some View {
        Text(terms.fullText)
            .font(.body)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
    }
}

// MARK: - Support Sheet

struct SupportSheet: View {
    let userId: String
    @Environment(\.dismiss) var dismiss
    @State private var subject: String = ""
    @State private var message: String = ""
    @State private var sending = false
    @State private var sent = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                if sent {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                        Text(AppL10n.t("support.sent"))
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if userId.isEmpty {
                                Text("Sign in to send a support request.")
                                    .font(.body)
                                    .foregroundColor(.gray)
                            } else {
                                TextField(AppL10n.t("support.subject_placeholder"), text: $subject)
                                    .textFieldStyle(.plain)
                                    .padding(12)
                                    .background(Color(white: 0.15))
                                    .cornerRadius(10)
                                    .foregroundColor(.white)
                                    .autocapitalization(.sentences)
                                
                                ZStack(alignment: .topLeading) {
                                    if message.isEmpty {
                                        Text(AppL10n.t("support.message_placeholder"))
                                            .foregroundColor(.gray.opacity(0.7))
                                            .padding(16)
                                    }
                                    TextEditor(text: $message)
                                        .padding(12)
                                        .frame(minHeight: 120)
                                        .scrollContentBackground(.hidden)
                                        .background(Color(white: 0.15))
                                        .cornerRadius(10)
                                        .foregroundColor(.white)
                                        .autocapitalization(.sentences)
                                }
                                
                                if let err = errorMessage {
                                    Text(err)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                Button(action: sendSupport) {
                                    HStack {
                                        if sending {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Text(AppL10n.t("support.send"))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color(red: 0.4, green: 0.49, blue: 0.92))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                .disabled(sending || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(AppL10n.t("support.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) { dismiss() }
                        .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
        }
    }
    
    private func sendSupport() {
        guard !userId.isEmpty, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        errorMessage = nil
        sending = true
        Task {
            do {
                _ = try await NetworkService.shared.submitSupport(
                    userId: userId,
                    subject: subject.isEmpty ? nil : subject,
                    message: message.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                await MainActor.run { sent = true }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    if errorMessage?.isEmpty == true { errorMessage = AppL10n.t("support.error") }
                    sending = false
                }
            }
        }
    }
}

// MARK: - Feedback Sheet

struct FeedbackSheet: View {
    let userId: String
    @Environment(\.dismiss) var dismiss
    @State private var message: String = ""
    @State private var rating: Int? = nil
    @State private var sending = false
    @State private var sent = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                if sent {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                        Text(AppL10n.t("feedback.sent"))
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if userId.isEmpty {
                                Text("Sign in to send feedback.")
                                    .font(.body)
                                    .foregroundColor(.gray)
                            } else {
                                Text(AppL10n.t("feedback.rating_label"))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                HStack(spacing: 12) {
                                    ForEach(1...5, id: \.self) { value in
                                        let isFilled = (rating ?? 0) >= value
                                        Button(action: { rating = rating == value ? nil : value }) {
                                            Image(systemName: isFilled ? "star.fill" : "star")
                                                .font(.title2)
                                                .foregroundColor(isFilled ? Color(red: 0.4, green: 0.49, blue: 0.92) : .gray)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                
                                ZStack(alignment: .topLeading) {
                                    if message.isEmpty {
                                        Text(AppL10n.t("feedback.message_placeholder"))
                                            .foregroundColor(.gray.opacity(0.7))
                                            .padding(16)
                                    }
                                    TextEditor(text: $message)
                                        .padding(12)
                                        .frame(minHeight: 120)
                                        .scrollContentBackground(.hidden)
                                        .background(Color(white: 0.15))
                                        .cornerRadius(10)
                                        .foregroundColor(.white)
                                        .autocapitalization(.sentences)
                                }
                                
                                if let err = errorMessage {
                                    Text(err)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                Button(action: sendFeedback) {
                                    HStack {
                                        if sending {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Text(AppL10n.t("feedback.send"))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color(red: 0.4, green: 0.49, blue: 0.92))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                .disabled(sending)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(AppL10n.t("feedback.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) { dismiss() }
                        .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
        }
    }
    
    private func sendFeedback() {
        guard !userId.isEmpty else { return }
        errorMessage = nil
        sending = true
        Task {
            do {
                _ = try await NetworkService.shared.submitFeedback(
                    userId: userId,
                    message: message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : message.trimmingCharacters(in: .whitespacesAndNewlines),
                    rating: rating
                )
                await MainActor.run { sent = true }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    if errorMessage?.isEmpty == true { errorMessage = AppL10n.t("feedback.error") }
                    sending = false
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
