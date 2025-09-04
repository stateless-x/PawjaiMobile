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
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Logo and branding
            VStack(spacing: 16) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                
                Text("Pawjai")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("ดูแลสัตว์เลี้ยงของคุณอย่างสมบูรณ์แบบ")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Sign in options
            VStack(spacing: 16) {
                if supabaseManager.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("กำลังเข้าสู่ระบบ...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Google Sign In Button
                    Button(action: {
                        supabaseManager.signInWithGoogle()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.title2)
                            
                            Text("เข้าสู่ระบบด้วย Google")
                                .font(.headline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(supabaseManager.isLoading)
                }
                
                if let errorMessage = supabaseManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .background(Color(.systemBackground))
        .onReceive(NotificationCenter.default.publisher(for: .navigateToURL)) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                navigateToWebView = true
            }
        }
        .fullScreenCover(isPresented: $navigateToWebView) {
            WebViewContainer(url: URL(string: "\(Configuration.webAppURL)/dashboard")!)
        }
    }
}

#Preview {
    AuthView()
}
