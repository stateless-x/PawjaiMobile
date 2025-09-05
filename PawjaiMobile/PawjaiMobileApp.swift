//
//  PawjaiMobileApp.swift
//  PawjaiMobile
//
//  Created by Purin Buriwong on 3/9/2568 BE.
//

import SwiftUI

@main
struct PawjaiMobileApp: App {
    init() {
        print("🚀 PawjaiMobileApp initializing...")
        
        // Register fonts with error handling
        do {
            // Temporarily disable font loading to test if it's causing the issue
            // FontManager.shared.registerFonts()
            print("⚠️ Font loading temporarily disabled for debugging")
        } catch {
            print("❌ Font registration failed: \(error)")
        }
        
        // Setup fonts with error handling
        // Temporarily disable font setup to test if it's causing the issue
        // setupDefaultFonts()
        print("⚠️ Font setup temporarily disabled for debugging")
        print("✅ App initialization complete")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    print("📱 ContentView appeared in WindowGroup")
                }
        }
    }
    
    private func setupDefaultFonts() {
        print("🔤 Setting up default fonts...")
        
        // Configure UIFont appearance for UIKit components with fallbacks
        let defaultFont = UIFont.kanitRegular(size: 16)
        print("🔤 Default font: \(defaultFont.fontName)")
        
        // Set default font for various UI elements
        UILabel.appearance().font = defaultFont
        UITextField.appearance().font = defaultFont
        UITextView.appearance().font = defaultFont
        UIButton.appearance().titleLabel?.font = defaultFont
        
        // Set navigation bar title font
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.titleTextAttributes = [
            .font: UIFont.kanitMedium(size: 18),
            .foregroundColor: UIColor.black
        ]
        navBarAppearance.largeTitleTextAttributes = [
            .font: UIFont.kanitBold(size: 28),
            .foregroundColor: UIColor.black
        ]
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        
        print("✅ Default fonts setup complete")
    }
}
