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

    func testCoursePreviousAndNextReplaceReaderAndKeepOutline() {
        let scope = MobileStudyScope()
        let italian = language("it-IT", "Italian")
        let course = activityCourse()
        scope.selectLanguage(italian)
        scope.homePath.append(.course(id: course.id, search: ""))
        scope.homePath.append(.lesson(id: "first"))
        scope.openCourseActivity("second", in: course)
        XCTAssertEqual(scope.homePath, [.library(italian), .course(id: course.id, search: ""), .lesson(id: "second")])
        scope.openCourseActivity("first", in: course)
        XCTAssertEqual(scope.homePath.count, 3)
        XCTAssertEqual(scope.homePath.last, .lesson(id: "first"))
    }

    func testCourseNavigationRejectsUnknownChapterAndStaleLanguage() {
        let scope = MobileStudyScope()
        let course = activityCourse()
        scope.selectLanguage(language("it-IT", "Italian"))
        scope.homePath.append(.course(id: course.id, search: ""))
        let path = scope.homePath
        scope.openCourseActivity("unknown", in: course)
        XCTAssertEqual(scope.homePath, path)
        scope.selectLanguage(language("et-EE", "Estonian"))
        let changedLanguagePath = scope.homePath
        scope.openCourseActivity("first", in: course)
        XCTAssertEqual(scope.homePath, changedLanguagePath)
    }

    func testEdgeSwipeOpensSidebarAtHomeAndLanguageLibraryWithoutChangingLanguage() {
        let scope = MobileStudyScope()
        scope.completeEdgeNavigation(scope.edgeNavigationIntent)
        XCTAssertTrue(scope.isSidebarPresented)
        XCTAssertTrue(scope.homePath.isEmpty)

        let italian = language("it-IT", "Italian")
        scope.selectLanguage(italian)
        XCTAssertFalse(scope.isSidebarPresented)
        scope.completeEdgeNavigation(scope.edgeNavigationIntent)
        XCTAssertTrue(scope.isSidebarPresented)
        XCTAssertEqual(scope.homePath, [.library(italian)])
        XCTAssertEqual(scope.language, italian)
    }

    func testEdgeSwipePopsOneCourseOrLessonAndDoesNotOpenSidebar() {
        let scope = MobileStudyScope()
        let italian = language("it-IT", "Italian")
        scope.selectLanguage(italian)
        scope.homePath.append(.course(id: "course", search: "greeting"))
        scope.homePath.append(.lesson(id: "chapter"))
        scope.completeEdgeNavigation(scope.edgeNavigationIntent)
        XCTAssertEqual(scope.homePath, [.library(italian), .course(id: "course", search: "greeting")])
        XCTAssertFalse(scope.isSidebarPresented)
        scope.completeEdgeNavigation(scope.edgeNavigationIntent)
        XCTAssertEqual(scope.homePath, [.library(italian)])
        XCTAssertFalse(scope.isSidebarPresented)

        scope.homePath.append(.lesson(id: "video"))
        scope.completeEdgeNavigation(scope.edgeNavigationIntent)
        XCTAssertEqual(scope.homePath, [.library(italian)])
        XCTAssertFalse(scope.isSidebarPresented)
    }

    func testInactiveHomeReaderDoesNotHijackOtherTabsEdgeSwipe() {
        for tab in [MobileStudyTab.words, .review, .account] {
            let scope = MobileStudyScope()
            scope.selectLanguage(language("it-IT", "Italian"))
            scope.homePath.append(.course(id: "course", search: ""))
            scope.homePath.append(.lesson(id: "chapter"))
            let retainedPath = scope.homePath
            scope.tab = tab
            scope.completeEdgeNavigation(scope.edgeNavigationIntent)
            XCTAssertTrue(scope.isSidebarPresented)
            XCTAssertEqual(scope.tab, tab)
            XCTAssertEqual(scope.homePath, retainedPath)
        }
    }

    func testStaleOrRepeatedEdgeCompletionCannotPopAnotherScreen() {
        let scope = MobileStudyScope()
        scope.selectLanguage(language("it-IT", "Italian"))
        scope.homePath.append(.course(id: "course", search: ""))
        scope.homePath.append(.lesson(id: "chapter"))
        let intent = scope.edgeNavigationIntent
        scope.completeEdgeNavigation(intent)
        let outline = scope.homePath
        scope.completeEdgeNavigation(intent)
        XCTAssertEqual(scope.homePath, outline)
        XCTAssertFalse(scope.isSidebarPresented)

        let courseIntent = scope.edgeNavigationIntent
        scope.tab = .review
        scope.completeEdgeNavigation(courseIntent)
        XCTAssertEqual(scope.homePath, outline)
        XCTAssertFalse(scope.isSidebarPresented)

        scope.selectLanguage(language("et-EE", "Estonian"))
        let changedLanguagePath = scope.homePath
        scope.completeEdgeNavigation(courseIntent)
        XCTAssertEqual(scope.homePath, changedLanguagePath)
        XCTAssertFalse(scope.isSidebarPresented)
    }

    func testSidebarAlreadyOpenBlocksBackNavigationUnderneath() {
        let scope = MobileStudyScope()
        scope.homePath = [.lesson(id: "lesson")]
        let intent = scope.edgeNavigationIntent
        scope.isSidebarPresented = true
        scope.completeEdgeNavigation(intent)
        XCTAssertEqual(scope.homePath, [.lesson(id: "lesson")])
        XCTAssertTrue(scope.isSidebarPresented)
        XCTAssertFalse(MobileStudyScope().isSidebarPresented)
    }

    func testEdgeSwipeAcceptsDeliberateSlowPullAndQuickFling() {
        XCTAssertTrue(MobileEdgeSwipe.shouldComplete(horizontal: 96, vertical: 8, velocity: 0, width: 390))
        XCTAssertTrue(MobileEdgeSwipe.shouldComplete(horizontal: 26, vertical: 4, velocity: 900, width: 390))
        XCTAssertFalse(MobileEdgeSwipe.shouldComplete(horizontal: 12, vertical: 0, velocity: 900, width: 390))
        XCTAssertFalse(MobileEdgeSwipe.shouldComplete(horizontal: 30, vertical: 4, velocity: 30, width: 390))
        XCTAssertFalse(MobileEdgeSwipe.shouldComplete(horizontal: 100, vertical: 150, velocity: 900, width: 390))
        XCTAssertFalse(MobileEdgeSwipe.shouldComplete(horizontal: -120, vertical: 0, velocity: -900, width: 390))
        XCTAssertFalse(MobileEdgeSwipe.shouldComplete(horizontal: 100, vertical: 0, velocity: -250, width: 390))
    }

    private func activityCourse() -> MobileCourse {
        MobileCourse(id: "course", title: "Course", languageCode: "it-IT", languageName: "Italian",
                     lessons: ["first", "second"].map { id in
            MobileLessonSummary(id: id, title: id, subtitle: "", languageCode: "it-IT", languageName: "Italian",
                                dialect: nil, paragraphCount: 1, kind: "course", channel: nil)
        })
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
