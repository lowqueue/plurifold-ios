import Foundation
import XCTest
@testable import Plurifold

@MainActor
final class StudyStoreTests: XCTestCase {
    func testReadingStartsAtZeroAndInvalidPositionsDoNotChangeProgress() {
        withDefaults { defaults in
            let catalog = fixture()
            let store = StudyStore(catalog: catalog, defaults: defaults)
            let lesson = catalog.courses[0].lessons[0]

            XCTAssertEqual(store.progress(for: lesson), 0)
            XCTAssertNil(store.lastParagraph(for: lesson))
            store.recordParagraph(-1, for: lesson)
            store.recordParagraph(lesson.paragraphs.count, for: lesson)
            XCTAssertNil(store.lastParagraph(for: lesson))

            store.recordParagraph(0, for: lesson)
            XCTAssertEqual(store.progress(for: lesson), 0.5)
            XCTAssertFalse(store.completedLessonIDs.contains(lesson.id))
            store.recordParagraph(1, for: lesson)
            store.recordParagraph(0, for: lesson)
            XCTAssertEqual(store.lastParagraph(for: lesson), 1)
            XCTAssertEqual(store.progress(for: lesson), 1)
            // Finishing the reader alone does not mark practice as complete.
            XCTAssertEqual(store.completionFraction(for: catalog.courses[0]), 0)
        }
    }

    func testSelectionWordsAndProgressSurviveReload() {
        withDefaults { defaults in
            let catalog = fixture()
            let firstLesson = catalog.courses[0].lessons[0]
            let secondLesson = catalog.courses[1].lessons[0]
            let store = StudyStore(catalog: catalog, defaults: defaults)
            store.chooseCourse(catalog.courses[1].id)
            store.toggleSaved(firstLesson.vocabulary[0].id)
            store.complete(firstLesson, score: 1)
            store.recordParagraph(0, for: secondLesson)

            let restored = StudyStore(catalog: catalog, defaults: defaults)
            XCTAssertEqual(restored.selectedCourse.id, catalog.courses[1].id)
            XCTAssertTrue(restored.isSaved(firstLesson.vocabulary[0].id))
            XCTAssertEqual(restored.savedWords.count, 1)
            XCTAssertEqual(restored.savedWords.first?.lessonID, firstLesson.id)
            XCTAssertEqual(restored.savedWords.first?.languageName, "Italian")
            XCTAssertEqual(restored.bestScore(for: firstLesson), 1)
            XCTAssertEqual(restored.completionFraction(for: catalog.courses[0]), 1)
            XCTAssertEqual(restored.progress(for: secondLesson), 0.5)
            XCTAssertNil(restored.storageNotice)
        }
    }

    func testRestoreDiscardsUnknownIdentifiersAndInvalidValues() throws {
        let catalog = fixture()
        let firstLesson = catalog.courses[0].lessons[0]
        let secondLesson = catalog.courses[1].lessons[0]
        let snapshot: [String: Any] = [
            "schemaVersion": 1,
            "selectedCourseID": "removed-course",
            "savedWordIDs": [firstLesson.vocabulary[0].id, "removed-word"],
            "completedLessonIDs": [firstLesson.id, "removed-lesson"],
            "lastParagraphByLesson": [firstLesson.id: 99, secondLesson.id: 0, "removed-lesson": 0],
            "bestScores": [firstLesson.id: -1, secondLesson.id: 99, "removed-lesson": 1]
        ]
        let data = try JSONSerialization.data(withJSONObject: snapshot)
        withDefaults { defaults in
            defaults.set(data, forKey: StudyStore.persistenceKey)
            let store = StudyStore(catalog: catalog, defaults: defaults)
            XCTAssertEqual(store.selectedCourse.id, catalog.courses[0].id)
            XCTAssertEqual(store.savedWordIDs, Set([firstLesson.vocabulary[0].id]))
            XCTAssertEqual(store.completedLessonIDs, Set([firstLesson.id]))
            XCTAssertEqual(store.lastParagraphByLesson, [secondLesson.id: 0])
            XCTAssertTrue(store.bestScores.isEmpty)

            store.chooseCourse("removed-course")
            store.toggleSaved("removed-word")
            XCTAssertEqual(store.selectedCourse.id, catalog.courses[0].id)
            XCTAssertEqual(store.savedWordIDs.count, 1)
        }
    }

    func testCompletionPreservesBestScoreAndBoundsNewScores() {
        withDefaults { defaults in
            let catalog = fixture()
            let lesson = catalog.courses[0].lessons[0]
            let store = StudyStore(catalog: catalog, defaults: defaults)
            store.complete(lesson, score: -4)
            XCTAssertEqual(store.bestScore(for: lesson), 0)
            store.complete(lesson, score: 1)
            store.complete(lesson, score: 0)
            XCTAssertEqual(store.bestScore(for: lesson), 1)
            store.complete(lesson, score: 999)
            XCTAssertEqual(store.bestScore(for: lesson), lesson.questions.count)
            XCTAssertEqual(store.progress(for: lesson), 1)
            XCTAssertEqual(store.completionFraction(for: catalog.courses[0]), 1)
        }
    }

    func testResetPreservesSavedVocabularyAndLanguageSelection() {
        withDefaults { defaults in
            let catalog = fixture()
            let lesson = catalog.courses[0].lessons[0]
            let store = StudyStore(catalog: catalog, defaults: defaults)
            store.chooseCourse(catalog.courses[1].id)
            store.toggleSaved(lesson.vocabulary[0].id)
            store.complete(lesson, score: 1)
            store.resetProgress()

            let restored = StudyStore(catalog: catalog, defaults: defaults)
            XCTAssertTrue(restored.completedLessonIDs.isEmpty)
            XCTAssertTrue(restored.bestScores.isEmpty)
            XCTAssertTrue(restored.lastParagraphByLesson.isEmpty)
            XCTAssertEqual(restored.progress(for: lesson), 0)
            XCTAssertTrue(restored.isSaved(lesson.vocabulary[0].id))
            XCTAssertEqual(restored.selectedCourse.id, catalog.courses[1].id)
        }
    }

