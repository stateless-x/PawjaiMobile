import SwiftUI
import UIKit

// MARK: - Font Manager
class FontManager {
    static let shared = FontManager()
    
    private init() {}
    
    // MARK: - Font Registration
    func registerFonts() {
        registerKanitFonts()
        registerNotoSansThaiFonts()
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
        // Try to find the font file in the bundle
        let fontName = fileName.replacingOccurrences(of: ".ttf", with: "")
        
        // First, try to load the font directly by name (if it's already in the bundle)
        if UIFont(name: fontFamily, size: 16) != nil {
            print("✅ Font already available: \(fontFamily)")
            return
        }
        
        // If not found, try to register it manually
        guard let fontURL = Bundle.main.url(forResource: fontName, withExtension: "ttf") else {
            print("❌ Font file not found: \(fileName)")
            return
        }
        
        guard let fontData = NSData(contentsOf: fontURL) else {
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
        
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterGraphicsFont(font, &error) {
            if let error = error {
                let errorDescription = CFErrorCopyDescription(error.takeRetainedValue())
                print("❌ Failed to register font \(fileName): \(errorDescription ?? "Unknown error" as CFString)")
            }
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
            print("⚠️ Kanit-Regular font not found, using system font")
            return Font.system(size: size)
        }
    }
    
    static func kanitMedium(size: CGFloat) -> Font {
        if UIFont(name: "Kanit-Medium", size: size) != nil {
            return Font.custom("Kanit-Medium", size: size)
        } else {
            print("⚠️ Kanit-Medium font not found, using system font")
            return Font.system(size: size, weight: .medium)
        }
    }
    
    static func kanitBold(size: CGFloat) -> Font {
        if UIFont(name: "Kanit-Bold", size: size) != nil {
            return Font.custom("Kanit-Bold", size: size)
        } else {
            print("⚠️ Kanit-Bold font not found, using system font")
            return Font.system(size: size, weight: .bold)
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
