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
        print("🔄 Force refreshing external domains...")
        fetchDomains()
    }

    func fetchDomains() {
        // Get API URL from environment or use default
        let apiBaseURL = ProcessInfo.processInfo.environment["API_URL"] ?? "https://pawjai-be-production.up.railway.app"
        let apiURL = "\(apiBaseURL)/api/external-domains"

        guard let url = URL(string: apiURL) else {
            print("❌ Invalid API URL:", apiURL)
            return
        }

        print("🌐 Fetching external domains from:", apiURL)

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 HTTP Status:", httpResponse.statusCode)
            }

            guard let data = data, error == nil else {
                print("❌ Failed to fetch external domains:", error?.localizedDescription ?? "Unknown error")
                return
            }

            // Print raw response for debugging
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("📄 Raw API response:", rawResponse)
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📦 JSON parsed:", json)

                    if let dataObj = json["data"] as? [String: Any] {
                        print("📦 Data object:", dataObj)

                        if let fetchedDomains = dataObj["domains"] as? [String] {
                            DispatchQueue.main.async {
                                self.domains = fetchedDomains
                                self.cacheDomains(fetchedDomains)
                                print("✅ Fetched", fetchedDomains.count, "external domains:", fetchedDomains)
                            }
                        } else {
                            print("❌ 'domains' key not found or not a string array in data object")
                        }
                    } else {
                        print("❌ 'data' key not found or not a dictionary")
                    }
                } else {
                    print("❌ Response is not a JSON dictionary")
                }
            } catch {
                print("❌ Failed to parse external domains:", error.localizedDescription)
            }
        }.resume()
    }

    private func cacheDomains(_ domains: [String]) {
        UserDefaults.standard.set(domains, forKey: cacheKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheExpiryKey)
        print("💾 Cached", domains.count, "domains")
    }

    private func loadCachedDomains() {
        guard let cachedDomains = UserDefaults.standard.array(forKey: cacheKey) as? [String],
              let cacheTime = UserDefaults.standard.object(forKey: cacheExpiryKey) as? TimeInterval else {
            print("📦 No cached domains found")
            return
        }

        // Check if cache is still valid
        let now = Date().timeIntervalSince1970
        if now - cacheTime < cacheExpiryDuration {
            self.domains = cachedDomains
            print("✅ Loaded", cachedDomains.count, "cached domains:", cachedDomains)
        } else {
            print("⏰ Cache expired, will fetch fresh data")
        }
    }

    /// Check if a URL host contains any of the external domains
    func shouldOpenInSafari(host: String?) -> Bool {
        guard let host = host else { return false }
        return domains.contains(where: { host.contains($0) })
    }
}
