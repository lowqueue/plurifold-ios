import Foundation
import XCTest
@testable import Plurifold

final class PassageSelectionTests: XCTestCase {
    func testPhrasePreservesExactUTF16RangeAfterEmojiAndAccents() throws {
        let context = "☕️ Vorrei un caffè, per favore."
        let range = (context as NSString).range(of: "un caffè")
        let selection = try XCTUnwrap(PassageSelection(context: context, range: range))
        XCTAssertEqual(selection.text, "un caffè")
        XCTAssertEqual(selection.range, range)
        XCTAssertEqual(selection.context, context)
        XCTAssertNotEqual(range.location, context.distance(from: context.startIndex, to: try XCTUnwrap(context.range(of: "un caffè")).lowerBound))
    }

    func testInvalidRangesAndWhitespaceCannotCreateSelections() {
        let context = "🌍 ciao"
        for range in [
            NSRange(location: NSNotFound, length: 1),
            NSRange(location: -1, length: 1),
            NSRange(location: 0, length: 0),
            NSRange(location: 0, length: Int.max),
            NSRange(location: 1, length: 1), // Half of the emoji's surrogate pair.
            NSRange(location: 2, length: 1), // Whitespace.
            NSRange(location: context.utf16.count, length: 1)
        ] {
            XCTAssertNil(PassageSelection(context: context, range: range), "Unexpected selection for \(range)")
        }
    }

    func testWordTapUsesUnicodeOffsetsAndDoesNotSelectSpacesOrPunctuation() throws {
        let context = "🌍 Un caffè, grazie."
        let expected = (context as NSString).range(of: "caffè")
        let range = try XCTUnwrap(PassageTextSelection.wordRange(in: context, utf16Offset: expected.location + 2))
        XCTAssertEqual(range, expected)
        XCTAssertNil(PassageTextSelection.wordRange(in: context, utf16Offset: 1))
        XCTAssertNil(PassageTextSelection.wordRange(in: context, utf16Offset: 2))
        XCTAssertNil(PassageTextSelection.wordRange(in: context, utf16Offset: NSMaxRange(expected)))
        XCTAssertNil(PassageTextSelection.wordRange(in: context, utf16Offset: context.utf16.count))
    }

    func testNonSpaceScriptProducesAWordContainingTheTappedCharacter() throws {
        let context = "私は日本語を勉強しています。"
        let tapped = (context as NSString).range(of: "日").location
        let range = try XCTUnwrap(PassageTextSelection.wordRange(in: context, utf16Offset: tapped))
        XCTAssertTrue(NSLocationInRange(tapped, range))
        let selected = try XCTUnwrap(PassageSelection(context: context, range: range))
        XCTAssertFalse(selected.text.isEmpty)
        XCTAssertLessThan(range.length, context.utf16.count)
    }

    func testSavedTermsDoNotHighlightUnrelatedWordFragments() {
        let context = "In the morning, in the park."
        let ranges = PassageTextSelection.highlightRanges(in: context, terms: ["in", "the park", "in", " "])
        let values = ranges.map { (context as NSString).substring(with: $0) }
        XCTAssertEqual(values.count, 3)
        XCTAssertEqual(Set(values), Set(["In", "in", "the park"]))
    }
}
