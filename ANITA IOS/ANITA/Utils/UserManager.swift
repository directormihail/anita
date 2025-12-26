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
    private let supabaseService = SupabaseService.shared
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private init() {
        supabaseService.loadSavedToken()
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
        }
    }
    
    func signUp(email: String, password: String) async throws {
        let authResponse = try await supabaseService.signUp(email: email, password: password)
        await MainActor.run {
            self.currentUser = authResponse.user
            self.isAuthenticated = true
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
    
    func reset() {
        signOut()
        UserDefaults.standard.removeObject(forKey: userIdKey)
    }
}

