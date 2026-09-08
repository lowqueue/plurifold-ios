import Foundation

enum LanguageDisplay {
    static func nativeName(for code: String, fallback: String) -> String {
        let key = code.lowercased().replacingOccurrences(of: "_", with: "-").split(separator: "-").first.map(String.init) ?? ""
        return ["it": "Italiano", "es": "Español", "et": "Eesti", "ka": "ქართული",
                "ru": "Русский", "uk": "Українська", "ja": "日本語"][key] ?? fallback
    }
}

struct MobileLanguageOption: Identifiable, Hashable {
    let code: String
    let name: String
    let courseCount: Int
    let lessonCount: Int

    var id: String { code }
    var flag: String { LanguageFlag.symbol(for: code) }

    var contentDescription: String {
        var parts: [String] = []
        if courseCount > 0 {
            parts.append("\(courseCount) \(courseCount == 1 ? "course" : "courses")")
        }
        if lessonCount > 0 {
            parts.append("\(lessonCount) \(lessonCount == 1 ? "lesson" : "lessons")")
        }
        return parts.joined(separator: " · ")
    }
}

/// The Home screen and its destinations share this catalog, so an empty or
/// removed language can never accidentally become an unfiltered library.
struct MobileLanguageCatalog {
    let languages: [MobileLanguageOption]
    private let availableCourses: [MobileCourse]

    init(courses: [MobileCourse]) {
        availableCourses = courses.filter {
            !$0.languageCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.lessons.isEmpty
        }
        let groups = Dictionary(grouping: availableCourses, by: \.languageCode)
        languages = groups.map { code, courses in
            let name = courses.lazy.map { $0.languageName.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty } ?? code
            return MobileLanguageOption(
                code: code,
                name: name,
                courseCount: courses.filter { $0.lessons.contains { $0.kind == "course" } }.count,
                lessonCount: courses.flatMap(\.lessons).filter { $0.kind != "course" }.count
            )
        }.sorted {
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.code < $1.code : comparison == .orderedAscending
        }
    }

    func language(for code: String) -> MobileLanguageOption? {
        languages.first { $0.code == code }
    }

    func courses(for code: String) -> [MobileCourse] {
        guard language(for: code) != nil else { return [] }
        return availableCourses.filter { $0.languageCode == code }
    }
}

enum LanguageFlag {
    static func symbol(for code: String) -> String {
        // The website uses es-AR for the whole Spanish library, with dialects
        // carried on individual lessons. This tile represents that language.
        if code.replacingOccurrences(of: "_", with: "-").lowercased() == "es-ar" { return "🇪🇸" }
        let parts = code.replacingOccurrences(of: "_", with: "-").split(separator: "-")
        let language = parts.first?.lowercased() ?? ""
        let preferredRegion: [String: String] = [
            "ar": "SA", "bg": "BG", "ca": "ES", "cs": "CZ", "da": "DK",
            "de": "DE", "el": "GR", "en": "GB", "es": "ES", "et": "EE",
            "fi": "FI", "fr": "FR", "he": "IL", "hi": "IN", "hr": "HR",
            "hu": "HU", "hy": "AM", "id": "ID", "is": "IS", "it": "IT",
            "ja": "JP", "ka": "GE", "ko": "KR", "lt": "LT", "lv": "LV",
            "nb": "NO", "nl": "NL", "nn": "NO", "no": "NO", "pl": "PL",
            "pt": "PT", "ro": "RO", "ru": "RU", "sk": "SK", "sl": "SI",
            "sq": "AL", "sr": "RS", "sv": "SE", "th": "TH", "tr": "TR",
            "uk": "UA", "vi": "VN", "zh": "CN"
        ]
        // Honor an explicit two-letter region (including codes with a script
        // subtag), then use the language's usual flag. Unknown codes stay usable.
        let region = parts.dropFirst().first { part in
            part.count == 2 && part.unicodeScalars.allSatisfy {
                (65...90).contains($0.value) || (97...122).contains($0.value)
            }
        }.map { $0.uppercased() } ?? preferredRegion[language]
        guard let region else { return "🌐" }
        let scalars = region.unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }
        return String(String.UnicodeScalarView(scalars))
    }
}
