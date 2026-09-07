import Foundation
import NaturalLanguage

struct ReadingSentence: Identifiable {
    var id: Int { range.location }
    let text: String
    let range: NSRange
    let paragraphIndex: Int
}

/// One reading surface with stable offsets back to the server's original passages.
struct ReadingDocument {
    let text: String
    let paragraphRanges: [NSRange]
    let sentencesByParagraph: [[ReadingSentence]]

    init(paragraphs: [MobileParagraph], languageCode: String = "") {
        var ranges: [NSRange] = []
        var sentences: [[ReadingSentence]] = []
        var offset = 0
        for (index, paragraph) in paragraphs.enumerated() {
            if index > 0 { offset += 2 }
            let length = paragraph.text.utf16.count
            ranges.append(NSRange(location: offset, length: length))
            let tokenizer = NLTokenizer(unit: .sentence)
            tokenizer.string = paragraph.text
            if let language = PassageTextSelection.tokenizerLanguageCode(languageCode) {
                tokenizer.setLanguage(NLLanguage(rawValue: language))
            }
            var paragraphSentences: [ReadingSentence] = []
            tokenizer.enumerateTokens(in: paragraph.text.startIndex..<paragraph.text.endIndex) { range, _ in
                let localRange = NSRange(range, in: paragraph.text)
                if !paragraph.text[range].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    paragraphSentences.append(ReadingSentence(text: String(paragraph.text[range]),
                        range: NSRange(location: offset + localRange.location, length: localRange.length),
                        paragraphIndex: index))
                }
                return true
            }
            if paragraphSentences.isEmpty, !paragraph.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                paragraphSentences.append(ReadingSentence(text: paragraph.text,
                    range: NSRange(location: offset, length: length), paragraphIndex: index))
            }
            sentences.append(paragraphSentences)
            offset += length
        }
        text = paragraphs.map(\.text).joined(separator: "\n\n")
        paragraphRanges = ranges
        sentencesByParagraph = sentences
    }

    /// Map a frozen sentence's local word selection back to the unchanged source.
    func selection(in sentence: ReadingSentence, localRange: NSRange) -> PassageSelection? {
        guard let local = PassageSelection(context: sentence.text, range: localRange),
              sentence.range.location >= 0, sentence.range.location <= text.utf16.count,
              sentence.range.length > 0,
              sentence.range.length <= text.utf16.count - sentence.range.location,
              (text as NSString).substring(with: sentence.range) == sentence.text else { return nil }
        return PassageSelection(context: text, range: NSRange(location: sentence.range.location + local.range.location,
                                                              length: local.range.length))
    }

    /// Whitespace between passages belongs to the preceding passage.
    func paragraphIndex(atUTF16Offset offset: Int) -> Int? {
        guard !paragraphRanges.isEmpty else { return nil }
        let clamped = max(0, min(offset, text.utf16.count))
        var lower = 0
        var upper = paragraphRanges.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if paragraphRanges[middle].location <= clamped {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return max(0, lower - 1)
    }
}

struct ReaderScrollRequest: Identifiable {
    let id = UUID()
    let utf16Offset: Int

    init(utf16Offset: Int) { self.utf16Offset = utf16Offset }
}
