//
//  AuthView.swift
//  PawjaiMobile
//
//  Created by Purin Buriwong on 3/9/2568 BE.
//

import SwiftUI
import UIKit

struct AuthView: View {
    @EnvironmentObject var language: LanguageManager
    @StateObject private var supabaseManager = SupabaseManager.shared
    @State private var navigateToWebView = false
    @State private var mode: AuthMode = .oauth
    @State private var authMode: AuthModeType = .signin
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var signInError = ""
    @State private var passwordError = ""
    @State private var showForgotPassword = false
    @State private var forgotPasswordEmail = ""
    @State private var forgotPasswordError = ""
    @State private var forgotPasswordSuccess = false

    // Cache translated strings to avoid repeated lookups
    private var titleText: String {
        authMode == .signin ? L("ใส่ใจน้องมากขึ้นทุกวัน", "Care More for Your Pet") : L("เริ่มต้นดูแลน้องให้ดียิ่งขึ้น", "Start caring for your pet better")
    }

    private var subtitleText: String {
        L("สุขภาพน้องดี คนในบ้านก็อุ่นใจ", "Healthy pets, Happy family")
    }
    
    enum AuthMode {
        case oauth, email
    }
    
    enum AuthModeType {
        case signin, signup
    }
    
    var body: some View {
        ZStack {
            // Solid background color
            Color(red: 1.0, green: 0.957, blue: 0.914) // #fff4e9
                .ignoresSafeArea()
                .onAppear {
                }
                .onChange(of: supabaseManager.errorMessage) {
                    if let error = supabaseManager.errorMessage {
                        signInError = error
                    }
                }
            
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)
                    
                    // Header section
                    VStack(spacing: 16) {
                        // Logo
                        VStack(spacing: 16) {
                            Image("pawjai-icon-text")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        }
                        
                        // Title and subtitle
                        VStack(spacing: 8) {
                            Text(titleText)
                                .font(.kanitBold(size: 24))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)

                            Text(subtitleText)
                                .font(.kanitRegular(size: 18))
                                .foregroundColor(.black.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 32)
                    
                    // Sign in form card
                    VStack(spacing: 24) {
                        if mode == .oauth {
                            // OAuth mode
                            VStack(spacing: 16) {
                                // Google Sign In Button
                                GoogleSignInButton(supabaseManager: supabaseManager, authMode: authMode)

                                // Apple Sign In Button
                                AppleSignInButton(supabaseManager: supabaseManager, authMode: authMode)
                                
                                // OR separator
                                OrSeparator()
                                
                                // Toggle to email/password
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        mode = .email
                                        signInError = ""
                                        passwordError = ""
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "envelope")
                                            .font(.system(size: 16))
                                        Text(L("ใช้อีเมลและรหัสผ่าน", "Use email and password"))
                                            .font(.kanitMedium(size: 14))
                                    }
                                    .foregroundColor(.black.opacity(0.6))
                                }
                                .disabled(supabaseManager.isLoading)
                                
                                // Toggle between Sign In/Sign Up
                                HStack(spacing: 4) {
                                    Text(authMode == .signin ? L("ยังไม่มีบัญชี?", "Don't have an account?") : L("มีบัญชีอยู่แล้ว?", "Already have an account?"))
                                        .font(.kanitRegular(size: 14))
                                        .foregroundColor(.black.opacity(0.6))
                                    
                                    Button(authMode == .signin ? L("สมัครสมาชิก", "Sign up") : L("เข้าสู่ระบบ", "Sign in")) {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            authMode = authMode == .signin ? .signup : .signin
                                            signInError = ""
                                            passwordError = ""
                                        }
                                    }
                                    .font(.kanitMedium(size: 14))
                                    .foregroundColor(Color(red: 1.0, green: 0.541, blue: 0.239)) // brand-orange
                                }
                            }
                        } else {
                            // Email mode
                            VStack(spacing: 16) {
                                // Email field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(L("อีเมล", "Email"))
                                        .font(.kanitMedium(size: 14))
                                        .foregroundColor(.black)

                                    CustomTextField(
                                        text: $email,
                                        placeholder: "doggo@pawjai.com",
                                        keyboardType: .emailAddress,
                                        isDisabled: supabaseManager.isLoading,
                                        autocapitalizationType: .none
                                    )
                                    .id("email-field")
                                    .frame(height: 44)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                
                                // Password field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(L("รหัสผ่าน", "Password"))
                                        .font(.kanitMedium(size: 14))
                                        .foregroundColor(.black)

                                    HStack {
                                        Group {
                                            if showPassword {
                                                TextField(authMode == .signup ? L("สร้างรหัสผ่านที่ปลอดภัย", "Create a secure password") : L("ใส่รหัสผ่าน", "Enter password"), text: $password)
                                                    .id("password-visible")
                                            } else {
                                                SecureField(authMode == .signup ? L("สร้างรหัสผ่านที่ปลอดภัย", "Create a secure password") : L("ใส่รหัสผ่าน", "Enter password"), text: $password)
                                                    .id("password-secure")
                                            }
                                        }
                                        .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.235))
                                        .tint(Color(red: 0.118, green: 0.161, blue: 0.235))
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)

                                        Button(action: {
                                            showPassword.toggle()
                                        }) {
                                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                                .foregroundColor(.black.opacity(0.6))
                                                .frame(width: 24, height: 24)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .disabled(supabaseManager.isLoading)
                                }
                                
                                // Confirm Password field (only for signup)
                                if authMode == .signup {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(L("ยืนยันรหัสผ่าน", "Confirm password"))
                                            .font(.kanitMedium(size: 14))
                                            .foregroundColor(.black)

                                        HStack {
                                            Group {
                                                if showConfirmPassword {
                                                    TextField(L("ยืนยันรหัสผ่าน", "Confirm password"), text: $confirmPassword)
                                                        .id("confirm-password-visible")
                                                } else {
                                                    SecureField(L("ยืนยันรหัสผ่าน", "Confirm password"), text: $confirmPassword)
                                                        .id("confirm-password-secure")
                                                }
                                            }
                                            .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.235))
                                            .tint(Color(red: 0.118, green: 0.161, blue: 0.235))
                                            .autocorrectionDisabled()
                                            .textInputAutocapitalization(.never)

                                            Button(action: {
                                                showConfirmPassword.toggle()
                                            }) {
                                                Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                                    .foregroundColor(.black.opacity(0.6))
                                                    .frame(width: 24, height: 24)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .disabled(supabaseManager.isLoading)
                                    }
                                }
                                
                                // Password error message
                                if !passwordError.isEmpty {
                                    Text(passwordError)
                                        .font(.kanitRegular(size: 14))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                
                                // General error message
                                if !signInError.isEmpty {
                                    Text(signInError)
                                        .font(.kanitRegular(size: 14))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                
                                // Forgot password link (only for signin)
                                if authMode == .signin {
                                    HStack {
                                        Spacer()
                                        Button(L("ลืมรหัสผ่าน?", "Forgot password?")) {
                                            showForgotPassword = true
                                        }
                                        .font(.kanitMedium(size: 14))
                                        .foregroundColor(Color(red: 1.0, green: 0.541, blue: 0.239)) // brand-orange
                                    }
                                }
                                
                                // Sign in/up button
                                Button(action: {
                                    handleEmailAuth()
                                }) {
                                    HStack {
                                        if supabaseManager.isLoading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        }
                                        Text(authMode == .signin ? L("เข้าสู่ระบบ", "Sign in") : L("เริ่มต้นดูแลน้องให้ดียิ่งขึ้น", "Start caring better"))
                                            .font(.kanitMedium(size: 16))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color(red: 1.0, green: 0.541, blue: 0.239)) // brand-orange
                                    .cornerRadius(12)
                                }
                                .disabled(supabaseManager.isLoading || email.isEmpty || password.isEmpty || (authMode == .signup && confirmPassword.isEmpty))
                                
                                // Toggle back to OAuth
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        mode = .oauth
                                        signInError = ""
                                        passwordError = ""
                                    }
                                }) {
                                    Text(L("กลับไปใช้ OAuth", "Back to OAuth"))
                                        .font(.kanitMedium(size: 14))
                                        .foregroundColor(.black.opacity(0.6))
                                }
                                
                                // Toggle between Sign In/Sign Up
                                HStack(spacing: 4) {
                                    Text(authMode == .signin ? L("ยังไม่มีบัญชี?", "Don't have an account?") : L("มีบัญชีอยู่แล้ว?", "Already have an account?"))
                                        .font(.kanitRegular(size: 14))
                                        .foregroundColor(.black.opacity(0.6))
                                    
                                    Button(authMode == .signin ? L("สมัครสมาชิก", "Sign up") : L("เข้าสู่ระบบ", "Sign in")) {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            authMode = authMode == .signin ? .signup : .signin
                                            signInError = ""
                                            passwordError = ""
                                        }
                                    }
                                    .font(.kanitMedium(size: 14))
                                    .foregroundColor(Color(red: 1.0, green: 0.541, blue: 0.239)) // brand-orange
                                }
                            }
                        }
                    }
                    .padding(32)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 60)
                }

                // Subtle language selector (Apple-like)
                HStack(spacing: 6) {
                    Button(action: { language.setLanguage(.th) }) {
                        Text("TH")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(language.language == .th ? .white : .black.opacity(0.6))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(
                                Capsule().fill(language.language == .th ? Color(red: 1.0, green: 0.541, blue: 0.239) : Color(red: 1.0, green: 0.541, blue: 0.239).opacity(0.12))
                            )
                    }
                    Button(action: { language.setLanguage(.en) }) {
                        Text("EN")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(language.language == .en ? .white : .black.opacity(0.6))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(
                                Capsule().fill(language.language == .en ? Color(red: 1.0, green: 0.541, blue: 0.239) : Color(red: 1.0, green: 0.541, blue: 0.239).opacity(0.12))
                            )
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToURL)) { notification in
            if notification.userInfo?["url"] is URL {
                navigateToWebView = true
            }
        }
        .fullScreenCover(isPresented: $navigateToWebView) {
            WebViewContainer(url: URL(string: "\(Configuration.webAppURL)/dashboard")!)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(
                email: $forgotPasswordEmail,
                error: $forgotPasswordError,
                success: $forgotPasswordSuccess,
                onSendReset: sendPasswordReset,
                onDismiss: {
                    showForgotPassword = false
                    forgotPasswordEmail = ""
                    forgotPasswordError = ""
                    forgotPasswordSuccess = false
                }
            )
        }
    }
    
    private func handleEmailAuth() {
        // Clear previous errors
        signInError = ""
        passwordError = ""
        
        // Validate password confirmation for signup
        if authMode == .signup && password != confirmPassword {
            passwordError = L("รหัสผ่านไม่ตรงกัน", "Passwords do not match")
            return
        }
        
        // Call the appropriate authentication method
        if authMode == .signin {
            signInWithEmail()
        } else {
            signUpWithEmail()
        }
    }
    
    private func signInWithEmail() {
        supabaseManager.signInWithEmail(email: email, password: password)
    }
    
    private func signUpWithEmail() {
        supabaseManager.signUpWithEmail(email: email, password: password)
    }
    
    private func sendPasswordReset() {
        supabaseManager.resetPassword(email: forgotPasswordEmail) { [self] success, error in
            if success {
                forgotPasswordSuccess = true
                forgotPasswordError = ""
            } else {
                forgotPasswordError = error ?? "เกิดข้อผิดพลาดในการส่งอีเมลรีเซ็ตรหัสผ่าน"
                forgotPasswordSuccess = false
            }
        }
    }
}

