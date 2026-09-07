import Combine
import Foundation

/// Device-local prototype progress. This store does not connect to website accounts.
@MainActor
final class StudyStore: ObservableObject {
    static let persistenceKey = "plurifold.ios.prototype.study.v1"

    let catalog: StudyCatalog
    @Published private(set) var selectedCourseID: String
    @Published private(set) var savedWordIDs: Set<String>
    @Published private(set) var completedLessonIDs: Set<String>
    @Published private(set) var lastParagraphByLesson: [String: Int]
    @Published private(set) var bestScores: [String: Int]
    @Published var storageNotice: String?

    private let defaults: UserDefaults
    private let lessonsByID: [String: Lesson]
    private let knownWordIDs: Set<String>

    init(catalog: StudyCatalog, defaults: UserDefaults = .standard) {
        do {
            try catalog.validate()
        } catch {
            preconditionFailure("StudyStore requires a validated catalog: \(error.localizedDescription)")
        }
        self.catalog = catalog
        self.defaults = defaults
        let lessons = catalog.courses.flatMap(\.lessons)
        self.lessonsByID = Dictionary(uniqueKeysWithValues: lessons.map { ($0.id, $0) })
        self.knownWordIDs = Set(lessons.flatMap(\.vocabulary).map(\.id))
        self.selectedCourseID = catalog.courses[0].id
        self.savedWordIDs = []
        self.completedLessonIDs = []
        self.lastParagraphByLesson = [:]
        self.bestScores = [:]
        self.storageNotice = nil

        restore()
    }

    var selectedCourse: Course {
        catalog.courses.first { $0.id == selectedCourseID } ?? catalog.courses[0]
    }

    var savedWords: [SavedWord] {
        catalog.courses.flatMap { course in
            course.lessons.flatMap { lesson in
                lesson.vocabulary.compactMap { entry -> SavedWord? in
                    guard savedWordIDs.contains(entry.id) else { return nil }
                    return SavedWord(
                        entry: entry,
                        lessonID: lesson.id,
                        lessonTitle: lesson.title,
                        languageName: course.languageName,
                        languageCode: course.languageCode
                    )
                }
            }
        }
    }

    func chooseCourse(_ id: String) {
        guard catalog.courses.contains(where: { $0.id == id }), selectedCourseID != id else { return }
        selectedCourseID = id
        persist()
    }

    func isSaved(_ id: String) -> Bool {
        savedWordIDs.contains(id)
    }

    func toggleSaved(_ id: String) {
        guard knownWordIDs.contains(id) else { return }
        if savedWordIDs.contains(id) {
            savedWordIDs.remove(id)
        } else {
            savedWordIDs.insert(id)
        }
        persist()
    }

    /// Keep the furthest visited paragraph so reading an earlier passage cannot erase progress.
    func recordParagraph(_ index: Int, for lesson: Lesson) {
        guard let knownLesson = lessonsByID[lesson.id], knownLesson.paragraphs.indices.contains(index) else { return }
        if let previous = lastParagraphByLesson[lesson.id], index <= previous { return }
        lastParagraphByLesson[lesson.id] = index
        persist()
    }

    func complete(_ lesson: Lesson, score: Int) {
        guard let knownLesson = lessonsByID[lesson.id] else { return }
        let boundedScore = min(max(score, 0), knownLesson.questions.count)
        completedLessonIDs.insert(lesson.id)
        lastParagraphByLesson[lesson.id] = knownLesson.paragraphs.count - 1
        bestScores[lesson.id] = max(bestScores[lesson.id] ?? 0, boundedScore)
        persist()
    }

    func progress(for lesson: Lesson) -> Double {
        guard let knownLesson = lessonsByID[lesson.id] else { return 0 }
        if completedLessonIDs.contains(lesson.id) { return 1 }
        guard let paragraph = lastParagraphByLesson[lesson.id] else { return 0 }
        return Double(paragraph + 1) / Double(knownLesson.paragraphs.count)
    }

    func completionFraction(for course: Course) -> Double {
        guard let knownCourse = catalog.courses.first(where: { $0.id == course.id }) else { return 0 }
        let completeCount = knownCourse.lessons.filter { completedLessonIDs.contains($0.id) }.count
        return Double(completeCount) / Double(knownCourse.lessons.count)
    }

    func bestScore(for lesson: Lesson) -> Int? {
        bestScores[lesson.id]
    }

    func lastParagraph(for lesson: Lesson) -> Int? {
        lastParagraphByLesson[lesson.id]
    }

    func resetProgress() {
        completedLessonIDs = []
        lastParagraphByLesson = [:]
        bestScores = [:]
        persist()
    }

    private func restore() {
        guard let storedObject = defaults.object(forKey: Self.persistenceKey) else { return }
        guard let data = storedObject as? Data else {
            storageNotice = "Saved study progress could not be read. New activity will start a fresh local record."
            return
        }
        do {
            let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
            guard snapshot.schemaVersion == 1 else {
                storageNotice = "This version cannot read the saved study progress. New activity will start a fresh local record."
                return
            }
            if catalog.courses.contains(where: { $0.id == snapshot.selectedCourseID }) {
                selectedCourseID = snapshot.selectedCourseID
            }
            savedWordIDs = snapshot.savedWordIDs.intersection(knownWordIDs)
            completedLessonIDs = snapshot.completedLessonIDs.intersection(Set(lessonsByID.keys))
            lastParagraphByLesson = snapshot.lastParagraphByLesson.filter { id, index in
                guard let lesson = lessonsByID[id] else { return false }
                return lesson.paragraphs.indices.contains(index)
            }
            bestScores = snapshot.bestScores.filter { id, score in
                guard let lesson = lessonsByID[id] else { return false }
                return (0...lesson.questions.count).contains(score)
            }
        } catch {
            storageNotice = "Saved study progress could not be read. New activity will start a fresh local record."
        }
    }

    private func persist() {
        let snapshot = Snapshot(
            schemaVersion: 1,
            selectedCourseID: selectedCourseID,
            savedWordIDs: savedWordIDs,
            completedLessonIDs: completedLessonIDs,
            lastParagraphByLesson: lastParagraphByLesson,
            bestScores: bestScores
        )
        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: Self.persistenceKey)
            storageNotice = nil
        } catch {
            storageNotice = "Your latest progress could not be saved on this device."
        }
    }

    private struct Snapshot: Codable {
        let schemaVersion: Int
        let selectedCourseID: String
        let savedWordIDs: Set<String>
        let completedLessonIDs: Set<String>
        let lastParagraphByLesson: [String: Int]
        let bestScores: [String: Int]
    }
}
