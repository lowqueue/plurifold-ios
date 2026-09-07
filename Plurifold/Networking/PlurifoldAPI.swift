import Foundation

/// The app only sends its account token to Plurifold's authenticated API.
@MainActor
final class PlurifoldAPI {
    private let account: NativeSession
    private let expectedUserID: String?
    private let expectedSessionIdentity: UUID
    private let transport: URLSession
    private let redirectPolicy = PlurifoldRedirectPolicy()
    private let origin = URL(string: "https://www.plurifold.com")!

    init(session: NativeSession) {
        account = session
        expectedUserID = session.user?.id
        expectedSessionIdentity = session.sessionIdentity
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120
        transport = URLSession(configuration: configuration, delegate: redirectPolicy, delegateQueue: nil)
    }

    deinit { transport.invalidateAndCancel() }

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await send(path, method: "GET", body: nil)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await send(path, method: "POST", body: JSONEncoder().encode(body))
    }

    private func send<T: Decodable>(_ path: String, method: String, body: Data?) async throws -> T {
        guard path.hasPrefix("/"), !path.hasPrefix("//"),
              let url = URL(string: path, relativeTo: origin)?.absoluteURL,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "https", components.host == "www.plurifold.com",
              components.port == nil || components.port == 443,
              components.user == nil, components.password == nil, components.fragment == nil,
              components.path.hasPrefix("/api/mobile/") || components.path == "/api/define" || components.path == "/api/ask"
        else { throw PlurifoldAPIError.invalidAddress }

        var rateLimitRetries = 0
        var didRecoverAuthentication = false
        while true {
            try requireCurrentSession()
            let token = try await account.accessToken()
            try requireCurrentSession()
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.httpBody = body
            request.httpShouldHandleCookies = false
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await transport.data(for: request)
            } catch let error as URLError {
                try requireCurrentSession()
                if error.code == .cancelled { throw CancellationError() }
                if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                    throw PlurifoldAPIError.connection("You’re offline. Reconnect and try again.")
                }
                if error.code == .timedOut {
                    throw PlurifoldAPIError.connection("Plurifold took too long to respond. Please try again.")
                }
                throw PlurifoldAPIError.connection("Couldn’t connect to Plurifold. Please try again.")
            }
            try requireCurrentSession()
            guard let http = response as? HTTPURLResponse else { throw PlurifoldAPIError.invalidResponse }
            if http.statusCode == 401 {
                if didRecoverAuthentication {
                    account.rejectUnauthorizedSession(expectedIdentity: expectedSessionIdentity)
                    throw PlurifoldAPIError.httpStatus(401, message: nil)
                }
                didRecoverAuthentication = true
                try await account.recoverUnauthorized()
                try requireCurrentSession()
                continue
            }
            if http.statusCode == 429, rateLimitRetries < 2 {
                rateLimitRetries += 1
                let seconds = min(5, max(1, Int(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 5))
                try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                try requireCurrentSession()
                continue
            }
            guard (200..<300).contains(http.statusCode) else {
                throw PlurifoldAPIError.httpStatus(http.statusCode, message: Self.serverMessage(data))
            }
            guard http.mimeType == "application/json" else { throw PlurifoldAPIError.invalidResponse }
            do { return try JSONDecoder().decode(T.self, from: data) }
            catch { throw PlurifoldAPIError.invalidResponse }
        }
    }

    private func requireCurrentSession() throws {
        try Task.checkCancellation()
        guard let expectedUserID, account.user?.id == expectedUserID,
              account.sessionIdentity == expectedSessionIdentity else { throw CancellationError() }
    }

    private static func serverMessage(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let nested = object["error"] as? [String: Any]
        let message = (object["message"] as? String)
            ?? (object["error"] as? String)
            ?? (nested?["message"] as? String)
        guard let message, !message.isEmpty, message.count <= 400,
              !message.contains("<html"), !message.contains("stack") else { return nil }
        return message
    }
}

private final class PlurifoldRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        // Never forward a bearer token across a redirect, including one to another host.
        completionHandler(nil)
    }
}

enum PlurifoldAPIError: LocalizedError {
    case invalidAddress
    case invalidResponse
    case connection(String)
    case httpStatus(Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "This Plurifold address isn’t supported. Please update the app."
        case .invalidResponse:
            return "Plurifold returned an unexpected response. Please try again or check for an app update."
        case .connection(let message):
            return message
        case .httpStatus(let status, let message):
            switch status {
            case 401: return "Your session has expired. Please sign in again."
            case 403: return "Your account doesn’t have access to this content."
            case 404: return "This content is no longer available. Refresh your library and try again."
            case 409: return "Your account changed on another device. Please refresh and try again."
            case 429: return "Plurifold is receiving requests too quickly. Please try again in a moment."
            case 500...599: return "Plurifold is temporarily unavailable. Please try again shortly."
            case 300...399: return "Plurifold’s address changed. Please update the app and try again."
            default: return message ?? "Plurifold couldn’t complete that request. Please try again."
            }
        }
    }
}
