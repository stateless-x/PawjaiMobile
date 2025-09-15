import SwiftUI
import UIKit

// MARK: - Font Manager
class FontManager {
    static let shared = FontManager()
    
    private init() {}
    
    // MARK: - Font Registration
    func registerFonts() {
        print("🔤 Starting font registration...")
        
        // First, check what fonts are available in the bundle
        checkAvailableFonts()
        
        // Try to use fonts without explicit registration first
        if tryUsingFontsWithoutRegistration() {
            print("✅ Fonts are available without explicit registration")
        } else {
            print("🔤 Fonts not available, attempting registration...")
            registerKanitFonts()
            registerNotoSansThaiFonts()
        }
        
        print("🔤 Font registration completed")
    }
    
    private func tryUsingFontsWithoutRegistration() -> Bool {
        let testFonts = ["Kanit-Regular", "Kanit-Medium", "Kanit-Bold", "NotoSansThai-Regular"]
        var availableCount = 0
        
        for fontName in testFonts {
            if UIFont(name: fontName, size: 16) != nil {
                availableCount += 1
                print("✅ Font available without registration: \(fontName)")
            }
        }
        
        return availableCount > 0
    }
    
    private func checkAvailableFonts() {
        print("🔤 Checking available fonts in bundle...")
        
        // Check for .ttf files
        if let ttfFiles = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) {
            print("🔤 Found \(ttfFiles.count) .ttf files in bundle:")
            for file in ttfFiles {
                print("  - \(file.lastPathComponent)")
            }
        } else {
            print("❌ No .ttf files found in bundle")
        }
        
        // Check for .otf files
        if let otfFiles = Bundle.main.urls(forResourcesWithExtension: "otf", subdirectory: nil) {
            print("🔤 Found \(otfFiles.count) .otf files in bundle:")
            for file in otfFiles {
                print("  - \(file.lastPathComponent)")
            }
        }
        
        // Check system fonts
        let systemFonts = UIFont.familyNames.filter { $0.contains("Kanit") || $0.contains("Noto") }
        if !systemFonts.isEmpty {
            print("🔤 System fonts containing Kanit/Noto: \(systemFonts)")
        }
        
