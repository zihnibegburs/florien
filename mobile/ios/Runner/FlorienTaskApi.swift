import Foundation

private enum FlorienL10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "")
    }
}

enum FlorienTaskApiError: Error, LocalizedError {
    case notAuthenticated
    case invalidConfiguration
    case networkError(String)
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return FlorienL10n.string("api.error.not_authenticated")
        case .invalidConfiguration:
            return FlorienL10n.string("api.error.invalid_configuration")
        case .networkError(let message):
            return String(format: FlorienL10n.string("api.error.network"), message)
        case .serverError:
            return FlorienL10n.string("intent.add_task.error.retry")
        }
    }
}

enum FlorienTaskApi {
    static func createTask(title: String) async throws {
        guard let token = FlorienSharedStorage.authToken else {
            throw FlorienTaskApiError.notAuthenticated
        }
        guard let baseUrl = FlorienSharedStorage.apiBaseUrl,
              let url = URL(string: "\(baseUrl)/tasks") else {
            throw FlorienTaskApiError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "title": title,
            "color": "#4F52B2",
            "icon": "task",
            "durationMinutes": 30,
            "isInbox": false,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FlorienTaskApiError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FlorienTaskApiError.networkError(FlorienL10n.string("api.error.invalid_response"))
        }

        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw FlorienTaskApiError.notAuthenticated
        default:
            throw FlorienTaskApiError.serverError(http.statusCode)
        }
    }
}
