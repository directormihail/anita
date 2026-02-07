//
//  AmountParsing.swift
//  ANITA
//
//  Parses amount strings accepting both comma and dot as decimal separator.
//

import Foundation

extension String {
    /// Parses a string as a numeric amount. Accepts both "," and "." as decimal separator.
    /// - Returns: Parsed Double, or nil if the string is not a valid number.
    func parseAmount() -> Double? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Normalize: use dot as decimal separator for Double parsing
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}
