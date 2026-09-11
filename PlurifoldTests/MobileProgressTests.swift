import XCTest
@testable import Plurifold

final class MobileProgressTests: XCTestCase {
    func testMissingServerFieldsStayUnavailableInsteadOfInventingZeroProgress() throws {
        let response = try JSONDecoder().decode(MobileProgressResponse.self, from: Data("{}".utf8))
        XCTAssertNil(response.vocabulary)
        XCTAssertNil(response.lessons)
        XCTAssertNil(response.trophies)
        XCTAssertFalse(response.matches(languageCode: "it-IT"))
        XCTAssertEqual(MobileProgressVocabulary.display(nil), "Unavailable")
        XCTAssertEqual(MobileProgressVocabulary.display(-1), "Unavailable")
        XCTAssertEqual(MobileProgressVocabulary.display(0), "0")
    }

    func testKnownCoverageDoesNotIncludeLearningFamiliarOrIgnoredForms() throws {
        let row = try lesson(["uniqueWords": 20, "known": 4, "learning": 7, "familiar": 5, "ignored": 4])
        XCTAssertEqual(row.knownFraction, 0.2)
        XCTAssertEqual(row.percentage, "20%")
        XCTAssertFalse(row.allKnown)
        XCTAssertTrue(MobileProgressFilter.learning.includes(row))
        XCTAssertTrue(MobileProgressFilter.familiar.includes(row))
        XCTAssertFalse(MobileProgressFilter.known.includes(row))
    }

    func testCoverageRoundsDownAndEmptyOrUnknownLessonsAreNeverAllKnown() throws {
        XCTAssertEqual(try lesson(["uniqueWords": 200, "known": 199]).percentage, "99%")
        XCTAssertEqual(try lesson(["uniqueWords": 400, "known": 1]).percentage, "<1%")
        XCTAssertTrue(try lesson(["uniqueWords": 10, "known": 10]).allKnown)
        let empty = try lesson(["uniqueWords": 0, "known": 0])
        XCTAssertEqual(empty.percentage, "0%")
        XCTAssertFalse(empty.allKnown)
        let unknown = try lesson(["uniqueWords": NSNull(), "known": NSNull()])
        XCTAssertNil(unknown.knownFraction)
        XCTAssertEqual(unknown.percentage, "Unavailable")
        XCTAssertFalse(unknown.allKnown)
    }

    func testInvalidCountsAndUnsafeThumbnailsAreNotRenderedAsProgressOrLoaded() throws {
        XCTAssertNil(try lesson(["known": 11, "uniqueWords": 10]).knownFraction)
        XCTAssertNil(try lesson(["known": -1]).knownFraction)
        XCTAssertNil(try lesson(["thumbnail": "http://example.com/image.jpg"]).thumbnailURL)
        XCTAssertNil(try lesson(["thumbnail": "https://user:secret@example.com/image.jpg"]).thumbnailURL)
        XCTAssertEqual(try lesson(["thumbnail": "https://i.ytimg.com/vi/example/hqdefault.jpg"]).thumbnailURL?.host, "i.ytimg.com")
    }

    func testLanguageResponseCannotPopulateAnotherScopeAndDuplicateRowsAreRemoved() throws {
        let italian = try lesson(["id": "one", "language": "it-IT"])
        let estonian = try lesson(["id": "two", "language": "et-EE"])
        let response = MobileProgressResponse(languageCode: "it-IT", vocabulary: nil,
                                              lessons: [italian, italian, estonian], trophies: nil)
        XCTAssertTrue(response.matches(languageCode: "IT_it"))
        XCTAssertFalse(response.matches(languageCode: "et-EE"))
        XCTAssertEqual(response.coverageLessons(for: "it-IT").map(\.id), ["one"])
        XCTAssertTrue(response.coverageLessons(for: "et-EE").isEmpty)
    }

    func testTrophiesRequireRecordedAwardsAndPreserveHistoricalRecognition() throws {
        let notAwarded = try trophy(["value": 25, "target": 25])
        XCTAssertFalse(notAwarded.isEarned)
        XCTAssertEqual(notAwarded.progressFraction, 1)
        let historic = try trophy(["earnedAt": "2026-09-10T12:30:00.000Z", "source": "backfill", "value": 0])
        XCTAssertTrue(historic.isEarned)
        XCTAssertEqual(historic.source, "backfill")
        XCTAssertNotNil(historic.earnedDate)
        let newer = try trophy(["earnedAt": "2026-09-10T12:30:00Z", "source": "activity"])
        XCTAssertNotNil(newer.earnedDate)
        XCTAssertNil(try trophy(["target": 0]).progressFraction)
        XCTAssertNil(try trophy(["value": NSNull()]).progressDescription)
    }

