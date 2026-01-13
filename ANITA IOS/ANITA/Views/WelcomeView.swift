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
    @State private var glowIntensity: Double = 0.3
    @State private var gradientRotation: Double = 0
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo and Title with animation
                VStack(spacing: 24) {
                    // Glass liquid logo with premium animations
                    ZStack {
                        // Animated outer glow
                        RoundedRectangle(cornerRadius: 22)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(glowIntensity),
                                        Color(red: 0.6, green: 0.4, blue: 0.8).opacity(glowIntensity * 0.7)
                                    ],
                                    startPoint: gradientStartPoint,
                                    endPoint: gradientEndPoint
                                )
                            )
                            .frame(width: 110, height: 110)
                            .blur(radius: 25)
                            .offset(y: 12)
                            .opacity(logoOpacity)
                        
                        // Glass liquid effect
                        RoundedRectangle(cornerRadius: 22)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.25).opacity(0.6),
                                        Color(white: 0.15).opacity(0.4)
                                    ],
                                    startPoint: gradientStartPointSlow,
                                    endPoint: gradientEndPointSlow
                                )
                            )
                            .frame(width: 96, height: 96)
                            .overlay {
                                // Glass reflection
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.15),
                                                Color.white.opacity(0.05),
                                                Color.clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .center
                                        )
                                    )
                                
                                // Animated border
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.25),
                                                Color.white.opacity(0.1),
                                                Color.white.opacity(0.15)
                                            ],
                                            startPoint: gradientStartPoint,
                                            endPoint: gradientEndPoint
                                        ),
                                        lineWidth: 1.5
                                    )
                            }
                            .shadow(color: Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.4 * glowIntensity), radius: 20, x: 0, y: 10)
                            .shadow(color: Color.white.opacity(0.1), radius: 5, x: 0, y: -2)
                        
                        // Letter A with gradient
                        Text("A")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.95),
                                        Color.white.opacity(0.85)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .rotationEffect(.degrees(logoRotation))
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    
                    VStack(spacing: 10) {
                        Text("Welcome to ANITA")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.95)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        Text("Personal Finance Assistant")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .offset(y: contentOffset)
                    .opacity(logoOpacity)
                }
                .padding(.bottom, 52)
                
                // Features - simplified and premium
                VStack(alignment: .leading, spacing: 24) {
                    FeatureBullet(
                        icon: "message.fill",
                        title: "AI Chat",
                        description: "Talk naturally, track automatically",
                        delay: 0.1
                    )
                    
                    FeatureBullet(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Finance Dashboard",
                        description: "See where money goes, stop leaks",
                        delay: 0.2
                    )
                    
                    FeatureBullet(
                        icon: "target",
                        title: "Smart Goals",
                        description: "AI breaks down goals into steps",
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
                            Text("Get Started")
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
                            Text("Sign In")
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
            glowIntensity = 0.3
            
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
            
            // Continuous glow pulse
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowIntensity = 0.5
            }
            
            // Continuous gradient rotation
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
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
