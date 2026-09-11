import Combine
import Foundation

enum MobileStudyTab: Hashable {
    case home, words, review, progress, account
}

enum MobileLibrarySection: Hashable { case lessons, courses }

/// Stable values own the entire Home stack, including nested course readers.
/// Catalog counts are intentionally not part of a destination's identity.
enum MobileStudyRoute: Hashable {
    case library(languageCode: String, languageName: String)
    case course(id: String, search: String)
    case lesson(id: String)

    static func library(_ language: MobileLanguageOption) -> Self {
        .library(languageCode: language.code, languageName: language.name)
    }
}

/// Capture when recognition begins so a delayed swipe cannot navigate a different screen.
struct MobileEdgeNavigationIntent: Equatable {
    enum Action { case sidebar, back }
    let tab: MobileStudyTab
    let path: [MobileStudyRoute]

    var action: Action {
        guard tab == .home, let destination = path.last else { return .sidebar }
        switch destination {
        case .course, .lesson: return .back
        case .library: return .sidebar
        }
    }
}

/// Owned by the signed-in root, so changing accounts starts with no language.
@MainActor
final class MobileStudyScope: ObservableObject {
    @Published private(set) var language: MobileLanguageOption?
    @Published var tab: MobileStudyTab = .home
    @Published var homePath: [MobileStudyRoute] = []
    @Published var isSidebarPresented = false
    @Published var librarySection: MobileLibrarySection = .lessons
    @Published var showingLanguagePicker = true
    @Published var showingTrophies = false
    @Published var showingSpeaking = false

    var edgeNavigationIntent: MobileEdgeNavigationIntent {
        MobileEdgeNavigationIntent(tab: tab, path: homePath)
    }

    func completeEdgeNavigation(_ intent: MobileEdgeNavigationIntent) {
        guard !isSidebarPresented, edgeNavigationIntent == intent else { return }
        switch intent.action {
        case .sidebar: isSidebarPresented = true
        case .back: homePath.removeLast()
        }
    }

    func selectLanguage(_ language: MobileLanguageOption) {
        guard MobileLanguageKey.normalized(language.code) != nil else { return }
        isSidebarPresented = false
        self.language = language
        showingLanguagePicker = false
        // Replace the destinations, never the NavigationStack displaying them.
        homePath = [.library(language)]
        tab = .home
    }

    func showLanguagePicker() {
        showingLanguagePicker = true
        isSidebarPresented = false
        homePath = []
        tab = .home
    }

    func showHome() {
        isSidebarPresented = false
        showingLanguagePicker = language == nil
        homePath = []
        tab = .home
    }

    func openLibrary(_ section: MobileLibrarySection) {
        librarySection = section
        if let language { selectLanguage(language) }
        else { showLanguagePicker() }
    }

    func openLesson(_ id: String) {
        guard let language else { return }
        isSidebarPresented = false
        showingLanguagePicker = false
        homePath = [.library(language), .lesson(id: id)]
        tab = .home
    }

    /// Previous/next stays inside the current course instead of stacking readers.
    func openCourseActivity(_ id: String, in course: MobileCourse) {
        guard let language,
              MobileLanguageKey.normalized(language.code) == MobileLanguageKey.normalized(course.languageCode),
              course.lessons.contains(where: { $0.id == id && $0.kind == "course" }) else { return }
        if let courseIndex = homePath.lastIndex(where: {
            if case .course(let courseID, _) = $0 { return courseID == course.id }
            return false
        }) {
            homePath = Array(homePath.prefix(courseIndex + 1)) + [.lesson(id: id)]
        } else if case .lesson(let currentID) = homePath.last,
                  course.lessons.contains(where: { $0.id == currentID && $0.kind == "course" }) {
            homePath = Array(homePath.dropLast()) + [.lesson(id: id)]
        } else { return }
        tab = .home
    }

    func reconcile(languages: [MobileLanguageOption]) {
        guard let language else { return }
        let key = MobileLanguageKey.normalized(language.code)
        if let current = languages.first(where: { MobileLanguageKey.normalized($0.code) == key }) {
            self.language = current
        } else {
            self.language = nil
            showingLanguagePicker = true
            homePath = []
        }
    }
}

/// Saved vocabulary remains reachable even if its source lesson was removed.
struct MobileStudyLanguageList {
    let languages: [MobileLanguageOption]

    init(courses: [MobileCourse], words: [MobileSavedWord], includeOffered: Bool = false) {
        var options = MobileLanguageCatalog(courses: courses).languages
        var known = Set(options.compactMap { MobileLanguageKey.normalized($0.code) })
        for word in words {
            guard let key = MobileLanguageKey.normalized(word.languageCode), known.insert(key).inserted else { continue }
            let name = word.languageName.trimmingCharacters(in: .whitespacesAndNewlines)
            options.append(MobileLanguageOption(code: word.languageCode, name: name.isEmpty ? word.languageCode : name,
                                                courseCount: 0, lessonCount: 0))
        }
        if includeOffered {
            for language in NativeWelcomeLanguages.offered {
                guard let key = MobileLanguageKey.normalized(language.code), known.insert(key).inserted else { continue }
                options.append(.init(code: language.code, name: language.name, courseCount: 0, lessonCount: 0))
            }
        }
        languages = options.sorted {
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.code < $1.code : comparison == .orderedAscending
        }
    }
}
