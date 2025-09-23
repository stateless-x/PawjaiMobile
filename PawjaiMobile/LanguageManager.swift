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
        let region = Locale.current.regionCode?.uppercased()
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

    // MARK: - Backend sync (same priority rules as web)
    func syncWithBackend(accessToken: String) {
        let base = Configuration.webAppURL
        let profileURL = URL(string: "\(base)/api/users/profile")!

        var req = URLRequest(url: profileURL)
        req.httpMethod = "GET"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: req) { [weak self] data, response, _ in
            guard let self = self else { return }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200, let data = data else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success,
                   let payload = json["data"] as? [String: Any] {
                    if let backendPref = payload["preferredLanguage"] as? String,
                       let lang = AppLanguage(rawValue: backendPref) {
                        // Backend preference wins
                        DispatchQueue.main.async { self.setLanguage(lang) }
                    } else {
                        // Push local choice once
                        self.pushPreference(accessToken: accessToken, language: self.language)
                    }
                }
            } catch { /* ignore */ }
        }.resume()
    }

    private func pushPreference(accessToken: String, language: AppLanguage) {
        let base = Configuration.webAppURL
        guard let url = URL(string: "\(base)/api/users/profile") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["preferredLanguage": language.rawValue]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req).resume()
    }
}


