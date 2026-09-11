import SwiftUI

struct LiveHomeView: View {
    @EnvironmentObject private var store: LiveLibraryStore
    @EnvironmentObject private var studyScope: MobileStudyScope
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var languages: [MobileLanguageOption] {
        MobileStudyLanguageList(courses: store.courses, words: store.words, includeOffered: true).languages
    }
    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 148), spacing: 12)]
    }
    private var currentLessons: [MobileLessonSummary] {
        store.courses.filter { MobileLanguageKey.normalized($0.languageCode) == MobileLanguageKey.normalized(studyScope.language?.code) }
            .flatMap(\.lessons)
    }
    private var resumeLesson: MobileLessonSummary? {
        currentLessons.first { store.positions[$0.id] != nil } ?? currentLessons.first
    }

    var body: some View {
        NavigationStack(path: $studyScope.homePath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let notice = store.notice { LibraryNoticeRow(notice: notice).gardenCard(padding: 14) }
                    if studyScope.showingLanguagePicker || studyScope.language == nil {
                        languagePicker
                    } else { dashboard }
                }
                .frame(maxWidth: 900, alignment: .leading)
                .padding(.horizontal, 16).padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            }
            .studyBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MobileStudyRoute.self) { route in
                switch route {
                case .library(let code, let name): LiveLibraryView(languageCode: code, languageName: name)
                case .course(let id, let search): LiveCourseView(courseID: id, initialSearch: search)
                case .lesson(let id):
                    if let course = store.courses.first(where: { $0.lessons.contains { $0.id == id && $0.kind == "course" } }) {
                        CourseActivityView(courseID: course.id, lessonID: id).id(id)
                    } else { LiveReaderView(lessonID: id) }
                }
            }
            .refreshable { await store.refresh() }
            .task { if !store.hasLoaded { await store.refresh() } }
        }
    }

    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your languages").font(StudyTypography.font(.largeTitle, weight: .bold))
            Text("Choose a language for your lessons, courses, and saved vocabulary.")
                .font(StudyTypography.font(.subheadline)).foregroundStyle(Palette.secondary)
            if store.isLoading && !store.hasLoaded { ProgressView("Loading your library…") }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(languages) { language in
                    Button {
                        studyScope.selectLanguage(language)
                        studyScope.showHome()
                    } label: { languageTile(language) }
                    .buttonStyle(GardenPressStyle())
                }
            }
        }
        .foregroundStyle(Palette.ink)
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let language = studyScope.language {
                HStack {
                    Text(LanguageDisplay.nativeName(for: language.code, fallback: language.name))
                        .font(StudyTypography.font(.largeTitle, weight: .bold))
                    Spacer()
                    Text(language.flag).font(.largeTitle).accessibilityHidden(true)
                }
                .foregroundStyle(Palette.ink)
            }
            sessionCard
            HStack {
                Text("Your study space").font(StudyTypography.font(.title2, weight: .semibold))
                Spacer()
            }
            LazyVGrid(columns: columns, spacing: 12) {
                shortcut("Courses", detail: "Structured study", icon: "books.vertical") { studyScope.openLibrary(.courses) }
                shortcut("Library", detail: "Videos, audio, and reading", icon: "book") { studyScope.openLibrary(.lessons) }
                shortcut("Saved", detail: "Your words and phrases", icon: "bookmark") { studyScope.tab = .words }
                shortcut("Progress", detail: "What you have marked", icon: "chart.bar") { studyScope.tab = .progress }
            }
            if !currentLessons.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("From your library").font(StudyTypography.font(.headline))
                    ForEach(Array(currentLessons.prefix(3))) { lesson in
                        Button { studyScope.openLesson(lesson.id) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: lesson.kind == "course" ? "books.vertical" : "play.rectangle")
                                    .foregroundStyle(Palette.accent).frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(lesson.title).font(StudyTypography.font(.subheadline, weight: .medium))
                                    Text(store.positions[lesson.id] == nil ? "Open lesson" : "Continue reading")
                                        .font(.caption).foregroundStyle(Palette.secondary)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.secondary)
                            }
                            .foregroundStyle(Palette.ink).frame(minHeight: 48)
                        }.buttonStyle(GardenPressStyle())
                    }
                }.gardenCard()
            }
            DisclosureGroup("How does Plurifold work?") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Courses guide you through a subject. The Library gives you individual videos, audio, and texts to explore.")
                    Text("Tap a word while reading to see its meaning. Save useful words and phrases, then return to Review to practise them.")
                    Text("Progress counts your own reading decisions. Marked known means a word you chose as known; it is not a fluency score.")
                    Text("Saved vocabulary and reading places sync with your account. Appearance stays on this device.")
                }.font(.subheadline).foregroundStyle(Palette.secondary).padding(.top, 10)
            }.gardenCard()
        }
        .foregroundStyle(Palette.ink)
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(resumeLesson.map { store.positions[$0.id] != nil } == true ? "CONTINUE LEARNING" : "START HERE")
                .font(StudyTypography.font(.caption, weight: .semibold)).tracking(2).foregroundStyle(Palette.secondary)
            Text(resumeLesson?.title ?? "Explore your language")
                .font(StudyTypography.font(.title, weight: .bold)).fixedSize(horizontal: false, vertical: true)
            Text(resumeLesson?.subtitle ?? "Browse available lessons or choose a different language.")
                .font(StudyTypography.font(.subheadline)).foregroundStyle(Palette.secondary)
            if let lesson = resumeLesson {
                Button { studyScope.openLesson(lesson.id) } label: {
                    Label(store.positions[lesson.id] == nil ? "Start learning" : "Continue", systemImage: "play.fill")
                }.buttonStyle(StudyButtonStyle())
                DisclosureGroup("Why this lesson?") {
                    Text(store.positions[lesson.id] == nil
                         ? "This is the first available lesson in your language. Choose Courses or Library below to find another starting point."
                         : "You have a saved reading place in this lesson. Continue from there or browse something else.")
                        .font(.footnote).foregroundStyle(Palette.secondary).padding(.top, 6)
                }.font(.subheadline)
            } else {
                Button("Browse lessons") { studyScope.openLibrary(.lessons) }.buttonStyle(StudyButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(24)
        .background { GardenSceneBackground(asset: "GardenSession") }
        .clipShape(RoundedRectangle(cornerRadius: Palette.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Palette.cardRadius).stroke(Palette.line, lineWidth: 1))
    }

    private func shortcut(_ title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon).font(.title2).foregroundStyle(Palette.accent)
                Text(title).font(StudyTypography.font(.headline)).foregroundStyle(Palette.ink)
                Text(detail).font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading).gardenCard(padding: 18)
        }.buttonStyle(GardenPressStyle())
    }

    private func languageTile(_ language: MobileLanguageOption) -> some View {
        let selected = MobileLanguageKey.normalized(studyScope.language?.code) == MobileLanguageKey.normalized(language.code)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(language.flag).font(.largeTitle).accessibilityHidden(true)
                Spacer()
                if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.accent) }
            }
            Text(LanguageDisplay.nativeName(for: language.code, fallback: language.name))
                .font(StudyTypography.font(.headline)).foregroundStyle(Palette.ink)
            Text(language.contentDescription.isEmpty ? "More content to come" : language.contentDescription)
                .font(.caption).foregroundStyle(Palette.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading).gardenCard(padding: 16)
        .accessibilityElement(children: .combine).accessibilityValue(selected ? "Selected" : "")
    }
}
