//
//  GoogleSignInConfigTester.swift
//  ANITA
//
//  Utility to test and validate Google Sign-In configuration
//

import Foundation

struct GoogleSignInConfigTester {
    
    /// Test the Google Sign-In configuration
    static func testConfiguration() -> TestResult {
        var issues: [String] = []
        var warnings: [String] = []
        var successes: [String] = []
        
        // Test 1: Check if Client ID is set
        if Config.googleClientID.isEmpty {
            issues.append("❌ Google Client ID is not set in Config.swift")
            issues.append("   → Add your iOS OAuth Client ID to Config.swift (line ~57)")
            issues.append("   → Format: \"123456789-abc123def456.apps.googleusercontent.com\"")
        } else {
            successes.append("✅ Google Client ID is set")
            
            // Test 2: Validate Client ID format
            if Config.isValidGoogleClientID(Config.googleClientID) {
                successes.append("✅ Google Client ID format is valid")
            } else {
                issues.append("❌ Google Client ID format is invalid")
                issues.append("   → Current: \(Config.googleClientID)")
                issues.append("   → Expected format: 123456789-abc123def456.apps.googleusercontent.com")
                issues.append("   → Make sure you're using an iOS OAuth Client ID, not a Web Client ID")
            }
        }
        
        // Test 3: Check reversed Client ID
        if let reversedID = Config.googleReversedClientID {
            successes.append("✅ Reversed Client ID calculated: \(reversedID)")
            
            // Check if it's in Info.plist (we can't directly read it, but we can provide instructions)
            warnings.append("⚠️  Make sure reversed Client ID is in Info.plist:")
            warnings.append("   → Add to CFBundleURLSchemes: \"\(reversedID)\"")
        } else {
            if !Config.googleClientID.isEmpty {
                issues.append("❌ Could not calculate reversed Client ID")
            }
        }
        
        // Test 4: Check Supabase configuration
        if Config.isConfigured {
            successes.append("✅ Supabase is configured")
        } else {
            warnings.append("⚠️  Supabase configuration may be incomplete")
        }
        
        // Test 5: Overall status
        let isConfigured = Config.isGoogleSignInConfigured
        if isConfigured {
            successes.append("✅ Google Sign-In is properly configured and ready to use!")
        }
        
        return TestResult(
            isConfigured: isConfigured,
            issues: issues,
            warnings: warnings,
            successes: successes
        )
    }
    
    /// Get a detailed status report
    static func getStatusReport() -> String {
        let result = testConfiguration()
        var report = "\n"
        report += "═══════════════════════════════════════════════════════════\n"
        report += "  Google Sign-In Configuration Test Report\n"
        report += "═══════════════════════════════════════════════════════════\n\n"
        
        if !result.successes.isEmpty {
            report += "✅ SUCCESSES:\n"
            for success in result.successes {
                report += "   \(success)\n"
            }
            report += "\n"
        }
        
        if !result.warnings.isEmpty {
            report += "⚠️  WARNINGS:\n"
            for warning in result.warnings {
                report += "   \(warning)\n"
            }
            report += "\n"
        }
        
        if !result.issues.isEmpty {
            report += "❌ ISSUES TO FIX:\n"
            for issue in result.issues {
                report += "   \(issue)\n"
            }
            report += "\n"
        }
        
        report += "═══════════════════════════════════════════════════════════\n"
        report += "  Configuration Status: \(result.isConfigured ? "✅ READY" : "❌ NOT READY")\n"
        report += "═══════════════════════════════════════════════════════════\n"
        
        if !result.isConfigured {
            report += "\n📋 SETUP INSTRUCTIONS:\n"
            report += "   1. Go to Google Cloud Console: https://console.cloud.google.com/\n"
            report += "   2. Create iOS OAuth Client ID (Application type: iOS)\n"
            report += "   3. Bundle ID must be: com.anita.app\n"
            report += "   4. Copy the Client ID\n"
            report += "   5. Add it to Config.swift (line ~57)\n"
            report += "   6. Add reversed Client ID to Info.plist\n"
            report += "   7. See GOOGLE_SIGNIN_IOS_SETUP.md for details\n"
        }
        
        return report
    }
    
    /// Calculate reversed Client ID from a given Client ID
    static func calculateReversedClientID(from clientID: String) -> String? {
        guard !clientID.isEmpty else { return nil }
        let components = clientID.components(separatedBy: ".")
        return components.reversed().joined(separator: ".")
    }
    
    /// Get setup instructions for a specific Client ID
    static func getSetupInstructions(for clientID: String) -> String {
        var instructions = "\n"
        instructions += "═══════════════════════════════════════════════════════════\n"
        instructions += "  Setup Instructions for Your Client ID\n"
        instructions += "═══════════════════════════════════════════════════════════\n\n"
        
        instructions += "Your iOS Client ID:\n"
        instructions += "  \(clientID)\n\n"
        
        if let reversed = calculateReversedClientID(from: clientID) {
            instructions += "Reversed Client ID (for Info.plist):\n"
            instructions += "  \(reversed)\n\n"
        }
        
        instructions += "STEP 1: Add to Config.swift\n"
        instructions += "─────────────────────────────────────────────────────────\n"
        instructions += "Open ANITA/Utils/Config.swift and replace line 57:\n\n"
        instructions += "  return \"\(clientID)\"\n\n"
        
        instructions += "STEP 2: Add to Info.plist\n"
        instructions += "─────────────────────────────────────────────────────────\n"
        if let reversed = calculateReversedClientID(from: clientID) {
            instructions += "Open ANITA/Info.plist and add to CFBundleURLSchemes array:\n\n"
            instructions += "  <string>\(reversed)</string>\n\n"
        }
        
        instructions += "STEP 3: Test\n"
        instructions += "─────────────────────────────────────────────────────────\n"
        instructions += "Build and run the app, then try Google Sign-In.\n\n"
        
        return instructions
    }
}

struct TestResult {
    let isConfigured: Bool
    let issues: [String]
    let warnings: [String]
    let successes: [String]
}

