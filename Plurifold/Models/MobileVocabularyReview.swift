import Foundation

enum MobileLanguageKey {
    static func normalized(_ code: String?) -> String? {
        guard let key = code?.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-").lowercased(), !key.isEmpty else {
            return nil
        }
        return key
    }
}

struct MobileVocabularyIndex {
    let words: [MobileSavedWord]

    init(words: [MobileSavedWord], languageCode: String?, search: String = "") {
        guard let language = MobileLanguageKey.normalized(languageCode) else {
            self.words = []
            return
        }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        self.words = words.filter { word in
            guard MobileLanguageKey.normalized(word.languageCode) == language else { return false }
            guard !query.isEmpty else { return true }
            return [word.term, word.meaning, word.note, word.sourceLessonTitle ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
}

/// A review round belongs to one selected language and this view's lifetime.
/// Ratings only order this round; they do not change saved vocabulary or schedule reviews.
struct MobileReviewSession {
    private(set) var languageCode: String? = nil
    private(set) var queue: [MobileSavedWord] = []
    private(set) var completedIDs: Set<String> = []
    private(set) var isAnswerRevealed = false

    var current: MobileSavedWord? { queue.first }
    var totalCount: Int { queue.count + completedIDs.count }

    mutating func reconcile(words: [MobileSavedWord], languageCode: String?) {
        let language = MobileLanguageKey.normalized(languageCode)
        guard language != nil, language == self.languageCode else {
            restart(words: words, languageCode: language)
            return
        }

        let previousCurrent = current
        let eligible = uniqueWords(words, languageCode: language)
        // Construct the lookup after deduplicating so repeated response IDs are safe.
        let byID = Dictionary(uniqueKeysWithValues: eligible.map { ($0.id, $0) })
        completedIDs.formIntersection(Set(byID.keys))
        var retainedIDs: Set<String> = []
        queue = queue.compactMap { word in
            guard !completedIDs.contains(word.id), retainedIDs.insert(word.id).inserted else { return nil }
            return byID[word.id]
        }
        let queuedIDs = Set(queue.map(\.id))
        queue.append(contentsOf: eligible.filter { !completedIDs.contains($0.id) && !queuedIDs.contains($0.id) })
        if current != previousCurrent {
            isAnswerRevealed = false
        }
    }

    mutating func reveal() {
        guard current != nil else { return }
        isAnswerRevealed = true
    }

    mutating func again() {
        guard isAnswerRevealed, !queue.isEmpty else { return }
        let word = queue.removeFirst()
        queue.append(word)
        isAnswerRevealed = false
    }

    mutating func gotIt() {
        guard isAnswerRevealed, !queue.isEmpty else { return }
        completedIDs.insert(queue.removeFirst().id)
        isAnswerRevealed = false
    }

    mutating func restart(words: [MobileSavedWord], languageCode: String?) {
        self.languageCode = MobileLanguageKey.normalized(languageCode)
        queue = uniqueWords(words, languageCode: self.languageCode)
        completedIDs = []
        isAnswerRevealed = false
    }

    private func uniqueWords(_ words: [MobileSavedWord], languageCode: String?) -> [MobileSavedWord] {
        var seen: Set<String> = []
        return MobileVocabularyIndex(words: words, languageCode: languageCode).words
            .filter { seen.insert($0.id).inserted }
    }
}