        // Test specific font names
        let testFonts = ["Kanit-Regular", "Kanit-Medium", "Kanit-Bold", "NotoSansThai-Regular"]
        print("🔤 Testing specific font names:")
        for fontName in testFonts {
            if UIFont(name: fontName, size: 16) != nil {
                print("  ✅ \(fontName) - Available")
            } else {
                print("  ❌ \(fontName) - Not available")
            }
        }
    }
    
    private func registerKanitFonts() {
        let kanitFonts = [
            "Kanit-Regular.ttf": "Kanit-Regular",
            "Kanit-Medium.ttf": "Kanit-Medium", 
            "Kanit-Bold.ttf": "Kanit-Bold"
        ]
        
        for (fileName, fontFamily) in kanitFonts {
            registerFont(fileName: fileName, fontFamily: fontFamily)
        }
    }
    
    private func registerNotoSansThaiFonts() {
        let notoSansThaiFonts = [
            "NotoSansThai-Light.ttf": "NotoSansThai-Light",
            "NotoSansThai-Regular.ttf": "NotoSansThai-Regular",
            "NotoSansThai-Medium.ttf": "NotoSansThai-Medium",
            "NotoSansThai-Bold.ttf": "NotoSansThai-Bold"
        ]
        
        for (fileName, fontFamily) in notoSansThaiFonts {
            registerFont(fileName: fileName, fontFamily: fontFamily)
        }
    }
    
    private func registerFont(fileName: String, fontFamily: String) {
        print("🔤 Attempting to register font: \(fileName) -> \(fontFamily)")
        
        // First, try to load the font directly by name (if it's already in the bundle)
        if UIFont(name: fontFamily, size: 16) != nil {
            print("✅ Font already available: \(fontFamily)")
            return
        }
        
        // Try alternative font names first (sometimes the font is available with a different name)
        let alternativeNames = [
            fontFamily,
            fontFamily.replacingOccurrences(of: "-", with: " "),
            fontFamily.replacingOccurrences(of: "-", with: ""),
            fontFamily.lowercased(),
            fontFamily.uppercased()
        ]
        
        for altName in alternativeNames {
            if UIFont(name: altName, size: 16) != nil {
                print("✅ Font available with alternative name: \(altName)")
                return
            }
        }
        
        // If not found, try to register it manually
        let fontName = fileName.replacingOccurrences(of: ".ttf", with: "")
        
        // Try different possible paths for the font file
        var fontURL: URL?
        
        // Try direct path first
        if let directURL = Bundle.main.url(forResource: fontName, withExtension: "ttf") {
            fontURL = directURL
            print("🔤 Found font at direct path: \(directURL)")
        }
        // Try with Fonts/ prefix
        else if let fontsURL = Bundle.main.url(forResource: "Fonts/\(fontName)", withExtension: "ttf") {
            fontURL = fontsURL
            print("🔤 Found font at Fonts/ path: \(fontsURL)")
        }
        // Try with full path
        else if let fullURL = Bundle.main.url(forResource: "Fonts/\(fontName)", withExtension: "ttf", subdirectory: nil) {
            fontURL = fullURL
            print("🔤 Found font at full Fonts/ path: \(fullURL)")
        }
        
        guard let foundFontURL = fontURL else {
            print("❌ Font file not found: \(fileName) - tried multiple paths")
            // List all available font files in bundle for debugging
            if let fontFiles = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) {
                print("🔤 Available .ttf files in bundle:")
                for file in fontFiles {
                    print("  - \(file.lastPathComponent)")
                }
            }
            return
        }
        
        // Try multiple registration approaches
        var registrationSuccess = false
        
        // Approach 1: Try iOS 18+ API first
        if #available(iOS 18.0, *) {
            var error: Unmanaged<CFError>?
            let success = CTFontManagerRegisterFontsForURL(foundFontURL as CFURL, .user, &error)
            if success {
                print("✅ Font registered successfully with iOS 18+ API: \(fontFamily)")
                registrationSuccess = true
            } else {
                if let error = error {
                    let errorDescription = CFErrorCopyDescription(error.takeRetainedValue())
                    print("❌ iOS 18+ API failed: \(errorDescription ?? "Unknown error" as CFString)")
                }
            }
        }
        
        // Approach 2: Try older API if iOS 18+ failed or not available
        if !registrationSuccess {
            guard let fontData = NSData(contentsOf: foundFontURL) else {
                print("❌ Could not load font data: \(fileName)")
                return
            }
            
            guard let provider = CGDataProvider(data: fontData) else {
                print("❌ Could not create data provider: \(fileName)")
                return
            }
            
            guard let font = CGFont(provider) else {
                print("❌ Could not create font: \(fileName)")
                return
            }
            
            // Use the older API only for iOS < 18
            if #available(iOS 18.0, *) {
                print("🔤 Skipping deprecated API for iOS 18+")
            } else {
                var error: Unmanaged<CFError>?
                let success = CTFontManagerRegisterGraphicsFont(font, &error)
                if success {
                    print("✅ Font registered successfully with older API: \(fontFamily)")
                    registrationSuccess = true
                } else {
                    if let error = error {
                        let errorDescription = CFErrorCopyDescription(error.takeRetainedValue())
                        print("❌ Older API failed: \(errorDescription ?? "Unknown error" as CFString)")
                    }
                }
            }
        }
        
        // Approach 3: Try alternative registration method
        if !registrationSuccess {
            print("🔤 Trying alternative registration method...")
            // Try registering with different scope
            if #available(iOS 18.0, *) {
                var error: Unmanaged<CFError>?
                // Use .process scope instead of .session (which is unavailable)
                let success = CTFontManagerRegisterFontsForURL(foundFontURL as CFURL, .process, &error)
                if success {
                    print("✅ Font registered successfully with process scope: \(fontFamily)")
                    registrationSuccess = true
                } else {
                    if let error = error {
                        let errorDescription = CFErrorCopyDescription(error.takeRetainedValue())
                        print("❌ Process scope failed: \(errorDescription ?? "Unknown error" as CFString)")
                    }
                }
            }
        }
        
        // Verify the font is now available
        if registrationSuccess {
            // Give the system a moment to register the font
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if UIFont(name: fontFamily, size: 16) != nil {
                    print("✅ Font verification successful: \(fontFamily)")
                } else {
                    print("⚠️ Font registered but not available: \(fontFamily)")
                    // Try alternative font names
                    self.tryAlternativeFontNames(for: fontFamily)
                }
            }
        } else {
            print("❌ All registration methods failed for: \(fontFamily)")
        }
    }
    
    private func tryAlternativeFontNames(for fontFamily: String) {
        print("🔤 Trying alternative font names for: \(fontFamily)")
        
        // Common alternative naming patterns
        let alternatives = [
            fontFamily,
            fontFamily.replacingOccurrences(of: "-", with: " "),
            fontFamily.replacingOccurrences(of: "-", with: ""),
            fontFamily.lowercased(),
            fontFamily.uppercased()
        ]
        
        for alternative in alternatives {
            if UIFont(name: alternative, size: 16) != nil {
                print("✅ Found alternative font name: \(alternative)")
                return
            }
        }
        
        // Check all available font families
        let allFonts = UIFont.familyNames.sorted()
        let matchingFonts = allFonts.filter { $0.contains(fontFamily.components(separatedBy: "-").first ?? "") }
        
        if !matchingFonts.isEmpty {
            print("🔤 Found similar font families: \(matchingFonts)")
        } else {
            print("❌ No similar fonts found for: \(fontFamily)")
        }
    }
}

