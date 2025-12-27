//
//  AuthViewModel.swift
//  ANITA
//
//  View model for authentication
//

import Foundation
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userManager = UserManager.shared
    
    init() {
        // Check initial auth status
        Task {
            await checkAuthStatus()
        }
    }
    
    func checkAuthStatus() async {
        await userManager.checkAuthStatus()
        isAuthenticated = userManager.isAuthenticated
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
    
    func signOut() {
        userManager.signOut()
        isAuthenticated = false
    }
}

