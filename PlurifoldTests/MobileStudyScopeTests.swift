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
        XCTAssertEqual(scope.homePath, [.library(italian)])
        XCTAssertEqual(scope.tab, .home)

        scope.tab = .review
        let estonian = language("et-EE", "Estonian")
        scope.selectLanguage(estonian)
        XCTAssertEqual(scope.language?.code, "et-EE")
        XCTAssertEqual(scope.homePath, [.library(estonian)])
    }

    func testPickerPopsToHomeWithoutLosingCurrentChoiceAndNewAccountStartsEmpty() {
        let scope = MobileStudyScope()
        scope.selectLanguage(language("it-IT", "Italian"))
        scope.tab = .review
        scope.showLanguagePicker()
        XCTAssertTrue(scope.homePath.isEmpty)
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

    func testSwitchingLanguagesReplacesEveryNestedDestination() {
        let scope = MobileStudyScope()
        let italian = language("it-IT", "Italian")
        let estonian = language("et-EE", "Estonian")
        scope.selectLanguage(italian)
        scope.homePath.append(.course(id: "course", search: "greetings"))
        scope.homePath.append(.lesson(id: "chapter"))
        scope.selectLanguage(estonian)
        XCTAssertEqual(scope.homePath, [.library(estonian)])
        XCTAssertEqual(scope.language, estonian)
        XCTAssertEqual(scope.tab, .home)
    }

    func testLibraryMenuReturnsToCurrentLibraryAndHomeClearsFullPath() {
        let scope = MobileStudyScope()
        let italian = language("it-IT", "Italian")
        scope.selectLanguage(italian)
        scope.homePath.append(.lesson(id: "cats"))
        scope.selectLanguage(italian)
        XCTAssertEqual(scope.homePath, [.library(italian)])
        scope.homePath.append(.course(id: "course", search: ""))
        scope.homePath.append(.lesson(id: "chapter"))
        scope.showLanguagePicker()
        XCTAssertTrue(scope.homePath.isEmpty)
        XCTAssertEqual(scope.language, italian)
    }

    func testCatalogRefreshDoesNotChangeAnOpenNavigationPath() {
        let scope = MobileStudyScope()
        let italian = language("it-IT", "Italian")
        scope.selectLanguage(italian)
        scope.homePath.append(.lesson(id: "cats"))
        let path = scope.homePath
        let updated = MobileLanguageOption(code: "it-IT", name: "Italian", courseCount: 4, lessonCount: 12)
        scope.reconcile(languages: [updated])
        XCTAssertEqual(scope.language, updated)
        XCTAssertEqual(scope.homePath, path)
        XCTAssertEqual(MobileStudyRoute.library(italian), MobileStudyRoute.library(updated))
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
