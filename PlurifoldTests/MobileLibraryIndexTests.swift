import XCTest
@testable import Plurifold

final class MobileLibraryIndexTests: XCTestCase {
    func testChaptersStayInFoldersAndLessonTitlesDoNotDetermineTheirCategory() throws {
        let chapter = lesson("chapter-1", title: "1. Greetings", kind: "course")
        let video = lesson("video-1", title: "Foundations of Georgian", kind: "lesson")
        let index = MobileLibraryIndex(courses: [group("mixed", lessons: [chapter, video])])

        let folder = try XCTUnwrap(index.courseFolders.first)
        XCTAssertEqual(folder.chapters.map(\.id), ["chapter-1"])
        XCTAssertEqual(folder.course.lessons.map(\.id), ["chapter-1"])
        XCTAssertEqual(index.lessonGroups.flatMap(\.lessons).map(\.id), ["video-1"])
    }

    func testChapterSearchRetainsCourseIdentityAndFullChapterCount() throws {
        let chapters = [lesson("one", title: "1. Greetings", kind: "course"),
                        lesson("two", title: "2. Food and drink", kind: "course"),
                        lesson("three", title: "3. At the market", kind: "course")]
        let catalog = [group("geofl-a1-lesson-1", lessons: chapters)]
        let index = MobileLibraryIndex(courses: catalog, search: "  food  ")

        let folder = try XCTUnwrap(index.courseFolders.first)
        XCTAssertEqual(folder.id, "geofl-a1-lesson-1")
        XCTAssertEqual(folder.chapters.map(\.id), ["two"])
        XCTAssertEqual(folder.course.lessons.count, 3)
        XCTAssertTrue(index.lessonGroups.isEmpty)
        XCTAssertEqual(MobileLibraryIndex(courses: catalog).courseFolders.first?.chapters.map(\.id),
                       ["one", "two", "three"])
    }

    func testCourseTitleSearchIncludesItsChaptersInOrder() throws {
        let chapters = [lesson("two", title: "2. Food", kind: "course"),
                        lesson("ten", title: "10. Weather", kind: "course")]
        let catalog = [group("course", title: "Colloquial Georgian", lessons: chapters)]
        let index = MobileLibraryIndex(courses: catalog, search: "COLLOQUIAL")
        XCTAssertEqual(try XCTUnwrap(index.courseFolders.first).chapters.map(\.id), ["two", "ten"])
    }

    func testLanguageFilterAndChannelOrDialectSearchApplyToBothAreas() {
        let georgian = group("course", lessons: [lesson("one", title: "Greetings", kind: "course")])
        let italian = MobileCourse(id: "library:it-IT:Italiano si", title: "Italiano sì",
                                   languageCode: "it-IT", languageName: "Italian",
                                   lessons: [MobileLessonSummary(id: "cats", title: "Five cats at night", subtitle: "A story",
                                      languageCode: "it-IT", languageName: "Italian", dialect: "Tuscan",
                                      paragraphCount: 107, kind: "lesson", channel: "Italiano sì")])
        let catalog = [georgian, italian]

        let byChannel = MobileLibraryIndex(courses: catalog, search: "Italiano", languageCode: "it-IT")
        XCTAssertTrue(byChannel.courseFolders.isEmpty)
        XCTAssertEqual(byChannel.lessonGroups.flatMap(\.lessons).map(\.id), ["cats"])
        XCTAssertEqual(MobileLibraryIndex(courses: catalog, search: "Tuscan").lessonGroups.count, 1)
        XCTAssertTrue(MobileLibraryIndex(courses: catalog, search: "Italiano", languageCode: "ka-GE").isEmpty)
        XCTAssertEqual(MobileLibraryIndex(courses: catalog, languageCode: "ka-GE").courseFolders.count, 1)
        XCTAssertTrue(MobileLibraryIndex(courses: catalog, search: "nothing matches").isEmpty)
    }

    private func lesson(_ id: String, title: String, kind: String) -> MobileLessonSummary {
        MobileLessonSummary(id: id, title: title, subtitle: "", languageCode: "ka-GE", languageName: "Georgian",
                            dialect: nil, paragraphCount: 10, kind: kind, channel: nil)
    }

    private func group(_ id: String, title: String = "Georgian Foundations", lessons: [MobileLessonSummary]) -> MobileCourse {
        MobileCourse(id: id, title: title, languageCode: "ka-GE", languageName: "Georgian", lessons: lessons)
    }
}
