//
//  UserPreferences.swift
//  ANITA
//
//  Utility class to manage user preferences (currency, date format, number format)
//  with Supabase sync
//

import Foundation
import SwiftUI

@MainActor
class UserPreferences: ObservableObject {
    static let shared = UserPreferences()
    
    @Published var currency: String = "USD"
    @Published var dateFormat: String = "MM/DD/YYYY"
    @Published var numberFormat: String = "1,234.56"
    @Published var emailNotifications: Bool = true
    
    private let supabaseService = SupabaseService.shared
    private let userManager = UserManager.shared
    
    private init() {
        loadPreferences()
    }
    
    // MARK: - Load Preferences
    
    func loadPreferences() {
        // First try to load from UserDefaults (fast, local)
        currency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        dateFormat = UserDefaults.standard.string(forKey: "anita_date_format") ?? "MM/DD/YYYY"
        numberFormat = UserDefaults.standard.string(forKey: "anita_number_format") ?? getNumberFormatForCurrency(currency)
        emailNotifications = UserDefaults.standard.bool(forKey: "anita_email_notifications")
        
        // Then sync from Supabase if authenticated
        if userManager.isAuthenticated {
            Task {
                await syncFromSupabase()
            }
        }
    }
    
    private func syncFromSupabase() async {
        guard let userId = userManager.userId, supabaseService.isAuthenticated else {
            return
        }
        
        do {
            let baseUrl = Config.supabaseURL.hasSuffix("/") ? String(Config.supabaseURL.dropLast()) : Config.supabaseURL
            let url = URL(string: "\(baseUrl)/rest/v1/profiles?id=eq.\(userId)&select=currency_code,date_format,number_format,email_notifications")!
            
            var request = URLRequest(url: url)
            request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            if let token = supabaseService.getAccessToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let profile = json.first {
                
                if let currencyCode = profile["currency_code"] as? String, !currencyCode.isEmpty {
                    await MainActor.run {
                        self.currency = currencyCode
                        UserDefaults.standard.set(currencyCode, forKey: "anita_user_currency")
                        // Update number format based on currency
                        let newNumberFormat = getNumberFormatForCurrency(currencyCode)
                        self.numberFormat = newNumberFormat
                        UserDefaults.standard.set(newNumberFormat, forKey: "anita_number_format")
                    }
                }
                
                if let dateFormat = profile["date_format"] as? String, !dateFormat.isEmpty {
                    await MainActor.run {
                        self.dateFormat = dateFormat
                        UserDefaults.standard.set(dateFormat, forKey: "anita_date_format")
                    }
                }
                
                if let numberFormat = profile["number_format"] as? String, !numberFormat.isEmpty {
                    await MainActor.run {
                        self.numberFormat = numberFormat
                        UserDefaults.standard.set(numberFormat, forKey: "anita_number_format")
                    }
                }
                
                if let emailNotifications = profile["email_notifications"] as? Bool {
                    await MainActor.run {
                        self.emailNotifications = emailNotifications
                        UserDefaults.standard.set(emailNotifications, forKey: "anita_email_notifications")
                    }
                }
            }
        } catch {
            print("[UserPreferences] Error syncing from Supabase: \(error)")
        }
    }
    
    // MARK: - Save Preferences
    
    func saveCurrency(_ newCurrency: String) {
        currency = newCurrency
        UserDefaults.standard.set(newCurrency, forKey: "anita_user_currency")
        
        // Update number format based on currency
        let newNumberFormat = getNumberFormatForCurrency(newCurrency)
        numberFormat = newNumberFormat
        UserDefaults.standard.set(newNumberFormat, forKey: "anita_number_format")
        
        // Save to Supabase
        saveToSupabase(currency: newCurrency, numberFormat: newNumberFormat)
    }
    
    func saveDateFormat(_ newDateFormat: String) {
        dateFormat = newDateFormat
        UserDefaults.standard.set(newDateFormat, forKey: "anita_date_format")
        saveToSupabase(dateFormat: newDateFormat)
    }
    
    func saveNumberFormat(_ newNumberFormat: String) {
        numberFormat = newNumberFormat
        UserDefaults.standard.set(newNumberFormat, forKey: "anita_number_format")
        saveToSupabase(numberFormat: newNumberFormat)
    }
    
