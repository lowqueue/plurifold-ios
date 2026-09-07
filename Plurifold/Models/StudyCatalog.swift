import Foundation

struct StudyCatalog: Codable {
    let courses: [Course]

    static func load(bundle: Bundle = .main) throws -> StudyCatalog {
        guard let url = bundle.url(forResource: "catalog", withExtension: "json") else {
            throw CatalogError.missingResource
        }
        let data = try Data(contentsOf: url)
        let catalog: StudyCatalog
        do {
            catalog = try JSONDecoder().decode(StudyCatalog.self, from: data)
        } catch {
            throw CatalogError.invalidJSON(error.localizedDescription)
        }
        try catalog.validate()
        return catalog
    }

    /// Validate before constructing a store so its selected course is always available.
    func validate() throws {
        guard !courses.isEmpty else {
            throw CatalogError.invalidContent("The catalog needs at least one course.")
        }
        var identifiers = Set<String>()
        func register(_ id: String) throws {
            guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CatalogError.invalidContent("Catalog identifiers cannot be empty.")
            }
            guard identifiers.insert(id).inserted else {
                throw CatalogError.invalidContent("The identifier ‘\(id)’ appears more than once.")
            }
        }
        func requireText(_ text: String, _ description: String) throws {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CatalogError.invalidContent("\(description) cannot be empty.")
            }
        }

        for course in courses {
            try register(course.id)
            try requireText(course.title, "A course title")
            try requireText(course.languageName, "A language name")
            try requireText(course.languageCode, "A language code")
            try requireText(course.symbol, "A course symbol")
            guard !course.lessons.isEmpty else {
                throw CatalogError.invalidContent("The course ‘\(course.title)’ needs a lesson.")
            }
            for lesson in course.lessons {
                try register(lesson.id)
                try requireText(lesson.title, "A lesson title")
                guard lesson.minutes > 0 else {
                    throw CatalogError.invalidContent("Lesson duration must be greater than zero.")
                }
                guard !lesson.paragraphs.isEmpty else {
                    throw CatalogError.invalidContent("The lesson ‘\(lesson.title)’ needs a paragraph.")
                }
                guard !lesson.questions.isEmpty else {
                    throw CatalogError.invalidContent("The lesson ‘\(lesson.title)’ needs a comprehension question.")
                }
                for paragraph in lesson.paragraphs {
                    try register(paragraph.id)
                    try requireText(paragraph.text, "Paragraph text")
                    try requireText(paragraph.translation, "A paragraph translation")
                }
                for word in lesson.vocabulary {
                    try register(word.id)
                    try requireText(word.term, "A vocabulary term")
                    try requireText(word.meaning, "A vocabulary meaning")
                }
                for question in lesson.questions {
                    try register(question.id)
                    try requireText(question.prompt, "A practice question")
                    guard question.options.count >= 2 else {
                        throw CatalogError.invalidContent("A practice question needs at least two options.")
                    }
                    for option in question.options {
                        try requireText(option, "An answer option")
                    }
                    guard question.options.indices.contains(question.answerIndex) else {
                        throw CatalogError.invalidContent("A practice answer is outside its options.")
                    }
                    try requireText(question.explanation, "An answer explanation")
                }
            }
        }
    }
}

enum CatalogError: LocalizedError {
    case missingResource
    case invalidJSON(String)
    case invalidContent(String)

    var errorDescription: String? {
        switch self {
        case .missingResource:
            return "The bundled lesson catalog could not be found."
        case .invalidJSON(let detail):
            return "The bundled lesson catalog could not be read: \(detail)"
        case .invalidContent(let detail):
            return detail
        }
    }
}

struct Course: Identifiable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let languageName: String
    let languageCode: String
    let symbol: String
    let lessons: [Lesson]
}

struct Lesson: Identifiable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let minutes: Int
    let paragraphs: [LessonParagraph]
    let vocabulary: [VocabularyEntry]
    let questions: [PracticeQuestion]
}

struct LessonParagraph: Identifiable, Codable {
    let id: String
    let text: String
    let translation: String
}

struct VocabularyEntry: Identifiable, Codable {
    let id: String
    let term: String
    let meaning: String
    let note: String
    let example: String
}

struct PracticeQuestion: Identifiable, Codable {
    let id: String
    let prompt: String
    let options: [String]
    let answerIndex: Int
    let explanation: String
}

struct SavedWord: Identifiable {
    var id: String { entry.id }
    let entry: VocabularyEntry
    let lessonID: String
    let lessonTitle: String
    let languageName: String
    let languageCode: String
}
