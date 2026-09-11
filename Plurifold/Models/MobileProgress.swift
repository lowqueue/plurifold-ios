import Combine
import Foundation

/// The authenticated server computes these values from the same word-form
/// states and achievement evidence as the website. Missing data is not zero.
struct MobileProgressResponse: Decodable, Equatable {
    let languageCode: String?
    let vocabulary: MobileProgressVocabulary?
    let lessons: [MobileProgressLesson]?
    let trophies: [MobileProgressTrophy]?

    func matches(languageCode requested: String?) -> Bool {
        guard let requested = MobileLanguageKey.normalized(requested) else { return true }
        return MobileLanguageKey.normalized(languageCode) == requested
    }

    func coverageLessons(for languageCode: String) -> [MobileProgressLesson] {
        guard matches(languageCode: languageCode) else { return [] }
        var seen: Set<String> = []
        return (lessons ?? []).filter {
            !$0.id.isEmpty && MobileLanguageKey.normalized($0.language) == MobileLanguageKey.normalized(languageCode)
                && seen.insert($0.id).inserted
        }
    }
}

struct MobileProgressVocabulary: Decodable, Equatable {
    let known: Int?
    let learning: Int?
    let familiar: Int?
    let phrases: Int?

    static func display(_ count: Int?) -> String {
        guard let count, count >= 0 else { return "Unavailable" }
        return count.formatted()
    }
}

struct MobileProgressLesson: Decodable, Equatable, Identifiable {
    let id: String
    let title: String
    let language: String
    let thumbnail: String?
    let media: String?
    let variety: String?
    let totalWords: Int?
    let uniqueWords: Int?
    let known: Int?
    let learning: Int?
    let familiar: Int?

    var knownFraction: Double? {
        guard let total = uniqueWords, let count = known,
              total >= 0, count >= 0, count <= total else { return nil }
        return total == 0 ? 0 : Double(count) / Double(total)
    }

    var percentage: String {
        guard let fraction = knownFraction else { return "Unavailable" }
        if fraction > 0 && fraction < 0.01 { return "<1%" }
        return "\(Int((fraction * 100).rounded(.down)))%"
    }

    var allKnown: Bool {
        guard let uniqueWords, uniqueWords > 0 else { return false }
        return known == uniqueWords
    }

    var coverageDescription: String {
        guard knownFraction != nil, let known, let uniqueWords else { return "Coverage unavailable" }
        return "\(known.formatted()) of \(uniqueWords.formatted()) unique word forms marked known"
    }

    var thumbnailURL: URL? {
        guard let thumbnail, let url = URL(string: thumbnail),
              url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { return nil }
        return url
    }

    var mediaSymbol: String {
        switch media {
        case "video": "play.rectangle"
        case "audio": "headphones"
        default: "book"
        }
    }
}

enum MobileProgressFilter: String, CaseIterable, Identifiable {
    case all, learning, familiar, known
    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All lessons"
        case .learning: "Learning"
        case .familiar: "Familiar"
        case .known: "All known"
        }
    }

    func includes(_ lesson: MobileProgressLesson) -> Bool {
        switch self {
        case .all: true
        case .learning: (lesson.learning ?? 0) > 0
        case .familiar: (lesson.familiar ?? 0) > 0
        case .known: lesson.allKnown
        }
    }
}

struct MobileProgressTrophy: Decodable, Equatable, Identifiable {
    let id: String
    let title: String
    let category: String
    let icon: String?
    let requirement: String
    let target: Int?
    let value: Int?
    let unit: String?
    let earnedAt: String?
    let source: String?

    /// An award is based on stored evidence, never inferred from a local card.
    var isEarned: Bool { earnedAt?.isEmpty == false }
    var progressFraction: Double? {
        guard let target, target > 0, let value, value >= 0 else { return nil }
        return min(1, Double(value) / Double(target))
    }

    var progressDescription: String? {
        guard let target, target > 0, let value, value >= 0 else { return nil }
        return "\(value.formatted()) of \(target.formatted()) \(unit ?? "completed")"
    }

    var earnedDate: Date? {
        guard let earnedAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: earnedAt) ?? ISO8601DateFormatter().date(from: earnedAt)
    }

    var systemImage: String {
        switch icon {
        case "return": "arrow.uturn.backward"
        case "repeat": "repeat"
        case "cards": "rectangle.on.rectangle"
        case "book": "book"
        case "spark": "sparkles"
        case "headphones": "headphones"
        case "circle": "circle.circle"
        case "medal": "medal"
        case "pen": "pencil.line"
        case "writing": "pencil.tip"
        case "sprout": "leaf"
        case "layers": "square.3.layers.3d"
        default: "trophy"
        }
    }
}

/// A request belongs to one view and language. Switching language or starting
/// another refresh prevents an older response from restoring the wrong totals.
@MainActor
final class MobileProgressLoader: ObservableObject {
    @Published private(set) var response: MobileProgressResponse?
    @Published private(set) var isLoading = false
    @Published private(set) var notice: String?
    private var generation = UUID()
    private var scope: String?

    func load(languageCode: String?, api: PlurifoldAPI) async {
        await load(languageCode: languageCode) { path in try await api.get(path) }
    }

    func load(languageCode: String?, fetch: (String) async throws -> MobileProgressResponse) async {
        let nextScope = MobileLanguageKey.normalized(languageCode)
        let request = UUID()
        generation = request
        if scope != nextScope { response = nil }
        scope = nextScope
        isLoading = true
        notice = nil
        defer { if generation == request { isLoading = false } }

        var components = URLComponents()
        components.path = "/api/mobile/progress"
        if let languageCode { components.queryItems = [URLQueryItem(name: "language", value: languageCode)] }
        guard let path = components.string else {
            notice = "This language couldn’t be loaded. Choose it again and retry."
            return
        }

        do {
            let result = try await fetch(path)
            try Task.checkCancellation()
            guard generation == request else { return }
            guard result.matches(languageCode: languageCode) else {
                notice = "Progress for this language couldn’t be loaded. Please try again."
                return
            }
            response = result
        } catch is CancellationError {
            return
        } catch {
            guard generation == request else { return }
            notice = error.localizedDescription
        }
    }
}