    func saveEmailNotifications(_ enabled: Bool) {
        emailNotifications = enabled
        UserDefaults.standard.set(enabled, forKey: "anita_email_notifications")
        saveToSupabase(emailNotifications: enabled)
    }
    
    private func saveToSupabase(currency: String? = nil, dateFormat: String? = nil, numberFormat: String? = nil, emailNotifications: Bool? = nil) {
        guard let userId = userManager.userId, supabaseService.isAuthenticated else {
            return
        }
        
        Task {
            do {
                let baseUrl = Config.supabaseURL.hasSuffix("/") ? String(Config.supabaseURL.dropLast()) : Config.supabaseURL
                let url = URL(string: "\(baseUrl)/rest/v1/profiles?id=eq.\(userId)")!
                
                var request = URLRequest(url: url)
                request.httpMethod = "PATCH"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("return=representation", forHTTPHeaderField: "Prefer")
                
                if let token = supabaseService.getAccessToken() {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                
                var updateData: [String: Any] = [:]
                if let currency = currency {
                    updateData["currency_code"] = currency
                    // Get currency symbol
                    updateData["currency_symbol"] = getCurrencySymbol(currency)
                }
                if let dateFormat = dateFormat {
                    updateData["date_format"] = dateFormat
                }
                if let numberFormat = numberFormat {
                    updateData["number_format"] = numberFormat
                }
                if let emailNotifications = emailNotifications {
                    updateData["email_notifications"] = emailNotifications
                }
                
                updateData["updated_at"] = ISO8601DateFormatter().string(from: Date())
                
                request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                    print("[UserPreferences] Failed to save to Supabase")
                    return
                }
                
                print("[UserPreferences] Successfully saved preferences to Supabase")
            } catch {
                print("[UserPreferences] Error saving to Supabase: \(error)")
            }
        }
    }
    
    // MARK: - Formatting Functions
    
    func formatCurrency(_ amount: Double, currencyCode: String? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode ?? currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    func formatAmount(_ amount: Double, currencyCode: String? = nil, showSign: Bool = false, isIncome: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode ?? currency
        let formatted = formatter.string(from: NSNumber(value: abs(amount))) ?? "$0.00"
        
        if showSign {
            let sign = isIncome ? "+" : "-"
            return "\(sign)\(formatted)"
        }
        return formatted
    }
    
    func formatDate(_ dateString: String) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = dateFormatter.date(from: dateString) else {
            // Try without fractional seconds
            dateFormatter.formatOptions = [.withInternetDateTime]
            guard let date = dateFormatter.date(from: dateString) else {
                return dateString
            }
            return formatDate(date)
        }
        
        return formatDate(date)
    }
    
    func formatDate(_ date: Date) -> String {
        let displayFormatter = DateFormatter()
        
        // Map date format strings to DateFormatter patterns
        switch dateFormat {
        case "MM/DD/YYYY":
            displayFormatter.dateFormat = "MM/dd/yyyy"
        case "DD/MM/YYYY":
            displayFormatter.dateFormat = "dd/MM/yyyy"
        case "YYYY-MM-DD":
            displayFormatter.dateFormat = "yyyy-MM-dd"
        default:
            displayFormatter.dateStyle = .short
        }
        
        return displayFormatter.string(from: date)
    }
    
    // MARK: - Helper Functions
    
    private func getNumberFormatForCurrency(_ currency: String) -> String {
        switch currency {
        case "EUR":
            return "1.234,56" // EU format
        case "USD", "GBP", "CAD", "AUD", "NZD", "SGD", "HKD":
            return "1,234.56" // US/UK format
        default:
            return "1,234.56" // Default to US format
        }
    }
    
    private func getCurrencySymbol(_ currency: String) -> String {
        switch currency {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        case "CAD": return "C$"
        case "AUD": return "A$"
        case "CHF": return "CHF"
        case "CNY": return "¥"
        case "INR": return "₹"
        case "BRL": return "R$"
        case "MXN": return "MX$"
        case "SGD": return "S$"
        case "HKD": return "HK$"
        case "NZD": return "NZ$"
        case "ZAR": return "R"
        default: return "$"
        }
    }
}

