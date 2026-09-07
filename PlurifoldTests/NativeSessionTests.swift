import Foundation
import XCTest
@testable import Plurifold

@MainActor
final class NativeSessionTests: XCTestCase {
    func testSavedSignInIsVerifiedAndSurvivesTemporaryConnectionFailure() async {
        let storage = MemoryCredentials()
        let transport = StubAuthTransport()
        let first = NativeSession(transport: transport, storage: storage)
        await first.signIn(email: "reader@example.com", password: "never-store-this-password")
        XCTAssertEqual(first.user?.id, "reader-1")
        XCTAssertFalse(String(data: storage.data ?? Data(), encoding: .utf8)?.contains("never-store-this-password") ?? true)

        let restored = NativeSession(transport: transport, storage: storage)
        transport.userIsOffline = true
        await restored.restore()
        XCTAssertNil(restored.user)
        XCTAssertTrue(restored.canRestoreSession)
        XCTAssertNotNil(storage.data)
        XCTAssertFalse(restored.isRestoring)

        transport.userIsOffline = false
        await restored.restore()
        XCTAssertEqual(restored.user?.id, "reader-1")
        XCTAssertFalse(restored.canRestoreSession)
        XCTAssertNil(restored.errorMessage)
        XCTAssertEqual(transport.userRequests, 2)
    }

    func testConcurrentCallsShareOneRotatingRefresh() async throws {
        let storage = MemoryCredentials()
        let transport = StubAuthTransport()
        transport.initialExpiry = 1
        let session = NativeSession(transport: transport, storage: storage)
        await session.signIn(email: "reader@example.com", password: "password")

        let started = expectation(description: "Refresh started")
        var resumeRefresh: CheckedContinuation<Void, Never>?
        transport.beforeRefresh = {
            await withCheckedContinuation { continuation in
                resumeRefresh = continuation
                started.fulfill()
            }
        }
        let first = Task { try await session.accessToken() }
        let second = Task { try await session.accessToken() }
        await fulfillment(of: [started], timeout: 2)
        resumeRefresh?.resume()
        let firstToken = try await first.value
        let secondToken = try await second.value
        XCTAssertEqual(firstToken, "access-refreshed")
        XCTAssertEqual(secondToken, firstToken)
        XCTAssertEqual(transport.refreshRequests, 1)
        XCTAssertTrue(String(data: storage.data ?? Data(), encoding: .utf8)?.contains("refresh-new") ?? false)
    }

    func testSignOutWhileSignInIsPendingCannotRestoreTheOldResult() async {
        let storage = MemoryCredentials()
        let transport = StubAuthTransport()
        let session = NativeSession(transport: transport, storage: storage)
        let started = expectation(description: "Password request started")
        var resumeSignIn: CheckedContinuation<Void, Never>?
        transport.beforePassword = {
            await withCheckedContinuation { continuation in
                resumeSignIn = continuation
                started.fulfill()
            }
        }
        let signingIn = Task { await session.signIn(email: "reader@example.com", password: "password") }
        await fulfillment(of: [started], timeout: 2)
        await session.signOut()
        resumeSignIn?.resume()
        await signingIn.value
        XCTAssertNil(session.user)
        XCTAssertNil(storage.data)
        XCTAssertFalse(session.isBusy)
    }

    func testRejectedRefreshClearsSessionButDoesNotSignOutOtherDevices() async {
        let storage = MemoryCredentials()
        let transport = StubAuthTransport()
        transport.initialExpiry = 1
        let session = NativeSession(transport: transport, storage: storage)
        await session.signIn(email: "reader@example.com", password: "password")
        transport.rejectRefresh = true
        do {
            _ = try await session.accessToken()
            XCTFail("A revoked refresh token must be rejected")
        } catch { }
        XCTAssertNil(session.user)
        XCTAssertNil(storage.data)

        transport.rejectRefresh = false
        await session.signIn(email: "reader@example.com", password: "password")
        await session.signOut()
        XCTAssertEqual(transport.logoutScope, "local")
    }

    func testUntrustedConfigurationNeverReceivesPasswordOrToken() async {
        let storage = MemoryCredentials()
        let transport = StubAuthTransport()
        transport.configURL = "https://attacker.example/supabase.co"
        let session = NativeSession(transport: transport, storage: storage)
        await session.signIn(email: "reader@example.com", password: "password")
        XCTAssertNil(session.user)
        XCTAssertNotNil(session.errorMessage)
        XCTAssertEqual(transport.passwordRequests, 0)
        XCTAssertNil(storage.data)
    }

