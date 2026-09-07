import XCTest
@testable import Plurifold

final class MobileVocabularyReviewTests: XCTestCase {
    func testLanguageNormalizationAcceptsFormattingButDoesNotCombineVarieties() {
        let words = [word("italian", language: " IT_it "), word("swiss", language: "it-CH"),
                     word("spanish", language: "es-ES"), word("generic", language: "it")]
        XCTAssertEqual(MobileLanguageKey.normalized(" \nIT_it\t"), "it-it")
        XCTAssertEqual(MobileVocabularyIndex(words: words, languageCode: "it-IT").words.map(\.id), ["italian"])
        XCTAssertEqual(MobileVocabularyIndex(words: words, languageCode: "IT").words.map(\.id), ["generic"])
    }

    func testMissingLanguageNeverFallsBackToAllWords() {
        let words = [word("italian"), word("spanish", language: "es-ES"), word("blank", language: "")]
        let languages: [String?] = [nil, "", " \n\t"]
        for language in languages {
            XCTAssertNil(MobileLanguageKey.normalized(language))
            XCTAssertTrue(MobileVocabularyIndex(words: words, languageCode: language).words.isEmpty)
        }
        XCTAssertTrue(MobileVocabularyIndex(words: words, languageCode: "et-EE").words.isEmpty)
    }

    func testSearchChecksOnlySupportedFieldsWithinSelectedLanguage() {
        let words = [word("term", term: "Buongiorno"), word("meaning", meaning: "Good morning"),
                     word("note", note: "Formal greeting"), word("source", source: "Morning in Rome"),
                     word("other-language", language: "es-ES", term: "Morning"),
                     word("context-only", context: "Morning")]
        XCTAssertEqual(MobileVocabularyIndex(words: words, languageCode: "it-IT", search: "  MORNING  ")
            .words.map(\.id), ["meaning", "source"])
        XCTAssertEqual(MobileVocabularyIndex(words: words, languageCode: "it-IT", search: "buongiorno")
            .words.map(\.id), ["term"])
        XCTAssertEqual(MobileVocabularyIndex(words: words, languageCode: "it-IT", search: "greeting")
            .words.map(\.id), ["note"])
    }

    func testReviewRequiresRevealingBeforeRatingAndAgainRequeues() {
        var session = MobileReviewSession()
        session.reconcile(words: [word("one"), word("two")], languageCode: "it-IT")
        session.again()
        session.gotIt()
        XCTAssertEqual(session.queue.map(\.id), ["one", "two"])
        XCTAssertTrue(session.completedIDs.isEmpty)

        session.reveal()
        session.again()
        XCTAssertEqual(session.queue.map(\.id), ["two", "one"])
        XCTAssertFalse(session.isAnswerRevealed)
        XCTAssertEqual(session.totalCount, 2)

        session.reveal()
        session.gotIt()
        XCTAssertEqual(session.current?.id, "one")
        XCTAssertEqual(session.completedIDs, ["two"])
        XCTAssertFalse(session.isAnswerRevealed)
        XCTAssertEqual(session.totalCount, 2)
    }

    func testAgainWithOneWordConcealsAnswerAndCompletionEndsRound() {
        var session = MobileReviewSession()
        session.restart(words: [word("one")], languageCode: "it-IT")
        session.reveal()
        session.again()
        XCTAssertEqual(session.current?.id, "one")
        XCTAssertFalse(session.isAnswerRevealed)
        session.reveal()
        session.gotIt()
        session.reveal()
        session.again()
        session.gotIt()
        XCTAssertNil(session.current)
        XCTAssertFalse(session.isAnswerRevealed)
        XCTAssertEqual(session.completedIDs, ["one"])
        XCTAssertEqual(session.totalCount, 1)
    }

    func testLanguageSwitchResetsRoundWhileEquivalentCodePreservesIt() {
        let words = [word("one"), word("two"), word("spanish", language: "es-ES")]
        var session = MobileReviewSession()
        session.restart(words: words, languageCode: "it-IT")
        session.reveal()
        session.gotIt()
        session.reveal()
        session.reconcile(words: words, languageCode: " IT_it ")
        XCTAssertEqual(session.languageCode, "it-it")
        XCTAssertEqual(session.completedIDs, ["one"])
        XCTAssertTrue(session.isAnswerRevealed)

        session.reconcile(words: words, languageCode: "es-ES")
        XCTAssertEqual(session.languageCode, "es-es")
        XCTAssertEqual(session.queue.map(\.id), ["spanish"])
        XCTAssertTrue(session.completedIDs.isEmpty)
        XCTAssertFalse(session.isAnswerRevealed)
    }

