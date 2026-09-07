import Foundation

/// One reading surface with stable offsets back to the server's original passages.
struct ReadingDocument {
    let text: String
    let paragraphRanges: [NSRange]

    init(paragraphs: [MobileParagraph]) {
        var ranges: [NSRange] = []
        var offset = 0
        for (index, paragraph) in paragraphs.enumerated() {
            if index > 0 { offset += 2 }
            let length = paragraph.text.utf16.count
            ranges.append(NSRange(location: offset, length: length))
            offset += length
        }
        text = paragraphs.map(\.text).joined(separator: "\n\n")
        paragraphRanges = ranges
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
