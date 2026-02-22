//
//  UserManager.swift
//  ANITA
//
//  User manager with Supabase authentication support
//

import Foundation

class UserManager: ObservableObject {
    static let shared = UserManager()
    
    private let userIdKey = "anita_user_id"
    private let profileNameKeyBase = "anita_profile_name"
    private let onboardingCompletedKey = "anita_onboarding_completed"
    private let onboardingSyncedKey = "anita_onboarding_synced_to_supabase"
    private let preferencesSyncedKey = "anita_preferences_synced_to_supabase"
    private let postSignupPlansPendingKey = "anita_post_signup_plans_pending"
    private let onboardingSurveyKey = OnboardingSurveyResponse.userDefaultsKey
    private let preferredLanguageKey = OnboardingSurveyResponse.preferredLanguageKey
    private let userCurrencyKeyBase = "anita_user_currency"
    private let numberFormatKeyBase = "anita_number_format"
    private let supabaseService = SupabaseService.shared
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var hasCompletedOnboarding = false
    @Published var shouldShowPostSignupPlans = false
    @Published var profileDisplayName: String = ""
    /// True when app was opened via password recovery link; user must set a new password before using the app.
    @Published var recoveryModeNeedsPassword = false
    
    /// UserDefaults key scoped to current account so profile name and onboarding don't leak between accounts.
    func prefKey(_ base: String) -> String {
        "\(base)_\(userId)"
    }
    