// Simple inline translator using LanguageManager
private func L(_ th: String, _ en: String) -> String {
    LanguageManager.shared.t(th, en)
}

// Custom UITextField wrapper for proper text color control
struct CustomTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var isDisabled: Bool = false
    var autocapitalizationType: UITextAutocapitalizationType = .sentences

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.isSecureTextEntry = isSecure
        textField.autocapitalizationType = autocapitalizationType
        textField.autocorrectionType = .no

        // Set text color to dark gray
        textField.textColor = UIColor(red: 0.118, green: 0.161, blue: 0.235, alpha: 1.0)
        textField.tintColor = UIColor(red: 0.118, green: 0.161, blue: 0.235, alpha: 1.0)

        // Set placeholder color to gray
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [NSAttributedString.Key.foregroundColor: UIColor.gray.withAlphaComponent(0.5)]
        )

        // Styling
        textField.font = UIFont.kanitRegular(size: 16)
        textField.backgroundColor = .white
        textField.borderStyle = .none

        // Performance optimizations
        textField.clearButtonMode = .never // Disable clear button to reduce complexity
        textField.enablesReturnKeyAutomatically = false

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Only update if values actually changed to prevent unnecessary re-renders
        if uiView.text != text {
            uiView.text = text
        }
        if uiView.isEnabled == isDisabled {
            uiView.isEnabled = !isDisabled
        }
        if uiView.isSecureTextEntry != isSecure {
            uiView.isSecureTextEntry = isSecure
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CustomTextField

        init(_ parent: CustomTextField) {
            self.parent = parent
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            // Use DispatchQueue.main.async to prevent blocking the main thread
            DispatchQueue.main.async {
                self.parent.text = textField.text ?? ""
            }
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            return true
        }

        func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
            return true
        }
    }
}

