import Foundation

enum FlorienSharedStorage {
    static let appGroupId = "group.com.florien.app"
    static let authTokenKey = "auth_token"
    static let apiBaseUrlKey = "api_base_url"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    static var authToken: String? {
        guard let token = defaults?.string(forKey: authTokenKey), !token.isEmpty else {
            return nil
        }
        return token
    }

    static var apiBaseUrl: String? {
        guard let url = defaults?.string(forKey: apiBaseUrlKey), !url.isEmpty else {
            return nil
        }
        return url
    }
}
