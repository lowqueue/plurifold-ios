import Combine
import Foundation
import Security

struct SignedInUser: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let email: String
}

/// Tokens stay in the device Keychain. Passwords are used for one request only.
@MainActor
final class NativeSession: ObservableObject {
    static let baseURL = URL(string: "https://www.plurifold.com")!

    @Published private(set) var user: SignedInUser?
    @Published private(set) var isRestoring = true
    @Published private(set) var isBusy = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var canRestoreSession = false

    /// Identifies one login, independently of the user ID and rotating access token.
    private(set) var sessionIdentity = UUID()

    private let transport: any NativeAuthTransporting
    private let storage: any NativeCredentialStoring
    private var configuration: AuthConfiguration?
    private var credentials: StoredSession?
    private var generation = 0
    private var refresh: (id: UUID, task: Task<StoredSession, Error>)?

    init(transport: (any NativeAuthTransporting)? = nil,
         storage: (any NativeCredentialStoring)? = nil) {
        self.transport = transport ?? CookieFreeAuthTransport()
        self.storage = storage ?? KeychainCredentialStore()
    }

    func restore() async {
        guard !isBusy, user == nil else { return }
        let operation = beginOperation(restoring: true)
        defer { finishOperation(operation) }
        do {
            if credentials == nil, let data = try storage.read() {
                do { credentials = try JSONDecoder().decode(StoredSession.self, from: data) }
                catch { throw NativeAuthError.expiredSession }
            }
            guard let saved = credentials else { return }
            canRestoreSession = true
            let config = try await loadConfiguration()
            try requireCurrent(operation)
            // Never send a saved token to a different project after configuration changes.
            guard saved.authOrigin == config.origin.absoluteString else {
                throw NativeAuthError.expiredSession
            }
            var current = try await usableSession(config: config, operation: operation)
            let verified: SignedInUser
            do {
                verified = try await fetchUser(token: current.accessToken, config: config)
            } catch let error as NativeAuthError where error.isSessionRejection {
                // The server may expire an access token before our local clock does.
                current = try await usableSession(config: config, operation: operation, force: true)
                verified = try await fetchUser(token: current.accessToken, config: config)
            }
            try requireCurrent(operation)
            guard verified.id == current.user.id else { throw NativeAuthError.expiredSession }
            current.user = verified
            try save(current)
            sessionIdentity = UUID()
            user = verified
            canRestoreSession = false
        } catch {
            guard operation == generation else { return }
            if (error as? NativeAuthError)?.isSessionRejection == true {
                clearCredentials()
                errorMessage = "Your sign-in has expired. Please sign in again."
            } else if !(error is CancellationError) {
                // Keep the refresh token on transient failures. A retry can restore it.
                errorMessage = message(for: error)
            }
        }
    }

