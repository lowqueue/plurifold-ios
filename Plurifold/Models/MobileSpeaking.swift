import Foundation

struct MobileSpeakingCapability: Decodable {
    let allowed: Bool
}

enum MobileSpeakingOperation: String {
    case session, hangup, savePhrase

    var path: String { "/api/mobile/speaking/\(self == .savePhrase ? "phrase" : rawValue)" }
}

/// Only these response fields cross into the isolated speaking page. Account
/// credentials, cookies, and arbitrary URLs are never part of the bridge.
struct MobileSpeakingHTTPResponse {
    let status: Int
    let headers: [String: String]
    let body: String

    var bridgeValue: [String: Any] {
        ["status": status, "headers": headers, "body": body]
    }

    var sessionHandle: String? {
        guard (200..<300).contains(status), let handle = headers["x-plurifold-realtime-session"],
              MobileSpeakingPolicy.validHandle(handle) else { return nil }
        return handle
    }
}

enum MobileSpeakingPolicy {
    static let host = "www.plurifold.com"
    static let roomPath = "/mobile/speaking"

    static func roomURL(language: String?, colorway: String? = nil, lighting: String? = nil) -> URL {
        var components = URLComponents(string: "https://\(host)\(roomPath)")!
        var query: [URLQueryItem] = []
        if let language, language.range(of: "^[a-z]{2}-[A-Z]{2}$", options: .regularExpression) != nil {
            query.append(URLQueryItem(name: "language", value: language))
        }
        if let colorway, ["verdant", "vermilion", "blue-hour"].contains(colorway) {
            query.append(URLQueryItem(name: "colorway", value: colorway))
        }
        if let lighting, ["light", "dark", "system"].contains(lighting) {
            query.append(URLQueryItem(name: "lighting", value: lighting))
        }
        components.queryItems = query.isEmpty ? nil : query
        return components.url!
    }

    static func allows(_ url: URL?) -> Bool {
        guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "https", components.host == host,
              components.port == nil || components.port == 443,
              components.user == nil, components.password == nil,
              components.path == roomPath, components.fragment == nil else { return false }
        let query = components.queryItems ?? []
        guard Set(query.map(\.name)).count == query.count else { return false }
        return query.allSatisfy { item in
            guard let value = item.value else { return false }
            switch item.name {
            case "language": return value.range(of: "^[a-z]{2}-[A-Z]{2}$", options: .regularExpression) != nil
            case "colorway": return ["verdant", "vermilion", "blue-hour"].contains(value)
            case "lighting": return ["light", "dark", "system"].contains(value)
            default: return false
            }
        }
    }

    static func validHandle(_ value: String) -> Bool {
        value.range(of: "^[a-f0-9]{48}$", options: .regularExpression) != nil
    }

    static func request(_ value: Any) -> (operation: MobileSpeakingOperation, body: Data)? {
        guard let envelope = value as? [String: Any], Set(envelope.keys) == ["operation", "body"],
              let name = envelope["operation"] as? String, let operation = MobileSpeakingOperation(rawValue: name),
              let body = envelope["body"] as? [String: Any], JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        switch operation {
        case .session:
            guard data.count <= 128_000, Set(body.keys).isSubset(of: ["sdp", "intro", "replaceCurrent"]),
                  let sdp = body["sdp"] as? String, sdp.utf8.count <= 24_000,
                  sdp.hasPrefix("v=0"), sdp.contains("m=audio"), body["intro"] is [String: Any] else { return nil }
        case .hangup:
            guard data.count <= 1_024, Set(body.keys).isSubset(of: ["session", "failedToConnect", "diagnostics"]),
                  let handle = body["session"] as? String, validHandle(handle) else { return nil }
        case .savePhrase:
            guard data.count <= 20_000, Set(body.keys) == ["language", "term", "meaning", "note", "context"],
                  let language = body["language"] as? String,
                  ["it-IT", "es-AR", "et-EE", "ka-GE", "ru-RU", "uk-UA", "ja-JP", "de-DE"].contains(language) else { return nil }
            for (key, limit) in [("term", 240), ("meaning", 400), ("note", 400), ("context", 2_400)] {
                guard let text = body[key] as? String, text.utf16.count <= limit,
                      (key != "term" && key != "meaning") || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            }
        }
        return (operation, data)
    }
}
