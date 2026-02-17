//
//  LoginView.swift
//  ANITA
//
//  Login screen with native iOS form design
//

import SwiftUI
import AuthenticationServices
import CryptoKit

/// Static storage so the nonce set in onRequest is always visible in onCompletion (no SwiftUI state timing).
private enum AppleSignInNonce {
    static var raw: String?
}

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var showForgotPassword: Bool = false
    @State private var showPrivacySheet: Bool = false
    @State private var showTermsSheet: Bool = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    private static func randomNonce(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return (0..<length).compactMap { _ in charset.randomElement() }.map(String.init).joined()
    }
    
    private static func sha256Nonce(_ nonce: String) -> String {
        let data = Data(nonce.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    var onAuthSuccess: () -> Void
    var onBack: (() -> Void)?
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Back Button
                    if let onBack = onBack {
                        HStack {
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                onBack()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(AppL10n.t("common.back"))
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(white: 0.15).opacity(0.3))
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    }
                    
                    // Header
                    VStack(spacing: 8) {
                        Text(AppL10n.t("welcome.title"))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(AppL10n.t("welcome.subtitle"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                    
                    // Auth Form - iOS Style
                    VStack(spacing: 0) {
                        // Email Field
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 17))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 20)
                            
                            TextField(AppL10n.t("login.email"), text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .foregroundColor(.white)
                                .font(.system(size: 17))
                                .focused($focusedField, equals: .email)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color(white: 0.1).opacity(0.3))
                        .overlay(
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(.white.opacity(0.1)),
                            alignment: .bottom
                        )
                        
                        // Password Field
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 17))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 20)
                            
                            if showPassword {
                                TextField(AppL10n.t("login.password"), text: $password)
                                    .textContentType(.password)
                                    .foregroundColor(.white)
                                    .font(.system(size: 17))
                                    .focused($focusedField, equals: .password)
                            } else {
                                SecureField(AppL10n.t("login.password"), text: $password)
                                    .textContentType(.password)
                                    .foregroundColor(.white)
                                    .font(.system(size: 17))
                                    .focused($focusedField, equals: .password)
                            }
                            
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                showPassword.toggle()
                            }) {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .font(.system(size: 17))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color(white: 0.1).opacity(0.3))
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(white: 0.1).opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    
                    // Forgot Password
                    HStack {
                        Spacer()
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            showForgotPassword = true
                        }) {
                            Text(AppL10n.t("login.forgot_password"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    
                    // Login Button
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        focusedField = nil
                        Task {
                            await viewModel.signIn(email: email, password: password)
                            if viewModel.isAuthenticated {
                                onAuthSuccess()
                            }
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                            } else {
                                Text(AppL10n.t("login.login"))
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(white: 0.2).opacity(0.4))
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading || email.isEmpty || password.isEmpty)
                    .opacity((viewModel.isLoading || email.isEmpty || password.isEmpty) ? 0.5 : 1.0)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    
                    // Divider
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 0.5)
                        
                        Text(AppL10n.t("auth.or"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 0.5)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    // Google Sign In Button
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        Task {
                            await viewModel.signInWithGoogle()
                            if viewModel.isAuthenticated {
                                onAuthSuccess()
                            }
                        }
                    }) {
                        HStack(spacing: 10) {
                            GoogleLogoView(size: 20)
                            
                            Text(AppL10n.t("login.google"))
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(white: 0.15).opacity(0.3))
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading)
                    .opacity(viewModel.isLoading ? 0.5 : 1.0)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                    
                    // Apple Sign In — nonce must match token (static so onCompletion always sees value set in onRequest)
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                            let rawNonce = Self.randomNonce()
                            AppleSignInNonce.raw = rawNonce
                            request.nonce = Self.sha256Nonce(rawNonce)
                        },
                        onCompletion: { result in
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            
                            switch result {
                            case .success(let authorization):
                                if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                    guard let identityToken = appleIDCredential.identityToken,
                                          let idTokenString = String(data: identityToken, encoding: .utf8) else {
                                        print("Apple Sign-In: Failed to get identity token")
                                        AppleSignInNonce.raw = nil
                                        return
                                    }
                                    let nonceToSend = AppleSignInNonce.raw
                                    AppleSignInNonce.raw = nil
                                    Task {
                                        await viewModel.signInWithApple(idToken: idTokenString, nonce: nonceToSend)
                                        if viewModel.isAuthenticated {
                                            onAuthSuccess()
                                        }
                                    }
                                } else {
                                    print("Apple Sign-In: Failed to get Apple ID credential")
                                    AppleSignInNonce.raw = nil
                                }
                            case .failure(let error):
                                print("Apple Sign-In failed: \(error.localizedDescription)")
                                viewModel.errorMessage = error.localizedDescription
                                AppleSignInNonce.raw = nil
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)
                    .disabled(viewModel.isLoading)
                    .opacity(viewModel.isLoading ? 0.5 : 1.0)
                    .padding(.horizontal, 24)
                    
                    // Error Message
                    if let errorMessage = viewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.red.opacity(0.9))
                            
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red.opacity(0.9))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(10)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    }
                    
                    // Footer
                    VStack(spacing: 8) {
                        Text(AppL10n.t("login.by_continuing"))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                        
                        HStack(spacing: 4) {
                            Button(AppL10n.t("auth.terms")) {
                                showTermsSheet = true
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            
                            Text(AppL10n.t("auth.and"))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Button(AppL10n.t("auth.privacy")) {
                                showPrivacySheet = true
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 40)
                }
            }
        }
        .alert(AppL10n.t("login.forgot_password"), isPresented: $showForgotPassword) {
            TextField(AppL10n.t("login.email"), text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
            Button(AppL10n.t("login.reset.send")) {
                // TODO: Implement password reset
            }
            Button(AppL10n.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(AppL10n.t("login.reset.help"))
        }
        .sheet(isPresented: $showPrivacySheet) {
            LegalDocumentSheetView(mode: .privacy)
        }
        .sheet(isPresented: $showTermsSheet) {
            LegalDocumentSheetView(mode: .terms)
        }
    }
}

#Preview {
    LoginView(onAuthSuccess: {}, onBack: nil)
}
