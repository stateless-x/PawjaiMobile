import SwiftUI
import UIKit

// MARK: - Font Manager
class FontManager {
    static let shared = FontManager()

    private init() {}

    // MARK: - Font Registration
    func registerFonts() {
        // Register all custom fonts directly
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
        // Skip if font is already available
        guard UIFont(name: fontFamily, size: 16) == nil else { return }

        // Get font URL from bundle
        let fontName = fileName.replacingOccurrences(of: ".ttf", with: "")
        guard let fontURL = Bundle.main.url(forResource: fontName, withExtension: "ttf") else {
            return
        }

        // Register font using appropriate API
        var error: Unmanaged<CFError>?
        if #available(iOS 18.0, *) {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
        } else {
            guard let fontData = NSData(contentsOf: fontURL),
                  let provider = CGDataProvider(data: fontData),
                  let font = CGFont(provider) else {
                return
            }
            CTFontManagerRegisterGraphicsFont(font, &error)
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
                return Font.custom(firstKanit, size: size)
            } else {
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
                return Font.custom(firstKanit, size: size)
            } else {
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
                return Font.custom(firstKanit, size: size)
            } else {
                return Font.system(size: size, weight: .bold)
            }
        }
    }
    
    // MARK: - Noto Sans Thai Fonts
    static func notoSansThaiLight(size: CGFloat) -> Font {
        if UIFont(name: "NotoSansThai-Light", size: size) != nil {
            return Font.custom("NotoSansThai-Light", size: size)
        } else {
            return Font.system(size: size, weight: .light)
        }
    }
    
    static func notoSansThaiRegular(size: CGFloat) -> Font {
        if UIFont(name: "NotoSansThai-Regular", size: size) != nil {
            return Font.custom("NotoSansThai-Regular", size: size)
        } else {
            return Font.system(size: size)
        }
    }
    
    static func notoSansThaiMedium(size: CGFloat) -> Font {
        if UIFont(name: "NotoSansThai-Medium", size: size) != nil {
            return Font.custom("NotoSansThai-Medium", size: size)
        } else {
            return Font.system(size: size, weight: .medium)
        }
    }
    
    static func notoSansThaiBold(size: CGFloat) -> Font {
        if UIFont(name: "NotoSansThai-Bold", size: size) != nil {
            return Font.custom("NotoSansThai-Bold", size: size)
        } else {
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
