import XCTest
@testable import Plurifold

@MainActor
final class MobileStudyScopeTests: XCTestCase {
    func testChoosingLanguageUpdatesSharedContextAndHomeDestination() {
        let scope = MobileStudyScope()
        let italian = language("it-IT", "Italian")
        scope.tab = .words
        scope.selectLanguage(italian)
        XCTAssertEqual(scope.language, italian)
        XCTAssertEqual(scope.homePath, [italian])
        XCTAssertEqual(scope.tab, .home)

        scope.tab = .review
        let estonian = language("et-EE", "Estonian")
        scope.selectLanguage(estonian)
        XCTAssertEqual(scope.language?.code, "et-EE")
        XCTAssertEqual(scope.homePath, [estonian])
    }

    func testPickerPopsToHomeWithoutLosingCurrentChoiceAndNewAccountStartsEmpty() {
        let scope = MobileStudyScope()
        scope.selectLanguage(language("it-IT", "Italian"))
        scope.tab = .review
        let previousRoot = scope.homeRootID
        scope.showLanguagePicker()
        XCTAssertTrue(scope.homePath.isEmpty)
        XCTAssertNotEqual(scope.homeRootID, previousRoot)
        XCTAssertEqual(scope.tab, .home)
        XCTAssertEqual(scope.language?.code, "it-IT")

        let newAccount = MobileStudyScope()
        XCTAssertNil(newAccount.language)
        XCTAssertTrue(newAccount.homePath.isEmpty)
        XCTAssertEqual(newAccount.tab, .home)
    }

    func testRemovedLanguageClearsScopeRatherThanShowingOtherLanguages() {
        let scope = MobileStudyScope()
        scope.selectLanguage(language("it-IT", "Italian"))
        scope.tab = .words
        scope.reconcile(languages: [language("et-EE", "Estonian")])
        XCTAssertNil(scope.language)
        XCTAssertTrue(scope.homePath.isEmpty)
        XCTAssertTrue(MobileVocabularyIndex(words: [word("et", "et-EE", "Estonian")],
                                            languageCode: scope.language?.code).words.isEmpty)
    }

    func testHomeRetainsSavedOnlyLanguagesAndDeduplicatesCodeVariants() {
        let italian = MobileCourse(id: "course", title: "Italian", languageCode: "it-IT", languageName: "Italian",
                                   lessons: [MobileLessonSummary(id: "lesson", title: "A lesson", subtitle: "",
                                                                 languageCode: "it-IT", languageName: "Italian", dialect: nil,
                                                                 paragraphCount: 1, kind: "lesson", channel: nil)])
        let list = MobileStudyLanguageList(courses: [italian], words: [
            word("it", "it_it", "Italian"), word("et", "et-EE", "Estonian"),
            word("et-2", "ET_ee", "Estonian"), word("invalid", " ", "Unknown")
        ])
        XCTAssertEqual(list.languages.map(\.name), ["Estonian", "Italian"])
        XCTAssertEqual(list.languages.first?.courseCount, 0)
        XCTAssertEqual(list.languages.first?.lessonCount, 0)
        XCTAssertEqual(list.languages.last?.code, "it-IT")
        XCTAssertEqual(list.languages.last?.lessonCount, 1)
    }

    private func language(_ code: String, _ name: String) -> MobileLanguageOption {
        MobileLanguageOption(code: code, name: name, courseCount: 0, lessonCount: 1)
    }

    private func word(_ id: String, _ code: String, _ name: String) -> MobileSavedWord {
        MobileSavedWord(id: id, term: id, meaning: "meaning", note: "", context: "", languageCode: code,
                        languageName: name, status: "new", kind: "word", sourceLessonID: nil,
                        sourceLessonTitle: nil, dialect: nil, pronunciation: nil, partOfSpeech: nil)
    }
}
