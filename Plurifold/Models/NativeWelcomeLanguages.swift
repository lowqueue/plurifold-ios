import Foundation

struct NativeWelcomeLanguage: Identifiable, Equatable, Sendable {
    let code: String
    let name: String
    let nativeName: String
    var id: String { code }

    func matches(_ search: String) -> Bool {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || [name, nativeName, code].contains {
            $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}

/// The same eight offered languages as the website's welcome catalog.
/// These are language preferences, never an authorization claim.
enum NativeWelcomeLanguages {
    static let offered: [NativeWelcomeLanguage] = [
        .init(code: "it-IT", name: "Italian", nativeName: "Italiano"),
        .init(code: "es-AR", name: "Spanish", nativeName: "Español"),
        .init(code: "et-EE", name: "Estonian", nativeName: "Eesti"),
        .init(code: "ka-GE", name: "Georgian", nativeName: "ქართული"),
        .init(code: "ru-RU", name: "Russian", nativeName: "Русский"),
        .init(code: "uk-UA", name: "Ukrainian", nativeName: "Українська"),
        .init(code: "ja-JP", name: "Japanese", nativeName: "日本語"),
        .init(code: "de-DE", name: "German", nativeName: "Deutsch")
    ]

    private static let selectionKey = "plurifold-native-welcome-selection"

    static func saveSelection(_ codes: [String], defaults: UserDefaults = .standard) {
        let valid = validated(codes)
        if valid.isEmpty { defaults.removeObject(forKey: selectionKey) }
        else { defaults.set(valid, forKey: selectionKey) }
    }

    static func selection(defaults: UserDefaults = .standard) -> [String] {
        validated(defaults.stringArray(forKey: selectionKey) ?? [])
    }

    /// Consume once after a successful sign-in and a completed catalog load.
    /// A failed sign-in or an email-confirmation step must not consume this.
    static func takeSelection(defaults: UserDefaults = .standard) -> [String] {
        let codes = selection(defaults: defaults)
        defaults.removeObject(forKey: selectionKey)
        return codes
    }

    private static func validated(_ codes: [String]) -> [String] {
        let allowed = Set(offered.map(\.code))
        var seen = Set<String>()
        return codes.filter { allowed.contains($0) && seen.insert($0).inserted }
    }
}
