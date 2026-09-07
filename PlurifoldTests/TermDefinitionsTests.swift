import XCTest
@testable import Plurifold

final class TermDefinitionsTests: XCTestCase {
    func testSavedDefinitionsMatchCanonicalAccentsAndCaseWithoutRemovingAccents() {
        let words = [word("café", language: "fr-FR")]
        XCTAssertNotNil(SavedDefinitionMatcher.find(in: words, term: " CAFE\u{301} ",
                                                     languageCode: "fr-FR", dialect: nil, kind: "word"))
        XCTAssertNil(SavedDefinitionMatcher.find(in: words, term: "cafe",
                                                  languageCode: "fr-FR", dialect: nil, kind: "word"))
    }

    func testSavedDefinitionsNeverCrossLanguagesKindsOrVarieties() {
        let words = [word("vino", language: "es-ES", dialect: "Rioplatense")]
        XCTAssertNotNil(SavedDefinitionMatcher.find(in: words, term: "VINO", languageCode: "es-ES",
                                                     dialect: " rioplatense ", kind: "word"))
        XCTAssertNil(SavedDefinitionMatcher.find(in: words, term: "vino", languageCode: "it-IT",
                                                  dialect: "Rioplatense", kind: "word"))
        XCTAssertNil(SavedDefinitionMatcher.find(in: words, term: "vino", languageCode: "es-ES",
                                                  dialect: nil, kind: "word"))
        XCTAssertNil(SavedDefinitionMatcher.find(in: words, term: "vino", languageCode: "es-ES",
                                                  dialect: "Rioplatense", kind: "phrase"))
    }

    func testEmptySavedVarietyMatchesUnspecifiedVariety() {
        XCTAssertNotNil(SavedDefinitionMatcher.find(in: [word("ciao", language: "it-IT", dialect: "  ")],
                                                     term: "ciao", languageCode: "it-IT", dialect: nil, kind: "word"))
    }

    func testLanguageCodeFormattingIsNormalizedWithoutCrossingRegions() {
        let words = [word("vino", language: "es_ES")]
        XCTAssertNotNil(SavedDefinitionMatcher.find(in: words, term: "vino", languageCode: "ES-es",
                                                     dialect: nil, kind: "word"))
        XCTAssertNil(SavedDefinitionMatcher.find(in: words, term: "vino", languageCode: "es-MX",
                                                  dialect: nil, kind: "word"))
        XCTAssertNil(SavedDefinitionMatcher.find(in: [word("vino", language: " ")], term: "vino",
                                                  languageCode: " ", dialect: nil, kind: "word"))
    }

    func testDictionaryStatusesDecodeWithoutPretendingEveryLookupSucceeded() throws {
        for status in ["found", "not_found", "unavailable", "not_applicable"] {
            let response = try JSONDecoder().decode(WordDictionaryResponse.self,
                                                   from: dictionaryData(status: status))
            XCTAssertEqual(response.status.rawValue, status)
            XCTAssertEqual(response.displayEntries.count, status == "found" ? 1 : 0)
        }
        XCTAssertThrowsError(try JSONDecoder().decode(WordDictionaryResponse.self,
                                                      from: dictionaryData(status: "invented")))
    }

    func testDictionaryTextStaysPlainAndAttributionTravelsWithSavedMeaning() throws {
        let response = try JSONDecoder().decode(WordDictionaryResponse.self,
                                               from: dictionaryData(status: "found", definition: "<b>hello</b> **greeting**"))
        let entry = try XCTUnwrap(response.displayEntries.first)
        XCTAssertEqual(entry.definitions, ["<b>hello</b> **greeting**"])
        XCTAssertTrue(entry.savedAttribution.contains("Wiktionary contributors"))
        XCTAssertTrue(entry.savedAttribution.contains("Definitions excerpted; formatting removed."))
        XCTAssertTrue(entry.savedAttribution.contains("https://en.wiktionary.org/wiki/ciao#Italian"))
        XCTAssertTrue(entry.savedAttribution.contains("CC BY-SA 4.0"))
        XCTAssertTrue(entry.savedAttribution.contains("https://creativecommons.org/licenses/by-sa/4.0/"))
    }

