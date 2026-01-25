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
    private let onboardingCompletedKey = "anita_onboarding_completed"
    private let onboardingSyncedKey = "anita_onboarding_synced_to_supabase"
    private let preferencesSyncedKey = "anita_preferences_synced_to_supabase"
    private let postSignupPlansPendingKey = "anita_post_signup_plans_pending"
    private let onboardingSurveyKey = OnboardingSurveyResponse.userDefaultsKey
    private let preferredLanguageKey = OnboardingSurveyResponse.preferredLanguageKey
    private let supabaseService = SupabaseService.shared
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var hasCompletedOnboarding = false
    @Published var shouldShowPostSignupPlans = false
    
    private init() {
        supabaseService.loadSavedToken()
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
        shouldShowPostSignupPlans = UserDefaults.standard.bool(forKey: postSignupPlansPendingKey)
        Task {
            await checkAuthStatus()
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
        let authResponse = try await supabaseService.signIn(email: email, password: password)
        await MainActor.run {
            self.currentUser = authResponse.user
            self.isAuthenticated = true
            // Preserve existing onboarding status for returning users
            self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
        }
        await syncSavedOnboardingToSupabaseIfNeeded()
    }
    
    func signUp(email: String, password: String) async throws {
        let authResponse = try await supabaseService.signUp(email: email, password: password)
        await MainActor.run {
            self.currentUser = authResponse.user
            self.isAuthenticated = true
            // If user completed onboarding pre-auth, keep it. Otherwise they still need onboarding.
            let completed = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
            self.hasCompletedOnboarding = completed
            if !completed {
                UserDefaults.standard.set(false, forKey: onboardingCompletedKey)
            }
            // New account created → show plans screen once.
            UserDefaults.standard.set(true, forKey: postSignupPlansPendingKey)
            self.shouldShowPostSignupPlans = true
        }
        await syncSavedOnboardingToSupabaseIfNeeded()
    }
    
    func signInWithGoogle() async throws {
        let authResponse = try await supabaseService.signInWithGoogle()
        await MainActor.run {
            self.currentUser = authResponse.user
            self.isAuthenticated = true
            // Check if this is a new user (first time signing in with Google)
            // If user doesn't exist in our system, they need onboarding
            // For now, we'll check if onboarding was already completed
            if !UserDefaults.standard.bool(forKey: onboardingCompletedKey) {
                self.hasCompletedOnboarding = false
            }
        }
        await syncSavedOnboardingToSupabaseIfNeeded()
    }
    
    func signInWithApple(idToken: String, nonce: String? = nil) async throws {
        let authResponse = try await supabaseService.signInWithApple(idToken: idToken, nonce: nonce)
        await MainActor.run {
            self.currentUser = authResponse.user
            self.isAuthenticated = true
            // Check if this is a new user (first time signing in with Apple)
            // If user doesn't exist in our system, they need onboarding
            // For now, we'll check if onboarding was already completed
            if !UserDefaults.standard.bool(forKey: onboardingCompletedKey) {
                self.hasCompletedOnboarding = false
            }
        }
        await syncSavedOnboardingToSupabaseIfNeeded()
    }
    
    func signOut() {
        supabaseService.signOut()
        Task { @MainActor in
            self.currentUser = nil
            self.isAuthenticated = false
            self.shouldShowPostSignupPlans = UserDefaults.standard.bool(forKey: postSignupPlansPendingKey)
        }
    }
    
    func checkAuthStatus() async {
        do {
            if let user = try await supabaseService.getCurrentUser() {
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                    // Preserve existing onboarding status
                    self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
                }
                await syncSavedOnboardingToSupabaseIfNeeded()
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
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
    }
    
    func completeOnboarding(survey: OnboardingSurveyResponse) {
        // Persist locally
        survey.saveToUserDefaults()
        AppL10n.setLanguageCode(survey.languageCode)
        UserDefaults.standard.set(survey.currencyCode, forKey: "anita_user_currency")
        UserDefaults.standard.set(numberFormatForCurrency(survey.currencyCode), forKey: "anita_number_format")
        
        // Mark onboarding completed
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
        UserDefaults.standard.set(false, forKey: onboardingSyncedKey)
        UserDefaults.standard.set(false, forKey: preferencesSyncedKey)
        
        // Sync to Supabase (best-effort)
        Task {
            await syncSavedOnboardingToSupabaseIfNeeded()
        }
    }
    
    /// Saves onboarding before authentication (so signup can happen after onboarding).
    /// This persists the survey + applies language, but defers Supabase metadata sync until after login/signup.
    func savePreAuthOnboarding(survey: OnboardingSurveyResponse) {
        survey.saveToUserDefaults()
        AppL10n.setLanguageCode(survey.languageCode)
        UserDefaults.standard.set(survey.currencyCode, forKey: "anita_user_currency")
        UserDefaults.standard.set(numberFormatForCurrency(survey.currencyCode), forKey: "anita_number_format")
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
        UserDefaults.standard.set(false, forKey: onboardingSyncedKey)
        UserDefaults.standard.set(false, forKey: preferencesSyncedKey)
    }
    
    private func syncSavedOnboardingToSupabaseIfNeeded() async {
        guard isAuthenticated else { return }
        guard UserDefaults.standard.bool(forKey: onboardingCompletedKey) else { return }
        guard let survey = OnboardingSurveyResponse.loadFromUserDefaults() else { return }
        
        if !UserDefaults.standard.bool(forKey: onboardingSyncedKey) {
            do {
                try await supabaseService.updateUserMetadata(data: [
                    "preferred_language": survey.languageCode,
                    "preferred_currency": survey.currencyCode,
                    "onboarding_answers": survey.answers,
                    "onboarding_completed_at": ISO8601DateFormatter().string(from: survey.completedAt)
                ])
                UserDefaults.standard.set(true, forKey: onboardingSyncedKey)
                print("[UserManager] ✅ Synced saved onboarding to user metadata")
            } catch {
                // Best-effort: we'll retry on next auth status check.
                print("[UserManager] ⚠️ Failed to sync saved onboarding (metadata): \(error)")
            }
        }
        
        if !UserDefaults.standard.bool(forKey: preferencesSyncedKey) {
            do {
                try await savePreferencesToSupabase(currency: survey.currencyCode)
                UserDefaults.standard.set(true, forKey: preferencesSyncedKey)
                print("[UserManager] ✅ Synced preferences to profiles")
            } catch {
                print("[UserManager] ⚠️ Failed to sync preferences to profiles: \(error)")
            }
        }
    }
    
    private func savePreferencesToSupabase(currency: String) async throws {
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
        
        let updateData: [String: Any] = [
            "currency_code": currency,
            "currency_symbol": currencySymbol(currency),
            "number_format": numberFormatForCurrency(currency),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw SupabaseError.databaseError("Failed to save preferences to profiles")
        }
    }
    
    private func numberFormatForCurrency(_ currency: String) -> String {
        switch currency {
        case "EUR", "PLN":
            return "1.234,56"
        default:
            return "1,234.56"
        }
    }
    
    private func currencySymbol(_ currency: String) -> String {
        switch currency {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "CHF": return "CHF"
        case "PLN": return "zł"
        case "TRY": return "₺"
        case "CAD": return "C$"
        default: return currency
        }
    }

    /// Clears onboarding completion + onboarding survey so onboarding shows again.
    func resetOnboardingForTesting() {
        UserDefaults.standard.removeObject(forKey: onboardingCompletedKey)
        UserDefaults.standard.removeObject(forKey: onboardingSyncedKey)
        UserDefaults.standard.removeObject(forKey: preferencesSyncedKey)
        UserDefaults.standard.removeObject(forKey: postSignupPlansPendingKey)
        UserDefaults.standard.removeObject(forKey: onboardingSurveyKey)
        UserDefaults.standard.removeObject(forKey: preferredLanguageKey)
        hasCompletedOnboarding = false
        shouldShowPostSignupPlans = false
    }
    
    func completePostSignupPlans() {
        UserDefaults.standard.set(false, forKey: postSignupPlansPendingKey)
        shouldShowPostSignupPlans = false
    }
    
    func reset() {
        signOut()
        UserDefaults.standard.removeObject(forKey: userIdKey)
        resetOnboardingForTesting()
    }
}

