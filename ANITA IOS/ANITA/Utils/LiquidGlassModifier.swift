//
//  LiquidGlassModifier.swift
//  ANITA
//
//  Reusable liquid glass effect modifier for Apple design
//

import SwiftUI

extension View {
    /// Applies a liquid glass effect with blur and gradient border
    /// Apple-style iOS glassmorphism, like Control Center / VisionOS cards
    func liquidGlass(cornerRadius: CGFloat = 16, intensity: CGFloat = 1.0) -> some View {
        self.background {
            ZStack {
                // Super dark gray background
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(white: 0.12))
                
                // Subtle border stroke for edge definition
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            }
        }
    }
    
    /// Applies a liquid glass effect for navigation bars
    func liquidGlassBar() -> some View {
        self.background {
            ZStack {
                // Super dark gray background for navigation bars
                Rectangle()
                    .fill(Color(white: 0.12))
                
                // Top border for edge definition
                VStack {
                    Rectangle()
                        .fill(.white.opacity(0.15))
                        .frame(height: 0.5)
                    Spacer()
                }
            }
        }
    }
}
