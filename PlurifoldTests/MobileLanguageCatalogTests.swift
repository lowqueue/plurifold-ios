import XCTest
@testable import Plurifold

final class MobileLanguageCatalogTests: XCTestCase {
    func testHomeDeduplicatesLanguagesAndCountsCoursesSeparatelyFromLessons() throws {
        let catalog = MobileLanguageCatalog(courses: [
            group("it-video", code: "it-IT", name: "Italian", kinds: ["lesson", "lesson"]),
            group("ka-course", code: "ka-GE", name: "Georgian", kinds: ["course", "course"]),
            group("it-course", code: "it-IT", name: "Italian", kinds: ["course", "lesson"])
        ])

        XCTAssertEqual(catalog.languages.map(\.name), ["Georgian", "Italian"])
        let italian = try XCTUnwrap(catalog.language(for: "it-IT"))
        XCTAssertEqual(italian.courseCount, 1)
        XCTAssertEqual(italian.lessonCount, 3)
        let georgian = try XCTUnwrap(catalog.language(for: "ka-GE"))
        XCTAssertEqual(georgian.courseCount, 1)
        XCTAssertEqual(georgian.lessonCount, 0)
    }

    func testOnlyLanguagesWithAccessibleContentAppearAndNamesHaveAFallback() {
        let catalog = MobileLanguageCatalog(courses: [
            group("empty", code: "et-EE", name: "Estonian", kinds: []),
            group("missing-code", code: "  ", name: "Unknown", kinds: ["lesson"]),
            group("unnamed", code: "ka-GE", name: "  ", kinds: ["course"]),
            group("named", code: "ka-GE", name: "Georgian", kinds: ["lesson"]),
            group("future", code: "xx", name: "", kinds: ["lesson"])
        ])

        XCTAssertEqual(catalog.languages.count, 2)
        XCTAssertEqual(catalog.language(for: "ka-GE")?.name, "Georgian")
        XCTAssertEqual(catalog.language(for: "xx")?.name, "xx")
        XCTAssertNil(catalog.language(for: "et-EE"))
        XCTAssertTrue(catalog.courses(for: "  ").isEmpty)
    }

    func testInvalidOrRemovedLanguageNeverOpensTheWholeLibrary() {
        let italian = group("italian", code: "it-IT", name: "Italian", kinds: ["lesson"])
        let georgian = group("georgian", code: "ka-GE", name: "Georgian", kinds: ["course"])
        let catalog = MobileLanguageCatalog(courses: [italian, georgian])

        XCTAssertEqual(catalog.courses(for: "it-IT").map(\.id), ["italian"])
        XCTAssertTrue(catalog.courses(for: "").isEmpty)
        XCTAssertTrue(catalog.courses(for: "unknown").isEmpty)
        let refreshed = MobileLanguageCatalog(courses: [georgian])
        XCTAssertNil(refreshed.language(for: "it-IT"))
        XCTAssertTrue(refreshed.courses(for: "it-IT").isEmpty)
        XCTAssertTrue(MobileLibraryIndex(courses: refreshed.courses(for: "it-IT")).isEmpty)
    }

    private func group(_ id: String, code: String, name: String, kinds: [String]) -> MobileCourse {
        MobileCourse(id: id, title: id, languageCode: code, languageName: name,
                     lessons: kinds.enumerated().map { index, kind in
            MobileLessonSummary(id: "\(id)-\(index)", title: "Lesson \(index)", subtitle: "",
                                languageCode: code, languageName: name, dialect: nil,
                                paragraphCount: 1, kind: kind, channel: nil)
        })
    }
}
