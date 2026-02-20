//
//  AuthViewModel.swift
//  ANITA
//
//  View model for authentication
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// True after the first auth check has completed. Prevents showing login screen before we've tried restoring session.
    @Published var hasCompletedInitialAuthCheck = false
    
    private let userManager = UserManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observe UserManager's authentication state changes
        userManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                self?.isAuthenticated = isAuthenticated
            }
            .store(in: &cancellables)
        
        // Check initial auth status (session restore from Keychain)
        Task {
            await checkAuthStatus()
        }
    }
    
    func checkAuthStatus() async {
        await userManager.checkAuthStatus()
        isAuthenticated = userManager.isAuthenticated
        hasCompletedInitialAuthCheck = true
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await userManager.signIn(email: email, password: password)
            isAuthenticated = userManager.isAuthenticated
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await userManager.signUp(email: email, password: password)
            isAuthenticated = userManager.isAuthenticated
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
        
        isLoading = false
    }
    
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await userManager.signInWithGoogle()
            isAuthenticated = userManager.isAuthenticated
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
        
        isLoading = false
    }
    
    func signInWithApple(idToken: String, nonce: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await userManager.signInWithApple(idToken: idToken, nonce: nonce)
            isAuthenticated = userManager.isAuthenticated
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
        
        isLoading = false
    }
    
    func signOut() {
        userManager.signOut()
        isAuthenticated = false
    }
}

