//
//  Config.swift
//  ANITA
//

import Foundation

struct Config {
    static let supabaseURL: String = {
        if let url = ProcessInfo.processInfo.environment["SUPABASE_URL"] {
            return url
        }
        return "https://kezregiqfxlrvaxytdet.supabase.co"
    }()
    
    static let supabaseAnonKey: String = {
        if let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] {
            return key
        }
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtlenJlZ2lxZnhscnZheHl0ZGV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc2OTY5MTgsImV4cCI6MjA3MzI3MjkxOH0.X4QWu0W31Kv_8KGQ6h_n4PYnQOMTX85CYbWJVbv2AxM"
    }()
    
    static let productionBackendURL: String = {
        if let url = ProcessInfo.processInfo.environment["PRODUCTION_BACKEND_URL"] {
            return url
        }
        return "https://anita-production-bb9a.up.railway.app"
    }()
    
    static let backendURL: String = {
        if let url = ProcessInfo.processInfo.environment["BACKEND_URL"], !url.isEmpty {
            return url
        }
        #if DEBUG
        return productionBackendURL
        #else
        return productionBackendURL
        #endif
    }()
    
    /// iOS OAuth client ID (`*.apps.googleusercontent.com`), not the web client.
    static let googleClientID: String = {
        if let clientId = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"], !clientId.isEmpty {
            return clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "730448941091-ckogfhc8vjhgce8l2bf7l2mpnjaku0i9.apps.googleusercontent.com"
    }()
    
    static func isValidGoogleClientID(_ clientID: String) -> Bool {
        let pattern = #"^\d+-[a-zA-Z0-9]+\.apps\.googleusercontent\.com$"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: clientID.utf16.count)
        return regex?.firstMatch(in: clientID, options: [], range: range) != nil
    }
    
    static var googleReversedClientID: String? {
        guard !googleClientID.isEmpty else { return nil }
        let components = googleClientID.components(separatedBy: ".")
        return components.reversed().joined(separator: ".")
    }
    
    static func calculateReversedClientID(from clientID: String) -> String? {
        guard !clientID.isEmpty else { return nil }
        let components = clientID.components(separatedBy: ".")
        return components.reversed().joined(separator: ".")
    }
    
    static var isConfigured: Bool {
        return !supabaseURL.isEmpty && 
               supabaseURL != "YOUR_SUPABASE_URL_HERE" &&
               !supabaseAnonKey.isEmpty &&
               supabaseAnonKey != "YOUR_SUPABASE_ANON_KEY_HERE"
    }
    
    static let posthogAPIKey: String = {
        if let key = ProcessInfo.processInfo.environment["POSTHOG_KEY"], !key.isEmpty {
            return key
        }
        return "phc_ec2vFoSH9LiPzanrLJ4r4is34g0yR81T3c6rVN0jRPd"
    }()
    
    static let posthogHost: String = {
        if let host = ProcessInfo.processInfo.environment["POSTHOG_HOST"], !host.isEmpty {
            return host
        }
        return "https://us.i.posthog.com"
    }()
    
    static let posthogProjectID: String = "318843"
    
    /// Publishable key only; must match backend test/live mode.
    static let stripePublishableKey: String = {
        if let key = ProcessInfo.processInfo.environment["STRIPE_PUBLISHABLE_KEY"], !key.isEmpty {
            return key.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "pk_live_51SPnR83ZFm0UsFDGAMEA6i8ubiNNPvYzIROv0W6xdPqHo1wCeSBNpmrBPbpNr3Pw5ZWmQIWYQxSdUEX2AsLNTDuI00DAtV3caw"
    }()
    
    static var isGoogleSignInConfigured: Bool {
        return !googleClientID.isEmpty && isValidGoogleClientID(googleClientID)
    }
    
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

