import XCTest
@testable import Plurifold

final class ReadingSentenceTests: XCTestCase {
    func testSentenceSnapshotsKeepExactOffsetsAcrossUnicodeAndParagraphs() throws {
        let texts = ["☕️ Here is coffee. Here is tea.", "Caffè e pane.\nAnother sentence!"]
        let document = ReadingDocument(paragraphs: texts.enumerated().map { index, text in
            MobileParagraph(id: String(index), text: text, translation: nil, start: nil, end: nil)
        }, languageCode: "en-US")
        XCTAssertEqual(document.sentencesByParagraph.count, 2)
        XCTAssertGreaterThanOrEqual(document.sentencesByParagraph[0].count, 2)
        for (index, sentences) in document.sentencesByParagraph.enumerated() {
            for sentence in sentences {
                XCTAssertEqual(sentence.paragraphIndex, index)
                XCTAssertEqual((document.text as NSString).substring(with: sentence.range), sentence.text)
                XCTAssertEqual(document.paragraphIndex(atUTF16Offset: sentence.range.location), index)
            }
        }
        let snapshot = try XCTUnwrap(document.sentencesByParagraph[1].first)
        let local = (snapshot.text as NSString).range(of: "Caffè")
        let selection = try XCTUnwrap(document.selection(in: snapshot, localRange: local))
        XCTAssertEqual(selection.text, "Caffè")
        XCTAssertEqual(selection.context, document.text)
        XCTAssertEqual(selection.range, (document.text as NSString).range(of: "Caffè"))
    }

    func testInvalidOrDifferentSentenceCannotMapIntoTheDocument() throws {
        let document = ReadingDocument(paragraphs: [MobileParagraph(id: "one", text: "🌍 Hello.",
            translation: nil, start: nil, end: nil)])
        let snapshot = ReadingSentence(text: document.text,
            range: NSRange(location: 0, length: document.text.utf16.count), paragraphIndex: 0)
        XCTAssertNil(document.selection(in: snapshot, localRange: NSRange(location: 1, length: 1)))
        XCTAssertNil(document.selection(in: snapshot, localRange: NSRange(location: 0, length: Int.max)))
        let wrong = ReadingSentence(text: "Other", range: snapshot.range, paragraphIndex: 0)
        XCTAssertNil(document.selection(in: wrong, localRange: NSRange(location: 0, length: 5)))
        let invalid = ReadingSentence(text: "Hello", range: NSRange(location: 0, length: -1), paragraphIndex: 0)
        XCTAssertNil(document.selection(in: invalid, localRange: NSRange(location: 0, length: 5)))
        XCTAssertTrue(ReadingDocument(paragraphs: []).sentencesByParagraph.isEmpty)
    }
}
