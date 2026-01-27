//
//  SignUpView.swift
//  ANITA
//
//  Sign up screen with native iOS form design
//

import SwiftUI
import AuthenticationServices

enum SignUpStep {
    case credentials
    case preferences
}

struct SignUpView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var currentStep: SignUpStep = .credentials
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var showConfirmPassword: Bool = false
    @State private var selectedCurrency: String = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    @State private var needsCurrencyStep: Bool = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password, confirmPassword
    }
    
    let currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY"]
    
    var onAuthSuccess: () -> Void
    var onBack: (() -> Void)?
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
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
                    .padding(.bottom, 24)
                    
                    // Back Button (only on credentials step)
                    if currentStep == .credentials, let onBack = onBack {
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
                        .padding(.bottom, 20)
                    }
                    
                    // Step Indicator
                    if needsCurrencyStep && currentStep == .preferences {
                        HStack {
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    currentStep = .credentials
                                }
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
                        .padding(.bottom, 20)
                    }
                    
                    // Step Indicator
                    if needsCurrencyStep {
                        HStack(spacing: 12) {
                            StepIndicatorItem(
                                number: "1",
                                label: AppL10n.t("settings.account_details"),
                                isActive: currentStep == .credentials,
                                isCompleted: currentStep == .preferences
                            )
                            
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: currentStep == .preferences ?
                                        [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.2)
                                        ] :
                                        [
                                            Color.white.opacity(0.15),
                                            Color.white.opacity(0.08)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 2)
                                .frame(maxWidth: 70)
                            
                            StepIndicatorItem(
                                number: "2",
                                label: AppL10n.t("settings.preferences_label"),
                                isActive: currentStep == .preferences,
                                isCompleted: false
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    } else {
                        // One-step signup (currency already chosen in onboarding)
                        Spacer().frame(height: 8)
                    }
                    
                    // Auth Form
                    if currentStep == .credentials {
                        credentialsStep
                    } else {
                        preferencesStep
                    }
                    
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
                        Text(AppL10n.t("signup.by_creating"))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                        
                        HStack(spacing: 4) {
                            Button(AppL10n.t("auth.terms")) {
                                // TODO: Show terms
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            
                            Text(AppL10n.t("auth.and"))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Button(AppL10n.t("auth.privacy")) {
                                // TODO: Show privacy
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
        .onAppear {
            let savedCurrency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? ""
            needsCurrencyStep = savedCurrency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if !needsCurrencyStep {
                selectedCurrency = savedCurrency.isEmpty ? "USD" : savedCurrency
            }
        }
    }
    
    private var credentialsStep: some View {
        VStack(spacing: 0) {
            // Form Container - iOS Style
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
                            .textContentType(.newPassword)
                            .foregroundColor(.white)
                            .font(.system(size: 17))
                            .focused($focusedField, equals: .password)
                    } else {
                        SecureField(AppL10n.t("login.password"), text: $password)
                            .textContentType(.newPassword)
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
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(.white.opacity(0.1)),
                    alignment: .bottom
                )
                
                // Confirm Password Field
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 20)
                    
                    if showConfirmPassword {
                        TextField(AppL10n.t("signup.confirm_password"), text: $confirmPassword)
                            .textContentType(.newPassword)
                            .foregroundColor(.white)
                            .font(.system(size: 17))
                            .focused($focusedField, equals: .confirmPassword)
                    } else {
                        SecureField(AppL10n.t("signup.confirm_password"), text: $confirmPassword)
                            .textContentType(.newPassword)
                            .foregroundColor(.white)
                            .font(.system(size: 17))
                            .focused($focusedField, equals: .confirmPassword)
                    }
                    
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        showConfirmPassword.toggle()
                    }) {
                        Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
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
            .padding(.bottom, 24)
            
            // Next Button
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                focusedField = nil
                if password == confirmPassword {
                    if needsCurrencyStep {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentStep = .preferences
                        }
                    } else {
                        Task {
                            await viewModel.signUp(email: email, password: password)
                            if viewModel.isAuthenticated {
                                onAuthSuccess()
                            }
                        }
                    }
                } else {
                    viewModel.errorMessage = AppL10n.t("auth.passwords_not_match")
                }
            }) {
                HStack {
                    Text(needsCurrencyStep ? AppL10n.t("signup.next") : AppL10n.t("signup.signup"))
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(white: 0.2).opacity(0.4))
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading || email.isEmpty || password.isEmpty || confirmPassword.isEmpty)
            .opacity((viewModel.isLoading || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) ? 0.5 : 1.0)
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
            
            // Google Sign Up Button
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
                    
                    Text(AppL10n.t("signup.google"))
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
            
            // Apple Sign Up Button
            AppleSignInButton(
                onSignIn: { idToken in
                    Task {
                        await viewModel.signInWithApple(idToken: idToken, nonce: nil)
                        if viewModel.isAuthenticated {
                            onAuthSuccess()
                        }
                    }
                },
                onError: { error in
                    viewModel.errorMessage = error
                }
            )
            .frame(height: 50)
            .disabled(viewModel.isLoading)
            .opacity(viewModel.isLoading ? 0.5 : 1.0)
            .padding(.horizontal, 24)
        }
    }
    
    private var preferencesStep: some View {
        VStack(spacing: 24) {
            // Currency Selector - iOS Style
            VStack(alignment: .leading, spacing: 12) {
                Text(AppL10n.t("signup.select_currency"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 24)
                
                Menu {
                    ForEach(currencies, id: \.self) { currency in
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            selectedCurrency = currency
                            persistCurrencySelection(currency)
                        }) {
                            HStack {
                                Text(currency)
                                if selectedCurrency == currency {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 17))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 20)
                        
                        Text(selectedCurrency)
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
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
            }
            
            // Sign Up Button
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                Task {
                    persistCurrencySelection(selectedCurrency)
                    await viewModel.signUp(email: email, password: password)
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
                        Text(AppL10n.t("signup.signup"))
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(white: 0.2).opacity(0.4))
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading)
            .opacity(viewModel.isLoading ? 0.5 : 1.0)
            .padding(.horizontal, 24)
        }
    }
    
    private func persistCurrencySelection(_ currency: String) {
        UserDefaults.standard.set(currency, forKey: "anita_user_currency")
        let numberFormat: String
        switch currency {
        case "EUR":
            numberFormat = "1.234,56"
        default:
            numberFormat = "1,234.56"
        }
        UserDefaults.standard.set(numberFormat, forKey: "anita_number_format")
    }
}

