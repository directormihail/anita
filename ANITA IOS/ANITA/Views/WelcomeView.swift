//
//  WelcomeView.swift
//  ANITA
//
//  Welcome — animated wordmark, clarity tagline, partners strip, actions.
//

import SwiftUI
import Foundation
import UIKit

struct WelcomeView: View {
    var onShowLogin: () -> Void
    var onGetStarted: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var stripOpacity: Double = 0
    @State private var stripOffset: CGFloat = 16
    @State private var buttonsOpacity: Double = 0
    @State private var buttonsOffset: CGFloat = 18
    
    @State private var backdropDrift: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                WelcomePremiumBackdrop(drift: backdropDrift)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: geo.safeAreaInsets.top + 12)
                    
                    Spacer(minLength: 12)
                    
                    WelcomeHeroSection(reduceMotion: reduceMotion)
                        .padding(.horizontal, 24)
                    
                    Spacer(minLength: 24)
                    
                    WelcomePartnerTrustStrip(reduceMotion: reduceMotion)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                        .opacity(stripOpacity)
                        .offset(y: stripOffset)
                    
                    VStack(spacing: 12) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onGetStarted()
                        }) {
                            Text(AppL10n.t("welcome.get_started"))
                                .font(.system(size: 17, weight: .semibold, design: .default))
                                .foregroundColor(Color(white: 0.08))
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(white: 0.99),
                                                    Color(white: 0.94)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .shadow(color: Color.white.opacity(0.12), radius: 0, x: 0, y: 1)
                                        .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 12)
                                )
                        }
                        .buttonStyle(PremiumButtonStyle())
                        
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onShowLogin()
                        }) {
                            Text(AppL10n.t("welcome.sign_in"))
                                .font(.system(size: 16, weight: .medium, design: .default))
                                .foregroundColor(.white.opacity(0.88))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                )
                        }
                        .buttonStyle(PremiumButtonStyle())
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, max(geo.safeAreaInsets.bottom, 14) + 2)
                    .opacity(buttonsOpacity)
                    .offset(y: buttonsOffset)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
        }
        .onAppear {
            WelcomePartnerLogoPrefetch.warmMarqueeDomains()
            runEntrance()
            startBackdropDriftIfNeeded()
        }
    }
    
    private func startBackdropDriftIfNeeded() {
        guard !reduceMotion else {
            backdropDrift = 0.5
            return
        }
        withAnimation(.easeInOut(duration: 22).repeatForever(autoreverses: true)) {
            backdropDrift = 1
        }
    }
    
    private func runEntrance() {
        if reduceMotion {
            stripOpacity = 1
            stripOffset = 0
            buttonsOpacity = 1
            buttonsOffset = 0
            return
        }
        withAnimation(.spring(response: 0.88, dampingFraction: 0.93).delay(0.58)) {
            stripOpacity = 1
            stripOffset = 0
        }
        withAnimation(.spring(response: 0.78, dampingFraction: 0.94).delay(0.76)) {
            buttonsOpacity = 1
            buttonsOffset = 0
        }
    }
}

// MARK: - Hero (wordmark + clarity)

private struct WelcomeHeroSection: View {
    let reduceMotion: Bool
    
    private static let letters: [Character] = Array("ANITA")
    
    @State private var letterOn: [Bool] = Array(repeating: false, count: 5)
    @State private var detailRevealed = false
    @State private var ruleWidth: CGFloat = 0
    @State private var wordmarkPulse: CGFloat = 1
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                HStack(spacing: 0) {
                    ForEach(0..<Self.letters.count, id: \.self) { i in
                        Text(String(Self.letters[i]))
                            .font(.system(size: 62, weight: .bold, design: .default))
                            .tracking(2)
                            .foregroundColor(Color(white: 0.98))
                            .shadow(color: Color.black.opacity(letterOn[i] ? 0.55 : 0), radius: 4, x: 0, y: 3)
                            .opacity(letterOn[i] ? 1 : 0)
                            .offset(y: letterOn[i] ? 0 : 34)
                            .scaleEffect(letterOn[i] ? 1 : 0.82, anchor: .bottom)
                    }
                }
                .scaleEffect(wordmarkPulse)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("ANITA")
            .accessibilityAddTraits(.isHeader)
            
