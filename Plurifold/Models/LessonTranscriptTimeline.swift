import Foundation

/// Matches absolute recording time to the source paragraph. No synthetic timing
/// is assigned to text that has no timestamp. Intervals are [start, end).
struct LessonTranscriptTimeline {
    private struct Span {
        let paragraphIndex: Int
        let end: Double
    }

    private struct Group {
        let start: Double
        let spans: [Span]
    }

    private let groups: [Group]

    var hasTimings: Bool { !groups.isEmpty }

    init(paragraphs: [MobileParagraph]) {
        let timedIndices = paragraphs.indices.filter { index in
            guard let start = paragraphs[index].start else { return false }
            return Self.validTime(start) && !paragraphs[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let byStart = Dictionary(grouping: timedIndices) { paragraphs[$0].start! }
        let starts = byStart.keys.sorted()
        groups = starts.enumerated().compactMap { offset, start in
            let nextStart = offset + 1 < starts.count ? starts[offset + 1] : nil
            let spans: [Span] = (byStart[start] ?? []).sorted().compactMap { index in
                let end: Double
                if let suppliedEnd = paragraphs[index].end {
                    // An explicit bad end is malformed data, not a missing end.
                    guard Self.validTime(suppliedEnd), suppliedEnd > start else { return nil }
                    end = min(suppliedEnd, nextStart ?? suppliedEnd)
                } else if let nextStart {
                    end = nextStart
                } else {
                    // A dangling final start cannot establish when speech stops.
                    return nil
                }
                return Span(paragraphIndex: index, end: end)
            }
            return spans.isEmpty ? nil : Group(start: start, spans: spans)
        }
    }

    func paragraphIndex(at time: Double) -> Int? {
        guard Self.validTime(time), !groups.isEmpty else { return nil }
        // A stateless lookup handles scrubbing backward as well as forward.
        var lower = 0
        var upper = groups.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if groups[middle].start <= time { lower = middle + 1 }
            else { upper = middle }
        }
        guard lower > 0 else { return nil }
        // Repeated timestamps cannot identify which sentence is being spoken.
        // Prefer the first source paragraph still inside its supplied interval.
        return groups[lower - 1].spans.first(where: { time < $0.end })?.paragraphIndex
    }

    private static func validTime(_ time: Double) -> Bool {
        time.isFinite && time >= 0 && time <= 86_400_000
    }
}
