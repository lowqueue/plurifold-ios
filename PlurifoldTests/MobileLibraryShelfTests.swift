import XCTest
@testable import Plurifold

final class MobileLibraryShelfTests: XCTestCase {
    func testMaterialLevelsSortNumericallyAndUnknownLevelsStayUnassessed() throws {
        let lessons = try [
            lesson("two", level: "2"), lesson("one-plus", level: "1+"),
            lesson("missing"), lesson("one", level: "1"), lesson("invalid", level: "Advanced")
        ]
        let shelf = MobileLibraryShelf(courses: [course("videos", lessons: lessons)])
        XCTAssertEqual(shelf.availableLevels, ["1", "1+", "2", "unassessed"])
        XCTAssertEqual(shelf.lessonGroups.map(\.level), ["1", "1+", "2", "unassessed"])
        XCTAssertEqual(shelf.lessonGroups.last?.lessons.map(\.id), ["missing", "invalid"])
        XCTAssertEqual(shelf.totalLessonCount, 5)
    }

    func testFiltersCombineWithoutChangingAvailableOptionsOrExposingChapters() throws {
        let courses = try [
            course("foundations", lessons: [lesson("chapter", kind: "course", channel: "Course", level: "1")]),
            course("videos", lessons: [
                lesson("cats", title: "Five cats at night", channel: "Italiano sì", level: "1"),
                lesson("story", title: "Another story", channel: "Italiano sì", level: "2"),
                lesson("radio", title: "Five animals", channel: "Radio Arlecchino", level: "1")
            ])
        ]
        let shelf = MobileLibraryShelf(courses: courses, search: "five", channel: "Italiano sì", level: "1")
        XCTAssertEqual(shelf.visibleLessonCount, 1)
        XCTAssertEqual(shelf.totalLessonCount, 3)
        XCTAssertEqual(shelf.lessonGroups.flatMap(\.lessons).map(\.id), ["cats"])
        XCTAssertEqual(shelf.availableChannels, ["Italiano sì", "Radio Arlecchino"])
        XCTAssertEqual(shelf.availableLevels, ["1", "2"])
        XCTAssertEqual(MobileLibraryShelf(courses: courses, channel: "No match").courseFolders.count, 1)
    }

    func testSearchingAChapterRetainsItsFolderAndFullChapterCount() throws {
        let chapters = try [lesson("one", title: "Greetings", kind: "course"),
                            lesson("two", title: "Food", kind: "course")]
        let shelf = MobileLibraryShelf(courses: [course("foundations", lessons: chapters)], search: "food")
        XCTAssertEqual(shelf.courseFolders.first?.chapters.map(\.id), ["two"])
        XCTAssertEqual(shelf.courseFolders.first?.course.lessons.count, 2)
        XCTAssertEqual(shelf.totalLessonCount, 0)
        XCTAssertTrue(shelf.lessonGroups.isEmpty)
    }

    func testOlderMetadataUsesSourceFallbackAndNoInventedLevel() throws {
        let shelf = MobileLibraryShelf(courses: [course("Local audio", lessons: [try lesson("audio")])])
        XCTAssertEqual(shelf.availableChannels, ["Local audio"])
        XCTAssertEqual(shelf.lessonGroups.first?.title, "ILR unassessed")
        XCTAssertEqual(shelf.lessonGroups.first?.lessons.first?.source, "Local audio")
        XCTAssertNil(shelf.lessonGroups.first?.lessons.first?.lesson.wordCount)
    }

    func testOldCatalogSummariesDecodeWithoutPresentationMetadata() throws {
        let summary = try lesson("older-api")
        XCTAssertNil(summary.thumbnailURL)
        XCTAssertNil(summary.mediaKind)
        XCTAssertNil(summary.ilrLevel)
        XCTAssertNil(summary.wordCount)
        XCTAssertNil(summary.uniqueWordCount)
        XCTAssertNil(summary.newWordCount)
        XCTAssertNil(summary.newWordPercent)
    }

    func testNewCatalogSummariesDecodeTheSuppliedCoverAndVocabularyCounts() throws {
        let payload: [String: Any] = [
            "id": "cats", "title": "Five cats", "subtitle": "", "kind": "lesson",
            "languageCode": "it-IT", "languageName": "Italian", "paragraphCount": 107,
            "thumbnailURL": "https://i.ytimg.com/vi/abcdefghijk/hqdefault.jpg",
            "mediaKind": "video", "ilrLevel": "1+", "wordCount": 91,
            "uniqueWordCount": 75, "newWordCount": 34, "newWordPercent": 45
        ]
        let summary = try JSONDecoder().decode(MobileLessonSummary.self,
            from: JSONSerialization.data(withJSONObject: payload))
        XCTAssertEqual(summary.thumbnailURL, "https://i.ytimg.com/vi/abcdefghijk/hqdefault.jpg")
        XCTAssertEqual(summary.mediaKind, "video")
        XCTAssertEqual(summary.ilrLevel, "1+")
        XCTAssertEqual(summary.wordCount, 91)
        XCTAssertEqual(summary.uniqueWordCount, 75)
        XCTAssertEqual(summary.newWordCount, 34)
        XCTAssertEqual(summary.newWordPercent, 45)
    }

    private func lesson(_ id: String, title: String = "Lesson", kind: String = "lesson",
                        channel: String? = nil, level: String? = nil) throws -> MobileLessonSummary {
        var payload: [String: Any] = [
            "id": id, "title": title, "subtitle": "", "kind": kind,
            "languageCode": "it-IT", "languageName": "Italian", "paragraphCount": 12
        ]
        if let channel { payload["channel"] = channel }
        if let level { payload["ilrLevel"] = level }
        return try JSONDecoder().decode(MobileLessonSummary.self,
                                       from: JSONSerialization.data(withJSONObject: payload))
    }

    private func course(_ id: String, lessons: [MobileLessonSummary]) -> MobileCourse {
        MobileCourse(id: id, title: id, languageCode: "it-IT", languageName: "Italian", lessons: lessons)
    }
}