    private init() {
        supabaseService.loadSavedToken()
        migrateLegacyUnkeyedStorageIfNeeded()
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: prefKey(onboardingCompletedKey))
        shouldShowPostSignupPlans = UserDefaults.standard.bool(forKey: prefKey(postSignupPlansPendingKey))
        // Hydrate display name so @Published is in sync and all UI updates without re-login
        profileDisplayName = UserDefaults.standard.string(forKey: prefKey(profileNameKeyBase))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        Task {
            await checkAuthStatus()
        }
    }
    
    /// Ensures the global "anita_user_currency" matches the current account's preference so subscription/upgrade screens show the correct symbol (e.g. € not $).
    private func syncGlobalCurrencyFromPerUser() {
        let perUser = UserDefaults.standard.string(forKey: prefKey(userCurrencyKeyBase))
        if let c = perUser, (c == "USD" || c == "EUR" || c == "CHF") {
            UserDefaults.standard.set(c, forKey: "anita_user_currency")
        }
    }
    
    /// One-time: copy legacy global keys into keyed keys for current user so existing users keep their data.
    private func migrateLegacyUnkeyedStorageIfNeeded() {
        let keyedProfile = prefKey(profileNameKeyBase)
        if UserDefaults.standard.string(forKey: keyedProfile) == nil,
           let legacy = UserDefaults.standard.string(forKey: profileNameKeyBase), !legacy.isEmpty {
            UserDefaults.standard.set(legacy, forKey: keyedProfile)
            UserDefaults.standard.removeObject(forKey: profileNameKeyBase)
        }
        let keyedSurvey = prefKey(onboardingSurveyKey)
        if UserDefaults.standard.data(forKey: keyedSurvey) == nil,
           let legacyData = UserDefaults.standard.data(forKey: onboardingSurveyKey) {
            UserDefaults.standard.set(legacyData, forKey: keyedSurvey)
            UserDefaults.standard.removeObject(forKey: onboardingSurveyKey)
        }
        let keyedCompleted = prefKey(onboardingCompletedKey)
        if !UserDefaults.standard.bool(forKey: keyedCompleted), UserDefaults.standard.object(forKey: onboardingCompletedKey) != nil {
            let legacy = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
            UserDefaults.standard.set(legacy, forKey: keyedCompleted)
            UserDefaults.standard.removeObject(forKey: onboardingCompletedKey)
        }
    }
    
    /// Copy storage from previous account (e.g. anonymous) to new account (e.g. after sign-up) so user keeps name/onboarding.
    private func migrateStorage(from oldUserId: String, to newUserId: String) {
        guard oldUserId != newUserId else { return }
        let keysToMigrate = [
            profileNameKeyBase,
            onboardingSurveyKey,
            preferredLanguageKey,
            userCurrencyKeyBase,
            numberFormatKeyBase,
            "anita_date_format",
            onboardingCompletedKey,
            onboardingSyncedKey,
            preferencesSyncedKey,
            postSignupPlansPendingKey
        ]
        for base in keysToMigrate {
            let oldK = "\(base)_\(oldUserId)"
            let newK = "\(base)_\(newUserId)"
            if UserDefaults.standard.object(forKey: newK) == nil,
               let value = UserDefaults.standard.object(forKey: oldK) {
                if let data = value as? Data {
                    UserDefaults.standard.set(data, forKey: newK)
                } else if let str = value as? String {
                    UserDefaults.standard.set(str, forKey: newK)
                } else if let bool = value as? Bool {
                    UserDefaults.standard.set(bool, forKey: newK)
                }
            }
        }
    }
    
    var userId: String {
        get {
            // If authenticated, use Supabase user ID
            if let user = currentUser {
                return user.id
            }
            // Otherwise, use stored local ID
            if let storedId = UserDefaults.standard.string(forKey: userIdKey), !storedId.isEmpty {
                return storedId
            }
            // Generate and store a new user ID
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: userIdKey)
            return newId
        }
    }
    
    func signIn(email: String, password: String) async throws {
        let oldUserId = userId
        let authResponse = try await supabaseService.signIn(email: email, password: password)
        await MainActor.run {
            let newUserId = authResponse.user.id
            migrateStorage(from: oldUserId, to: newUserId)
            self.currentUser = authResponse.user
            self.isAuthenticated = true
            self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: prefKey(onboardingCompletedKey))
        }
        await syncSavedOnboardingToSupabaseIfNeeded()
        syncGlobalCurrencyFromPerUser()
        Task { @MainActor in await SubscriptionManager.shared.refresh() }
    }
    
    func signUp(email: String, password: String) async throws {
        let oldUserId = userId
        let authResponse = try await supabaseService.signUp(email: email, password: password)
        await MainActor.run {
            let newUserId = authResponse.user.id
            migrateStorage(from: oldUserId, to: newUserId)
            self.currentUser = authResponse.user
            self.isAuthenticated = true
            self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: prefKey(onboardingCompletedKey))
            if !hasCompletedOnboarding {
                UserDefaults.standard.set(false, forKey: prefKey(onboardingCompletedKey))
            }
            UserDefaults.standard.set(true, forKey: prefKey(postSignupPlansPendingKey))
            self.shouldShowPostSignupPlans = true
        }
        await syncSavedOnboardingToSupabaseIfNeeded()
        syncGlobalCurrencyFromPerUser()
        Task { @MainActor in await SubscriptionManager.shared.refresh() }
    }
    
    /// Request a password reset email. No session change; Supabase sends the recovery link to the user.
    func resetPassword(email: String) async throws {
        try await supabaseService.resetPassword(email: email)
    }
    
    /// Set session from recovery link (anita://...#access_token=...&refresh_token=...&type=recovery), then require new password.
    func setRecoverySession(accessToken: String, refreshToken: String) async {
        supabaseService.setSessionFromRecovery(accessToken: accessToken, refreshToken: refreshToken)
        await checkAuthStatus()
        await MainActor.run {
            self.recoveryModeNeedsPassword = true
        }
    }
    
    /// Clear recovery mode after user has set a new password.
    func clearRecoveryMode() {
        recoveryModeNeedsPassword = false
    }
    
    /// Update password for current session (recovery flow). Call after setRecoverySession; clears recovery mode on success (caller may call clearRecoveryMode after).
    func updatePasswordForRecovery(_ newPassword: String) async throws {
        try await supabaseService.updatePassword(newPassword)
    }
    
    func signInWithGoogle() async throws {
        let oldUserId = userId
        let authResponse = try await supabaseService.signInWithGoogle()
        await MainActor.run {
            let newUserId = authResponse.user.id
            migrateStorage(from: oldUserId, to: newUserId)
            self.currentUser = authResponse.user
            self.isAuthenticated = true
            self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: prefKey(onboardingCompletedKey))
        }
        await syncSavedOnboardingToSupabaseIfNeeded()
        syncGlobalCurrencyFromPerUser()
        Task { @MainActor in await SubscriptionManager.shared.refresh() }
    }
    
    func signInWithApple(idToken: String, nonce: String? = nil) async throws {
        let oldUserId = userId
        let authResponse = try await supabaseService.signInWithApple(idToken: idToken, nonce: nonce)
        await MainActor.run {
            let newUserId = authResponse.user.id
            migrateStorage(from: oldUserId, to: newUserId)
            self.currentUser = authResponse.user
            self.isAuthenticated = true
            self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: prefKey(onboardingCompletedKey))
        }
        await syncSavedOnboardingToSupabaseIfNeeded()
        syncGlobalCurrencyFromPerUser()
        Task { @MainActor in await SubscriptionManager.shared.refresh() }
    }
    
    func signOut() {
        supabaseService.signOut()
        // Clear stored anonymous id so next sign-in doesn't migrate previous account's data into a new account
        UserDefaults.standard.removeObject(forKey: userIdKey)
        Task { @MainActor in
            self.currentUser = nil
            self.isAuthenticated = false
            self.shouldShowPostSignupPlans = UserDefaults.standard.bool(forKey: prefKey(postSignupPlansPendingKey))
            await SubscriptionManager.shared.refresh()
        }
    }
    
    func checkAuthStatus() async {
        do {
            if let user = try await supabaseService.getCurrentUser() {
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                    self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: prefKey(onboardingCompletedKey))
                }
                syncGlobalCurrencyFromPerUser()
                await syncSavedOnboardingToSupabaseIfNeeded()
                await syncProfileNameFromSupabase()
            } else {
                await MainActor.run {
                    self.isAuthenticated = false
                }
            }
        } catch {
            await MainActor.run {
                self.isAuthenticated = false
            }
        }
        Task { @MainActor in await SubscriptionManager.shared.refresh() }
    }
    
    // MARK: - Per-account profile (so name doesn't flow between accounts)
    
    func getProfileName() -> String? {
        let fromUd = UserDefaults.standard.string(forKey: prefKey(profileNameKeyBase))?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let s = fromUd, !s.isEmpty { return s }
        return profileDisplayName.isEmpty ? nil : profileDisplayName
    }
    
    func setProfileName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profileDisplayName = trimmed
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: prefKey(profileNameKeyBase))
        } else {
            UserDefaults.standard.set(trimmed, forKey: prefKey(profileNameKeyBase))
        }
    }
    
    func getOnboardingSurvey() -> OnboardingSurveyResponse? {
        OnboardingSurveyResponse.loadFromUserDefaults(userId: userId)
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: prefKey(onboardingCompletedKey))
    }
    
    func completeOnboarding(survey: OnboardingSurveyResponse) {
        let uid = userId
        survey.saveToUserDefaults(userId: uid)
        AppL10n.setLanguageCode(survey.languageCode)
        UserDefaults.standard.set(survey.currencyCode, forKey: prefKey(userCurrencyKeyBase))
        UserDefaults.standard.set(survey.currencyCode, forKey: "anita_user_currency") // So UpgradeView/subscription shows same currency
        UserDefaults.standard.set(numberFormatForCurrency(survey.currencyCode), forKey: prefKey(numberFormatKeyBase))
        setProfileName(survey.userName)
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: prefKey(onboardingCompletedKey))
        UserDefaults.standard.set(false, forKey: prefKey(onboardingSyncedKey))
        UserDefaults.standard.set(false, forKey: prefKey(preferencesSyncedKey))
        Task {
            await syncSavedOnboardingToSupabaseIfNeeded()
        }
    }
    
    /// Saves onboarding before authentication (so signup can happen after onboarding).
    /// This persists the survey + applies language, but defers Supabase metadata sync until after login/signup.
    func savePreAuthOnboarding(survey: OnboardingSurveyResponse) {
        let uid = userId
        survey.saveToUserDefaults(userId: uid)
        AppL10n.setLanguageCode(survey.languageCode)
        UserDefaults.standard.set(survey.currencyCode, forKey: prefKey(userCurrencyKeyBase))
        UserDefaults.standard.set(survey.currencyCode, forKey: "anita_user_currency") // So UpgradeView/subscription shows same currency
        UserDefaults.standard.set(numberFormatForCurrency(survey.currencyCode), forKey: prefKey(numberFormatKeyBase))
        setProfileName(survey.userName)
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: prefKey(onboardingCompletedKey))
        UserDefaults.standard.set(false, forKey: prefKey(onboardingSyncedKey))
        UserDefaults.standard.set(false, forKey: prefKey(preferencesSyncedKey))
    }
    
    private func syncSavedOnboardingToSupabaseIfNeeded() async {
        guard isAuthenticated else { return }
        guard UserDefaults.standard.bool(forKey: prefKey(onboardingCompletedKey)) else { return }
        guard let survey = OnboardingSurveyResponse.loadFromUserDefaults(userId: userId) else { return }
        
        if !UserDefaults.standard.bool(forKey: prefKey(onboardingSyncedKey)) {
            do {
                try await supabaseService.updateUserMetadata(data: [
                    "preferred_language": survey.languageCode,
                    "preferred_currency": survey.currencyCode,
                    "user_name": survey.userName,
                    "onboarding_answers": survey.answers,
                    "onboarding_completed_at": ISO8601DateFormatter().string(from: survey.completedAt)
                ])
                UserDefaults.standard.set(true, forKey: prefKey(onboardingSyncedKey))
                print("[UserManager] ✅ Synced saved onboarding to user metadata")
            } catch {
                print("[UserManager] ⚠️ Failed to sync saved onboarding (metadata): \(error)")
            }
        }
        
        if !UserDefaults.standard.bool(forKey: prefKey(preferencesSyncedKey)) {
            do {
                try await savePreferencesToSupabase(currency: survey.currencyCode, displayName: survey.userName)
                UserDefaults.standard.set(true, forKey: prefKey(preferencesSyncedKey))
                print("[UserManager] ✅ Synced preferences to profiles")
            } catch {
                print("[UserManager] ⚠️ Failed to sync preferences to profiles: \(error)")
            }
        }
        await syncProfileNameFromSupabase()
    }
    
    /// Fetches display_name from Supabase profiles and updates local storage so the app shows the correct name everywhere.
    func syncProfileNameFromSupabase() async {
        guard supabaseService.isAuthenticated else { return }
        let uid = userId
        let baseUrl = Config.supabaseURL.hasSuffix("/") ? String(Config.supabaseURL.dropLast()) : Config.supabaseURL
        guard let url = URL(string: "\(baseUrl)/rest/v1/profiles?id=eq.\(uid)&select=display_name,name,full_name") else { return }
        var request = URLRequest(url: url)
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = supabaseService.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let profile = json.first else { return }
            let a = (profile["display_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let b = (profile["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let c = (profile["full_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = (a?.isEmpty == false ? a : nil) ?? (b?.isEmpty == false ? b : nil) ?? (c?.isEmpty == false ? c : nil)
            let local = await MainActor.run { getProfileName()?.trimmingCharacters(in: .whitespacesAndNewlines) }
            if let name = name, (local?.isEmpty ?? true) {
                await MainActor.run { setProfileName(name) }
                print("[UserManager] ✅ Loaded profile name from database: \(name)")
            }
        } catch {
            print("[UserManager] ⚠️ Failed to load profile name from Supabase: \(error)")
        }
    }
    
    private func savePreferencesToSupabase(currency: String, displayName: String? = nil) async throws {
        guard supabaseService.isAuthenticated else { return }
        let userId = userId
        
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
        
        var updateData: [String: Any] = [
            "currency_code": currency,
            "currency_symbol": currencySymbol(currency),
            "number_format": numberFormatForCurrency(currency),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        if let name = displayName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updateData["display_name"] = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw SupabaseError.databaseError("Failed to save preferences to profiles")
        }
    }
    
    /// Saves the profile display name to Supabase (PATCH then POST upsert fallback). Persists across re-login.
    func saveProfileNameToSupabase(_ name: String) async throws {
        guard supabaseService.isAuthenticated else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let uid = userId
        let baseUrl = Config.supabaseURL.hasSuffix("/") ? String(Config.supabaseURL.dropLast()) : Config.supabaseURL
        let dateStr = ISO8601DateFormatter().string(from: Date())
        var payload: [String: Any] = ["updated_at": dateStr]
        if !trimmed.isEmpty { payload["display_name"] = trimmed }
        let bodyData = try JSONSerialization.data(withJSONObject: payload)
        func authHeaders() -> [String: String] {
            var h: [String: String] = [
                "Content-Type": "application/json",
                "apikey": Config.supabaseAnonKey,
                "Accept": "application/json"
            ]
            if let token = supabaseService.getAccessToken() {
                h["Authorization"] = "Bearer \(token)"
            }
            return h
        }
        // 1) PATCH (when profile row already exists, e.g. created by trigger)
        let patchUrl = URL(string: "\(baseUrl)/rest/v1/profiles?id=eq.\(uid)")!
        var patchReq = URLRequest(url: patchUrl)
        patchReq.httpMethod = "PATCH"
        for (k, v) in authHeaders() { patchReq.setValue(v, forHTTPHeaderField: k) }
        patchReq.setValue("return=representation", forHTTPHeaderField: "Prefer")
        patchReq.httpBody = bodyData
        let (patchData, patchRes) = try await URLSession.shared.data(for: patchReq)
        if let r = patchRes as? HTTPURLResponse, r.statusCode >= 200 && r.statusCode < 300 {
            let updated = (try? JSONSerialization.jsonObject(with: patchData)) as? [[Any]]
            if (updated?.isEmpty == false) { return }
        }
        // 2) POST upsert (create row if missing or PATCH failed)
        var postPayload = payload
        postPayload["id"] = uid
        let postBody = try JSONSerialization.data(withJSONObject: postPayload)
        let postUrl = URL(string: "\(baseUrl)/rest/v1/profiles")!
        var postReq = URLRequest(url: postUrl)
        postReq.httpMethod = "POST"
        for (k, v) in authHeaders() { postReq.setValue(v, forHTTPHeaderField: k) }
        postReq.setValue("return=representation, resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        postReq.httpBody = postBody
        let (_, postRes) = try await URLSession.shared.data(for: postReq)
        guard let r = postRes as? HTTPURLResponse, r.statusCode >= 200 && r.statusCode < 300 else {
            throw SupabaseError.databaseError("Failed to save profile name to profiles")
        }
    }
    
    private func numberFormatForCurrency(_ currency: String) -> String {
        (currency == "CHF" || currency == "EUR") ? "1.234,56" : "1,234.56" // USD and others: US format
    }
    
    private func currencySymbol(_ currency: String) -> String {
        switch currency {
        case "USD": return "$"
        case "EUR": return "€"
        case "CHF": return "CHF"
        default: return "$"
        }
    }

    /// Clears onboarding and profile for the current account only (so other accounts are unaffected).
    func resetOnboardingForTesting() {
        UserDefaults.standard.removeObject(forKey: prefKey(onboardingCompletedKey))
        UserDefaults.standard.removeObject(forKey: prefKey(onboardingSyncedKey))
        UserDefaults.standard.removeObject(forKey: prefKey(preferencesSyncedKey))
        UserDefaults.standard.removeObject(forKey: prefKey(postSignupPlansPendingKey))
        UserDefaults.standard.removeObject(forKey: prefKey(onboardingSurveyKey))
        UserDefaults.standard.removeObject(forKey: prefKey(preferredLanguageKey))
        UserDefaults.standard.removeObject(forKey: prefKey(profileNameKeyBase))
        UserDefaults.standard.removeObject(forKey: prefKey(userCurrencyKeyBase))
        UserDefaults.standard.removeObject(forKey: prefKey(numberFormatKeyBase))
        UserDefaults.standard.removeObject(forKey: prefKey("anita_date_format"))
        hasCompletedOnboarding = false
        shouldShowPostSignupPlans = false
    }
    
    /// Remove all keyed storage for a given user (e.g. after full reset).
    func clearKeyedStorage(for userId: String) {
        let keys = [
            profileNameKeyBase, onboardingCompletedKey, onboardingSyncedKey, preferencesSyncedKey,
            postSignupPlansPendingKey, onboardingSurveyKey, preferredLanguageKey,
            userCurrencyKeyBase, numberFormatKeyBase, "anita_date_format", "anita_email_notifications"
        ]
        for base in keys {
            UserDefaults.standard.removeObject(forKey: "\(base)_\(userId)")
        }
    }
    
    func completePostSignupPlans() {
        UserDefaults.standard.set(false, forKey: prefKey(postSignupPlansPendingKey))
        shouldShowPostSignupPlans = false
    }
    
    func reset() {
        let idToClear = userId
        signOut()
        UserDefaults.standard.removeObject(forKey: userIdKey)
        clearKeyedStorage(for: idToClear)
        hasCompletedOnboarding = false
        shouldShowPostSignupPlans = false
    }
}

