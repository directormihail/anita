#!/usr/bin/env swift

//
//  test-google-config.swift
//  Quick test script to validate Google Sign-In configuration
//
//  Usage: swift test-google-config.swift [CLIENT_ID]
//

import Foundation

// Simple validation function (matches Config.swift logic)
func isValidGoogleClientID(_ clientID: String) -> Bool {
    let pattern = #"^\d+-[a-zA-Z0-9]+\.apps\.googleusercontent\.com$"#
    let regex = try? NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(location: 0, length: clientID.utf16.count)
    return regex?.firstMatch(in: clientID, options: [], range: range) != nil
}

func calculateReversedClientID(from clientID: String) -> String {
    let components = clientID.components(separatedBy: ".")
    return components.reversed().joined(separator: ".")
}

func testClientID(_ clientID: String) {
    print("\n═══════════════════════════════════════════════════════════")
    print("  Google Client ID Test")
    print("═══════════════════════════════════════════════════════════\n")
    
    print("Client ID: \(clientID)\n")
    
    // Test format
    if isValidGoogleClientID(clientID) {
        print("✅ Format: VALID")
    } else {
        print("❌ Format: INVALID")
        print("   Expected: 123456789-abc123def456.apps.googleusercontent.com")
        return
    }
    
    // Calculate reversed
    let reversed = calculateReversedClientID(from: clientID)
    print("✅ Reversed Client ID: \(reversed)\n")
    
    print("═══════════════════════════════════════════════════════════")
    print("  Setup Instructions")
    print("═══════════════════════════════════════════════════════════\n")
    
    print("STEP 1: Add to Config.swift (line ~57):")
    print("─────────────────────────────────────────────────────────")
    print("  return \"\(clientID)\"\n")
    
    print("STEP 2: Add to Info.plist (CFBundleURLSchemes array):")
    print("─────────────────────────────────────────────────────────")
    print("  <string>\(reversed)</string>\n")
    
    print("STEP 3: Build and test the app\n")
    print("✅ Configuration is ready!\n")
}

// Main
let args = CommandLine.arguments

if args.count > 1 {
    let clientID = args[1]
    testClientID(clientID)
} else {
    print("Usage: swift test-google-config.swift [CLIENT_ID]")
    print("\nExample:")
    print("  swift test-google-config.swift 123456789-abc123def456.apps.googleusercontent.com")
    print("\nThis will validate your Client ID and show setup instructions.")
}

