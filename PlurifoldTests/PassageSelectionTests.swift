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

    func testSelectionsRequireWholeCharactersAndPreserveCompleteOnes() throws {
        for character in ["🌍", "e\u{301}", "☕\u{FE0F}", "👩🏽‍💻", "🇪🇪", "か\u{3099}"] {
            let context = "A\(character)B"
            let width = character.utf16.count
            let complete = NSRange(location: 1, length: width)
            let selection = try XCTUnwrap(PassageSelection(context: context, range: complete))
            XCTAssertEqual(Array(selection.text.utf16), Array(character.utf16))
            XCTAssertEqual(selection.range, complete)

            // Exercise every partial UTF-16 range, including ranges that split
            // a surrogate pair, accent, variation selector, or joined emoji.
            for offset in 0..<width {
                for length in 1...(width - offset) {
                    let partial = NSRange(location: 1 + offset, length: length)
                    guard partial != complete else { continue }
                    XCTAssertNil(PassageSelection(context: context, range: partial),
                                 "Partial character accepted: \(character), \(partial)")
                }
            }
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

    func testDragSelectsWholeWordsInEitherDirectionAcrossPassages() throws {
        let context = "☕️ In questo video.\n\nFiniamo il caffè."
        let words = PassageTextSelection.wordRanges(in: context, languageCode: "it")
        let start = try XCTUnwrap(PassageTextSelection.wordRange(
            in: words, utf16Offset: (context as NSString).range(of: "questo").location + 2, nearest: false))
        let end = try XCTUnwrap(PassageTextSelection.wordRange(
            in: words, utf16Offset: (context as NSString).range(of: "caffè").location + 1, nearest: false))
        let forward = PassageTextSelection.phraseRange(anchor: start, endpoint: end)
        let backward = PassageTextSelection.phraseRange(anchor: end, endpoint: start)
        XCTAssertEqual(forward, backward)
        XCTAssertEqual(try XCTUnwrap(PassageSelection(context: context, range: forward)).text,
                       "questo video.\n\nFiniamo il caffè")
        XCTAssertEqual(PassageTextSelection.phraseRange(anchor: start, endpoint: start), start)
    }

    func testDraggingThroughWhitespaceSnapsButTappingWhitespaceDoesNot() {
        let words = [NSRange(location: 3, length: 2), NSRange(location: 11, length: 4)]
        XCTAssertNil(PassageTextSelection.wordRange(in: words, utf16Offset: 7, nearest: false))
        XCTAssertEqual(PassageTextSelection.wordRange(in: words, utf16Offset: 7, nearest: true), words[0])
        XCTAssertEqual(PassageTextSelection.wordRange(in: words, utf16Offset: 10, nearest: true), words[1])
        XCTAssertEqual(PassageTextSelection.wordRange(in: words, utf16Offset: 0, nearest: true), words[0])
        XCTAssertEqual(PassageTextSelection.wordRange(in: words, utf16Offset: 100, nearest: true), words[1])
        XCTAssertNil(PassageTextSelection.wordRange(in: [], utf16Offset: 0, nearest: true))
    }

    func testDragDirectionKeepsVerticalReadingScrollAndImmediateSelectMode() {
        XCTAssertEqual(PassageDragDecision.decide(dx: 2, dy: 5, selectionMode: false), .pending)
        XCTAssertEqual(PassageDragDecision.decide(dx: 2, dy: 5, selectionMode: true), .pending)
        XCTAssertEqual(PassageDragDecision.decide(dx: 2, dy: 6, selectionMode: false), .scroll)
        XCTAssertEqual(PassageDragDecision.decide(dx: 6, dy: 2, selectionMode: false), .select)
        XCTAssertEqual(PassageDragDecision.decide(dx: -6, dy: -2, selectionMode: false), .select)
        XCTAssertEqual(PassageDragDecision.decide(dx: 6, dy: 6, selectionMode: false), .scroll)
        XCTAssertEqual(PassageDragDecision.decide(dx: 0, dy: -6, selectionMode: true), .select)
    }

    func testTokenizerUsesLanguageInsteadOfSpeechLocale() {
        XCTAssertEqual(PassageTextSelection.tokenizerLanguageCode("it-IT"), "it")
        XCTAssertEqual(PassageTextSelection.tokenizerLanguageCode("ka_GE"), "ka")
        XCTAssertEqual(PassageTextSelection.tokenizerLanguageCode("ja-JP"), "ja")
        XCTAssertEqual(PassageTextSelection.tokenizerLanguageCode("zh-TW"), "zh-Hant")
        XCTAssertEqual(PassageTextSelection.tokenizerLanguageCode("zh-Hans-CN"), "zh-Hans")
        XCTAssertNil(PassageTextSelection.tokenizerLanguageCode(""))
    }

    func testContinuousDocumentPreservesParagraphBoundariesAndResumeMapping() {
        let texts = ["☕️ Caffè", "ქართული\nტექსტი", "日本語"]
        let document = ReadingDocument(paragraphs: texts.enumerated().map { index, text in
            MobileParagraph(id: String(index), text: text, translation: nil, start: nil, end: nil)
        })
        XCTAssertEqual(document.text, texts.joined(separator: "\n\n"))
        for (index, range) in document.paragraphRanges.enumerated() {
            XCTAssertEqual((document.text as NSString).substring(with: range), texts[index])
            XCTAssertEqual(document.paragraphIndex(atUTF16Offset: range.location), index)
            XCTAssertEqual(document.paragraphIndex(atUTF16Offset: NSMaxRange(range) - 1), index)
            if index < texts.count - 1 {
                XCTAssertEqual(document.paragraphIndex(atUTF16Offset: NSMaxRange(range)), index)
                XCTAssertEqual(document.paragraphIndex(atUTF16Offset: NSMaxRange(range) + 1), index)
            }
        }
        XCTAssertEqual(document.paragraphIndex(atUTF16Offset: -100), 0)
        XCTAssertEqual(document.paragraphIndex(atUTF16Offset: Int.max), texts.count - 1)
        XCTAssertNil(ReadingDocument(paragraphs: []).paragraphIndex(atUTF16Offset: 0))
    }
}
