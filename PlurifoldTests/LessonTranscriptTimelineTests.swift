import XCTest
@testable import Plurifold

final class LessonTranscriptTimelineTests: XCTestCase {
    func testAbsoluteTimesHonorStartsEndsAndSilentGaps() {
        let timeline = LessonTranscriptTimeline(paragraphs: [
            paragraph("one", start: 42, end: 46),
            paragraph("two", start: 50, end: 55)
        ])
        XCTAssertTrue(timeline.hasTimings)
        XCTAssertNil(timeline.paragraphIndex(at: 0))
        XCTAssertNil(timeline.paragraphIndex(at: 41.99))
        XCTAssertEqual(timeline.paragraphIndex(at: 42), 0)
        XCTAssertEqual(timeline.paragraphIndex(at: 45.99), 0)
        XCTAssertNil(timeline.paragraphIndex(at: 46))
        XCTAssertNil(timeline.paragraphIndex(at: 49))
        XCTAssertEqual(timeline.paragraphIndex(at: 50), 1)
        XCTAssertNil(timeline.paragraphIndex(at: 55))
    }

    func testMissingEndsUseNextStartButDoNotInventAFinalEnd() {
        let timeline = LessonTranscriptTimeline(paragraphs: [
            paragraph("one", start: 0),
            paragraph("untimed"),
            paragraph("two", start: 5),
            paragraph("three", start: 12)
        ])
        XCTAssertEqual(timeline.paragraphIndex(at: 4.99), 0)
        XCTAssertEqual(timeline.paragraphIndex(at: 5), 2)
        XCTAssertEqual(timeline.paragraphIndex(at: 11.99), 2)
        XCTAssertNil(timeline.paragraphIndex(at: 12))
        XCTAssertNil(timeline.paragraphIndex(at: 500))
    }

    func testUntimedAndMalformedEntriesDoNotBecomeActive() {
        let timeline = LessonTranscriptTimeline(paragraphs: [
            paragraph("untimed", end: 20),
            paragraph("negative", start: -2, end: 3),
            paragraph("nan", start: .nan, end: 5),
            paragraph("infinite", start: .infinity),
            paragraph("zero duration", start: 0, end: 0),
            paragraph("backward", start: 3, end: 2),
            paragraph("bad end", start: 4, end: .infinity),
            paragraph(" \n ", start: 5, end: 8),
            paragraph("dangling", start: 10)
        ])
        XCTAssertFalse(timeline.hasTimings)
        for time in [Double.nan, .infinity, -1, 0, 3, 4, 5, 10, 100] {
            XCTAssertNil(timeline.paragraphIndex(at: time))
        }
    }

    func testDuplicateStartsUseStableSourceOrderWithoutZeroLengthInference() {
        let timeline = LessonTranscriptTimeline(paragraphs: [
            paragraph("first", start: 0, end: 3),
            paragraph("same timestamp", start: 0, end: 8),
            paragraph("next", start: 10, end: 12)
        ])
        XCTAssertEqual(timeline.paragraphIndex(at: 0), 0)
        XCTAssertEqual(timeline.paragraphIndex(at: 2), 0)
        XCTAssertEqual(timeline.paragraphIndex(at: 3), 1)
        XCTAssertNil(timeline.paragraphIndex(at: 8))
        XCTAssertEqual(timeline.paragraphIndex(at: 10), 2)

        let missingEnds = LessonTranscriptTimeline(paragraphs: [
            paragraph("first", start: 0), paragraph("second", start: 0),
            paragraph("next", start: 10, end: 12)
        ])
        XCTAssertEqual(missingEnds.paragraphIndex(at: 9.9), 0)
    }

    func testOutOfOrderTimestampsAndBackSeekingPreserveOriginalIndices() {
        let timeline = LessonTranscriptTimeline(paragraphs: [
            paragraph("later", start: 20, end: 30),
            paragraph("earlier", start: 0, end: 10),
            paragraph("middle", start: 10, end: 20)
        ])
        XCTAssertEqual(timeline.paragraphIndex(at: 25), 0)
        XCTAssertEqual(timeline.paragraphIndex(at: 2), 1)
        XCTAssertEqual(timeline.paragraphIndex(at: 15), 2)
        XCTAssertEqual(timeline.paragraphIndex(at: 10), 2)
        XCTAssertEqual(timeline.paragraphIndex(at: 1), 1)
        XCTAssertNil(timeline.paragraphIndex(at: .nan))
    }

    func testLaterStartsBoundOverlapsWithoutRevivingEarlierSpeechInAGap() {
        let timeline = LessonTranscriptTimeline(paragraphs: [
            paragraph("long", start: 0, end: 30),
            paragraph("interrupting", start: 10, end: 12),
            paragraph("last", start: 20, end: 25)
        ])
        XCTAssertEqual(timeline.paragraphIndex(at: 9), 0)
        XCTAssertEqual(timeline.paragraphIndex(at: 10), 1)
        XCTAssertNil(timeline.paragraphIndex(at: 15))
        XCTAssertEqual(timeline.paragraphIndex(at: 20), 2)
    }

    private func paragraph(_ text: String, start: Double? = nil, end: Double? = nil) -> MobileParagraph {
        MobileParagraph(id: text, text: text, translation: nil, start: start, end: end)
    }
}
