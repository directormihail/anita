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
    
    // Validate configuration
    static var isConfigured: Bool {
        return !supabaseURL.isEmpty && 
               supabaseURL != "YOUR_SUPABASE_URL_HERE" &&
               !supabaseAnonKey.isEmpty &&
               supabaseAnonKey != "YOUR_SUPABASE_ANON_KEY_HERE"
    }
}

