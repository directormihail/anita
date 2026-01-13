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
    private let supabaseService = SupabaseService.shared
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var hasCompletedOnboarding = false
    
    private init() {
        supabaseService.loadSavedToken()
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
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
    }
    
    func signUp(email: String, password: String) async throws {
        let authResponse = try await supabaseService.signUp(email: email, password: password)
        await MainActor.run {
            self.currentUser = authResponse.user
            self.isAuthenticated = true
            // New users need to complete onboarding
            self.hasCompletedOnboarding = false
            UserDefaults.standard.set(false, forKey: onboardingCompletedKey)
        }
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
    }
    
    func signOut() {
        supabaseService.signOut()
        Task { @MainActor in
            self.currentUser = nil
            self.isAuthenticated = false
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
    
    func reset() {
        signOut()
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: onboardingCompletedKey)
        hasCompletedOnboarding = false
    }
}