            VStack(spacing: 6) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.45),
                                Color.white.opacity(0.18)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: ruleWidth, height: 1.5)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Text(AppL10n.t("welcome.subtitle"))
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.92),
                                Color.white.opacity(0.78)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .tracking(0.35)
                    .padding(.horizontal, 8)
                    .blur(radius: detailRevealed ? 0 : 7)
                    .opacity(detailRevealed ? 1 : 0)
                    .offset(y: detailRevealed ? 0 : 12)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            playEntrance()
        }
    }
    
    private func playEntrance() {
        if reduceMotion {
            letterOn = Array(repeating: true, count: Self.letters.count)
            ruleWidth = 196
            detailRevealed = true
            wordmarkPulse = 1
            return
        }
        let stagger: Double = 0.058
        for i in 0..<Self.letters.count {
            let idx = i
            DispatchQueue.main.asyncAfter(deadline: .now() + stagger * Double(idx)) {
                withAnimation(.spring(response: 0.52, dampingFraction: 0.78)) {
                    letterOn[idx] = true
                }
            }
        }
        let lettersDone = stagger * Double(Self.letters.count - 1) + 0.02
        DispatchQueue.main.asyncAfter(deadline: .now() + lettersDone) {
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.prepare()
            if #available(iOS 17.0, *) {
                gen.impactOccurred(intensity: 0.42)
            } else {
                gen.impactOccurred()
            }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.74)) {
                wordmarkPulse = 1.032
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.spring(response: 0.58, dampingFraction: 0.9)) {
                    wordmarkPulse = 1
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.72, dampingFraction: 0.9)) {
                ruleWidth = 196
                detailRevealed = true
            }
        }
    }
}

// MARK: - Backdrop

private enum WelcomePremiumPalette {
    static let accent = Color(red: 0.45, green: 0.82, blue: 0.68)
    static let accentSoft = Color(red: 0.32, green: 0.55, blue: 0.52)
    static let highlight = Color(red: 0.55, green: 0.62, blue: 0.72)
}

private struct WelcomePremiumBackdrop: View {
    var drift: CGFloat
    
    var body: some View {
        let t = drift
        ZStack {
            Color(red: 0.03, green: 0.035, blue: 0.042)
                .allowsHitTesting(false)
            
            RadialGradient(
                colors: [
                    WelcomePremiumPalette.highlight.opacity(0.08),
                    WelcomePremiumPalette.accent.opacity(0.04),
                    Color.clear
                ],
                center: UnitPoint(x: 0.72 + t * 0.04, y: 0.1 + t * 0.03),
                startRadius: 2,
                endRadius: 380
            )
            .allowsHitTesting(false)
            
            RadialGradient(
                colors: [
                    WelcomePremiumPalette.accentSoft.opacity(0.06),
                    Color.clear
                ],
                center: UnitPoint(x: 0.15 - t * 0.04, y: 0.9 - t * 0.02),
                startRadius: 2,
                endRadius: 320
            )
            .allowsHitTesting(false)
            
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.55)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
    }
}

struct FeatureBullet: View {
    let icon: String
    let title: String
    let description: String
    let delay: Double
    
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 20
    @State private var iconScale: CGFloat = 0.8
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.2).opacity(0.4),
                                Color(white: 0.15).opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.25),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.white.opacity(0.1), radius: 8, x: 0, y: 4)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color.white.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(iconScale)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                
                Text(description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .opacity(opacity)
        .offset(y: offset)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(delay)) {
                opacity = 1.0
                offset = 0
                iconScale = 1.0
            }
        }
    }
}

struct PremiumButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

#Preview {
    WelcomeView(
        onShowLogin: {},
        onGetStarted: {}
    )
}