// Custom text field style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.235))
            .accentColor(Color(red: 0.118, green: 0.161, blue: 0.235))
            .tint(Color(red: 0.118, green: 0.161, blue: 0.235))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

// Custom placeholder modifier
struct PlaceholderStyle: ViewModifier {
    var showPlaceholder: Bool
    var placeholder: String
    
    func body(content: Content) -> some View {
        ZStack(alignment: .leading) {
            if showPlaceholder {
                Text(placeholder)
                    .font(.kanitRegular(size: 16))
                    .foregroundColor(.gray.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            content
        }
    }
}

// Google Sign In Button
struct GoogleSignInButton: View {
    @EnvironmentObject var language: LanguageManager
    let supabaseManager: SupabaseManager
    let authMode: AuthView.AuthModeType

    var body: some View {
        Button(action: {
            supabaseManager.signInWithGoogle()
        }) {
            HStack(spacing: 12) {
                // Google logo
                GoogleLogo()
                
                Text(authMode == .signin ? language.t("เข้าสู่ระบบด้วย Google", "Sign in with Google") : language.t("สมัครด้วย Google", "Sign up with Google"))
                    .font(.kanitMedium(size: 16))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(supabaseManager.isLoading)
    }
}

// Apple Sign In Button
struct AppleSignInButton: View {
    @EnvironmentObject var language: LanguageManager
    let supabaseManager: SupabaseManager
    let authMode: AuthView.AuthModeType

    var body: some View {
        Button(action: {
            supabaseManager.signInWithApple()
        }) {
            HStack(spacing: 12) {
                // Apple logo
                AppleLogo()
                
                Text(authMode == .signin ? language.t("เข้าสู่ระบบด้วย Apple", "Sign in with Apple") : language.t("สมัครด้วย Apple", "Sign up with Apple"))
                    .font(.kanitMedium(size: 16))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.black)
            .cornerRadius(12)
        }
        .disabled(supabaseManager.isLoading)
    }
}

// Google Logo Component
struct GoogleLogo: View {
    var body: some View {
        Image("google-icon")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
    }
}

// Apple Logo Component
struct AppleLogo: View {
    var body: some View {
        Image(systemName: "applelogo")
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(.white)
    }
}

// OR Separator
struct OrSeparator: View {
    @EnvironmentObject var language: LanguageManager
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
            
            Text(language.t("หรือ", "or"))
                .font(.kanitRegular(size: 14))
                .foregroundColor(.black.opacity(0.6))
                .padding(.horizontal, 16)
                .background(Color.white)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
    }
}

// MARK: - Forgot Password View
struct ForgotPasswordView: View {
    @Binding var email: String
    @Binding var error: String
    @Binding var success: Bool
    let onSendReset: () -> Void
    let onDismiss: () -> Void
    
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(red: 1.0, green: 0.957, blue: 0.914) // #fff4e9
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 40)
                        
                        // Header section
                        VStack(spacing: 24) {
                            // Email icon
                            VStack(spacing: 16) {
                                Image(systemName: "envelope.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(Color(red: 1.0, green: 0.541, blue: 0.239)) // brand-orange
                            }
                            
                            // Title and subtitle
                            VStack(spacing: 8) {
                                Text(L("รีเซ็ตรหัสผ่าน", "Reset password"))
                                    .font(.kanitBold(size: 24))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                                
                                Text(L("กรุณาใส่อีเมลของคุณเพื่อรับลิงก์รีเซ็ตรหัสผ่าน", "Enter your email and we’ll send a reset link"))
                                    .font(.kanitRegular(size: 18))
                                    .foregroundColor(.black.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.bottom, 32)
                        
                        // Forgot password form card
                        VStack(spacing: 24) {
                            VStack(spacing: 16) {
                                if success {
                                    // Success state
                                    VStack(spacing: 16) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(.green)
                                        
                                        Text(L("ส่งอีเมลเรียบร้อยแล้ว", "Email sent"))
                                            .font(.kanitBold(size: 20))
                                            .foregroundColor(.black)
                                        
                                        Text(L("เราได้ส่งลิงก์รีเซ็ตรหัสผ่านไปยังอีเมลของคุณแล้ว กรุณาตรวจสอบกล่องจดหมายและคลิกลิงก์เพื่อรีเซ็ตรหัสผ่าน", "We sent a reset link to your email. Please check your inbox and click the link to reset your password."))
                                            .font(.kanitRegular(size: 16))
                                            .foregroundColor(.black.opacity(0.7))
                                            .multilineTextAlignment(.center)
                                        
                                        Text(L("อีเมล:", "Email:") + " \(email)")
                                            .font(.kanitMedium(size: 14))
                                            .foregroundColor(.black.opacity(0.6))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                } else {
                                    // Form state
                                    VStack(spacing: 16) {
                                        // Email field
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(L("อีเมล", "Email"))
                                                .font(.kanitMedium(size: 14))
                                                .foregroundColor(.black)

                                            CustomTextField(
                                                text: $email,
                                                placeholder: "doggo@pawjai.com",
                                                keyboardType: .emailAddress,
                                                isDisabled: isLoading,
                                                autocapitalizationType: .none
                                            )
                                            .frame(height: 44)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(Color.white)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                        }
                                        
                                        // Error message
                                        if !error.isEmpty {
                                            Text(error)
                                                .font(.kanitRegular(size: 14))
                                                .foregroundColor(.red)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color.red.opacity(0.1))
                                                .cornerRadius(8)
                                        }
                                        
                                        // Send reset button
                                        Button(action: {
                                            if !email.isEmpty {
                                                isLoading = true
                                                error = ""
                                                onSendReset()
                                            }
                                        }) {
                                            HStack {
                                                if isLoading {
                                                    ProgressView()
                                                        .scaleEffect(0.8)
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                }
                                                Text(L("ส่งลิงก์รีเซ็ตรหัสผ่าน", "Send reset link"))
                                                    .font(.kanitMedium(size: 16))
                                            }
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 48)
                                            .background(Color(red: 1.0, green: 0.541, blue: 0.239)) // brand-orange
                                            .cornerRadius(12)
                                        }
                                        .disabled(isLoading || email.isEmpty)
                                    }
                                }
                                
                                // Help text
                                VStack(spacing: 4) {
                                    Text(L("ไม่ได้รับอีเมล? ตรวจสอบโฟลเดอร์ Spam", "Didn't receive the email? Check your Spam"))
                                        .font(.kanitRegular(size: 12))
                                        .foregroundColor(.black.opacity(0.5))
                                        .multilineTextAlignment(.center)
                                    
                                    Text(L("ติดต่อเราได้ที่ support@pawjai.co", "Contact us at support@pawjai.co"))
                                        .font(.kanitRegular(size: 12))
                                        .foregroundColor(.black.opacity(0.5))
                                }
                            }
                        }
                        .padding(32)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle(L("รีเซ็ตรหัสผ่าน", "Reset password"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("ยกเลิก") {
                        onDismiss()
                    }
                    .font(.kanitMedium(size: 16))
                    .foregroundColor(Color(red: 1.0, green: 0.541, blue: 0.239)) // brand-orange
                }
                
                if success {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("เสร็จสิ้น") {
                            onDismiss()
                        }
                        .font(.kanitMedium(size: 16))
                        .foregroundColor(Color(red: 1.0, green: 0.541, blue: 0.239)) // brand-orange
                    }
                }
            }
        }
        .onChange(of: success) {
            if success {
                isLoading = false
            }
        }
        .onChange(of: error) {
            if !error.isEmpty {
                isLoading = false
            }
        }
    }
}

#Preview {
    AuthView()
}
