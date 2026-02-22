//
//  TextFormatter.swift
//  ANITA
//
//  Text formatting utility for structured AI responses
//  Similar to webapp's TextFormatter
//

import Foundation
import SwiftUI

struct FormattedTextElement {
    let type: ElementType
    let content: String
    let level: Int?
    
    enum ElementType {
        case text
        case heading
        case list
        case listItem
        case indent
    }
}

@MainActor
public class TextFormatter {
    /**
     * Format a complete AI response with structure
     * Parses markdown-style formatting and converts to AttributedString
     */
    public static func formatResponse(_ text: String) -> AttributedString {
        let elements = parseStructuredText(text)
        return elementsToAttributedString(elements)
    }
    
    /**
     * Parse AI response text and convert it to structured format
     */
    private static func parseStructuredText(_ text: String) -> [FormattedTextElement] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var elements: [FormattedTextElement] = []
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            
            // Check for headings
            if isHeading(line) {
                let heading = parseHeading(line)
                elements.append(heading)
            }
            // Check for lists
            else if isList(line) {
                let listResult = parseList(lines, startIndex: i)
                elements.append(contentsOf: listResult.elements)
                i = listResult.nextIndex - 1 // -1 because we'll increment at the end
            }
            // Check for indented content
            else if isIndented(line) {
                let indentLevel = getIndentLevel(line)
                let indentResult = parseIndentedContent(lines, startIndex: i, baseIndentLevel: indentLevel)
                elements.append(indentResult.element)
                i = indentResult.nextIndex - 1
            }
            // Regular text
            else {
                let textElement = parseTextLine(line)
                elements.append(textElement)
            }
            
