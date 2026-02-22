//
//  SupabaseService.swift
//  ANITA
//
//  Supabase service for authentication and database access
//

import Foundation
import AuthenticationServices
import UIKit

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

private let keychainAccessTokenKey = "supabase_access_token"
private let keychainRefreshTokenKey = "supabase_refresh_token"
private let userDefaultsTokenKey = "supabase_access_token"

class SupabaseService {
    static let shared = SupabaseService()
    
    private var supabaseUrl: String
    private var supabaseAnonKey: String
    private var accessToken: String?
    private var refreshToken: String?
    
    // Track OAuth progress
    private var isOAuthInProgress = false
    
    private init() {
        // Load from Config instead of UserDefaults
        self.supabaseUrl = Config.supabaseURL
        self.supabaseAnonKey = Config.supabaseAnonKey
        
        if !Config.isConfigured {
            print("[Supabase] ⚠️ WARNING: Supabase not configured! Please set SUPABASE_URL and SUPABASE_ANON_KEY in Config.swift")
        }
        
        // Check Google Sign-In configuration
        if !Config.isGoogleSignInConfigured {
            print("[Supabase] ⚠️ WARNING: Google Sign-In not configured!")
            print("[Supabase] \(Config.googleSignInStatus)")
            print("[Supabase] See GOOGLE_SIGNIN_IOS_SETUP.md for setup instructions")
            print("[Supabase]")
            print("[Supabase] To configure:")
            print("[Supabase] 1. Get iOS OAuth Client ID from Google Cloud Console")
            print("[Supabase] 2. Add it to Config.swift (line ~57)")
            print("[Supabase] 3. Add reversed Client ID to Info.plist")
            print("[Supabase] 4. See GET_GOOGLE_CLIENT_ID_FROM_WEBAPP.md for details")
        } else {
            print("[Supabase] ✓ Google Sign-In configuration validated")
            print("[Supabase] Client ID: \(Config.googleClientID)")
            if let reversed = Config.googleReversedClientID {
                print("[Supabase] Reversed Client ID: \(reversed)")
                print("[Supabase] ⚠️  Make sure this is added to Info.plist CFBundleURLSchemes")
            }
        }
    }
    
    /// Persist full session (e.g. after login/signup). Uses Keychain so it survives app restarts and TestFlight updates.
    private func setSession(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        KeychainHelper.set(accessToken, forKey: keychainAccessTokenKey)
        KeychainHelper.set(refreshToken, forKey: keychainRefreshTokenKey)
        UserDefaults.standard.set(accessToken, forKey: userDefaultsTokenKey)
    }
    
    func setAccessToken(_ token: String?) {
        self.accessToken = token
        if let token = token {
            KeychainHelper.set(token, forKey: keychainAccessTokenKey)
            UserDefaults.standard.set(token, forKey: userDefaultsTokenKey)
        } else {
            self.refreshToken = nil
            KeychainHelper.delete(forKey: keychainAccessTokenKey)
            KeychainHelper.delete(forKey: keychainRefreshTokenKey)
            UserDefaults.standard.removeObject(forKey: userDefaultsTokenKey)
        }
    }
    
    // Get access token (public method for other services)
    func getAccessToken() -> String? {
        return accessToken
    }
    
    // Check if user is authenticated
    var isAuthenticated: Bool {
        return accessToken != nil
    }
    
    /// Load saved session from Keychain (primary) or UserDefaults (migration). Keychain persists on TestFlight.
    func loadSavedToken() {
        if let access = KeychainHelper.get(forKey: keychainAccessTokenKey),
           let refresh = KeychainHelper.get(forKey: keychainRefreshTokenKey) {
            self.accessToken = access
            self.refreshToken = refresh
            UserDefaults.standard.set(access, forKey: userDefaultsTokenKey)
            return
        }
        if let access = UserDefaults.standard.string(forKey: userDefaultsTokenKey) {
            self.accessToken = access
            KeychainHelper.set(access, forKey: keychainAccessTokenKey)
            if let refresh = KeychainHelper.get(forKey: keychainRefreshTokenKey) {
                self.refreshToken = refresh
            }
        }
    }
    