// MARK: - Font Extensions
extension Font {
    // MARK: - Kanit Fonts
    static func kanitRegular(size: CGFloat) -> Font {
        if UIFont(name: "Kanit-Regular", size: size) != nil {
            return Font.custom("Kanit-Regular", size: size)
        } else {
            // Try to find any Kanit font
            let availableKanitFonts = UIFont.familyNames.filter { $0.contains("Kanit") }
            if let firstKanit = availableKanitFonts.first {
                print("⚠️ Kanit-Regular not found, using \(firstKanit)")
                return Font.custom(firstKanit, size: size)
            } else {
                print("⚠️ No Kanit fonts found, using system font")
                return Font.system(size: size)
            }
        }
    }
    
    static func kanitMedium(size: CGFloat) -> Font {
        if UIFont(name: "Kanit-Medium", size: size) != nil {
            return Font.custom("Kanit-Medium", size: size)
        } else {
            // Try to find any Kanit font
            let availableKanitFonts = UIFont.familyNames.filter { $0.contains("Kanit") }
            if let firstKanit = availableKanitFonts.first {
                print("⚠️ Kanit-Medium not found, using \(firstKanit)")
                return Font.custom(firstKanit, size: size)
            } else {
                print("⚠️ No Kanit fonts found, using system font")
                return Font.system(size: size, weight: .medium)
            }
        }
    }
    
    static func kanitBold(size: CGFloat) -> Font {
        if UIFont(name: "Kanit-Bold", size: size) != nil {
            return Font.custom("Kanit-Bold", size: size)
        } else {
            // Try to find any Kanit font
            let availableKanitFonts = UIFont.familyNames.filter { $0.contains("Kanit") }
            if let firstKanit = availableKanitFonts.first {
                print("⚠️ Kanit-Bold not found, using \(firstKanit)")
                return Font.custom(firstKanit, size: size)
            } else {
                print("⚠️ No Kanit fonts found, using system font")
                return Font.system(size: size, weight: .bold)
            }
        }
    }
    