            i += 1
        }
        
        return elements
    }
    
    /**
     * Check if a line is a heading
     */
    private static func isHeading(_ line: String) -> Bool {
        // Markdown headings (# ## ###)
        if line.range(of: #"^#{1,6}\s"#, options: .regularExpression) != nil {
            return true
        }
        // Numbered sections like "1. Introduction"
        if line.range(of: #"^\d+\.\s+[A-Z]"#, options: .regularExpression) != nil {
            return true
        }
        // ALL CAPS headings
        if line.range(of: #"^[A-Z][A-Z\s]+:?\s*$"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }
    
    /**
     * Parse a heading line
     */
    private static func parseHeading(_ line: String) -> FormattedTextElement {
        // Markdown-style headings
        if let match = line.range(of: #"^#+\s*"#, options: .regularExpression) {
            let level = line.distance(from: line.startIndex, to: match.upperBound) - 1
            let content = String(line[match.upperBound...]).trimmingCharacters(in: .whitespaces)
            return FormattedTextElement(
                type: .heading,
                content: parseInlineFormatting(content),
                level: min(level, 6)
            )
        }
        
        // Numbered sections
        if let match = line.range(of: #"^\d+\.\s*"#, options: .regularExpression) {
            let content = String(line[match.upperBound...]).trimmingCharacters(in: .whitespaces)
            return FormattedTextElement(
                type: .heading,
                content: parseInlineFormatting(content),
                level: 2
            )
        }
        
        // ALL CAPS headings
        if line.range(of: #"^[A-Z][A-Z\s]+:?\s*$"#, options: .regularExpression) != nil {
            let content = line.replacingOccurrences(of: #":\s*$"#, with: "", options: .regularExpression)
            return FormattedTextElement(
                type: .heading,
                content: parseInlineFormatting(content),
                level: 3
            )
        }
        
        return FormattedTextElement(
            type: .text,
            content: parseInlineFormatting(line),
            level: nil
        )
    }
    
    /**
     * Check if a line is a list item
     */
    private static func isList(_ line: String) -> Bool {
        return line.range(of: #"^[-*+]\s"#, options: .regularExpression) != nil ||
               line.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil ||
               line.range(of: #"^•\s"#, options: .regularExpression) != nil ||
               line.range(of: #"^••\s"#, options: .regularExpression) != nil
    }
    
    /**
     * Parse a list starting from the given index
     */
    private static func parseList(_ lines: [String], startIndex: Int) -> (elements: [FormattedTextElement], nextIndex: Int) {
        var elements: [FormattedTextElement] = []
        var listItems: [FormattedTextElement] = []
        var i = startIndex
        
        while i < lines.count {
            let line = lines[i]
            
            if isList(line) {
                let listItem = parseListItem(line)
                listItems.append(listItem)
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                // Empty line, continue
            } else {
                // Not a list item, stop parsing
                break
            }
            
            i += 1
        }
        
        // If we have list items, add them directly
        // Each list item will be rendered with a bullet point
        if !listItems.isEmpty {
            elements.append(contentsOf: listItems)
        }
        
        return (elements, i)
    }
    
    /**
     * Parse a single list item
     */
    private static func parseListItem(_ line: String) -> FormattedTextElement {
        var content = line
        // Remove list markers
        content = content.replacingOccurrences(of: #"^[-*+]\s*"#, with: "", options: .regularExpression)
        content = content.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
        content = content.replacingOccurrences(of: #"^•+\s*"#, with: "", options: .regularExpression)
        content = content.trimmingCharacters(in: .whitespaces)
        
        return FormattedTextElement(
            type: .listItem,
            content: parseInlineFormatting(content),
            level: nil
        )
    }
    
    /**
     * Check if a line is indented
     */
    private static func isIndented(_ line: String) -> Bool {
        return line.range(of: #"^\s{2,}"#, options: .regularExpression) != nil
    }
    
    /**
     * Get the indentation level of a line
     */
    private static func getIndentLevel(_ line: String) -> Int {
        if let match = line.range(of: #"^(\s+)"#, options: .regularExpression) {
            let spaces = line[match]
            return spaces.count / 2 // 2 spaces = 1 level
        }
        return 0
    }
    
    /**
     * Parse indented content
     */
    private static func parseIndentedContent(_ lines: [String], startIndex: Int, baseIndentLevel: Int) -> (element: FormattedTextElement, nextIndex: Int) {
        var content: [String] = []
        var i = startIndex
        
        while i < lines.count {
            let line = lines[i]
            let currentIndentLevel = getIndentLevel(line)
            
            if currentIndentLevel >= baseIndentLevel && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                content.append(line.trimmingCharacters(in: .whitespaces))
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                // Empty line, continue
            } else {
                // Less indented or different content, stop
                break
            }
            
            i += 1
        }
        
        return (
            FormattedTextElement(
                type: .indent,
                content: content.joined(separator: "\n"),
                level: baseIndentLevel
            ),
            i
        )
    }
    
    /**
     * Parse a regular text line
     */
    private static func parseTextLine(_ line: String) -> FormattedTextElement {
        return FormattedTextElement(
            type: .text,
            content: parseInlineFormatting(line),
            level: nil
        )
    }
    
    /**
     * Parse inline formatting (bold, italic, etc.)
     * Preserves the text with markdown markers - we'll handle formatting in AttributedString
     */
    private static func parseInlineFormatting(_ text: String) -> String {
        // Keep the text as-is with markdown markers - we'll parse them in AttributedString
        return text
    }
    
    /**
     * Convert structured elements to AttributedString
     */
    private static func elementsToAttributedString(_ elements: [FormattedTextElement]) -> AttributedString {
        var result = AttributedString()
        
        for (index, element) in elements.enumerated() {
            let attributed = elementToAttributedString(element)
            
            // Add consistent spacing between elements
            if index > 0 {
                let previousElement = elements[index - 1]
                
                // If current element is a heading, add spacing before it (separates sections)
                if element.type == .heading {
                    result.append(AttributedString("\n\n"))
                }
                // If previous was a heading, add spacing after it (heading sits above content)
                else if previousElement.type == .heading {
                    result.append(AttributedString("\n"))
                }
                // If previous was text, add spacing
                else if previousElement.type == .text {
                    result.append(AttributedString("\n\n"))
                }
                // If previous was list item, add spacing
                else if previousElement.type == .listItem {
                    result.append(AttributedString("\n"))
                }
                // Default spacing
                else {
                    result.append(AttributedString("\n"))
                }
            }
            
            result.append(attributed)
        }
        
        return result
    }
    
    /**
     * Convert a single element to AttributedString
     */
    private static func elementToAttributedString(_ element: FormattedTextElement) -> AttributedString {
        // First parse inline formatting (bold, italic) to get the base attributed string
        var attributed = parseBoldAndItalic(AttributedString(element.content))
        
        // Apply formatting based on element type
        switch element.type {
        case .heading:
            let level = element.level ?? 1
            let fontSize: CGFloat = {
                switch level {
                case 1: return 22
                case 2: return 20
                case 3: return 18
                case 4: return 17
                case 5: return 16
                case 6: return 15
                default: return 18
                }
            }()
            
            // Apply heading style to entire text
            attributed.font = .system(size: fontSize, weight: .bold)
            attributed.foregroundColor = .white
            // Spacing is handled by newlines in elementsToAttributedString (NSParagraphStyle not Sendable on iOS)
            
            // Preserve bold formatting within headings
            let text = String(attributed.characters)
            if let regex = try? NSRegularExpression(pattern: #"\*\*(.*?)\*\*"#, options: []) {
                let nsString = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                for match in matches.reversed() {
                    if match.numberOfRanges >= 2 {
                        let fullRange = match.range(at: 0)
                        let contentRange = match.range(at: 1)
                        if let fullSwiftRange = Range(fullRange, in: text),
                           let contentSwiftRange = Range(contentRange, in: text) {
                            let content = String(text[contentSwiftRange])
                            if let fullAttributedRange = attributed.range(of: String(text[fullSwiftRange])) {
                                attributed.replaceSubrange(fullAttributedRange, with: AttributedString(content))
                                if let contentRange = attributed.range(of: content) {
                                    attributed[contentRange].font = .system(size: fontSize, weight: .bold)
                                }
                            }
                        }
                    }
                }
            }
            
        case .listItem:
            // Add bullet point with proper spacing
            // Note: Numbered lists will show as bullet points for consistency with webapp
            var bullet = AttributedString("• ")
            bullet.foregroundColor = .white.opacity(0.8)
            bullet.font = .system(size: 16)
            attributed = bullet + attributed
            attributed.foregroundColor = .white
            attributed.font = .system(size: 16)
            // Spacing handled by newlines in elementsToAttributedString
            
            // Ensure bold text in list items uses bold font
            let text = String(attributed.characters)
            if let regex = try? NSRegularExpression(pattern: #"\*\*(.*?)\*\*"#, options: []) {
                let nsString = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                for match in matches.reversed() {
                    if match.numberOfRanges >= 2 {
                        let fullRange = match.range(at: 0)
                        let contentRange = match.range(at: 1)
                        if let fullSwiftRange = Range(fullRange, in: text),
                           let contentSwiftRange = Range(contentRange, in: text) {
                            let content = String(text[contentSwiftRange])
                            if let fullAttributedRange = attributed.range(of: String(text[fullSwiftRange])) {
                                attributed.replaceSubrange(fullAttributedRange, with: AttributedString(content))
                                if let contentRange = attributed.range(of: content) {
                                    attributed[contentRange].font = .system(size: 16, weight: .bold)
                                }
                            }
                        }
                    }
                }
            }
            
        case .indent:
            attributed.foregroundColor = .white.opacity(0.9)
            attributed.font = .system(size: 15)
            // Indent/spacing handled by newlines in elementsToAttributedString
            
        case .text:
            attributed.foregroundColor = .white
            attributed.font = .system(size: 16)
            // Spacing handled by newlines in elementsToAttributedString
            
        case .list:
            // Lists are handled by list items
            break
        }
        
        return attributed
    }
    
    /**
     * Parse bold (**text**) and italic (*text*) formatting
     */
    private static func parseBoldAndItalic(_ attributed: AttributedString) -> AttributedString {
        let text = String(attributed.characters)
        var result = AttributedString(text)
        
        // Apply base attributes
        if let font = attributed.font {
            result.font = font
        } else {
            result.font = .system(size: 16)
        }
        if let foregroundColor = attributed.foregroundColor {
            result.foregroundColor = foregroundColor
        } else {
            result.foregroundColor = .white
        }
        
        // Parse bold text (**text**) - process in reverse to preserve indices
        let boldPattern = #"\*\*(.*?)\*\*"#
        if let regex = try? NSRegularExpression(pattern: boldPattern, options: []) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            // Process matches in reverse to preserve indices
            for match in matches.reversed() {
                if match.numberOfRanges >= 2 {
                    let fullRange = match.range(at: 0)
                    let contentRange = match.range(at: 1)
                    
                    if let fullSwiftRange = Range(fullRange, in: text),
                       let contentSwiftRange = Range(contentRange, in: text) {
                        let fullMatch = String(text[fullSwiftRange])
                        let content = String(text[contentSwiftRange])
                        
                        // Find and replace the markdown markers with just the content
                        if let fullAttributedRange = result.range(of: fullMatch) {
                            // Use default font size for bold text (SwiftUI Font doesn't expose pointSize easily)
                            let fontSize: CGFloat = 16
                            
                            result.replaceSubrange(fullAttributedRange, with: AttributedString(content))
                            
                            // Apply bold to the content
                            if let contentRange = result.range(of: content) {
                                result[contentRange].font = .system(size: fontSize, weight: .bold)
                            }
                        }
                    }
                }
            }
        }
        
        // Parse italic text (*text*) - but not if it's part of **text**
        // Note: We'll skip italic for now as SwiftUI Font doesn't have direct italic support
        // The bold formatting is more important for the structured responses
        
        return result
    }
}

