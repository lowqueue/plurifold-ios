import Foundation

/// A saved meaning belongs to its language, term kind, and variety. Do not borrow
/// a different dialect's definition merely because its spelling is identical.
enum SavedDefinitionMatcher {
    static func find(in words: [MobileSavedWord], term: String, languageCode: String,
                     dialect: String?, kind: String) -> MobileSavedWord? {
        guard let language = MobileLanguageKey.normalized(languageCode) else { return nil }
        let normalized = normalizedTerm(term, language: languageCode)
        return words.first {
            MobileLanguageKey.normalized($0.languageCode) == language && $0.kind == kind
                && normalizedTerm($0.term, language: languageCode) == normalized
                && normalizedDialect($0.dialect) == normalizedDialect(dialect)
        }
    }

    static func normalizedTerm(_ value: String, language: String) -> String {
        value.precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .caseInsensitive, locale: Locale(identifier: language))
            .precomposedStringWithCanonicalMapping
    }

    static func normalizedDialect(_ value: String?) -> String {
        normalizedTerm(value ?? "", language: "en-US")
    }
}

struct WordDictionaryRequest: Encodable {
    let term: String
    let languageCode: String
}

struct WordDictionaryResponse: Decodable {
    enum Status: String, Decodable {
        case found
        case notFound = "not_found"
        case unavailable
        case notApplicable = "not_applicable"
    }

    let status: Status
    let entries: [WordDictionaryEntry]
    let sourceName: String
    let attribution: String
    let licenseName: String
    let licenseURL: String
    let notice: String?

    var displayEntries: [WordDictionaryEntry] {
        guard status == .found else { return [] }
        return entries.filter {
            $0.safeSourceURL != nil && $0.definitions.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }

    static let attributionLicenseURL = URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!
}

struct WordDictionaryEntry: Decodable {
    let term: String
    let partOfSpeech: String
    let definitions: [String]
    let sourceURL: String

    var safeSourceURL: URL? {
        guard sourceURL.utf16.count <= 1_200, term.utf16.count <= 200,
              let components = URLComponents(string: sourceURL),
              components.scheme == "https", components.host == "en.wiktionary.org",
              components.user == nil, components.password == nil,
              components.port == nil || components.port == 443,
              components.query == nil, components.path.hasPrefix("/wiki/"),
              components.path.count > "/wiki/".count else { return nil }
        return components.url
    }

    /// Attribution travels with a saved dictionary sense to desktop and Review.
    /// Source text is displayed as plain text, never as HTML or injected Markdown.
    var savedAttribution: String {
        guard let url = safeSourceURL else { return "" }
        return "Dictionary: Wiktionary contributors\nDefinitions excerpted; formatting removed.\nEntry: \(term)\nSource: \(url.absoluteString)\nLicense: CC BY-SA 4.0\nhttps://creativecommons.org/licenses/by-sa/4.0/"
    }
}
