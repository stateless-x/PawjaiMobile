//
//  EmailConfirmationView.swift
//  PawjaiMobile
//
//  Created by Purin Buriwong on 3/9/2568 BE.
//

import SwiftUI

struct EmailConfirmationView: View {
    @StateObject private var supabaseManager = SupabaseManager.shared
    @State private var navigateToWebView = false
    @State private var cooldown = 0
    @State private var isResending = false
    
    var body: some View {
        ZStack {
            // Solid background color
            Color(red: 1.0, green: 0.957, blue: 0.914) // #fff4e9
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)
                    
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
                            Text("ยืนยันอีเมลของคุณ")
                                .font(.kanitBold(size: 24))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                            
                            Text("เราได้ส่งลิงก์ยืนยันไปยังอีเมลของคุณแล้ว")
                                .font(.kanitRegular(size: 18))
                                .foregroundColor(.black.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, 32)
                    
                    // Email confirmation card
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            // Instructions
                            VStack(spacing: 12) {
                                Text("กรุณาตรวจสอบกล่องจดหมายและคลิกลิงก์เพื่อยืนยันการสมัครสมาชิก")
                                    .font(.kanitRegular(size: 16))
                                    .foregroundColor(.black.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                
                                if let email = supabaseManager.pendingEmailConfirmation {
                                    Text("อีเมล: \(email)")
                                        .font(.kanitMedium(size: 14))
                                        .foregroundColor(.black.opacity(0.6))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            
                            // Info box
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("หลังจากยืนยันอีเมลแล้ว")
                                        .font(.kanitMedium(size: 14))
                                        .foregroundColor(.blue)
                                }
                                
                                Text("คุณจะสามารถเข้าสู่ระบบและเริ่มต้นการตั้งค่าโปรไฟล์ได้")
                                    .font(.kanitRegular(size: 14))
                                    .foregroundColor(.blue.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            
                            // Action buttons
                            VStack(spacing: 12) {
                                // Sign in after confirmation button
                                Button(action: {
                                    // Navigate to sign in
                                    supabaseManager.requiresEmailConfirmation = false
                                    supabaseManager.pendingEmailConfirmation = nil
                                }) {
                                    HStack {
                                        Text("เข้าสู่ระบบหลังจากยืนยันแล้ว")
                                            .font(.kanitMedium(size: 16))
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 16))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color(red: 1.0, green: 0.541, blue: 0.239)) // brand-orange
                                    .cornerRadius(12)
                                }
                                
                                // Resend email button
                                Button(action: {
                                    resendConfirmationEmail()
                                }) {
                                    HStack {
                                        if isResending {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 16))
                                        }
                                        
                                        if cooldown > 0 {
                                            Text("ส่งใหม่ได้ใน \(cooldown) วินาที")
                                        } else {
                                            Text("ส่งอีเมลยืนยันใหม่")
                                        }
                                    }
                                    .font(.kanitMedium(size: 16))
                                    .foregroundColor(.black.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .disabled(cooldown > 0 || isResending)
                                
                                // Back to sign in button
                                Button(action: {
                                    supabaseManager.requiresEmailConfirmation = false
                                    supabaseManager.pendingEmailConfirmation = nil
                                }) {
                                    Text("กลับไปหน้าสมัครสมาชิก")
                                        .font(.kanitMedium(size: 14))
                                        .foregroundColor(.black.opacity(0.6))
                                }
                            }
                            
                            // Help text
                            VStack(spacing: 4) {
                                Text("ไม่ได้รับอีเมลยืนยัน? ตรวจสอบโฟลเดอร์ Spam")
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
                    
                    Spacer(minLength: 60)
                }
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
        .onAppear {
            // Start cooldown timer
            startCooldownTimer()
        }
    }
    
    private func startCooldownTimer() {
        cooldown = 60 // 60 seconds cooldown
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if cooldown > 0 {
                cooldown -= 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func resendConfirmationEmail() {
        guard let email = supabaseManager.pendingEmailConfirmation else { return }
        
        isResending = true
        
        // Create the resend confirmation request
        var urlComponents = URLComponents(string: "\(Configuration.supabaseURL)/auth/v1/resend")!
        urlComponents.queryItems = [
            URLQueryItem(name: "apikey", value: Configuration.supabaseAnonKey)
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "type": "signup",
            "email": email
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            isResending = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isResending = false
                
                if let error = error {
                    print("📱 Resend confirmation error: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    print("📱 Confirmation email resent successfully")
                    cooldown = 60 // Reset cooldown
                } else {
                    print("📱 Failed to resend confirmation email")
                }
            }
        }.resume()
    }
}

#Preview {
    EmailConfirmationView()
}
