import Foundation

/// Course material stays structured so the app can show reading, reference
/// tables, illustrations, and answerable activities without flattening them
/// into transcript paragraphs.
struct MobileCourseContent: Codable, Hashable {
    let courseID: String
    let courseTitle: String
    let unitTitle: String?
    let position: Int
    let total: Int
    let originalInstruction: String?
    let sourceAttribution: String?
    let images: [MobileCourseImage]
    let sections: [MobileCourseSection]
    let exercise: MobileCourseExercise?
}

struct MobileCourseImage: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let url: String
}

struct MobileCourseSection: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let body: String?
    let rows: [MobileCourseRow]
}

struct MobileCourseRow: Codable, Hashable, Identifiable {
    let id: String
    let text: String
    let meaning: String?
    let note: String?
}

struct MobileCourseExercise: Codable, Hashable {
    let kind: String
    let title: String
    let items: [MobileCourseExerciseItem]
}

struct MobileCourseExerciseItem: Codable, Hashable, Identifiable {
    let id: String
    let prompt: String
    let answers: [String]
    let options: [MobileCourseExerciseOption]
    let correctOptionIDs: [String]
    let multiple: Bool
}

struct MobileCourseExerciseOption: Codable, Hashable, Identifiable {
    let id: String
    let label: String
}

enum MobileCourseAnswerMatcher {
    /// Ignore presentation differences, while keeping diacritics meaningful
    /// for languages such as Estonian. Canonically equivalent Unicode forms
    /// compare equally, including answers entered with combining accents.
    static func normalized(_ answer: String) -> String {
        let folded = answer.precomposedStringWithCanonicalMapping
            .folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        // Punctuation separates words, just as it does in the website's
        // exercise matcher: "tere,ma" and "tere ma" remain equivalent.
        let lettersAndSpacing = folded.unicodeScalars.map {
            CharacterSet.punctuationCharacters.contains($0) ? " " : String($0)
        }.joined()
        return lettersAndSpacing.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .precomposedStringWithCanonicalMapping
    }

    static func matches(_ answer: String, answers: [String]) -> Bool {
        let candidate = normalized(answer)
        guard !candidate.isEmpty else { return false }
        return answers.contains { normalized($0) == candidate }
    }

    static func matches(optionIDs: Set<String>, correctOptionIDs: [String]) -> Bool {
        guard !optionIDs.isEmpty else { return false }
        return optionIDs == Set(correctOptionIDs)
    }
}
