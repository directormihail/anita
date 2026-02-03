//
//  WelcomeView.swift
//  ANITA
//
//  Welcome/Onboarding screen with premium glass liquid design
//

import SwiftUI
import Foundation

struct WelcomeView: View {
    // Computed properties for gradient points
    private var gradientStartPoint: UnitPoint {
        let radians = gradientRotation * .pi / 180
        return UnitPoint(
            x: 0.5 + 0.5 * CGFloat(cos(radians)),
            y: 0.5 + 0.5 * CGFloat(sin(radians))
        )
    }
    
    private var gradientEndPoint: UnitPoint {
        let radians = gradientRotation * .pi / 180
        return UnitPoint(
            x: 0.5 - 0.5 * CGFloat(cos(radians)),
            y: 0.5 - 0.5 * CGFloat(sin(radians))
        )
    }
    
    private var gradientStartPointSlow: UnitPoint {
        let radians = (gradientRotation * 0.5) * .pi / 180
        return UnitPoint(
            x: 0.5 + 0.3 * CGFloat(cos(radians)),
            y: 0.5 + 0.3 * CGFloat(sin(radians))
        )
    }
    
    private var gradientEndPointSlow: UnitPoint {
        let radians = (gradientRotation * 0.5) * .pi / 180
        return UnitPoint(
            x: 0.5 - 0.3 * CGFloat(cos(radians)),
            y: 0.5 - 0.3 * CGFloat(sin(radians))
        )
    }
    
    var onShowLogin: () -> Void
    var onShowSignUp: () -> Void
    
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var contentOffset: CGFloat = 50
    @State private var logoRotation: Double = -5
    @State private var glowIntensity: Double = 0.25
    @State private var gradientRotation: Double = 0
    @State private var jellyPhase: Double = 0
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Name and subtitle — PFA straight under ANITA
                VStack(spacing: 8) {
                    // ANITA + PFA with jelly-like premium glow (subtle, not bright)
                    ZStack {
                        // Premium palette — muted, deep (not bright)
                        let softViolet = Color(red: 0.38, green: 0.36, blue: 0.48)
                        let softIndigo = Color(red: 0.32, green: 0.32, blue: 0.44)
                        let softLavender = Color(red: 0.42, green: 0.38, blue: 0.52)
                        
                        let t = gradientRotation * .pi / 180
                        let t2 = (gradientRotation * 0.6) * .pi / 180
                        let t3 = (gradientRotation + 140) * .pi / 180
                        let t4 = (gradientRotation * 0.85) * .pi / 180
                        let j = jellyPhase * .pi / 180
                        // Jelly: squish/stretch (x and y scale out of phase)
                        let jelly1X = 1 + 0.06 * CGFloat(sin(j))
                        let jelly1Y = 1 + 0.05 * CGFloat(cos(j + 0.8))
                        let jelly2X = 1 + 0.05 * CGFloat(cos(j * 1.1))
                        let jelly2Y = 1 + 0.07 * CGFloat(sin(j * 0.9))
                        let jelly3X = 1 + 0.06 * CGFloat(sin(j + 1.2))
                        let jelly3Y = 1 + 0.05 * CGFloat(cos(j))
                        let jelly4X = 1 + 0.05 * CGFloat(cos(j + 0.5))
                        let jelly4Y = 1 + 0.06 * CGFloat(sin(j + 1))
                        
                        // Blob 1 — jelly drift + wobble
                        RoundedRectangle(cornerRadius: 80)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        softLavender.opacity(glowIntensity * 0.5),
                                        softViolet.opacity(glowIntensity * 0.25)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 320, height: 160)
                            .blur(radius: 58)
                            .scaleEffect(x: jelly1X, y: jelly1Y)
                            .offset(x: 48 * CGFloat(cos(t)), y: 32 * CGFloat(sin(t)))
                            .opacity(logoOpacity)
                        
                        // Blob 2 — tall, jelly
                        RoundedRectangle(cornerRadius: 70)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        softViolet.opacity(glowIntensity * 0.45),
                                        softIndigo.opacity(glowIntensity * 0.2)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 180, height: 280)
                            .blur(radius: 52)
                            .scaleEffect(x: jelly2X, y: jelly2Y)
                            .offset(x: -42 * CGFloat(cos(t2)), y: -38 * CGFloat(sin(t2)))
                            .opacity(logoOpacity)
                        