    @MainActor
    func testDelayedLanguageResponseCannotReplaceNewLanguage() async throws {
        let loader = MobileProgressLoader()
        let started = expectation(description: "Italian request started")
        var finishItalian: CheckedContinuation<MobileProgressResponse, Error>?
        let italianTask = Task { @MainActor in
            await loader.load(languageCode: "it-IT") { _ in
                try await withCheckedThrowingContinuation { continuation in
                    finishItalian = continuation
                    started.fulfill()
                }
            }
        }
        await fulfillment(of: [started], timeout: 2)
        await loader.load(languageCode: "et-EE") { path in
            XCTAssertEqual(path, "/api/mobile/progress?language=et-EE")
            return MobileProgressResponse(languageCode: "et-EE", vocabulary: nil, lessons: [], trophies: [])
        }
        finishItalian?.resume(returning: MobileProgressResponse(languageCode: "it-IT", vocabulary: nil, lessons: [], trophies: []))
        await italianTask.value
        XCTAssertEqual(loader.response?.languageCode, "et-EE")
        XCTAssertNil(loader.notice)
        XCTAssertFalse(loader.isLoading)
    }

    @MainActor
    func testLanguageChangeClearsPreviousDataEvenWhenNewRequestFails() async {
        let loader = MobileProgressLoader()
        await loader.load(languageCode: "it-IT") { _ in
            MobileProgressResponse(languageCode: "it-IT", vocabulary: nil, lessons: [], trophies: [])
        }
        XCTAssertNotNil(loader.response)
        await loader.load(languageCode: "ja-JP") { _ in throw URLError(.notConnectedToInternet) }
        XCTAssertNil(loader.response)
        XCTAssertNotNil(loader.notice)
        XCTAssertFalse(loader.isLoading)
    }

    @MainActor
    func testSameScopeRefreshFailureKeepsLastDataAndCancellationDoesNotShowAnError() async {
        let loader = MobileProgressLoader()
        await loader.load(languageCode: "it-IT") { _ in
            MobileProgressResponse(languageCode: "it-IT", vocabulary: nil, lessons: [], trophies: [])
        }
        await loader.load(languageCode: "it-IT") { _ in throw URLError(.notConnectedToInternet) }
        XCTAssertEqual(loader.response?.languageCode, "it-IT")
        XCTAssertNotNil(loader.notice)
        await loader.load(languageCode: "it-IT") { _ in throw CancellationError() }
        XCTAssertNil(loader.notice)
        XCTAssertFalse(loader.isLoading)
    }

    @MainActor
    func testWrongScopeResponseIsRejectedAndTrophiesUseAccountWideEndpoint() async {
        let loader = MobileProgressLoader()
        await loader.load(languageCode: "it-IT") { _ in
            MobileProgressResponse(languageCode: "ru-RU", vocabulary: nil, lessons: [], trophies: [])
        }
        XCTAssertNil(loader.response)
        XCTAssertNotNil(loader.notice)
        await loader.load(languageCode: nil) { path in
            XCTAssertEqual(path, "/api/mobile/progress")
            return MobileProgressResponse(languageCode: nil, vocabulary: nil, lessons: nil, trophies: [])
        }
        XCTAssertNotNil(loader.response?.trophies)
        XCTAssertNil(loader.notice)
    }

    private func lesson(_ changes: [String: Any] = [:]) throws -> MobileProgressLesson {
        var json: [String: Any] = [
            "id": "lesson", "title": "A story", "language": "it-IT", "totalWords": 40,
            "uniqueWords": 10, "known": 1, "learning": 0, "familiar": 0
        ]
        json.merge(changes) { _, updated in updated }
        return try JSONDecoder().decode(MobileProgressLesson.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private func trophy(_ changes: [String: Any] = [:]) throws -> MobileProgressTrophy {
        var json: [String: Any] = [
            "id": "in-rotation", "title": "In Rotation", "category": "Review", "icon": "repeat",
            "requirement": "Record 25 vocabulary reviews.", "target": 25, "value": 2, "unit": "reviews"
        ]
        json.merge(changes) { _, updated in updated }
        return try JSONDecoder().decode(MobileProgressTrophy.self, from: JSONSerialization.data(withJSONObject: json))
    }
}