    // MARK: - Noto Sans Thai Fonts
    static func notoSansThaiLight(size: CGFloat) -> Font {
        if UIFont(name: "NotoSansThai-Light", size: size) != nil {
            return Font.custom("NotoSansThai-Light", size: size)
        } else {
            print("⚠️ NotoSansThai-Light font not found, using system font")
            return Font.system(size: size, weight: .light)
        }
    }
    
    static func notoSansThaiRegular(size: CGFloat) -> Font {
        if UIFont(name: "NotoSansThai-Regular", size: size) != nil {
            return Font.custom("NotoSansThai-Regular", size: size)
        } else {
            print("⚠️ NotoSansThai-Regular font not found, using system font")
            return Font.system(size: size)
        }
    }
    
    static func notoSansThaiMedium(size: CGFloat) -> Font {
        if UIFont(name: "NotoSansThai-Medium", size: size) != nil {
            return Font.custom("NotoSansThai-Medium", size: size)
        } else {
            print("⚠️ NotoSansThai-Medium font not found, using system font")
            return Font.system(size: size, weight: .medium)
        }
    }
    
    static func notoSansThaiBold(size: CGFloat) -> Font {
        if UIFont(name: "NotoSansThai-Bold", size: size) != nil {
            return Font.custom("NotoSansThai-Bold", size: size)
        } else {
            print("⚠️ NotoSansThai-Bold font not found, using system font")
            return Font.system(size: size, weight: .bold)
        }
    }
}

// MARK: - UIFont Extensions
extension UIFont {
    // MARK: - Kanit Fonts
    static func kanitRegular(size: CGFloat) -> UIFont {
        return UIFont(name: "Kanit-Regular", size: size) ?? UIFont.systemFont(ofSize: size)
    }
    
    static func kanitMedium(size: CGFloat) -> UIFont {
        return UIFont(name: "Kanit-Medium", size: size) ?? UIFont.systemFont(ofSize: size, weight: .medium)
    }
    
    static func kanitBold(size: CGFloat) -> UIFont {
        return UIFont(name: "Kanit-Bold", size: size) ?? UIFont.systemFont(ofSize: size, weight: .bold)
    }
    
    // MARK: - Noto Sans Thai Fonts
    static func notoSansThaiLight(size: CGFloat) -> UIFont {
        return UIFont(name: "NotoSansThai-Light", size: size) ?? UIFont.systemFont(ofSize: size, weight: .light)
    }
    
    static func notoSansThaiRegular(size: CGFloat) -> UIFont {
        return UIFont(name: "NotoSansThai-Regular", size: size) ?? UIFont.systemFont(ofSize: size)
    }
    
    static func notoSansThaiMedium(size: CGFloat) -> UIFont {
        return UIFont(name: "NotoSansThai-Medium", size: size) ?? UIFont.systemFont(ofSize: size, weight: .medium)
    }
    
    static func notoSansThaiBold(size: CGFloat) -> UIFont {
        return UIFont(name: "NotoSansThai-Bold", size: size) ?? UIFont.systemFont(ofSize: size, weight: .bold)
    }
}

// MARK: - Font Weight Helper
extension Font.Weight {
    static func kanitWeight(_ weight: Font.Weight) -> Font.Weight {
        switch weight {
        case .light, .ultraLight, .thin:
            return .regular
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold, .bold, .heavy, .black:
            return .bold
        default:
            return .regular
        }
    }
    
    static func notoSansThaiWeight(_ weight: Font.Weight) -> Font.Weight {
        switch weight {
        case .light, .ultraLight, .thin:
            return .light
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold, .bold, .heavy, .black:
            return .bold
        default:
            return .regular
        }
    }
}