    func testOnlyWiktionaryArticleLinksCanBeOpenedOrSaved() {
        for address in ["https://example.com/wiki/ciao", "http://en.wiktionary.org/wiki/ciao",
                        "https://en.wiktionary.org.evil.example/wiki/ciao", "javascript:alert(1)",
                        "https://user@en.wiktionary.org/wiki/ciao", "https://en.wiktionary.org/w/api.php",
                        "https://en.wiktionary.org/wiki/ciao?redirect=elsewhere", "https://en.wiktionary.org/wiki/"] {
            let entry = WordDictionaryEntry(term: "ciao", partOfSpeech: "interjection",
                                            definitions: ["hello"], sourceURL: address)
            XCTAssertNil(entry.safeSourceURL, address)
            XCTAssertTrue(entry.savedAttribution.isEmpty, address)
        }
        let entry = WordDictionaryEntry(term: "ciao", partOfSpeech: "interjection", definitions: ["hello"],
                                        sourceURL: "https://en.wiktionary.org/wiki/ciao#Italian")
        XCTAssertNotNil(entry.safeSourceURL)
    }

    func testCacheMissIsAValidResponseWithoutStartingAI() throws {
        let response = try JSONDecoder().decode(InsightDefineResponse.self,
                                               from: Data(#"{"insight":null,"source":null,"cached":false}"#.utf8))
        XCTAssertNil(response.insight)
        XCTAssertNil(response.source)
    }

    func testCacheRequestCarriesReadOnlyFlagAndFullDesktopContext() throws {
        let request = InsightDefineRequest(selection: "ciao", context: "short", language: "Italian",
                                           dialect: nil, scope: "word", cacheContext: "full desktop context", lookupOnly: true)
        let encoded = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["profile"] as? String, "mobile-lite")
        XCTAssertEqual(object["lookupOnly"] as? Bool, true)
        XCTAssertEqual(object["context"] as? String, "short")
        XCTAssertEqual(object["cacheContext"] as? String, "full desktop context")
    }

    func testFullMultiwordSelectionUsesSentenceScopeButSavedKindStaysPhrase() {
        XCTAssertEqual(InsightText.scope(kind: "phrase", selection: " Mina olen. ", context: "Mina olen."), "sentence")
        XCTAssertEqual(InsightText.scope(kind: "phrase", selection: "Mina olen", context: "Mina olen Kristel."), "phrase")
        XCTAssertEqual(InsightText.scope(kind: "word", selection: "Ciao!", context: "Ciao!"), "word")
    }

    func testUTF16ContextWindowKeepsSelectionAndDoesNotSplitUnicodeCharacters() throws {
        let prefix = String(repeating: "🇪🇪é ", count: 300)
        let selected = "mina olen"
        let context = prefix + selected + String(repeating: "e\u{301} 🇪🇪 ", count: 300)
        let selection = try XCTUnwrap(PassageSelection(context: context,
                                                       range: (context as NSString).range(of: selected)))
        for limit in [1_200, 2_400] {
            let clipped = InsightText.context(around: selection, utf16Limit: limit)
            XCTAssertLessThanOrEqual(clipped.utf16.count, limit)
            XCTAssertTrue(clipped.contains(selected))
            XCTAssertFalse(clipped.contains("\u{FFFD}"))
        }
    }

    private func dictionaryData(status: String, definition: String = "hello") throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "status": status,
            "entries": [["term": "ciao", "partOfSpeech": "interjection", "definitions": [definition],
                         "sourceURL": "https://en.wiktionary.org/wiki/ciao#Italian"]],
            "sourceName": "Wiktionary", "attribution": "Wiktionary contributors",
            "licenseName": "CC BY-SA 4.0", "licenseURL": "https://creativecommons.org/licenses/by-sa/4.0/"
        ])
    }

    private func word(_ term: String, language: String, dialect: String? = nil) -> MobileSavedWord {
        MobileSavedWord(id: "saved", term: term, meaning: "Saved meaning", note: "Saved note", context: "Original context",
                        languageCode: language, languageName: "Language", status: "learning", kind: "word",
                        sourceLessonID: nil, sourceLessonTitle: nil, dialect: dialect, pronunciation: nil, partOfSpeech: nil)
    }
}
