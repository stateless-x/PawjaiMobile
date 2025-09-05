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
        FontManager.shared.registerFonts()
        setupDefaultFonts()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .font(.kanitRegular(size: 16)) 
        }
    }
    
    private func setupDefaultFonts() {
        // Configure UIFont appearance for UIKit components
        let defaultFont = UIFont.kanitRegular(size: 16)
        
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
    }
}
