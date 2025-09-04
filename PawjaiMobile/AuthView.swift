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
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var signInError = ""
    
    enum AuthMode {
        case oauth, email
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
                            Text("ใส่ใจน้องมากขึ้นทุกวัน")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                            
                            Text("ง่าย รวดเร็ว และปลอดภัย")
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
                                GoogleSignInButton()
                                
                                // OR separator
                                OrSeparator()
                                
                                // Toggle to email/password
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        mode = .email
                                        signInError = ""
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
                                
                                // Sign up link
                                HStack(spacing: 4) {
                                    Text("ยังไม่มีบัญชี?")
                                        .font(.system(size: 14))
                                        .foregroundColor(.black.opacity(0.6))
                                    
                                    Button("สมัครสมาชิก") {
                                        // TODO: Navigate to signup
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
                                            TextField("ใส่รหัสผ่าน", text: $password)
                                        } else {
                                            SecureField("ใส่รหัสผ่าน", text: $password)
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
                                
                                // Error message
                                if !signInError.isEmpty {
                                    Text(signInError)
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                
                                // Forgot password link
                                HStack {
                                    Spacer()
                                    Button("ลืมรหัสผ่าน?") {
                                        // TODO: Navigate to forgot password
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(red: 1.0, green: 0.541, blue: 0.239)) // brand-orange
                                }
                                
                                // Sign in button
                                Button(action: {
                                    signInWithEmail()
                                }) {
                                    HStack {
                                        if supabaseManager.isLoading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        }
                                        Text("เข้าสู่ระบบ")
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color(red: 1.0, green: 0.541, blue: 0.239)) // brand-orange
                                    .cornerRadius(12)
                                }
                                .disabled(supabaseManager.isLoading || email.isEmpty || password.isEmpty)
                                
                                // Toggle back to OAuth
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        mode = .oauth
                                        signInError = ""
                                    }
                                }) {
                                    Text("กลับไปใช้ OAuth")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.black.opacity(0.6))
                                }
                                
                                // Sign up link
                                HStack(spacing: 4) {
                                    Text("ยังไม่มีบัญชี?")
                                        .font(.system(size: 14))
                                        .foregroundColor(.black.opacity(0.6))
                                    
                                    Button("สมัครสมาชิก") {
                                        // TODO: Navigate to signup
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
    
    private func signInWithEmail() {
        // TODO: Implement email/password sign in
        signInError = "Email sign in not implemented yet"
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
    
    var body: some View {
        Button(action: {
            supabaseManager.signInWithGoogle()
        }) {
            HStack(spacing: 12) {
                // Google logo
                GoogleLogo()
                
                Text("เข้าสู่ระบบด้วย Google")
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
