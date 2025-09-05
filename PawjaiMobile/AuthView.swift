//
//  AuthView.swift
//  PawjaiMobile
//
//  Created by Purin Buriwong on 3/9/2568 BE.
//

import SwiftUI

struct AuthView: View {
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
                    print("🔐 AuthView appeared")
                    print("🔐 SupabaseManager isLoading: \(supabaseManager.isLoading)")
                    print("🔐 SupabaseManager isAuthenticated: \(supabaseManager.isAuthenticated)")
                }
                .onChange(of: supabaseManager.errorMessage) { errorMessage in
                    if let error = errorMessage {
                        signInError = error
                        print("🔐 AuthView received error: \(error)")
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
                            Text(getTitle())
                                .font(.kanitBold(size: 24))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                            
                            Text(getSubtitle())
                                .font(.kanitRegular(size: 18))
                                .foregroundColor(.black.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, 32)
                    
                    // Sign in form card
                    VStack(spacing: 24) {
                        if mode == .oauth {
                            // OAuth mode
                            VStack(spacing: 16) {
                                // Google Sign In Button
                                GoogleSignInButton(authMode: authMode)
                                
                                // Apple Sign In Button
                                AppleSignInButton(authMode: authMode)
                                
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
                                        Text("ใช้อีเมลและรหัสผ่าน")
                                            .font(.kanitMedium(size: 14))
                                    }
                                    .foregroundColor(.black.opacity(0.6))
                                }
                                
                                // Toggle between Sign In/Sign Up
                                HStack(spacing: 4) {
                                    Text(authMode == .signin ? "ยังไม่มีบัญชี?" : "มีบัญชีอยู่แล้ว?")
                                        .font(.kanitRegular(size: 14))
                                        .foregroundColor(.black.opacity(0.6))
                                    
                                    Button(authMode == .signin ? "สมัครสมาชิก" : "เข้าสู่ระบบ") {
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
                                    Text("อีเมล")
                                        .font(.kanitMedium(size: 14))
                                        .foregroundColor(.black)
                                    
                                    ZStack(alignment: .leading) {
                                        TextField("", text: $email)
                                            .textFieldStyle(CustomTextFieldStyle())
                                            .keyboardType(.emailAddress)
                                            .autocapitalization(.none)
                                            .disabled(supabaseManager.isLoading)
                                            .foregroundColor(.black)
                                        
                                        if email.isEmpty {
                                            Text("doggo@pawjai.com")
                                                .font(.kanitRegular(size: 16))
                                                .foregroundColor(Color.gray.opacity(0.8))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 12)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                }
                                
                                // Password field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("รหัสผ่าน")
                                        .font(.kanitMedium(size: 14))
                                        .foregroundColor(.black)
                                    
                                    ZStack(alignment: .leading) {
                                        HStack {
                                            if showPassword {
                                                TextField("", text: $password)
                                                    .foregroundColor(.black)
                                            } else {
                                                SecureField("", text: $password)
                                                    .foregroundColor(.black)
                                            }
                                            
                                            Button(action: {
                                                showPassword.toggle()
                                            }) {
                                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                                    .foregroundColor(.black.opacity(0.6))
                                            }
                                        }
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .disabled(supabaseManager.isLoading)
                                        
                                        if password.isEmpty {
                                            Text(authMode == .signup ? "สร้างรหัสผ่านที่ปลอดภัย" : "ใส่รหัสผ่าน")
                                                .font(.kanitRegular(size: 16))
                                                .foregroundColor(Color.gray.opacity(0.8))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 12)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                }
                                
                                // Confirm Password field (only for signup)
                                if authMode == .signup {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("ยืนยันรหัสผ่าน")
                                            .font(.kanitMedium(size: 14))
                                            .foregroundColor(.black)
                                        
                                        ZStack(alignment: .leading) {
                                            HStack {
                                                if showConfirmPassword {
                                                    TextField("", text: $confirmPassword)
                                                        .foregroundColor(.black)
                                                } else {
                                                    SecureField("", text: $confirmPassword)
                                                        .foregroundColor(.black)
                                                }
                                                
                                                Button(action: {
                                                    showConfirmPassword.toggle()
                                                }) {
                                                    Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                                        .foregroundColor(.black.opacity(0.6))
                                                }
                                            }
                                            .textFieldStyle(CustomTextFieldStyle())
                                            .disabled(supabaseManager.isLoading)
                                            
                                            if confirmPassword.isEmpty {
                                                Text("ยืนยันรหัสผ่าน")
                                                    .font(.kanitRegular(size: 16))
                                                    .foregroundColor(Color.gray.opacity(0.8))
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 12)
                                                    .allowsHitTesting(false)
                                            }
                                        }
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
                                        Button("ลืมรหัสผ่าน?") {
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
                                        Text(authMode == .signin ? "เข้าสู่ระบบ" : "เริ่มต้นดูแลน้องให้ดียิ่งขึ้น")
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
                                    Text("กลับไปใช้ OAuth")
                                        .font(.kanitMedium(size: 14))
                                        .foregroundColor(.black.opacity(0.6))
                                }
                                
                                // Toggle between Sign In/Sign Up
                                HStack(spacing: 4) {
                                    Text(authMode == .signin ? "ยังไม่มีบัญชี?" : "มีบัญชีอยู่แล้ว?")
                                        .font(.kanitRegular(size: 14))
                                        .foregroundColor(.black.opacity(0.6))
                                    
                                    Button(authMode == .signin ? "สมัครสมาชิก" : "เข้าสู่ระบบ") {
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
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToURL)) { notification in
            if let url = notification.userInfo?["url"] as? URL {
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
    
    private func getTitle() -> String {
        return authMode == .signin ? "ใส่ใจน้องมากขึ้นทุกวัน" : "เริ่มต้นดูแลน้องให้ดียิ่งขึ้น"
    }
    
    private func getSubtitle() -> String {
        return "ง่าย รวดเร็ว และปลอดภัย"
    }
    
    private func handleEmailAuth() {
        // Clear previous errors
        signInError = ""
        passwordError = ""
        
        // Validate password confirmation for signup
        if authMode == .signup && password != confirmPassword {
            passwordError = "รหัสผ่านไม่ตรงกัน"
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
        print("📱 AuthView: Starting email sign in")
        supabaseManager.signInWithEmail(email: email, password: password)
    }
    
    private func signUpWithEmail() {
        print("📱 AuthView: Starting email sign up")
        supabaseManager.signUpWithEmail(email: email, password: password)
    }
    
    private func sendPasswordReset() {
        print("📱 AuthView: Starting password reset for: \(forgotPasswordEmail)")
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

// Custom text field style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .foregroundColor(.black) // Ensure text is dark/black
            .accentColor(.black) // Cursor color
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
    @StateObject private var supabaseManager = SupabaseManager.shared
    let authMode: AuthView.AuthModeType
    
    var body: some View {
        Button(action: {
            supabaseManager.signInWithGoogle()
        }) {
            HStack(spacing: 12) {
                // Google logo
                GoogleLogo()
                
                Text(authMode == .signin ? "เข้าสู่ระบบด้วย Google" : "สมัครด้วย Google")
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
    @StateObject private var supabaseManager = SupabaseManager.shared
    let authMode: AuthView.AuthModeType
    
    var body: some View {
        Button(action: {
            supabaseManager.signInWithApple()
        }) {
            HStack(spacing: 12) {
                // Apple logo
                AppleLogo()
                
                Text(authMode == .signin ? "เข้าสู่ระบบด้วย Apple" : "สมัครด้วย Apple")
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
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
            
            Text("หรือ")
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
                                Text("รีเซ็ตรหัสผ่าน")
                                    .font(.kanitBold(size: 24))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                                
                                Text("กรุณาใส่อีเมลของคุณเพื่อรับลิงก์รีเซ็ตรหัสผ่าน")
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
                                        
                                        Text("ส่งอีเมลเรียบร้อยแล้ว")
                                            .font(.kanitBold(size: 20))
                                            .foregroundColor(.black)
                                        
                                        Text("เราได้ส่งลิงก์รีเซ็ตรหัสผ่านไปยังอีเมลของคุณแล้ว กรุณาตรวจสอบกล่องจดหมายและคลิกลิงก์เพื่อรีเซ็ตรหัสผ่าน")
                                            .font(.kanitRegular(size: 16))
                                            .foregroundColor(.black.opacity(0.7))
                                            .multilineTextAlignment(.center)
                                        
                                        Text("อีเมล: \(email)")
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
                                            Text("อีเมล")
                                                .font(.kanitMedium(size: 14))
                                                .foregroundColor(.black)
                                            
                                            ZStack(alignment: .leading) {
                                                TextField("", text: $email)
                                                    .textFieldStyle(CustomTextFieldStyle())
                                                    .keyboardType(.emailAddress)
                                                    .autocapitalization(.none)
                                                    .disabled(isLoading)
                                                    .foregroundColor(.black)
                                                
                                                if email.isEmpty {
                                                    Text("doggo@pawjai.com")
                                                        .font(.kanitRegular(size: 16))
                                                        .foregroundColor(Color.gray.opacity(0.8))
                                                        .padding(.horizontal, 16)
                                                        .padding(.vertical, 12)
                                                        .allowsHitTesting(false)
                                                }
                                            }
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
                                                Text("ส่งลิงก์รีเซ็ตรหัสผ่าน")
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
                                    Text("ไม่ได้รับอีเมล? ตรวจสอบโฟลเดอร์ Spam")
                                        .font(.kanitRegular(size: 12))
                                        .foregroundColor(.black.opacity(0.5))
                                        .multilineTextAlignment(.center)
                                    
                                    Text("ติดต่อเราได้ที่ support@pawjai.co")
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
            .navigationTitle("รีเซ็ตรหัสผ่าน")
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
        .onChange(of: success) { newValue in
            if newValue {
                isLoading = false
            }
        }
        .onChange(of: error) { newValue in
            if !newValue.isEmpty {
                isLoading = false
            }
        }
    }
}

#Preview {
    AuthView()
}