                        // Blob 3 — large oval, jelly
                        RoundedRectangle(cornerRadius: 90)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        softLavender.opacity(glowIntensity * 0.4),
                                        softViolet.opacity(glowIntensity * 0.18)
                                    ],
                                    startPoint: UnitPoint(x: 0.3, y: 0.3),
                                    endPoint: UnitPoint(x: 0.8, y: 0.8)
                                )
                            )
                            .frame(width: 260, height: 220)
                            .blur(radius: 54)
                            .scaleEffect(x: jelly3X, y: jelly3Y)
                            .offset(x: 38 * CGFloat(cos(t3)), y: -48 * CGFloat(sin(t3)))
                            .opacity(logoOpacity)
                        
                        // Blob 4 — medium, jelly
                        RoundedRectangle(cornerRadius: 75)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        softViolet.opacity(glowIntensity * 0.4),
                                        softIndigo.opacity(glowIntensity * 0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 240, height: 200)
                            .blur(radius: 50)
                            .scaleEffect(x: jelly4X, y: jelly4Y)
                            .offset(x: -52 * CGFloat(sin(t4)), y: 42 * CGFloat(cos(t4)))
                            .opacity(logoOpacity)
                        
                        // Blob 5 — soft base, gentle jelly pulse only (no drift)
                        RoundedRectangle(cornerRadius: 100)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        softIndigo.opacity(glowIntensity * 0.35),
                                        Color.clear
                                    ],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 340, height: 240)
                            .blur(radius: 62)
                            .scaleEffect(x: 1 + 0.03 * CGFloat(sin(j * 0.7)), y: 1 + 0.03 * CGFloat(cos(j * 0.7)))
                            .opacity(logoOpacity)
                        
                        // Text stack: ANITA then PFA straight under
                        VStack(spacing: 6) {
                            Text("ANITA")
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .tracking(6)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.98),
                                            Color.white.opacity(0.88)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .rotationEffect(.degrees(logoRotation))
                            
                            Text(AppL10n.t("welcome.subtitle"))
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                        }
                        .offset(y: contentOffset)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                }
                .padding(.bottom, 52)
                
                // Features - simplified and premium
                VStack(alignment: .leading, spacing: 24) {
                    FeatureBullet(
                        icon: "message.fill",
                        title: AppL10n.t("welcome.feature.chat.title"),
                        description: AppL10n.t("welcome.feature.chat.desc"),
                        delay: 0.1
                    )
                    
                    FeatureBullet(
                        icon: "chart.line.uptrend.xyaxis",
                        title: AppL10n.t("welcome.feature.finance.title"),
                        description: AppL10n.t("welcome.feature.finance.desc"),
                        delay: 0.2
                    )
                    
                    FeatureBullet(
                        icon: "target",
                        title: AppL10n.t("welcome.feature.goals.title"),
                        description: AppL10n.t("welcome.feature.goals.desc"),
                        delay: 0.3
                    )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
                .offset(y: contentOffset)
                .opacity(logoOpacity)
                
                // Action Buttons
                VStack(spacing: 14) {
                    // Get Started Button (Primary)
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        onShowSignUp()
                    }) {
                        HStack {
                            Spacer()
                            Text(AppL10n.t("welcome.get_started"))
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(height: 58)
                        .background {
                            ZStack {
                                // Glass liquid effect
                                RoundedRectangle(cornerRadius: 16)
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
                                
                                // Glass reflection
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.12),
                                                Color.white.opacity(0.05),
                                                Color.clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .center
                                        )
                                    )
                                
                                // Border
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.25),
                                                Color.white.opacity(0.15)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            }
                        }
                        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
                        .shadow(color: Color.white.opacity(0.05), radius: 3, x: 0, y: -1)
                    }
                    .buttonStyle(PremiumButtonStyle())
                    
                    // Sign In Button (Secondary)
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        onShowLogin()
                    }) {
                        HStack {
                            Spacer()
                            Text(AppL10n.t("welcome.sign_in"))
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(height: 58)
                        .background {
                            ZStack {
                                // Glass liquid effect
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(white: 0.15).opacity(0.3),
                                                Color(white: 0.1).opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                // Border
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.2),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                        }
                    }
                    .buttonStyle(PremiumButtonStyle())
                }
                .padding(.horizontal, 28)
                .offset(y: contentOffset)
                .opacity(logoOpacity)
                
                Spacer()
            }
        }
        .onAppear {
            // Reset animations
            logoScale = 0.8
            logoOpacity = 0
            contentOffset = 50
            logoRotation = -5
            glowIntensity = 0.25
            jellyPhase = 0
            
            // Logo entrance animation
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                logoScale = 1.0
                logoOpacity = 1.0
                logoRotation = 0
            }
            
            // Content entrance animation
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.15)) {
                contentOffset = 0
            }
            
            // Premium subtle pulse — not bright, refined
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                glowIntensity = 0.42
            }
            
            // Jelly wobble — squish/stretch (smooth, organic)
            withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true)) {
                jellyPhase = 360
            }
            
            // Slow drift — very smooth
            withAnimation(.linear(duration: 26).repeatForever(autoreverses: false)) {
                gradientRotation = 360
            }
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
            // Premium icon with animation
            ZStack {
                // Glass circle background with glow
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
            
            // Text content - simplified
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
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    WelcomeView(
        onShowLogin: {},
        onShowSignUp: {}
    )
}
