import Combine
import Foundation

enum MobileStudyTab: Hashable {
    case home, words, review, account
}

/// Owned by the signed-in root, so changing accounts starts with no language.
@MainActor
final class MobileStudyScope: ObservableObject {
    @Published private(set) var language: MobileLanguageOption?
    @Published var tab: MobileStudyTab = .home
    @Published var homePath: [MobileLanguageOption] = []
    @Published private(set) var homeRootID = UUID()

    func selectLanguage(_ language: MobileLanguageOption) {
        guard MobileLanguageKey.normalized(language.code) != nil else { return }
        self.language = language
        homePath = [language]
        // A header switch also closes view-based chapter/reader destinations.
        homeRootID = UUID()
        tab = .home
    }

    func showLanguagePicker() {
        homePath = []
        // Also dismiss destinations opened with a view-based NavigationLink.
        homeRootID = UUID()
        tab = .home
    }

    func reconcile(languages: [MobileLanguageOption]) {
        guard let language else { return }
        let key = MobileLanguageKey.normalized(language.code)
        if let current = languages.first(where: { MobileLanguageKey.normalized($0.code) == key }) {
            self.language = current
        } else {
            self.language = nil
            homePath = []
            homeRootID = UUID()
        }
    }
}

/// Saved vocabulary remains reachable even if its source lesson was removed.
struct MobileStudyLanguageList {
    let languages: [MobileLanguageOption]

    init(courses: [MobileCourse], words: [MobileSavedWord]) {
        var options = MobileLanguageCatalog(courses: courses).languages
        var known = Set(options.compactMap { MobileLanguageKey.normalized($0.code) })
        for word in words {
            guard let key = MobileLanguageKey.normalized(word.languageCode), known.insert(key).inserted else { continue }
            let name = word.languageName.trimmingCharacters(in: .whitespacesAndNewlines)
            options.append(MobileLanguageOption(code: word.languageCode, name: name.isEmpty ? word.languageCode : name,
                                                courseCount: 0, lessonCount: 0))
        }
        languages = options.sorted {
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.code < $1.code : comparison == .orderedAscending
        }
    }
}
