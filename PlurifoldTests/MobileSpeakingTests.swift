import XCTest
@testable import Plurifold

final class MobileSpeakingTests: XCTestCase {
    func testRoomIsBoundToTheDedicatedHTTPSPage() {
        XCTAssertTrue(MobileSpeakingPolicy.allows(MobileSpeakingPolicy.roomURL(language: "ja-JP")))
        XCTAssertTrue(MobileSpeakingPolicy.allows(MobileSpeakingPolicy.roomURL(language: "it-IT", colorway: "blue-hour", lighting: "dark")))
        XCTAssertTrue(MobileSpeakingPolicy.allows(URL(string: "https://www.plurifold.com:443/mobile/speaking")))
        for address in [
            "http://www.plurifold.com/mobile/speaking",
            "https://plurifold.com/mobile/speaking",
            "https://www.plurifold.com.evil.example/mobile/speaking",
            "https://www.plurifold.com:444/mobile/speaking",
            "https://user:password@www.plurifold.com/mobile/speaking",
            "https://www.plurifold.com/reader",
            "https://www.plurifold.com/mobile/speaking?return_to=https://example.com",
            "https://www.plurifold.com/mobile/speaking#access_token=secret",
            "https://www.plurifold.com/mobile/speaking?language=javascript:alert(1)",
            "https://www.plurifold.com/mobile/speaking?colorway=arbitrary",
            "https://www.plurifold.com/mobile/speaking?lighting=light&lighting=dark"
        ] {
            XCTAssertFalse(MobileSpeakingPolicy.allows(URL(string: address)), address)
        }
    }

    func testSavePhraseCannotEscapeTheBoundedVocabularyOperation() {
        let body: [String: Any] = ["language": "it-IT", "term": "Un caffè, per favore.",
            "meaning": "A coffee, please.", "note": "Polite order", "context": "At a café"]
        XCTAssertEqual(MobileSpeakingPolicy.request(["operation": "savePhrase", "body": body])?.operation, .savePhrase)
        var unsupported = body
        unsupported["language"] = "unknown"
        XCTAssertNil(MobileSpeakingPolicy.request(["operation": "savePhrase", "body": unsupported]))
        var oversized = body
        oversized["term"] = String(repeating: "a", count: 241)
        XCTAssertNil(MobileSpeakingPolicy.request(["operation": "savePhrase", "body": oversized]))
        var extraField = body
        extraField["sourceLessonID"] = "arbitrary"
        XCTAssertNil(MobileSpeakingPolicy.request(["operation": "savePhrase", "body": extraField]))
    }

    func testBridgeOnlyAcceptsIntroSessionAndOwnedHandleRequests() {
        let sdp = "v=0\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111\r\n"
        let valid: [String: Any] = ["operation": "session", "body": ["sdp": sdp,
            "intro": ["language": "it-IT", "confidence": "starting"], "replaceCurrent": false]]
        XCTAssertEqual(MobileSpeakingPolicy.request(valid)?.operation, .session)
        XCTAssertNil(MobileSpeakingPolicy.request(["operation": "fetch", "body": ["url": "https://example.com"]]))
        XCTAssertNil(MobileSpeakingPolicy.request(["operation": "session", "body": ["sdp": sdp, "pack": [:]]]))
        XCTAssertNil(MobileSpeakingPolicy.request(["operation": "session", "body": ["sdp": "not sdp", "intro": [:]]]))
        XCTAssertNil(MobileSpeakingPolicy.request(["operation": "session", "body": ["sdp": String(repeating: sdp, count: 1_000), "intro": [:]]]))
        let handle = String(repeating: "ab", count: 24)
        XCTAssertEqual(MobileSpeakingPolicy.request(["operation": "hangup", "body": ["session": handle]])?.operation, .hangup)
        XCTAssertNil(MobileSpeakingPolicy.request(["operation": "hangup", "body": ["session": "other"]]))
        XCTAssertNil(MobileSpeakingPolicy.request(["operation": "hangup", "body": ["session": handle, "url": "/api/mobile/account"]]))
    }

    func testBridgePreservesCooldownAndOnlyAcceptsSuccessfulSessionHandles() {
        let limited = MobileSpeakingHTTPResponse(status: 429, headers: ["retry-after": "127", "content-type": "application/json"],
                                                 body: "{\"error\":\"Try again after the cooldown.\"}")
        XCTAssertEqual(limited.bridgeValue["status"] as? Int, 429)
        XCTAssertEqual((limited.bridgeValue["headers"] as? [String: String])?["retry-after"], "127")
        XCTAssertNil(limited.sessionHandle)
        let handle = String(repeating: "ab", count: 24)
        XCTAssertEqual(MobileSpeakingHTTPResponse(status: 200, headers: ["x-plurifold-realtime-session": handle], body: "v=0").sessionHandle, handle)
        XCTAssertNil(MobileSpeakingHTTPResponse(status: 500, headers: ["x-plurifold-realtime-session": handle], body: "").sessionHandle)
        XCTAssertNil(MobileSpeakingHTTPResponse(status: 200, headers: ["x-plurifold-realtime-session": "unexpected"], body: "v=0").sessionHandle)
    }
}