    func testRecoveryKeepsLoginIdentityButOldAPIIsRejectedAfterSameAccountSignsInAgain() async throws {
        let storage = MemoryCredentials()
        let transport = StubAuthTransport()
        let session = NativeSession(transport: transport, storage: storage)
        await session.signIn(email: "reader@example.com", password: "password")
        let firstIdentity = session.sessionIdentity
        let oldAPI = PlurifoldAPI(session: session)

        try await session.recoverUnauthorized()
        XCTAssertEqual(session.sessionIdentity, firstIdentity)
        XCTAssertEqual(transport.refreshRequests, 1)
        XCTAssertEqual(transport.userRequests, 1)
        let renewedToken = try await session.accessToken()
        XCTAssertEqual(renewedToken, "access-refreshed")

        await session.signOut()
        let signedOutIdentity = session.sessionIdentity
        XCTAssertNotEqual(signedOutIdentity, firstIdentity)
        await session.signIn(email: "reader@example.com", password: "password")
        XCTAssertNotEqual(session.sessionIdentity, firstIdentity)
        XCTAssertNotEqual(session.sessionIdentity, signedOutIdentity)
        // An old response cannot invalidate the new session, even for the same user.
        session.rejectUnauthorizedSession(expectedIdentity: firstIdentity)
        XCTAssertEqual(session.user?.id, "reader-1")
        do {
            // The identity guard must reject this before any real network request.
            let _: [String: String] = try await oldAPI.get("/api/mobile/config")
            XCTFail("An old API instance must not adopt a new login's token")
        } catch is CancellationError { }
        catch { XCTFail("Expected stale-login cancellation, got \(error)") }
    }

    func testUnauthorizedRecoveryRetainsSessionOnOutageAndClearsDefinitiveRejection() async {
        let storage = MemoryCredentials()
        let transport = StubAuthTransport()
        let session = NativeSession(transport: transport, storage: storage)
        await session.signIn(email: "reader@example.com", password: "password")
        let identity = session.sessionIdentity
        transport.refreshServerUnavailable = true
        do {
            try await session.recoverUnauthorized()
            XCTFail("The server outage should surface as an error")
        } catch { }
        XCTAssertEqual(session.user?.id, "reader-1")
        XCTAssertEqual(session.sessionIdentity, identity)
        XCTAssertNotNil(storage.data)

        transport.refreshServerUnavailable = false
        transport.userIsOffline = true
        do {
            try await session.recoverUnauthorized()
            XCTFail("The offline verification should surface as an error")
        } catch { }
        XCTAssertEqual(session.user?.id, "reader-1")
        XCTAssertEqual(session.sessionIdentity, identity)
        XCTAssertNotNil(storage.data)

        transport.userIsOffline = false
        transport.rejectUser = true
        do {
            try await session.recoverUnauthorized()
            XCTFail("A rejected authenticated user must be signed out")
        } catch { }
        XCTAssertNil(session.user)
        XCTAssertNotEqual(session.sessionIdentity, identity)
        XCTAssertNil(storage.data)
    }
}

@MainActor
private final class MemoryCredentials: NativeCredentialStoring {
    var data: Data?
    func read() throws -> Data? { data }
    func write(_ data: Data) throws { self.data = data }
    func delete() throws { data = nil }
}

@MainActor
private final class StubAuthTransport: NativeAuthTransporting {
    var initialExpiry = 3_600
    var configURL = "https://plurifold-test.supabase.co"
    var userIsOffline = false
    var rejectRefresh = false
    var rejectUser = false
    var refreshServerUnavailable = false
    var passwordRequests = 0
    var refreshRequests = 0
    var userRequests = 0
    var logoutScope: String?
    var beforeRefresh: (() async -> Void)?
    var beforePassword: (() async -> Void)?

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = try XCTUnwrap(request.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        var status = 200
        let body: [String: Any]
        switch url.path {
        case "/api/mobile/config":
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            body = ["supabase": ["url": configURL, "publishableKey": "sb_publishable_test_public_key"]]
        case "/auth/v1/token" where query["grant_type"] == "password":
            passwordRequests += 1
            await beforePassword?()
            body = token(access: "access-initial", refresh: "refresh-initial", expires: initialExpiry)
        case "/auth/v1/token":
            refreshRequests += 1
            await beforeRefresh?()
            if refreshServerUnavailable {
                status = 503
                body = ["error_code": "unexpected_failure"]
            } else if rejectRefresh {
                status = 400
                body = ["error_code": "refresh_token_not_found"]
            } else {
                body = token(access: "access-refreshed", refresh: "refresh-new", expires: 3_600)
            }
        case "/auth/v1/user":
            userRequests += 1
            if userIsOffline { throw URLError(.notConnectedToInternet) }
            XCTAssertNotNil(request.value(forHTTPHeaderField: "Authorization"))
            if rejectUser {
                status = 401
                body = ["error_code": "bad_jwt"]
            } else {
                body = ["id": "reader-1", "email": "reader@example.com"]
            }
        case "/auth/v1/logout":
            logoutScope = query["scope"]
            body = [:]
            status = 204
        default:
            XCTFail("Unexpected auth endpoint")
            body = [:]
            status = 404
        }
        return (try JSONSerialization.data(withJSONObject: body),
                try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)))
    }

    private func token(access: String, refresh: String, expires: Int) -> [String: Any] {
        ["access_token": access, "refresh_token": refresh, "expires_in": expires,
         "user": ["id": "reader-1", "email": "reader@example.com"]]
    }
}
