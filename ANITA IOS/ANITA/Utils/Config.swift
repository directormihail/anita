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
    // Production backend URL - Update this with your actual deployed backend URL
    // 
    // The iOS app uses a separate Express backend (in "ANITA backend" folder)
    // You need to deploy this backend to a hosting service before TestFlight
    //
    // Common deployment platforms:
    // - Railway: https://anita-backend.railway.app (recommended - easy setup)
    // - Render: https://anita-backend.onrender.com (free tier available)
    // - Fly.io: https://anita-backend.fly.dev
    // - Custom domain: https://api.anita.app
    //
    // IMPORTANT: Replace the URL below with your actual deployed backend URL
    // before building for TestFlight!
    static let productionBackendURL: String = {
        if let url = ProcessInfo.processInfo.environment["PRODUCTION_BACKEND_URL"] {
            return url
        }
        // Railway deployment — your public backend URL
        return "https://anita-production-bb9a.up.railway.app"
    }()
    
    static let backendURL: String = {
        // Check environment variable first
        if let url = ProcessInfo.processInfo.environment["BACKEND_URL"] {
            return url
        }
        // Use production Railway URL for all builds (test). For local dev, set Backend URL in Settings to http://localhost:3001 or your Mac IP.
        return productionBackendURL
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
        return "730448941091-ckogfhc8vjhgce8l2bf7l2mpnjaku0i9.apps.googleusercontent.com"
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
        // Reverse the client ID domain parts
        // Example: "123456789-abc.apps.googleusercontent.com" 
        // Becomes: "com.googleusercontent.apps.123456789-abc"
        let components = googleClientID.components(separatedBy: ".")
        return components.reversed().joined(separator: ".")
    }
    
    /// Helper to calculate reversed client ID from any client ID string
    static func calculateReversedClientID(from clientID: String) -> String? {
        guard !clientID.isEmpty else { return nil }
        let components = clientID.components(separatedBy: ".")
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

