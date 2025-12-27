//
//  Config.swift
//  ANITA
//
//  Configuration file for Supabase and API keys
//  IMPORTANT: Add this file to .gitignore to keep keys secure
//

import Foundation

struct Config {
    // Supabase Configuration
    static let supabaseURL: String = {
        // Try to read from environment variable first (for CI/CD)
        if let url = ProcessInfo.processInfo.environment["SUPABASE_URL"] {
            return url
        }
        // Hardcoded value
        return "https://kezregiqfxlrvaxytdet.supabase.co"
    }()
    
    static let supabaseAnonKey: String = {
        // Try to read from environment variable first (for CI/CD)
        if let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] {
            return key
        }
        // Hardcoded value
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtlenJlZ2lxZnhscnZheHl0ZGV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc2OTY5MTgsImV4cCI6MjA3MzI3MjkxOH0.X4QWu0W31Kv_8KGQ6h_n4PYnQOMTX85CYbWJVbv2AxM"
    }()
    
    // Backend API Configuration
    static let backendURL: String = {
        if let url = ProcessInfo.processInfo.environment["BACKEND_URL"] {
            return url
        }
        // Default to localhost for development
        return "http://localhost:3001"
    }()
    
    // Google Sign-In Configuration
    // IMPORTANT: This must be an iOS OAuth Client ID, not a Web Client ID!
    // 
    // To get your iOS Client ID:
    // 1. Go to Google Cloud Console -> APIs & Services -> Credentials
    // 2. Create OAuth client ID with Application type: "iOS"
    // 3. Bundle ID must be: com.anita.app
    // 4. Copy the Client ID (format: 123456789-abc123def456.apps.googleusercontent.com)
    // 5. Paste it below or set GOOGLE_CLIENT_ID environment variable
    //
    // See GOOGLE_SIGNIN_IOS_SETUP.md for detailed instructions
    static let googleClientID: String = {
        if let clientId = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"], !clientId.isEmpty {
            return clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Add your iOS OAuth Client ID here
        // Example: "123456789-abc123def456.apps.googleusercontent.com"
        return ""
    }()
    
    // Validate Google Client ID format
    static func isValidGoogleClientID(_ clientID: String) -> Bool {
        // Google Client ID format: numbers-letters.apps.googleusercontent.com
        let pattern = #"^\d+-[a-zA-Z0-9]+\.apps\.googleusercontent\.com$"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: clientID.utf16.count)
        return regex?.firstMatch(in: clientID, options: [], range: range) != nil
    }
    
    // Get reversed client ID for URL scheme (required for Google Sign-In)
    static var googleReversedClientID: String? {
        guard !googleClientID.isEmpty else { return nil }
        // Reverse the client ID: com.googleusercontent.apps.xxx -> com.googleusercontent.apps.xxx
        // Actually, it's the full client ID reversed
        let components = googleClientID.components(separatedBy: ".")
        return components.reversed().joined(separator: ".")
    }
    
    // Validate configuration
    static var isConfigured: Bool {
        return !supabaseURL.isEmpty && 
               supabaseURL != "YOUR_SUPABASE_URL_HERE" &&
               !supabaseAnonKey.isEmpty &&
               supabaseAnonKey != "YOUR_SUPABASE_ANON_KEY_HERE"
    }
    
    // Validate Google Sign-In configuration
    static var isGoogleSignInConfigured: Bool {
        return !googleClientID.isEmpty && isValidGoogleClientID(googleClientID)
    }
    
    // Get configuration status message
    static var googleSignInStatus: String {
        if googleClientID.isEmpty {
            return "Google Client ID is not set. Please add your iOS OAuth Client ID to Config.swift"
        }
        if !isValidGoogleClientID(googleClientID) {
            return "Google Client ID format is invalid. Expected format: 123456789-abc123def456.apps.googleusercontent.com"
        }
        return "Google Sign-In is properly configured"
    }
}

