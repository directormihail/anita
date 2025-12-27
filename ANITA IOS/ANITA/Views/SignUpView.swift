//
//  SignUpView.swift
//  ANITA
//
//  Sign up screen with native iOS form design
//

import SwiftUI

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
    @State private var selectedCurrency: String = "USD"
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
                        Text("Welcome to ANITA")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Personal Finance Assistant")
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
                                    Text("Back")
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
                    if currentStep == .preferences {
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
                                    Text("Back")
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
                    HStack(spacing: 12) {
                        StepIndicatorItem(
                            number: "1",
                            label: "Account Details",
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
                            label: "Preferences",
                            isActive: currentStep == .preferences,
                            isCompleted: false
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    
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
                        Text("By creating an account, you agree to our")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                        
                        HStack(spacing: 4) {
                            Button("Terms of Service") {
                                // TODO: Show terms
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            
                            Text("and")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Button("Privacy Policy") {
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
                    
                    TextField("Email", text: $email)
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
                        TextField("Password", text: $password)
                            .textContentType(.newPassword)
                            .foregroundColor(.white)
                            .font(.system(size: 17))
                            .focused($focusedField, equals: .password)
                    } else {
                        SecureField("Password", text: $password)
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
                        TextField("Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .foregroundColor(.white)
                            .font(.system(size: 17))
                            .focused($focusedField, equals: .confirmPassword)
                    } else {
                        SecureField("Confirm Password", text: $confirmPassword)
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
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = .preferences
                    }
                } else {
                    viewModel.errorMessage = "Passwords do not match"
                }
            }) {
                HStack {
                    Text("Next")
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
                
                Text("OR")
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
                    
                    Text("Sign up with Google")
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
        }
    }
    
    private var preferencesStep: some View {
        VStack(spacing: 24) {
            // Currency Selector - iOS Style
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Currency")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 24)
                
                Menu {
                    ForEach(currencies, id: \.self) { currency in
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            selectedCurrency = currency
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
                        Text("Sign Up")
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

#Preview {
    SignUpView(onAuthSuccess: {}, onBack: nil)
}
