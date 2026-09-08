import XCTest
@testable import Plurifold

final class TermDefinitionsTests: XCTestCase {
    func testAutomaticExplanationsStartAtTwoWordsAndStopAfterFourteen() {
        for count in [1, 2, 14, 15] {
            let text = Array(repeating: "olen", count: count).joined(separator: " ")
            XCTAssertEqual(DefinitionSelection.wordCount(in: text, languageCode: "et-EE"), count)
            XCTAssertEqual(DefinitionSelection.shouldAutomaticallyExplain(text, languageCode: "et-EE"),
                           (2...14).contains(count))
            XCTAssertEqual(DefinitionSelection.exceedsExplanationWordLimit(text, languageCode: "et-EE"),
                           count > 14)
        }
    }

    func testPunctuationAndEmojiDoNotSpendTheLexicalWordLimit() {
        let text = " ‘cafe\u{301}’ 👩🏽‍💻,\n mondo! 🇮🇹 "
        XCTAssertEqual(DefinitionSelection.wordCount(in: text, languageCode: "it-IT"), 2)
        XCTAssertTrue(DefinitionSelection.shouldAutomaticallyExplain(text, languageCode: "it-IT"))
        for empty in ["", " \n", "!!! 🇪🇪 👩🏽‍💻"] {
            XCTAssertEqual(DefinitionSelection.wordCount(in: empty, languageCode: "et-EE"), 0)
            XCTAssertFalse(DefinitionSelection.shouldAutomaticallyExplain(empty, languageCode: "et-EE"))
        }
    }

    func testGeorgianWhitespaceAndUnspacedJapaneseBothEnforceTheWordLimit() {
        XCTAssertEqual(DefinitionSelection.wordCount(in: "მე\nვარ", languageCode: "ka-GE"), 2)
        let georgianParagraph = Array(repeating: "გამარჯობა", count: 100).joined(separator: "\u{00A0}")
        XCTAssertEqual(DefinitionSelection.wordCount(in: georgianParagraph, languageCode: "ka-GE"), 15)
        XCTAssertFalse(DefinitionSelection.shouldAutomaticallyExplain(georgianParagraph, languageCode: "ka-GE"))
        XCTAssertTrue(DefinitionSelection.exceedsExplanationWordLimit(georgianParagraph, languageCode: "ka-GE"))
        XCTAssertGreaterThan(DefinitionSelection.wordCount(in: "猫がいる", languageCode: "ja-JP"), 1)
        XCTAssertTrue(DefinitionSelection.shouldAutomaticallyExplain("猫がいる", languageCode: "ja-JP"))
        let japaneseParagraph = String(repeating: "猫がいる。", count: 15)
        XCTAssertEqual(DefinitionSelection.wordCount(in: japaneseParagraph, languageCode: "ja-JP"), 15)
        XCTAssertTrue(DefinitionSelection.exceedsExplanationWordLimit(japaneseParagraph, languageCode: "ja-JP"))
        XCTAssertFalse(DefinitionSelection.shouldAutomaticallyExplain(japaneseParagraph, languageCode: "ja-JP"))
    }

    func testDictionaryUsesIndividualEstonianAndGeorgianFormsWithoutSurroundingPunctuation() {
        XCTAssertEqual(DefinitionSelection.dictionaryTerm(for: " “Tere!” ", languageCode: "et-EE"), "Tere")
        XCTAssertEqual(DefinitionSelection.dictionaryTerm(for: "გამარჯობა,", languageCode: "ka-GE"), "გამარჯობა")
        XCTAssertEqual(DefinitionSelection.dictionaryTerm(for: "(არის)", languageCode: "ka-GE"), "არის")
        XCTAssertEqual(DefinitionSelection.dictionaryTerm(for: "l'amico", languageCode: "it-IT"), "l'amico")
        XCTAssertEqual(DefinitionSelection.dictionaryTerm(for: "col·legi", languageCode: "ca-ES"), "col·legi")
        XCTAssertNil(DefinitionSelection.dictionaryTerm(for: "a.b", languageCode: "et-EE"))
    }

    func testDictionaryNormalizesAccentsButNeverSendsPhrasesOrArbitrarySelectionText() {
        XCTAssertEqual(DefinitionSelection.dictionaryTerm(for: "cafe\u{301}", languageCode: "fr-FR"), "café")
        for term in ["mina olen", "მე ვარ", "ciao\nmondo", "a/b", "https://example.com", "!!!", "",
                     String(repeating: "a", count: 81)] {
            XCTAssertNil(DefinitionSelection.dictionaryTerm(for: term, languageCode: "et-EE"), term)
        }
    }

    func testUnspacedJapanesePhrasesStaySeparateFromIndividualDictionaryWords() {
        XCTAssertEqual(DefinitionSelection.dictionaryTerm(for: "猫。", languageCode: "ja-JP"), "猫")
        XCTAssertNil(DefinitionSelection.dictionaryTerm(for: "猫がいる", languageCode: "ja-JP"))
        XCTAssertEqual(DefinitionSelection.kind(for: "猫がいる", languageCode: "ja-JP"), "phrase")
    }

    func testSavedKindRecognizesWhitespacePhrasesInGeorgianAndEstonian() {
        XCTAssertEqual(DefinitionSelection.kind(for: "მე ვარ", languageCode: "ka-GE"), "phrase")
        XCTAssertEqual(DefinitionSelection.kind(for: "mina olen", languageCode: "et-EE"), "phrase")
        XCTAssertEqual(DefinitionSelection.kind(for: "Tere!", languageCode: "et-EE"), "word")
    }

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
