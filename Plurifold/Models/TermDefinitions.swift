import Foundation
import NaturalLanguage

enum DefinitionSelection {
    static let maximumWordCount = 14
    static let wordLimitMessage = "Select 14 words or fewer for a focused explanation."

    static func shouldAutomaticallyExplain(_ text: String, languageCode: String) -> Bool {
        (2...maximumWordCount).contains(wordCount(in: text, languageCode: languageCode))
    }

    static func exceedsExplanationWordLimit(_ text: String, languageCode: String) -> Bool {
        wordCount(in: text, languageCode: languageCode) > maximumWordCount
    }

    /// Keep saved-word classification independent of dictionary lookup. Tokenization
    /// helps with unspaced scripts; unsupported tokenizers still need to recognize
    /// an ordinary phrase containing separate words.
    static func kind(for text: String, languageCode: String) -> String {
        wordCount(in: text, languageCode: languageCode) > 1 ? "phrase" : "word"
    }

    /// A trailing comma or sentence punctuation should not prevent lookup of an
    /// Estonian or Georgian word. Send only the normalized lexical form, keeping
    /// the original selection untouched for saves and contextual AI explanations.
    static func dictionaryTerm(for text: String, languageCode: String) -> String? {
        let trimmed = text.precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        guard !trimmed.isEmpty, trimmed.utf16.count <= 80,
              trimmed.range(of: #"^[\p{L}\p{M}\p{N}]+(?:['’·-][\p{L}\p{M}\p{N}]+)*$"#,
                            options: .regularExpression) != nil else { return nil }
        // A Japanese phrase may have no spaces, unlike the current other languages.
        if languageCode.lowercased().hasPrefix("ja"), wordCount(in: trimmed, languageCode: languageCode) > 1 {
            return nil
        }
        return trimmed
    }

    /// Count lexical words, including unspaced scripts. Only counts through the
    /// first disallowed word are needed, so a whole transcript cannot make this
    /// selection check grow with the entire tokenized document.
    static func wordCount(in text: String, languageCode: String) -> Int {
        let countLimit = maximumWordCount + 1
        let separatedWords = text.split(whereSeparator: \.isWhitespace).lazy.filter {
            $0.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
        }.prefix(countLimit).count
        if separatedWords == countLimit { return countLimit }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        if let language = PassageTextSelection.tokenizerLanguageCode(languageCode) {
            tokenizer.setLanguage(NLLanguage(rawValue: language))
        }
        var words = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            if text[range].unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) {
                words += 1
            }
            return words < countLimit
        }
        return max(separatedWords, words)
    }
}

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
