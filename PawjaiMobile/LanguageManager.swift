//
//  LanguageManager.swift
//  PawjaiMobile
//

import Foundation

enum AppLanguage: String, Codable {
    case th
    case en
}

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    private let storageKey = "pawjai.language"
    @Published var language: AppLanguage

    private init() {
        if let saved = UserDefaults.standard.string(forKey: storageKey),
           let lang = AppLanguage(rawValue: saved) {
            self.language = lang
            return
        }
        // Default by device region/language (TH => th, else en)
        let region: String?
        if #available(iOS 16, *) {
            region = Locale.current.region?.identifier.uppercased()
        } else {
            region = Locale.current.regionCode?.uppercased()
        }
        let prefersThai = Locale.preferredLanguages.contains(where: { $0.lowercased().hasPrefix("th") })
        if region == "TH" || prefersThai {
            self.language = .th
        } else {
            self.language = .en
        }
        UserDefaults.standard.set(self.language.rawValue, forKey: storageKey)
    }

    func setLanguage(_ lang: AppLanguage) {
        language = lang
        UserDefaults.standard.set(lang.rawValue, forKey: storageKey)
    }

    // Lightweight translator for key pairs (Thai default, English alt)
    func t(_ th: String, _ en: String) -> String {
        switch language {
        case .th: return th
        case .en: return en
        }
    }
}