struct StepIndicatorItem: View {
    let number: String
    let label: String
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        isActive || isCompleted ?
                        Color.white.opacity(0.25) :
                        Color.white.opacity(0.12)
                    )
                    .frame(width: 36, height: 36)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                } else {
                    Text(number)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(isActive ? .white : .white.opacity(0.6))
                }
            }
            .overlay {
                if isActive {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 44, height: 44)
                }
            }
            
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(isActive ? .white.opacity(0.95) : .white.opacity(0.5))
        }
    }
}

// MARK: - Apple Sign In Button

struct AppleSignInButton: UIViewRepresentable {
    let onSignIn: (String) -> Void
    let onError: (String) -> Void
    
    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor(white: 0.15, alpha: 0.3)
        button.layer.cornerRadius = 12
        button.clipsToBounds = true
        
        // Create horizontal stack with Apple logo and text
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.alignment = .center
        stackView.isUserInteractionEnabled = false
        
        // Apple logo
        let appleLogo = UIImageView(image: UIImage(systemName: "apple.logo"))
        appleLogo.tintColor = .white
        appleLogo.contentMode = .scaleAspectFit
        appleLogo.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            appleLogo.widthAnchor.constraint(equalToConstant: 20),
            appleLogo.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        // Text label
        let label = UILabel()
        label.text = AppL10n.t("auth.apple_sign_in")
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        label.textColor = .white
        
        stackView.addArrangedSubview(appleLogo)
        stackView.addArrangedSubview(label)
        
        button.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        
        button.addTarget(context.coordinator, action: #selector(Coordinator.buttonTapped), for: .touchUpInside)
        
        return button
    }
    
    func updateUIView(_ uiView: UIButton, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSignIn: onSignIn, onError: onError)
    }
    
    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let onSignIn: (String) -> Void
        let onError: (String) -> Void
        
        init(onSignIn: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onSignIn = onSignIn
            self.onError = onError
        }
        
        @objc func buttonTapped() {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let identityToken = appleIDCredential.identityToken,
                      let idTokenString = String(data: identityToken, encoding: .utf8) else {
                    onError("Failed to get identity token")
                    return
                }
                onSignIn(idTokenString)
            } else {
                onError("Failed to get Apple ID credential")
            }
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            onError("Apple Sign-In failed: \(error.localizedDescription)")
        }
        
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return window
            }
            // Fallback - create a temporary window
            return UIWindow(frame: UIScreen.main.bounds)
        }
    }
}

#Preview {
    SignUpView(onAuthSuccess: {}, onBack: nil)
}