    func signIn(email: String, password: String) async {
        guard !isBusy, user == nil else { return }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Enter your email address and password."
            return
        }
        let operation = beginOperation(restoring: false)
        defer { finishOperation(operation) }
        do {
            let config = try await loadConfiguration()
            try requireCurrent(operation)
            let response = try await tokenRequest(
                grant: "password", body: ["email": email, "password": password], config: config
            )
            try requireCurrent(operation)
            let current = try response.storedSession(origin: config.origin)
            try save(current)
            sessionIdentity = UUID()
            user = current.user
            canRestoreSession = false
        } catch {
            guard operation == generation, !(error is CancellationError) else { return }
            errorMessage = message(for: error)
        }
    }

    /// An API 401 can arrive before local expiry. Refresh once and verify with Auth.
    /// Network errors and 5xx responses retain the session for a later retry.
    func recoverUnauthorized() async throws {
        guard let signedInUser = user, !isRestoring, !isBusy else { throw NativeAuthError.expiredSession }
        let operation = generation
        let identity = sessionIdentity
        do {
            let config = try await loadConfiguration()
            try requireCurrent(operation)
            let current = try await usableSession(config: config, operation: operation, force: true)
            let verified = try await fetchUser(token: current.accessToken, config: config)
            try requireCurrent(operation)
            guard verified.id == signedInUser.id else { throw NativeAuthError.expiredSession }
            // Another caller may already have rotated again while /user was in flight.
            // Preserve the newest tokens rather than resaving our older local snapshot.
            if var latest = credentials {
                latest.user = verified
                try save(latest)
            }
            user = verified
            errorMessage = nil
        } catch {
            guard operation == generation, sessionIdentity == identity else { throw CancellationError() }
            if (error as? NativeAuthError)?.isSessionRejection == true {
                rejectUnauthorizedSession(expectedIdentity: identity)
            }
            throw error
        }
    }

    /// Called only after an authenticated API still returns 401 after recovery.
    /// A delayed response from an old login cannot sign out a newer login.
    func rejectUnauthorizedSession(expectedIdentity: UUID) {
        guard sessionIdentity == expectedIdentity else { return }
        generation += 1
        refresh?.task.cancel()
        refresh = nil
        clearCredentials()
        errorMessage = "Your sign-in has expired. Please sign in again."
    }

    func signOut() async {
        let previous = credentials
        let config = configuration
        let operation = beginOperation(restoring: false)
        clearCredentials()
        defer { finishOperation(operation) }
        // Local sign-out is immediate. Only revoke this device's session, not the website's.
        if let previous, let config, previous.authOrigin == config.origin.absoluteString {
            do {
                var request = authRequest(path: "logout", config: config, token: previous.accessToken)
                request.url = request.url?.appending(queryItems: [URLQueryItem(name: "scope", value: "local")])
                request.httpMethod = "POST"
                _ = try await send(request)
            } catch {
                // The Keychain entry is already removed even when the network is unavailable.
            }
        }
    }

    /// Call immediately before an authenticated Plurifold API request.
    /// The caller must restrict its request URL to the approved Plurifold API origin.
    func accessToken() async throws -> String {
        guard user != nil, !isRestoring, !isBusy else { throw NativeAuthError.expiredSession }
        let operation = generation
        do {
            let config = try await loadConfiguration()
            try requireCurrent(operation)
            let current = try await usableSession(config: config, operation: operation)
            try requireCurrent(operation)
            guard user?.id == current.user.id else { throw CancellationError() }
            return current.accessToken
        } catch {
            if operation == generation, (error as? NativeAuthError)?.isSessionRejection == true {
                generation += 1
                clearCredentials()
                errorMessage = "Your sign-in has expired. Please sign in again."
            }
            throw error
        }
    }

    private func beginOperation(restoring: Bool) -> Int {
        generation += 1
        refresh?.task.cancel()
        refresh = nil
        isBusy = true
        isRestoring = restoring
        errorMessage = nil
        return generation
    }

    private func finishOperation(_ operation: Int) {
        guard operation == generation else { return }
        isBusy = false
        isRestoring = false
    }

    private func requireCurrent(_ operation: Int) throws {
        try Task.checkCancellation()
        guard operation == generation else { throw CancellationError() }
    }

    private func save(_ current: StoredSession) throws {
        try storage.write(JSONEncoder().encode(current))
        credentials = current
    }

    private func clearCredentials() {
        sessionIdentity = UUID()
        user = nil
        credentials = nil
        canRestoreSession = false
        do { try storage.delete() }
        catch { errorMessage = "This device could not remove the saved sign-in. Unlock your phone and try signing out again." }
    }

    private func usableSession(config: AuthConfiguration, operation: Int, force: Bool = false) async throws -> StoredSession {
        try requireCurrent(operation)
        guard let saved = credentials, saved.authOrigin == config.origin.absoluteString else {
            throw NativeAuthError.expiredSession
        }
        if !force, saved.expiresAt.timeIntervalSinceNow > 60 { return saved }
        // All callers share one refresh. Supabase rotates refresh tokens after use.
        if let refresh { return try await refresh.task.value }
        let id = UUID()
        let task = Task { @MainActor [weak self] () async throws -> StoredSession in
            guard let self else { throw CancellationError() }
            let response = try await self.tokenRequest(
                grant: "refresh_token", body: ["refresh_token": saved.refreshToken], config: config
            )
            try self.requireCurrent(operation)
            let renewed = try response.storedSession(origin: config.origin)
            guard renewed.user.id == saved.user.id else { throw NativeAuthError.expiredSession }
            // Persist the rotated token before any waiter can start another refresh.
            try self.save(renewed)
            return renewed
        }
        refresh = (id, task)
        defer { if refresh?.id == id { refresh = nil } }
        return try await task.value
    }

    private func loadConfiguration() async throws -> AuthConfiguration {
        if let configuration { return configuration }
        let request = URLRequest(url: Self.baseURL.appendingPathComponent("api/mobile/config"))
        let data: Data
        do { data = try await send(request) }
        catch is CancellationError { throw CancellationError() }
        catch { throw NativeAuthError.configurationUnavailable }
        let envelope: MobileConfiguration
        do { envelope = try JSONDecoder().decode(MobileConfiguration.self, from: data) }
        catch { throw NativeAuthError.configurationUnavailable }
        let config = try AuthConfiguration(url: envelope.supabase.url, key: envelope.supabase.publishableKey)
        configuration = config
        return config
    }

    private func tokenRequest(grant: String, body: [String: String], config: AuthConfiguration) async throws -> TokenResponse {
        var request = authRequest(path: "token", config: config)
        request.url = request.url?.appending(queryItems: [URLQueryItem(name: "grant_type", value: grant)])
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)
        let data = try await send(request)
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func fetchUser(token: String, config: AuthConfiguration) async throws -> SignedInUser {
        let data = try await send(authRequest(path: "user", config: config, token: token))
        return try JSONDecoder().decode(SignedInUser.self, from: data)
    }

    private func authRequest(path: String, config: AuthConfiguration, token: String? = nil) -> URLRequest {
        var request = URLRequest(url: config.origin.appendingPathComponent("auth/v1/\(path)"))
        request.setValue(config.key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await transport.send(request)
        guard response.url == request.url, data.count <= 1_048_576 else { throw NativeAuthError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else {
            let detail = try? JSONDecoder().decode(AuthFailure.self, from: data)
            throw NativeAuthError.rejected(status: response.statusCode, code: detail?.error_code ?? detail?.error)
        }
        return data
    }

    private func message(for error: Error) -> String {
        if let error = error as? NativeAuthError { return error.localizedDescription }
        if error is KeychainCredentialStore.Failure { return "Your phone could not securely save this sign-in. Unlock your phone and try again." }
        if error is URLError { return "Could not reach Plurifold. Check your connection and try again." }
        return "Sign-in could not be completed. Please try again."
    }
}

private struct MobileConfiguration: Decodable {
    struct Supabase: Decodable { let url: String; let publishableKey: String }
    let supabase: Supabase
}

private struct AuthConfiguration {
    let origin: URL
    let key: String

    init(url: String, key: String) throws {
        guard let origin = URL(string: url), origin.scheme == "https",
              let host = origin.host, host.range(of: "^[a-z0-9-]+\\.supabase\\.co$", options: .regularExpression) != nil,
              origin.port == nil || origin.port == 443,
              origin.user == nil, origin.password == nil, origin.query == nil, origin.fragment == nil,
              origin.path.isEmpty || origin.path == "/", Self.isPublicKey(key) else {
            throw NativeAuthError.configurationUnavailable
        }
        self.origin = origin
        self.key = key
    }

    private static func isPublicKey(_ key: String) -> Bool {
        if key.hasPrefix("sb_publishable_"), key.count > 20 { return true }
        // Compatibility with the website's older anon JWT. Service-role keys are refused.
        let pieces = key.split(separator: ".")
        guard pieces.count == 3 else { return false }
        var payload = String(pieces[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return object["role"] as? String == "anon"
    }
}

private struct StoredSession: Codable {
    let authOrigin: String
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    var user: SignedInUser
}

private struct TokenResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_in: Double
    let expires_at: Double?
    let user: SignedInUser

    func storedSession(origin: URL) throws -> StoredSession {
        guard !access_token.isEmpty, !refresh_token.isEmpty, expires_in > 0,
              !user.id.isEmpty, !user.email.isEmpty else { throw NativeAuthError.invalidResponse }
        let expiresAt = expires_at.map(Date.init(timeIntervalSince1970:)) ?? Date().addingTimeInterval(expires_in)
        return StoredSession(authOrigin: origin.absoluteString, accessToken: access_token,
                             refreshToken: refresh_token, expiresAt: expiresAt, user: user)
    }
}

private struct AuthFailure: Decodable { let error_code: String?; let error: String? }

enum NativeAuthError: LocalizedError {
    case configurationUnavailable, invalidResponse, expiredSession
    case rejected(status: Int, code: String?)

    var isSessionRejection: Bool {
        switch self {
        case .expiredSession: return true
        case let .rejected(status, code):
            return status == 401 || status == 403 ||
                (status == 400 && (code?.hasPrefix("refresh_token") == true ||
                    ["invalid_grant", "session_not_found", "session_expired", "user_not_found", "user_banned", "bad_jwt"].contains(code ?? "")))
        default: return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .configurationUnavailable: return "Account sign-in is temporarily unavailable. Please try again shortly."
        case .invalidResponse: return "Plurifold returned an unexpected response. Please try again."
        case .expiredSession: return "Please sign in to your Plurifold account."
        case let .rejected(status, code):
            if status == 429 { return "Too many attempts. Wait a moment before trying again." }
            if code == "email_not_confirmed" { return "Confirm your email using the link from Plurifold, then sign in." }
            if code == "captcha_failed" { return "Your account requires a security check. Please visit Plurifold on the web for help." }
            if code == "invalid_credentials" { return "That email and password did not match. Please try again." }
            if status >= 500 { return "Account sign-in is temporarily unavailable. Please try again shortly." }
            return "Could not sign in. Check your details or reset your password on the website."
        }
    }
}

@MainActor
protocol NativeAuthTransporting {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

@MainActor
private final class CookieFreeAuthTransport: NativeAuthTransporting {
    private let session: URLSession
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 45
        session = URLSession(configuration: config, delegate: RefuseAuthRedirects(), delegateQueue: nil)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard request.url?.scheme == "https" else { throw NativeAuthError.invalidResponse }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw NativeAuthError.invalidResponse }
        return (data, response)
    }
}

private final class RefuseAuthRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor
protocol NativeCredentialStoring {
    func read() throws -> Data?
    func write(_ data: Data) throws
    func delete() throws
}

@MainActor
private struct KeychainCredentialStore: NativeCredentialStoring {
    struct Failure: Error { let status: OSStatus }
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.plurifold.ios.account",
         kSecAttrAccount as String: "supabase-session"]
    }

    func read() throws -> Data? {
        var query = self.query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw Failure(status: status) }
        return data
    }

    func write(_ data: Data) throws {
        let values: [String: Any] = [kSecValueData as String: data,
                                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let updated = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if updated == errSecItemNotFound {
            let status = SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil)
            guard status == errSecSuccess else { throw Failure(status: status) }
        } else if updated != errSecSuccess { throw Failure(status: updated) }
    }

    func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure(status: status) }
    }
}
