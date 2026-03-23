//
//  LiquidGlassModifier.swift
//  ANITA
//
//  Reusable liquid glass effect — dark, solid, Apple-style panels
//

import SwiftUI

// MARK: - Film grain / noise (matte glass tactility)

private struct GlassFilmGrain: View {
    let step: CGFloat
    let strength: Double

    var body: some View {
        Canvas { context, size in
            guard step > 1 else { return }

            let stepPx = step
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let xi = Int(x / stepPx)
                    let yi = Int(y / stepPx)

                    // Deterministic hash -> [0,1)
                    let n1 = UInt32(truncatingIfNeeded: xi &* 374761393)
                    let n2 = UInt32(truncatingIfNeeded: yi &* 668265263)
                    let h = (n1 ^ n2) &* 2246822519
                    let u = Double(h & 0xffff) / 65_535.0

                    // Light vs dark specks
                    let isLight = u > 0.5
                    let alphaBase = isLight ? 0.055 : 0.028
                    let alpha = min(0.085, alphaBase * strength)

                    let dot = CGRect(x: x, y: y, width: 1.35, height: 1.35)
                    context.fill(
                        Path(ellipseIn: dot),
                        with: .color(Color(white: isLight ? 1.0 : 0.0).opacity(alpha))
                    )

                    x += stepPx
                }
                y += stepPx
            }
        }
        .blendMode(.softLight)
        .opacity(0.95)
        .allowsHitTesting(false)
    }
}

// MARK: - Section panel (main cards: balance, insights headers, lists)

private struct FinanceSolidGlassSectionBackground: View {
    var cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            // Deep grey flat base (no glow / no moving shimmer)
            .fill(Color(white: 0.12))
    }
}

private struct FinanceSolidGlassSectionOuterStroke: View {
    var cornerRadius: CGFloat

    var body: some View {
        EmptyView()
    }
}

private struct FinanceSolidGlassSectionTopHighlight: View {
    var cornerRadius: CGFloat

    var body: some View {
        EmptyView()
    }
}

// MARK: - Compact tile (metric pills, dense cells)

private struct FinanceSolidGlassTileBackground: View {
    var cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(white: 0.12))
    }
}

// MARK: - Circular control (month chevrons, small round buttons)

private struct FinanceSolidGlassCircleBackground: View {
    var body: some View {
        Circle()
            .fill(Color(white: 0.12))
    }
}

// MARK: - Public API

extension View {
    /// Large finance card: dark liquid glass + rim + top sheen (matches main balance window).
    func financeSolidGlassSection(cornerRadius: CGFloat = 20) -> some View {
        self
            .background { FinanceSolidGlassSectionBackground(cornerRadius: cornerRadius) }
    }

    /// Dense tile (2×2 metrics, small chips) — same family, no outer rim arc.
    func financeSolidGlassTile(cornerRadius: CGFloat = 16) -> some View {
        self.background { FinanceSolidGlassTileBackground(cornerRadius: cornerRadius) }
    }

    /// Round control matching the same dark glass treatment.
    func financeSolidGlassCircle() -> some View {
        self.background { FinanceSolidGlassCircleBackground() }
    }

    /// App-wide liquid glass — same family as Finance: dark solid glass.
    /// Small radii use the compact tile; larger surfaces get rim + top sheen.
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = 16, intensity: CGFloat = 1.0) -> some View {
        if cornerRadius <= 11 {
            self.financeSolidGlassTile(cornerRadius: cornerRadius)
        } else {
            self.financeSolidGlassSection(cornerRadius: cornerRadius)
        }
    }

    /// Dark frosted bar for navigation / toolbars (matches app glass).
    func liquidGlassBar() -> some View {
        self.background {
            ZStack(alignment: .top) {
                Rectangle().fill(Color(white: 0.10))
                Rectangle()
                    .fill(Color.black.opacity(0.18))
            }
        }
    }
}