    // Test Supabase connection
    func testConnection() async throws -> Bool {
        guard !supabaseUrl.isEmpty, !supabaseAnonKey.isEmpty else {
            throw SupabaseError.notConfigured
        }
        
        let baseUrl = supabaseUrl.hasSuffix("/") ? String(supabaseUrl.dropLast()) : supabaseUrl
        let url = URL(string: "\(baseUrl)/auth/v1/health")!
        
        var request = URLRequest(url: url)
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("[Supabase] Testing connection to: \(url.absoluteString)")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        print("[Supabase] Health check status: \(httpResponse.statusCode)")
        return httpResponse.statusCode == 200
    }
    
    // MARK: - Authentication
    
    func signIn(email: String, password: String) async throws -> AuthResponse {
        guard !supabaseUrl.isEmpty, !supabaseAnonKey.isEmpty else {
            throw SupabaseError.notConfigured
        }
        
        // Ensure URL doesn't have trailing slash
        let baseUrl = supabaseUrl.hasSuffix("/") ? String(supabaseUrl.dropLast()) : supabaseUrl
        let url = URL(string: "\(baseUrl)/auth/v1/token?grant_type=password")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        // Don't set Authorization header for password grant - Supabase uses apikey header only
        
        let body: [String: String] = [
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        print("[Supabase] Sign in request to: \(url.absoluteString)")
        print("[Supabase] Email: \(email)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[Supabase] Invalid response type")
            throw SupabaseError.invalidResponse
        }
        
        print("[Supabase] Response status: \(httpResponse.statusCode)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("[Supabase] Response body: \(responseString)")
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            do {
                let authResponse = try decoder.decode(AuthResponse.self, from: data)
                setSession(accessToken: authResponse.accessToken, refreshToken: authResponse.refreshToken)
                print("[Supabase] Sign in successful, user ID: \(authResponse.user.id)")
                return authResponse
            } catch {
                print("[Supabase] Decode error: \(error)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("[Supabase] Response JSON: \(json)")
                }
                throw SupabaseError.authFailed("Failed to decode response: \(error.localizedDescription)")
            }
        } else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[Supabase] Auth failed with status \(httpResponse.statusCode): \(errorString)")
            
            if let error = try? JSONDecoder().decode(SupabaseAuthError.self, from: data) {
                let errorMsg = error.message ?? error.error ?? "Authentication failed"
                throw SupabaseError.authFailed(errorMsg)
            } else {
                throw SupabaseError.authFailed("Authentication failed: \(errorString)")
            }
        }
    }
    
    func signUp(email: String, password: String) async throws -> AuthResponse {
        guard !supabaseUrl.isEmpty, !supabaseAnonKey.isEmpty else {
            throw SupabaseError.notConfigured
        }
        
        // Ensure URL doesn't have trailing slash
        let baseUrl = supabaseUrl.hasSuffix("/") ? String(supabaseUrl.dropLast()) : supabaseUrl
        let url = URL(string: "\(baseUrl)/auth/v1/signup")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        // Don't set Authorization header for signup - Supabase uses apikey header only
        
        let body: [String: String] = [
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        print("[Supabase] Sign up request to: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        print("[Supabase] Sign up response status: \(httpResponse.statusCode)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("[Supabase] Sign up response: \(responseString)")
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            do {
                let authResponse = try decoder.decode(AuthResponse.self, from: data)
                setSession(accessToken: authResponse.accessToken, refreshToken: authResponse.refreshToken)
                print("[Supabase] Sign up successful, user ID: \(authResponse.user.id)")
                return authResponse
            } catch {
                print("[Supabase] Decode error: \(error)")
                throw SupabaseError.authFailed("Failed to decode response: \(error.localizedDescription)")
            }
        } else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[Supabase] Sign up failed: \(errorString)")
            
            if let error = try? JSONDecoder().decode(SupabaseAuthError.self, from: data) {
                let errorMsg = error.message ?? error.error ?? "Sign up failed"
                throw SupabaseError.authFailed(errorMsg)
            } else {
                throw SupabaseError.authFailed("Sign up failed: \(errorString)")
            }
        }
    }
    
    /// Request a password reset email for the given address. Supabase sends a recovery link to the user.
    func resetPassword(email: String) async throws {
        guard !supabaseUrl.isEmpty, !supabaseAnonKey.isEmpty else {
            throw SupabaseError.notConfigured
        }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SupabaseError.authFailed("Please enter your email address.")
        }
        
        let baseUrl = supabaseUrl.hasSuffix("/") ? String(supabaseUrl.dropLast()) : supabaseUrl
        let url = URL(string: "\(baseUrl)/auth/v1/recover")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        // redirect_to so the email link opens the app (must be allowed in Supabase Auth URL config)
        let body: [String: String] = [
            "email": trimmed,
            "redirect_to": "anita://auth/callback"
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        print("[Supabase] Password reset request for: \(trimmed)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("[Supabase] Recover response (\(httpResponse.statusCode)): \(responseString)")
        }
        
        // Supabase returns 200 and sends the email; it may return an error body even on 200 for "user not found" in some configs
        if httpResponse.statusCode == 200 {
            return
        }
        let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
        if let error = try? JSONDecoder().decode(SupabaseAuthError.self, from: data) {
            throw SupabaseError.authFailed(error.message ?? error.error ?? "Password reset failed")
        }
        throw SupabaseError.authFailed("Password reset failed: \(errorString)")
    }
    
    /// Set session from recovery link tokens (e.g. after user opens anita://...#access_token=...&refresh_token=...&type=recovery).
    func setSessionFromRecovery(accessToken: String, refreshToken: String) {
        setSession(accessToken: accessToken, refreshToken: refreshToken)
        print("[Supabase] Session set from recovery link")
    }
    
    /// Update the current user's password. Call after recovery link has set the session; used to complete "forgot password" flow.
    func updatePassword(_ newPassword: String) async throws {
        guard let token = accessToken else {
            throw SupabaseError.authFailed("No session. Open the reset link from your email first.")
        }
        let trimmed = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6 else {
            throw SupabaseError.authFailed("Password must be at least 6 characters.")
        }
        
        let baseUrl = supabaseUrl.hasSuffix("/") ? String(supabaseUrl.dropLast()) : supabaseUrl
        let url = URL(string: "\(baseUrl)/auth/v1/user")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: String] = ["password": trimmed]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
            return
        }
        let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
        if let error = try? JSONDecoder().decode(SupabaseAuthError.self, from: data) {
            throw SupabaseError.authFailed(error.message ?? error.error ?? "Failed to update password")
        }
        throw SupabaseError.authFailed("Failed to update password: \(errorString)")
    }
    
    func signOut() {
        setAccessToken(nil)
    }
    
    /// Refresh access token using refresh token. Call when access token is expired or getCurrentUser returns 401.
    private func refreshSession() async throws -> Bool {
        guard let refresh = refreshToken, !refresh.isEmpty else { return false }
        guard !supabaseUrl.isEmpty, !supabaseAnonKey.isEmpty else { return false }
        
        let baseUrl = supabaseUrl.hasSuffix("/") ? String(supabaseUrl.dropLast()) : supabaseUrl
        let url = URL(string: "\(baseUrl)/auth/v1/token?grant_type=refresh_token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: String] = ["refresh_token": refresh]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { return false }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let authResponse = try decoder.decode(AuthResponse.self, from: data)
            setSession(accessToken: authResponse.accessToken, refreshToken: authResponse.refreshToken)
            print("[Supabase] Session refreshed successfully")
            return true
        }
        return false
    }
    
    // MARK: - OAuth Authentication (Native Google Sign-In)
    
    func signInWithGoogle() async throws -> AuthResponse {
        #if canImport(GoogleSignIn)
        guard !supabaseUrl.isEmpty, !supabaseAnonKey.isEmpty else {
            throw SupabaseError.notConfigured
        }
        
        // Prevent multiple simultaneous sign-in attempts
        let alreadyInProgress = await MainActor.run {
            if self.isOAuthInProgress {
                return true
            }
            self.isOAuthInProgress = true
            return false
        }
        
        if alreadyInProgress {
            throw SupabaseError.authFailed("Google sign-in already in progress")
        }
        
        defer {
            Task { @MainActor in
                self.isOAuthInProgress = false
            }
        }
        
        // Get the root view controller for Google Sign-In
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw SupabaseError.authFailed("Could not find root view controller")
        }
        
        // Configure Google Sign-In
        guard !Config.googleClientID.isEmpty else {
            throw SupabaseError.authFailed("Google Client ID not configured. Please set GOOGLE_CLIENT_ID in Config.swift. See GOOGLE_SIGNIN_IOS_SETUP.md for instructions. You need an iOS OAuth Client ID from Google Cloud Console (not a Web Client ID).")
        }
        
        // Validate client ID format
        guard Config.isValidGoogleClientID(Config.googleClientID) else {
            throw SupabaseError.authFailed("Invalid Google Client ID format. Expected format: 123456789-abc123def456.apps.googleusercontent.com. Make sure you're using an iOS OAuth Client ID, not a Web Client ID.")
        }
        
        let configuration = GIDConfiguration(clientID: Config.googleClientID)
        GIDSignIn.sharedInstance.configuration = configuration
        
        // Perform native Google Sign-In
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw SupabaseError.authFailed("No ID token received from Google")
        }
        
        let accessToken = result.user.accessToken.tokenString
        
        print("[Supabase] Google Sign-In successful, ID token received")
        
        // Exchange ID token with Supabase
        return try await signInWithIdToken(idToken: idToken, accessToken: accessToken)
        #else
        throw SupabaseError.authFailed("GoogleSignIn SDK not installed. Please add it via Swift Package Manager:\n1. File → Add Package Dependencies\n2. URL: https://github.com/google/GoogleSignIn-iOS\n3. Version: 7.0.0 or later")
        #endif
    }
    
    private func signInWithIdToken(idToken: String, accessToken: String) async throws -> AuthResponse {
        guard !supabaseUrl.isEmpty, !supabaseAnonKey.isEmpty else {
            throw SupabaseError.notConfigured
        }
        
        let baseUrl = supabaseUrl.hasSuffix("/") ? String(supabaseUrl.dropLast()) : supabaseUrl
        let url = URL(string: "\(baseUrl)/auth/v1/token?grant_type=id_token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("2024-01-01", forHTTPHeaderField: "X-Supabase-Api-Version")
        
        // Do NOT pass nonce for Google: GoTrue hashes the passed nonce and compares to the token,
        // but Google's id_token contains raw nonce, so that causes "Nonces mismatch". Enable
        // "Skip nonce checks" for Google in Supabase Dashboard (Auth → Providers → Google).
        let clientId = Config.googleClientID
        var body: [String: Any] = [
            "provider": "google",
            "id_token": idToken,
            "access_token": accessToken
        ]
        if !clientId.isEmpty {
            body["client_id"] = clientId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("[Supabase] Exchanging Google ID token with Supabase")
        print("[Supabase] URL: \(url.absoluteString)")
        print("[Supabase] Provider: google")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        print("[Supabase] ID token exchange response status: \(httpResponse.statusCode)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("[Supabase] Response body: \(responseString)")
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            do {
                let authResponse = try decoder.decode(AuthResponse.self, from: data)
                setSession(accessToken: authResponse.accessToken, refreshToken: authResponse.refreshToken)
                print("[Supabase] ✅ Google sign-in successful, user ID: \(authResponse.user.id)")
                return authResponse
            } catch {
                print("[Supabase] ❌ Decode error: \(error)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("[Supabase] Response JSON: \(json)")
                }
                throw SupabaseError.authFailed("Failed to decode response: \(error.localizedDescription)")
            }
        } else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[Supabase] ❌ Google sign-in failed with status \(httpResponse.statusCode)")
            print("[Supabase] Full error response: \(errorString)")
            
            // Try to parse error message (error_description has the real reason, e.g. "Unacceptable audience")
            if let error = try? JSONDecoder().decode(SupabaseAuthError.self, from: data) {
                let errorMsg = error.errorDescription ?? error.message ?? error.error ?? "Authentication failed"
                throw SupabaseError.authFailed(errorMsg)
            } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let msg = json["error_description"] as? String {
                    throw SupabaseError.authFailed(msg)
                } else if let msg = json["message"] as? String {
                    throw SupabaseError.authFailed(msg)
                } else if let msg = json["error"] as? String {
                    throw SupabaseError.authFailed(msg)
                } else {
                    throw SupabaseError.authFailed("Authentication failed: \(errorString)")
                }
            } else {
                throw SupabaseError.authFailed("Authentication failed: \(errorString)")
            }
        }
    }
    
    // MARK: - Apple Sign-In
    
    func signInWithApple(idToken: String, nonce: String? = nil) async throws -> AuthResponse {
        guard !supabaseUrl.isEmpty, !supabaseAnonKey.isEmpty else {
            throw SupabaseError.notConfigured
        }
        
        let baseUrl = supabaseUrl.hasSuffix("/") ? String(supabaseUrl.dropLast()) : supabaseUrl
        let url = URL(string: "\(baseUrl)/auth/v1/token?grant_type=id_token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("2024-01-01", forHTTPHeaderField: "X-Supabase-Api-Version")
        
        // Supabase GoTrue expects JSON body; Client IDs in Dashboard must include this bundle ID
        let clientId = Bundle.main.bundleIdentifier ?? "com.anita.app"
        var body: [String: Any] = [
            "provider": "apple",
            "id_token": idToken,
            "client_id": clientId
        ]
        if let nonce = nonce, !nonce.isEmpty {
            body["nonce"] = nonce
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("[Supabase] Exchanging Apple ID token with Supabase")
        print("[Supabase] URL: \(url.absoluteString)")
        print("[Supabase] Provider: apple")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        print("[Supabase] Apple ID token exchange response status: \(httpResponse.statusCode)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("[Supabase] Response body: \(responseString)")
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            do {
                let authResponse = try decoder.decode(AuthResponse.self, from: data)
                setSession(accessToken: authResponse.accessToken, refreshToken: authResponse.refreshToken)
                print("[Supabase] ✅ Apple sign-in successful, user ID: \(authResponse.user.id)")
                return authResponse
            } catch {
                print("[Supabase] ❌ Decode error: \(error)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("[Supabase] Response JSON: \(json)")
                }
                throw SupabaseError.authFailed("Failed to decode response: \(error.localizedDescription)")
            }
        } else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[Supabase] ❌ Apple sign-in failed with status \(httpResponse.statusCode)")
            print("[Supabase] Full error response: \(errorString)")
            
            // Try to parse error message (error_description has the real reason, e.g. "Unacceptable audience")
            if let error = try? JSONDecoder().decode(SupabaseAuthError.self, from: data) {
                let errorMsg = error.errorDescription ?? error.message ?? error.error ?? "Authentication failed"
                throw SupabaseError.authFailed(errorMsg)
            } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let msg = json["error_description"] as? String {
                    throw SupabaseError.authFailed(msg)
                } else if let msg = json["message"] as? String {
                    throw SupabaseError.authFailed(msg)
                } else if let msg = json["error"] as? String {
                    throw SupabaseError.authFailed(msg)
                } else {
                    throw SupabaseError.authFailed("Authentication failed: \(errorString)")
                }
            } else {
                throw SupabaseError.authFailed("Authentication failed: \(errorString)")
            }
        }
    }
    
    func getCurrentUser() async throws -> User? {
        guard let token = accessToken else {
            return nil
        }
        
        let baseUrl = supabaseUrl.hasSuffix("/") ? String(supabaseUrl.dropLast()) : supabaseUrl
        let url = URL(string: "\(baseUrl)/auth/v1/user")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return nil
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try? decoder.decode(User.self, from: data)
        }
        if httpResponse.statusCode == 401, (try? await refreshSession()) == true {
            return try await getCurrentUser()
        }
        print("[Supabase] Get user failed with status: \(httpResponse.statusCode)")
        return nil
    }
    
    // MARK: - User Metadata
    
    /// Updates Supabase Auth user metadata (user.user_metadata).
    /// Best place to store onboarding answers without requiring profile table schema changes.
    func updateUserMetadata(data: [String: Any]) async throws {
        guard let token = accessToken else {
            throw SupabaseError.authFailed("No access token available")
        }
        
        let baseUrl = supabaseUrl.hasSuffix("/") ? String(supabaseUrl.dropLast()) : supabaseUrl
        let url = URL(string: "\(baseUrl)/auth/v1/user")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "data": data
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
            return
        }
        
        let errorString = String(data: responseData, encoding: .utf8) ?? "Unknown error"
        print("[Supabase] updateUserMetadata failed: \(errorString)")
        throw SupabaseError.authFailed("Failed to update user metadata")
    }
    
    // MARK: - Database Operations
    
    private func makeDatabaseRequest(endpoint: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard !supabaseUrl.isEmpty, !supabaseAnonKey.isEmpty else {
            throw SupabaseError.notConfigured
        }
        
        let baseUrl = supabaseUrl.hasSuffix("/") ? String(supabaseUrl.dropLast()) : supabaseUrl
        let url = URL(string: "\(baseUrl)/rest/v1/\(endpoint)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        print("[Supabase] Database request: \(method) \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        print("[Supabase] Database response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
            return data
        } else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[Supabase] Database error: \(errorString)")
            let error = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data)
            throw SupabaseError.databaseError(error?.message ?? errorString)
        }
    }
    
    // Create conversation
    func createConversation(userId: String, title: String) async throws -> Conversation {
        let body: [String: Any] = [
            "user_id": userId,
            "title": title
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        let data = try await makeDatabaseRequest(endpoint: "conversations", method: "POST", body: bodyData)
        let decoder = JSONDecoder()
        return try decoder.decode(Conversation.self, from: data)
    }
    
    // Get conversations
    func getConversations(userId: String) async throws -> [Conversation] {
        let endpoint = "conversations?user_id=eq.\(userId)&order=updated_at.desc"
        let data = try await makeDatabaseRequest(endpoint: endpoint)
        let decoder = JSONDecoder()
        return try decoder.decode([Conversation].self, from: data)
    }
    
    // Get messages for a conversation
    func getMessages(conversationId: String, userId: String) async throws -> [SupabaseMessage] {
        let endpoint = "anita_data?conversation_id=eq.\(conversationId)&account_id=eq.\(userId)&data_type=eq.message&order=created_at.asc"
        let data = try await makeDatabaseRequest(endpoint: endpoint)
        let decoder = JSONDecoder()
        return try decoder.decode([SupabaseMessage].self, from: data)
    }
    
    // Save message
    func saveMessage(userId: String, conversationId: String, messageId: String, messageText: String, sender: String) async throws -> SupabaseMessage {
        let body: [String: Any] = [
            "account_id": userId,
            "conversation_id": conversationId,
            "message_text": messageText,
            "sender": sender,
            "message_id": messageId,
            "data_type": "message",
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        let data = try await makeDatabaseRequest(endpoint: "anita_data", method: "POST", body: bodyData)
        let decoder = JSONDecoder()
        let messages = try decoder.decode([SupabaseMessage].self, from: data)
        return messages[0]
    }
}

// MARK: - Models

struct AuthResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case user
    }
    
    // Handle cases where response might be wrapped
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        tokenType = try container.decode(String.self, forKey: .tokenType)
        expiresIn = try container.decode(Int.self, forKey: .expiresIn)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        user = try container.decode(User.self, forKey: .user)
    }
    
    // Custom initializer for OAuth
    init(accessToken: String, tokenType: String, expiresIn: Int, refreshToken: String, user: User) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.refreshToken = refreshToken
        self.user = user
    }
}


struct User: Codable {
    let id: String
    let email: String?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
    }
    
    // Handle different response formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

struct SupabaseAuthError: Codable {
    let message: String?
    let error: String?
    let errorDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case message, error
        case errorDescription = "error_description"
    }
}

struct SupabaseErrorResponse: Codable {
    let message: String?
    let code: String?
}

struct SupabaseMessage: Codable {
    let id: String
    let accountId: String
    let conversationId: String?
    let messageText: String?
    let sender: String?
    let messageId: String?
    let dataType: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case conversationId = "conversation_id"
        case messageText = "message_text"
        case sender
        case messageId = "message_id"
        case dataType = "data_type"
        case createdAt = "created_at"
    }
}

enum SupabaseError: LocalizedError {
    case notConfigured
    case invalidResponse
    case authFailed(String)
    case databaseError(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase is not configured. Please set URL and anon key."
        case .invalidResponse:
            return "Invalid response from server"
        case .authFailed(let message):
            return "Authentication failed: \(message)"
        case .databaseError(let message):
            return "Database error: \(message)"
        }
    }
}

