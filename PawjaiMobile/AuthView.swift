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
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                            
                            Text(getSubtitle())
                                .font(.system(size: 18))
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
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(.black.opacity(0.6))
                                }
                                
                                // Toggle between Sign In/Sign Up
                                HStack(spacing: 4) {
                                    Text(authMode == .signin ? "ยังไม่มีบัญชี?" : "มีบัญชีอยู่แล้ว?")
                                        .font(.system(size: 14))
                                        .foregroundColor(.black.opacity(0.6))
                                    
                                    Button(authMode == .signin ? "สมัครสมาชิก" : "เข้าสู่ระบบ") {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            authMode = authMode == .signin ? .signup : .signin
                                            signInError = ""
                                            passwordError = ""
                                        }
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(red: 1.0, green: 0.541, blue: 0.239)) // brand-orange
                                }
                            }
                        } else {
                            // Email mode
                            VStack(spacing: 16) {
                                // Email field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("อีเมล")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.black)
                                    
                                    TextField("doggo@pawjai.com", text: $email)
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .disabled(supabaseManager.isLoading)
                                }
                                
                                // Password field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("รหัสผ่าน")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.black)
                                    
                                    HStack {
                                        if showPassword {
                                            TextField(authMode == .signup ? "สร้างรหัสผ่านที่ปลอดภัย" : "ใส่รหัสผ่าน", text: $password)
                                        } else {
                                            SecureField(authMode == .signup ? "สร้างรหัสผ่านที่ปลอดภัย" : "ใส่รหัสผ่าน", text: $password)
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
                                }
                                
                                // Confirm Password field (only for signup)
                                if authMode == .signup {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("ยืนยันรหัสผ่าน")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.black)
                                        
                                        HStack {
                                            if showConfirmPassword {
                                                TextField("ยืนยันรหัสผ่าน", text: $confirmPassword)
                                            } else {
                                                SecureField("ยืนยันรหัสผ่าน", text: $confirmPassword)
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
                                    }
                                }
                                
                                // Password error message
                                if !passwordError.isEmpty {
                                    Text(passwordError)
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                
                                // General error message
                                if !signInError.isEmpty {
                                    Text(signInError)
                                        .font(.system(size: 14))
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
                                            // TODO: Navigate to forgot password
                                        }
                                        .font(.system(size: 14, weight: .medium))
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
                                            .font(.system(size: 16, weight: .medium))
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
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.black.opacity(0.6))
                                }
                                
                                // Toggle between Sign In/Sign Up
                                HStack(spacing: 4) {
                                    Text(authMode == .signin ? "ยังไม่มีบัญชี?" : "มีบัญชีอยู่แล้ว?")
                                        .font(.system(size: 14))
                                        .foregroundColor(.black.opacity(0.6))
                                    
                                    Button(authMode == .signin ? "สมัครสมาชิก" : "เข้าสู่ระบบ") {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            authMode = authMode == .signin ? .signup : .signin
                                            signInError = ""
                                            passwordError = ""
                                        }
                                    }
                                    .font(.system(size: 14, weight: .medium))
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
        // TODO: Implement email/password sign in
        signInError = "Email sign in not implemented yet"
    }
    
    private func signUpWithEmail() {
        // TODO: Implement email/password sign up
        signInError = "Email sign up not implemented yet"
    }
}

// Custom text field style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
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
                    .font(.system(size: 16, weight: .medium))
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

// Google Logo Component
struct GoogleLogo: View {
    var body: some View {
        Image("google-icon")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
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
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .background(Color.white)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
    }
}

#Preview {
    AuthView()
}
