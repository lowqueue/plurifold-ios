import Combine
import Foundation

struct MobileCourse: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let languageCode: String
    let languageName: String
    let lessons: [MobileLessonSummary]
}

struct MobileLessonSummary: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let languageCode: String
    let languageName: String
    let dialect: String?
    let paragraphCount: Int
    let kind: String
    let channel: String?
    // Optional additions keep older catalog responses and test fixtures valid.
    var thumbnailURL: String? = nil
    var mediaKind: String? = nil
    var ilrLevel: String? = nil
    var wordCount: Int? = nil
    var uniqueWordCount: Int? = nil
    var newWordCount: Int? = nil
    var newWordPercent: Int? = nil
}

struct MobileLesson: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let languageCode: String
    let languageName: String
    let dialect: String?
    let paragraphCount: Int
    let kind: String
    let channel: String?
    let paragraphs: [MobileParagraph]
    let media: [MobileMedia]
    let resources: [MobileResource]
    let vocabulary: [MobileGlossary]
}

struct MobileParagraph: Codable, Identifiable, Hashable {
    let id: String
    let text: String
    let translation: String?
    let start: Double?
    let end: Double?
}

struct MobileMedia: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let kind: String
    let url: String
    let start: Double?
    let end: Double?
}

struct MobileResource: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let url: String
}

struct MobileGlossary: Codable, Hashable {
    let term: String
    let meaning: String
    let note: String?
}

struct MobileSavedWord: Codable, Identifiable, Hashable {
    let id: String
    let term: String
    let meaning: String
    let note: String
    let context: String
    let languageCode: String
    let languageName: String
    let status: String
    let kind: String
    let sourceLessonID: String?
    let sourceLessonTitle: String?
    let dialect: String?
    let pronunciation: String?
    let partOfSpeech: String?
}

struct MobileWordDraft: Encodable {
    var term: String
    var meaning: String
    var note: String = ""
    var context: String = ""
    var languageCode: String
    var dialect: String? = nil
    var kind: String = "word"
    var sourceLessonID: String
    var sourceLessonTitle: String
    var pronunciation: String? = nil
    var partOfSpeech: String? = nil
    var status: String? = nil
}

struct MobileCatalogResponse: Decodable {
    let courses: [MobileCourse]
}

struct MobileLessonResponse: Decodable {
    let lesson: MobileLesson
}

struct MobileStudyResponse: Decodable {
    let words: [MobileSavedWord]
    let positions: [String: Int]
}

@MainActor
final class LiveLibraryStore: ObservableObject {
    @Published private(set) var courses: [MobileCourse] = []
    @Published private(set) var words: [MobileSavedWord] = []
    @Published private(set) var positions: [String: Int] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var hasLoaded = false
    @Published var notice: String?
    let api: PlurifoldAPI

    private var studyGeneration = 0
    private var pendingMutations = 0
    private var mutationTail: Task<Void, Never>?
    private var lastMutationID = UUID()

    init(session: NativeSession) {
        api = PlurifoldAPI(session: session)
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        notice = nil
        defer { isLoading = false }

        do {
            let catalog: MobileCatalogResponse = try await api.get("/api/mobile/catalog")
            try Task.checkCancellation()
            courses = catalog.courses
            hasLoaded = true
        } catch is CancellationError { return }
        catch { notice = error.localizedDescription }

        let generation = studyGeneration
        do {
            let study: MobileStudyResponse = try await api.get("/api/mobile/study")
            try Task.checkCancellation()
            // A refresh started before a write must not restore the old server snapshot.
            if generation == studyGeneration, pendingMutations == 0 { apply(study) }
        } catch is CancellationError { return }
        catch {
            if notice == nil { notice = error.localizedDescription }
        }
    }

    func loadLesson(_ id: String) async throws -> MobileLesson {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#%")
        guard !id.isEmpty, let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) else {
            throw PlurifoldAPIError.invalidAddress
        }
        let response: MobileLessonResponse = try await api.get("/api/mobile/lessons/\(encoded)")
        return response.lesson
    }

    func saveWord(_ word: MobileWordDraft) async {
        await enqueue(.save(word))
    }

    func removeWord(_ id: String) async {
        await enqueue(.remove(id))
    }

    func recordPosition(lessonID: String, position: Int) async {
        guard positions[lessonID] != max(0, position) else { return }
        await enqueue(.progress(lessonID, max(0, position)))
    }

    private func apply(_ study: MobileStudyResponse) {
        words = study.words
        positions = study.positions
    }

    private func enqueue(_ mutation: StudyMutation) async {
        let previous = mutationTail
        let mutationID = UUID()
        lastMutationID = mutationID
        pendingMutations += 1
        studyGeneration &+= 1
        isSaving = true
        let task = Task { @MainActor [weak self] in
            await previous?.value
            guard let self else { return }
            self.notice = nil
            do {
                let study: MobileStudyResponse = try await self.api.post("/api/mobile/study", body: mutation)
                self.apply(study)
            } catch is CancellationError {
                // Cancellation is not a server failure and needs no error banner.
            } catch {
                self.notice = error.localizedDescription
            }
            self.studyGeneration &+= 1
            self.pendingMutations -= 1
            self.isSaving = self.pendingMutations > 0
            if self.lastMutationID == mutationID { self.mutationTail = nil }
        }
        mutationTail = task
        await task.value
    }
}

private enum StudyMutation: Encodable {
    case save(MobileWordDraft)
    case remove(String)
    case progress(String, Int)

    private enum CodingKeys: String, CodingKey {
        case action, id, lessonID, position
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .save(let word):
            try container.encode("saveWord", forKey: .action)
            // Encode the word into the same object, keeping the endpoint's flat payload.
            try word.encode(to: encoder)
        case .remove(let id):
            try container.encode("removeWord", forKey: .action)
            try container.encode(id, forKey: .id)
        case .progress(let lessonID, let position):
            try container.encode("progress", forKey: .action)
            try container.encode(lessonID, forKey: .lessonID)
            try container.encode(position, forKey: .position)
        }
    }
}
