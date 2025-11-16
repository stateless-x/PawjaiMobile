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
            if supabaseManager.isInitializing {
                // Hold initial render until auth restoration completes
                ZStack {
                    Color(red: 1.0, green: 0.957, blue: 0.914).ignoresSafeArea()
                    ProgressView().scaleEffect(1.2)
                }
            } else if supabaseManager.isAuthenticated {
                WebViewContainer(url: webViewURL ?? URL(string: "\(Configuration.webAppURL)/dashboard")!)
            } else if supabaseManager.requiresEmailConfirmation {
                EmailConfirmationView()
            } else {
                AuthView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToURL)) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                webViewURL = url
                // Ensure authentication state is set
                if !supabaseManager.isAuthenticated {
                    supabaseManager.isAuthenticated = true
                }
            }
        }
        .onAppear {
            if supabaseManager.isAuthenticated && webViewURL == nil {
                webViewURL = URL(string: "\(Configuration.webAppURL)/dashboard")!
            }
            if let token = supabaseManager.currentUser?.accessToken {
                language.syncWithBackend(accessToken: token)
            }
        }
        .onChange(of: supabaseManager.isAuthenticated) {
            if supabaseManager.isAuthenticated && webViewURL == nil {
                webViewURL = URL(string: "\(Configuration.webAppURL)/dashboard")!
            }
            
            // Setup notifications when user is authenticated
            if supabaseManager.isAuthenticated {
                if notificationManager.isAuthorized {
                    notificationManager.scheduleDailyNotification()
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
