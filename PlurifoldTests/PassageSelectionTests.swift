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

    func testMovementBeforeHoldScrollsAndCompletedHoldSelectsInEveryDirection() {
        XCTAssertEqual(PassageDragDecision.decide(dx: 2, dy: 5, holdReady: false), .pending)
        XCTAssertEqual(PassageDragDecision.decide(dx: 2, dy: 8, holdReady: false), .scroll)
        XCTAssertEqual(PassageDragDecision.decide(dx: 8, dy: 2, holdReady: false), .scroll)
        XCTAssertEqual(PassageDragDecision.decide(dx: -8, dy: -2, holdReady: false), .scroll)
        XCTAssertEqual(PassageDragDecision.decide(dx: 0, dy: 0, holdReady: true), .select)
        XCTAssertEqual(PassageDragDecision.decide(dx: 0, dy: -20, holdReady: true), .select)
        XCTAssertEqual(PassageDragDecision.decide(dx: -20, dy: 10, holdReady: true), .select)
    }

    func testWordFeedbackTicksAtNewEndpointsWhenExtendingShorteningAndReversing() {
        let first = NSRange(location: 0, length: 2)
        let middle = NSRange(location: 3, length: 6)
        let last = NSRange(location: 10, length: 5)
        var feedback = PassageWordFeedbackState()
        feedback.begin(at: middle)

        XCTAssertFalse(feedback.move(to: middle))
        XCTAssertFalse(feedback.move(to: nil)) // Crossing a space is silent.
        XCTAssertTrue(feedback.move(to: last)) // Extend to the right.
        for _ in 0..<60 { XCTAssertFalse(feedback.move(to: last)) }
        XCTAssertFalse(feedback.move(to: nil))
        XCTAssertFalse(feedback.move(to: last)) // Re-entering the same word is silent.
        XCTAssertTrue(feedback.move(to: middle)) // Shorten back to the anchor.
        XCTAssertTrue(feedback.move(to: first)) // Reverse beyond the anchor.
        XCTAssertFalse(feedback.move(to: first))
    }

    func testWordFeedbackStopsAfterCancellationAndStartsFreshForTheNextGesture() {
        let first = NSRange(location: 0, length: 4)
        let second = NSRange(location: 5, length: 4)
        var feedback = PassageWordFeedbackState()
        XCTAssertFalse(feedback.move(to: first))
        feedback.begin(at: first)
        feedback.reset() // Early swipe, interruption, clear, or completed gesture.
        XCTAssertFalse(feedback.move(to: second))
        XCTAssertFalse(feedback.move(to: nil))
        feedback.begin(at: second)
        XCTAssertFalse(feedback.move(to: second))
        XCTAssertTrue(feedback.move(to: first))
        feedback.reset()
        XCTAssertFalse(feedback.move(to: second))
    }

    func testHeldPhraseSelectionCanExtendDownwardAcrossLines() throws {
        let text = "Mina olen Kristel.\nMina olen Kert Kristian."
        let anchor = try XCTUnwrap(PassageTextSelection.wordRange(in: text, utf16Offset: 5))
        let endpoint = try XCTUnwrap(PassageTextSelection.wordRange(in: text,
            utf16Offset: (text as NSString).range(of: "Kert").location))
        XCTAssertEqual(PassageDragDecision.decide(dx: 1, dy: 56, holdReady: true), .select)
        XCTAssertEqual(PassageDragDecision.decide(dx: 1, dy: 56, holdReady: false), .scroll)
        let range = PassageTextSelection.phraseRange(anchor: anchor, endpoint: endpoint)
        let selection = try XCTUnwrap(PassageSelection(context: text, range: range))
        XCTAssertEqual(selection.text, "olen Kristel.\nMina olen Kert")
        XCTAssertTrue(DefinitionSelection.shouldAutomaticallyExplain(selection.text, languageCode: "et-EE"))
        XCTAssertEqual(PassageTextSelection.phraseRange(anchor: endpoint, endpoint: anchor), range)
    }

    func testInvalidGestureGeometryAlwaysReleasesReaderScroll() {
        for held in [false, true] {
            XCTAssertEqual(PassageDragDecision.decide(dx: .nan, dy: 56, holdReady: held), .scroll)
            XCTAssertEqual(PassageDragDecision.decide(dx: 0, dy: .infinity, holdReady: held), .scroll)
        }
    }

    func testRepeatedWordTapClearsButHoldAndNewSelectionsRemain() {
        let first = NSRange(location: 3, length: 5)
        let second = NSRange(location: 10, length: 4)
        XCTAssertTrue(PassageTapDecision.shouldClear(previous: first, completed: first, afterHold: false))
        XCTAssertFalse(PassageTapDecision.shouldClear(previous: first, completed: first, afterHold: true))
        XCTAssertFalse(PassageTapDecision.shouldClear(previous: nil, completed: first, afterHold: false))
        XCTAssertFalse(PassageTapDecision.shouldClear(previous: first, completed: second, afterHold: false))
    }

    func testCachedGeometryDistinguishesWordsFromSpacesAndSnapsDragging() {
        let first = NSRange(location: 0, length: 2)
        let second = NSRange(location: 3, length: 6)
        let third = NSRange(location: 11, length: 5)
        let geometry = PassageWordGeometryIndex(hits: [
            PassageWordHit(range: first, rect: CGRect(x: 0, y: 0, width: 15, height: 24)),
            PassageWordHit(range: second, rect: CGRect(x: 22, y: 0, width: 50, height: 24)),
            PassageWordHit(range: third, rect: CGRect(x: 0, y: 40, width: 45, height: 24))
        ])
        XCTAssertEqual(geometry.word(at: CGPoint(x: 30, y: 12), nearest: false), second)
        XCTAssertEqual(geometry.word(at: CGPoint(x: 16, y: 12), nearest: false), first)
        XCTAssertNil(geometry.word(at: CGPoint(x: 18, y: 12), nearest: false))
        XCTAssertNil(geometry.word(at: CGPoint(x: 100, y: 12), nearest: false))
        XCTAssertNil(geometry.word(at: CGPoint(x: 10, y: 32), nearest: false))
        XCTAssertEqual(geometry.word(at: CGPoint(x: 100, y: 12), nearest: true), second)
        XCTAssertEqual(geometry.word(at: CGPoint(x: -10, y: 50), nearest: true), third)
        XCTAssertEqual(geometry.word(at: CGPoint(x: 20, y: 1000), nearest: true), third)
        XCTAssertNil(PassageWordGeometryIndex(hits: []).word(at: .zero, nearest: true))
    }

    func testGeometryPreservesLogicalRangesWhenVisualWordOrderIsReversed() {
        let first = NSRange(location: 0, length: 4)
        let second = NSRange(location: 5, length: 3)
        let geometry = PassageWordGeometryIndex(hits: [
            PassageWordHit(range: first, rect: CGRect(x: 70, y: 0, width: 35, height: 24)),
            PassageWordHit(range: second, rect: CGRect(x: 30, y: 0, width: 30, height: 24))
        ])
        XCTAssertEqual(geometry.word(at: CGPoint(x: 80, y: 12), nearest: false), first)
        XCTAssertEqual(geometry.word(at: CGPoint(x: 40, y: 12), nearest: false), second)
        XCTAssertEqual(PassageTextSelection.phraseRange(anchor: first, endpoint: second),
                       NSRange(location: 0, length: 8))
    }

    func testSelectionRepaintsOnlyChangedEdgesAndClearsTheOldRange() {
        let first = NSRange(location: 3, length: 10)
        let extended = NSRange(location: 3, length: 20)
        XCTAssertEqual(PassageTextSelection.changedDisplayRanges(previous: first, current: extended),
                       [NSRange(location: 13, length: 10)])
        XCTAssertEqual(PassageTextSelection.changedDisplayRanges(previous: extended, current: first),
                       [NSRange(location: 13, length: 10)])
        XCTAssertEqual(PassageTextSelection.changedDisplayRanges(previous: extended, current: nil), [extended])
        XCTAssertEqual(PassageTextSelection.changedDisplayRanges(previous: nil, current: first), [first])
        XCTAssertEqual(PassageTextSelection.changedDisplayRanges(previous: first, current: first), [])
        XCTAssertEqual(PassageTextSelection.changedDisplayRanges(previous: first,
                       current: NSRange(location: 7, length: 10)),
                       [NSRange(location: 3, length: 4), NSRange(location: 13, length: 4)])
    }

    func testSelectedNeighboursJoinSpacesButKeepLineAndPassageBreaks() {
        let hits = [
            PassageWordHit(range: NSRange(location: 0, length: 4), rect: CGRect(x: 10, y: 0, width: 30, height: 24)),
            PassageWordHit(range: NSRange(location: 5, length: 4), rect: CGRect(x: 46, y: 0, width: 32, height: 24)),
            PassageWordHit(range: NSRange(location: 10, length: 4), rect: CGRect(x: 0, y: 30, width: 36, height: 24)),
            PassageWordHit(range: NSRange(location: 16, length: 4), rect: CGRect(x: 0, y: 82, width: 38, height: 24))
        ]
        let geometry = PassageWordGeometryIndex(hits: hits)
        XCTAssertEqual(geometry.selectionFragments(for: NSRange(location: 0, length: 9)),
                       [CGRect(x: 10, y: 0, width: 68, height: 24)])
        XCTAssertEqual(geometry.selectionFragments(for: NSRange(location: 0, length: 20)), [
            CGRect(x: 10, y: 0, width: 68, height: 24), hits[2].rect, hits[3].rect
        ])
        // A partial redraw still paints the joined fragment to its original
        // first word, avoiding a seam at the former selection edge.
        XCTAssertEqual(geometry.selectionFragments(for: NSRange(location: 0, length: 20),
                                                   displaying: hits[1].range),
                       [CGRect(x: 10, y: 0, width: 68, height: 24)])
        XCTAssertEqual(geometry.selectionFragments(for: NSRange(location: 0, length: 0)), [])
    }

    func testJoinedSelectionDoesNotBridgeAnUnselectedVisualWordInBidiText() {
        let first = PassageWordHit(range: NSRange(location: 0, length: 4),
                                   rect: CGRect(x: 0, y: 0, width: 28, height: 24))
        let intervening = PassageWordHit(range: NSRange(location: 10, length: 4),
                                         rect: CGRect(x: 35, y: 0, width: 26, height: 24))
        let second = PassageWordHit(range: NSRange(location: 5, length: 4),
                                    rect: CGRect(x: 68, y: 0, width: 28, height: 24))
        let geometry = PassageWordGeometryIndex(hits: [second, first, intervening])
        XCTAssertEqual(geometry.selectionFragments(for: NSRange(location: 0, length: 9)),
                       [first.rect, second.rect])
        XCTAssertEqual(geometry.selectionFragments(for: NSRange(location: 0, length: 14)),
                       [CGRect(x: 0, y: 0, width: 96, height: 24)])
    }

    func testShrinkingAndReversingJoinedSelectionRestoresOnlyCurrentWordShapes() {
        let hits = (0..<3).map { index in
            PassageWordHit(range: NSRange(location: index * 5, length: 4),
                           rect: CGRect(x: CGFloat(index * 36), y: 0, width: 30, height: 24))
        }
        let geometry = PassageWordGeometryIndex(hits: hits)
        let anchor = hits[1].range
        let extended = PassageTextSelection.phraseRange(anchor: anchor, endpoint: hits[2].range)
        let reversed = PassageTextSelection.phraseRange(anchor: anchor, endpoint: hits[0].range)
        XCTAssertEqual(geometry.selectionFragments(for: extended), [CGRect(x: 36, y: 0, width: 66, height: 24)])
        XCTAssertEqual(geometry.selectionFragments(for: anchor), [hits[1].rect])
        XCTAssertEqual(geometry.selectionFragments(for: reversed), [CGRect(x: 0, y: 0, width: 66, height: 24)])
        let redraw = PassageTextSelection.highlightDisplayRanges(previous: extended, current: reversed,
                                                                 words: hits.map(\.range))
        for hit in hits { XCTAssertTrue(redraw.contains(hit.range)) }
        XCTAssertTrue(PassageTextSelection.highlightDisplayRanges(previous: reversed, current: nil,
                                                                 words: hits.map(\.range)).contains(reversed))
        XCTAssertEqual(PassageTextSelection.highlightDisplayRanges(previous: anchor, current: anchor,
                                                                  words: hits.map(\.range)), [])
    }

    func testWordReactionSettlesAndClearCannotLeaveAStalePulse() {
        let first = NSRange(location: 0, length: 4)
        let second = NSRange(location: 5, length: 4)
        var reaction = PassageSelectionReactionState()
        reaction.begin(at: first, timestamp: 10)
        XCTAssertEqual(reaction.range, first)
        XCTAssertGreaterThan(reaction.lift(at: 10.06), 0)
        reaction.begin(at: second, timestamp: 10.08)
        XCTAssertEqual(reaction.range, second)
        reaction.begin(at: first, timestamp: 10.10) // Reverse onto the first word.
        XCTAssertEqual(reaction.range, first)
        XCTAssertLessThan(reaction.lift(at: 10.20), 2)
        XCTAssertFalse(reaction.isActive(at: 11))
        XCTAssertEqual(reaction.lift(at: 11), 0)
        reaction.clear()
        XCTAssertNil(reaction.range)
        XCTAssertFalse(reaction.isActive(at: 10.15))
        XCTAssertEqual(reaction.lift(at: 10.15), 0)
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