    func testClearingLanguageAndCreatingAnotherSessionNeverRetainsPreviousWords() {
        var session = MobileReviewSession()
        session.restart(words: [word("one")], languageCode: "it-IT")
        session.reveal()
        session.reconcile(words: [word("one")], languageCode: nil)
        XCTAssertNil(session.languageCode)
        XCTAssertTrue(session.queue.isEmpty)
        XCTAssertTrue(session.completedIDs.isEmpty)
        XCTAssertFalse(session.isAnswerRevealed)

        let fresh = MobileReviewSession()
        XCTAssertNil(fresh.languageCode)
        XCTAssertNil(fresh.current)
        XCTAssertEqual(fresh.totalCount, 0)
    }

    func testReconcilePreservesReviewOrderUpdatesSnapshotsAndAppendsNewWords() {
        var session = MobileReviewSession()
        session.restart(words: [word("one"), word("two"), word("three")], languageCode: "it-IT")
        session.reveal()
        session.again()
        session.reveal()
        session.reconcile(words: [word("three"), word("four"), word("two", meaning: "Updated answer"), word("one")],
                          languageCode: "it-IT")
        XCTAssertEqual(session.queue.map(\.id), ["two", "three", "one", "four"])
        XCTAssertEqual(session.current?.meaning, "Updated answer")
        XCTAssertFalse(session.isAnswerRevealed)
    }

    func testReconcileKeepsAnswerVisibleWhenCurrentIsUnchanged() {
        var session = MobileReviewSession()
        session.restart(words: [word("one"), word("two")], languageCode: "it-IT")
        session.reveal()
        session.reconcile(words: [word("two", meaning: "Different answer"), word("one"), word("three")],
                          languageCode: "it-IT")
        XCTAssertEqual(session.current?.id, "one")
        XCTAssertTrue(session.isAnswerRevealed)
        XCTAssertEqual(session.queue.last?.id, "three")
    }

    func testReconcileRemovesDeletedCompletedAndCurrentWordsAndConcealsReplacement() {
        var session = MobileReviewSession()
        session.restart(words: [word("one"), word("two"), word("three")], languageCode: "it-IT")
        session.reveal()
        session.gotIt()
        session.reveal()
        session.reconcile(words: [word("three")], languageCode: "it-IT")
        XCTAssertEqual(session.current?.id, "three")
        XCTAssertTrue(session.completedIDs.isEmpty)
        XCTAssertEqual(session.totalCount, 1)
        XCTAssertFalse(session.isAnswerRevealed)
        session.reconcile(words: [], languageCode: "it-IT")
        XCTAssertNil(session.current)
        XCTAssertEqual(session.totalCount, 0)
    }

    func testDuplicateResponseIDsAreDeduplicatedWithoutReintroducingCompletedWords() {
        let words = [word("one"), word("one", meaning: "Duplicate answer"), word("two")]
        var session = MobileReviewSession()
        session.restart(words: words, languageCode: "it-IT")
        XCTAssertEqual(session.queue.map(\.id), ["one", "two"])
        XCTAssertEqual(session.current?.meaning, "")
        session.reveal()
        session.gotIt()
        session.reconcile(words: words + [word("two")], languageCode: "it-IT")
        XCTAssertEqual(session.queue.map(\.id), ["two"])
        XCTAssertEqual(session.completedIDs, ["one"])
        XCTAssertEqual(session.totalCount, 2)
    }

    func testRestartBeginsNewRoundForTheChosenLanguage() {
        let words = [word("one"), word("two", language: "es-ES")]
        var session = MobileReviewSession()
        session.restart(words: words, languageCode: "it-IT")
        session.reveal()
        session.gotIt()
        session.restart(words: words, languageCode: "it-IT")
        XCTAssertEqual(session.queue.map(\.id), ["one"])
        XCTAssertTrue(session.completedIDs.isEmpty)
        XCTAssertFalse(session.isAnswerRevealed)
    }

    private func word(_ id: String, language: String = "it-IT", term: String = "ciao", meaning: String = "",
                      note: String = "", source: String? = nil, context: String = "") -> MobileSavedWord {
        MobileSavedWord(id: id, term: term, meaning: meaning, note: note, context: context,
                        languageCode: language, languageName: "Language", status: "saved", kind: "word",
                        sourceLessonID: source == nil ? nil : "lesson", sourceLessonTitle: source,
                        dialect: nil, pronunciation: nil, partOfSpeech: nil)
    }
}
