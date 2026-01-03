#!/usr/bin/env swift

//
//  test-google-setup.swift
//  Comprehensive test for Google Sign-In configuration
//

import Foundation

// Test configuration
struct GoogleConfigTest {
    static func runAllTests() {
        print("\n")
        print("═══════════════════════════════════════════════════════════")
        print("  Google Sign-In Configuration Test Suite")
        print("═══════════════════════════════════════════════════════════")
        print("")
        
        var allPassed = true
        
        // Test 1: Check Config.swift exists
        print("Test 1: Checking Config.swift...")
        let configPath = "ANITA/Utils/Config.swift"
        if FileManager.default.fileExists(atPath: configPath) {
            print("  ✅ Config.swift exists")
            
            // Read and check content
            if let content = try? String(contentsOfFile: configPath, encoding: .utf8) {
                // Check if googleClientID is defined
                if content.contains("googleClientID") {
                    print("  ✅ googleClientID property found")
                    
                    // Check if it's empty
                    if content.contains("return \"\"") {
                        print("  ⚠️  googleClientID is empty - needs to be configured")
                        allPassed = false
                    } else if content.range(of: #"return\s+"[^"]+\.apps\.googleusercontent\.com""#, options: .regularExpression) != nil {
                        print("  ✅ googleClientID appears to be configured")
                    }
                } else {
                    print("  ❌ googleClientID property not found")
                    allPassed = false
                }
            }
        } else {
            print("  ❌ Config.swift not found at: \(configPath)")
            allPassed = false
        }
        
        print("")
        
        // Test 2: Check Info.plist exists
        print("Test 2: Checking Info.plist...")
        let plistPath = "ANITA/Info.plist"
        if FileManager.default.fileExists(atPath: plistPath) {
            print("  ✅ Info.plist exists")
            
            if let content = try? String(contentsOfFile: plistPath, encoding: .utf8) {
                // Check for CFBundleURLSchemes
                if content.contains("CFBundleURLSchemes") {
                    print("  ✅ CFBundleURLSchemes found")
                    
                    // Check if reversed client ID is present
                    if content.range(of: #"com\.googleusercontent\.apps\.[0-9]+-[a-zA-Z0-9]+"#, options: .regularExpression) != nil {
                        print("  ✅ Reversed Client ID appears to be configured")
                    } else {
                        print("  ⚠️  Reversed Client ID not found - needs to be added")
                        allPassed = false
                    }
                } else {
                    print("  ⚠️  CFBundleURLSchemes not found")
                    allPassed = false
                }
            }
        } else {
            print("  ❌ Info.plist not found at: \(plistPath)")
            allPassed = false
        }
        
        print("")
        
        // Test 3: Validate Client ID format (if provided)
        if CommandLine.arguments.count > 1 {
            let clientID = CommandLine.arguments[1]
            print("Test 3: Validating Client ID format...")
            print("  Client ID: \(clientID)")
            
            let pattern = #"^\d+-[a-zA-Z0-9]+\.apps\.googleusercontent\.com$"#
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: clientID.utf16.count)
            
            if regex?.firstMatch(in: clientID, options: [], range: range) != nil {
                print("  ✅ Client ID format is valid")
                
                // Calculate reversed
                let components = clientID.components(separatedBy: ".")
                let reversed = components.reversed().joined(separator: ".")
                print("  ✅ Reversed Client ID: \(reversed)")
            } else {
                print("  ❌ Client ID format is invalid")
                print("  Expected format: 123456789-abc123def456.apps.googleusercontent.com")
                allPassed = false
            }
        } else {
            print("Test 3: Skipped (no Client ID provided)")
            print("  To test format, run: swift test-google-setup.swift \"YOUR_CLIENT_ID\"")
        }
        
        print("")
        print("═══════════════════════════════════════════════════════════")
        if allPassed {
            print("  ✅ All tests passed!")
        } else {
            print("  ⚠️  Some tests failed - configuration needs attention")
        }
        print("═══════════════════════════════════════════════════════════")
        print("")
        
        if !allPassed {
            print("Next steps:")
            print("1. Get iOS OAuth Client ID from Google Cloud Console")
            print("2. Add it to Config.swift (line ~57)")
            print("3. Add reversed Client ID to Info.plist")
            print("4. Run this test again to verify")
            print("")
        }
    }
}

// Run tests
GoogleConfigTest.runAllTests()

