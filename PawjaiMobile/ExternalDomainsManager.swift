import Foundation

class ExternalDomainsManager {
    static let shared = ExternalDomainsManager()

    private var domains: [String] = ["shopee.co.th", "shopee.com", "lazada.co.th", "amazon.com"]
    private let cacheKey = "external_domains_cache"
    private let cacheExpiryKey = "external_domains_cache_expiry"
    private let cacheExpiryDuration: TimeInterval = 3600 // 1 hour

    private init() {
        loadCachedDomains()
        fetchDomains()
    }

    func getDomains() -> [String] {
        return domains
    }

    /// Force refresh domains from API, bypassing cache
    func forceRefresh() {
        fetchDomains()
    }

    func fetchDomains() {
        // Get API URL from environment or use default
        let apiBaseURL = ProcessInfo.processInfo.environment["API_URL"] ?? "https://pawjai-be-production.up.railway.app"
        let apiURL = "\(apiBaseURL)/api/external-domains"

        guard let url = URL(string: apiURL) else {
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataObj = json["data"] as? [String: Any],
                   let fetchedDomains = dataObj["domains"] as? [String] {
                    DispatchQueue.main.async {
                        self.domains = fetchedDomains
                        self.cacheDomains(fetchedDomains)
                    }
                }
            } catch {
                // Silent failure - use fallback domains
            }
        }.resume()
    }

    private func cacheDomains(_ domains: [String]) {
        UserDefaults.standard.set(domains, forKey: cacheKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheExpiryKey)
    }

    private func loadCachedDomains() {
        guard let cachedDomains = UserDefaults.standard.array(forKey: cacheKey) as? [String],
              let cacheTime = UserDefaults.standard.object(forKey: cacheExpiryKey) as? TimeInterval else {
            return
        }

        // Check if cache is still valid
        let now = Date().timeIntervalSince1970
        if now - cacheTime < cacheExpiryDuration {
            self.domains = cachedDomains
        }
    }

    /// Check if a URL host contains any of the external domains
    func shouldOpenInSafari(host: String?) -> Bool {
        guard let host = host else { return false }
        return domains.contains(where: { host.contains($0) })
    }
}