    func testCorruptPersistenceShowsNoticeAndCanRecoverThroughNewActivity() {
        withDefaults { defaults in
            defaults.set(Data("broken JSON".utf8), forKey: StudyStore.persistenceKey)
            let catalog = fixture()
            let store = StudyStore(catalog: catalog, defaults: defaults)
            XCTAssertNotNil(store.storageNotice)
            XCTAssertTrue(store.savedWordIDs.isEmpty)

            store.toggleSaved(catalog.courses[0].lessons[0].vocabulary[0].id)
            XCTAssertNil(store.storageNotice)
            let restored = StudyStore(catalog: catalog, defaults: defaults)
            XCTAssertEqual(restored.savedWordIDs.count, 1)
            XCTAssertNil(restored.storageNotice)
        }
    }

    func testFutureSnapshotVersionIsNotInterpretedAsCurrentData() throws {
        let catalog = fixture()
        let snapshot: [String: Any] = [
            "schemaVersion": 2,
            "selectedCourseID": catalog.courses[1].id,
            "savedWordIDs": [catalog.courses[0].lessons[0].vocabulary[0].id],
            "completedLessonIDs": [],
            "lastParagraphByLesson": [:],
            "bestScores": [:]
        ]
        let data = try JSONSerialization.data(withJSONObject: snapshot)
        withDefaults { defaults in
            defaults.set(data, forKey: StudyStore.persistenceKey)
            let store = StudyStore(catalog: catalog, defaults: defaults)
            XCTAssertNotNil(store.storageNotice)
            XCTAssertEqual(store.selectedCourse.id, catalog.courses[0].id)
            XCTAssertTrue(store.savedWordIDs.isEmpty)
            // Loading alone must not overwrite a record from a different version.
            XCTAssertEqual(defaults.data(forKey: StudyStore.persistenceKey), data)
        }
    }

    func testCatalogValidationRejectsDuplicateIdentifiersAndMissingContent() throws {
        let valid = fixture()
        XCTAssertNoThrow(try valid.validate())
        XCTAssertThrowsError(try StudyCatalog(courses: []).validate())
        XCTAssertThrowsError(try StudyCatalog(courses: [valid.courses[0], valid.courses[0]]).validate())
        let emptyCourse = Course(
            id: "empty-course", title: "Empty", subtitle: "", languageName: "Italian",
            languageCode: "it-IT", symbol: "book", lessons: []
        )
        XCTAssertThrowsError(try StudyCatalog(courses: [emptyCourse]).validate())

        let emptyLesson = Lesson(
            id: "empty-lesson", title: "Empty", subtitle: "", minutes: 1,
            paragraphs: [], vocabulary: [], questions: []
        )
        XCTAssertThrowsError(try catalog(with: emptyLesson).validate())
    }

    func testCatalogValidationRejectsOutOfBoundsPracticeAnswer() {
        let lesson = fixture().courses[0].lessons[0]
        for answerIndex in [-1, 2] {
            let invalidLesson = Lesson(
                id: lesson.id, title: lesson.title, subtitle: lesson.subtitle, minutes: lesson.minutes,
                paragraphs: lesson.paragraphs, vocabulary: lesson.vocabulary,
                questions: [PracticeQuestion(
                    id: "invalid-answer", prompt: "Choose the meaning.", options: ["Hello", "Goodbye"],
                    answerIndex: answerIndex, explanation: "This answer is invalid."
                )]
            )
            XCTAssertThrowsError(try catalog(with: invalidLesson).validate())
        }
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "PlurifoldTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            XCTFail("Could not create isolated preferences.")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    private func fixture() -> StudyCatalog {
        let italian = lesson(id: "it-lesson", term: "ciao", text: "Ciao, come stai?")
        let spanish = lesson(id: "es-lesson", term: "hola", text: "Hola, ¿cómo estás?")
        return StudyCatalog(courses: [
            Course(
                id: "it-course", title: "First steps", subtitle: "Italian foundations",
                languageName: "Italian", languageCode: "it-IT", symbol: "sun.max",
                lessons: [italian]
            ),
            Course(
                id: "es-course", title: "First steps", subtitle: "Spanish foundations",
                languageName: "Spanish", languageCode: "es-ES", symbol: "sun.max",
                lessons: [spanish]
            )
        ])
    }

    private func lesson(id: String, term: String, text: String) -> Lesson {
        Lesson(
            id: id, title: "A greeting", subtitle: "Meet someone new", minutes: 2,
            paragraphs: [
                LessonParagraph(id: "\(id)-p1", text: text, translation: "Hello, how are you?"),
                LessonParagraph(id: "\(id)-p2", text: term, translation: "Hello")
            ],
            vocabulary: [VocabularyEntry(
                id: "\(id)-word", term: term, meaning: "hello", note: "A greeting", example: text
            )],
            questions: [PracticeQuestion(
                id: "\(id)-q1", prompt: "What does ‘\(term)’ mean?", options: ["Hello", "Thank you"],
                answerIndex: 0, explanation: "‘\(term)’ is a greeting."
            )]
        )
    }

    private func catalog(with lesson: Lesson) -> StudyCatalog {
        StudyCatalog(courses: [Course(
            id: "test-course", title: "Test", subtitle: "", languageName: "Italian",
            languageCode: "it-IT", symbol: "book", lessons: [lesson]
        )])
    }
}
