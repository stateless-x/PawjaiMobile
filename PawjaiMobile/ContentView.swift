//
//  ContentView.swift
//  PawjaiMobile
//
//  Created by Purin Buriwong on 3/9/2568 BE.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var supabaseManager = SupabaseManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @EnvironmentObject var language: LanguageManager
    @State private var webViewURL: URL?
    
    var body: some View {
        Group {
            if supabaseManager.isAuthenticated {
                WebViewContainer(url: webViewURL ?? URL(string: "\(Configuration.webAppURL)/dashboard")!)
            } else if supabaseManager.requiresEmailConfirmation {
                EmailConfirmationView()
            } else {
                AuthView()
            }
        }
        .onAppear {
            print("📱 ContentView body appeared")
            print("📱 SupabaseManager isAuthenticated: \(supabaseManager.isAuthenticated)")
            print("📱 WebViewURL: \(webViewURL?.absoluteString ?? "nil")")
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToURL)) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                print("📱 ContentView received navigateToURL notification: \(url)")
                webViewURL = url
                // Ensure authentication state is set
                if !supabaseManager.isAuthenticated {
                    supabaseManager.isAuthenticated = true
                }
            }
        }
        .onAppear {
            print("📱 ContentView appeared - isAuthenticated: \(supabaseManager.isAuthenticated)")
            if supabaseManager.isAuthenticated && webViewURL == nil {
                webViewURL = URL(string: "\(Configuration.webAppURL)/dashboard")!
                print("📱 Set WebView URL to dashboard: \(webViewURL?.absoluteString ?? "nil")")
            }
            // Sync language with backend once authenticated
            if let token = supabaseManager.currentUser?.accessToken {
                language.syncWithBackend(accessToken: token)
            }
        }
        .onChange(of: supabaseManager.isAuthenticated) {
            print("📱 Authentication state changed to: \(supabaseManager.isAuthenticated)")
            if supabaseManager.isAuthenticated && webViewURL == nil {
                webViewURL = URL(string: "\(Configuration.webAppURL)/dashboard")!
                print("📱 Set WebView URL to dashboard after auth change: \(webViewURL?.absoluteString ?? "nil")")
            }
            
            // Setup notifications when user is authenticated
            if supabaseManager.isAuthenticated {
                if notificationManager.isAuthorized {
                    notificationManager.scheduleDailyNotification()
                    print("🔔 Daily notifications scheduled for authenticated user (12:00 PM)")
                } else {
                    notificationManager.requestNotificationPermission()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
