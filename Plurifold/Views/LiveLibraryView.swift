import SwiftUI

struct LiveLibraryView: View {
    @EnvironmentObject private var store: LiveLibraryStore
    @EnvironmentObject private var studyScope: MobileStudyScope
    @State private var search = ""
    @State private var courseSearch = ""
    @State private var selectedChannel = ""
    @State private var selectedLevel = ""
    @State private var showsFilters = false
    let languageCode: String
    let languageName: String

    private var isCourses: Bool { studyScope.librarySection == .courses }

    var body: some View {
        // One catalog/shelf snapshot per render; every row and filter reads the
        // same result instead of sorting and grouping the library repeatedly.
        let catalog = MobileLanguageCatalog(courses: store.courses)
        let languageKey = MobileLanguageKey.normalized(languageCode)
        let language = catalog.languages.first {
            MobileLanguageKey.normalized($0.code) == languageKey
        }
        let shelf = MobileLibraryShelf(courses: catalog.courses(for: language?.code ?? languageCode),
                                       search: isCourses ? courseSearch : search,
                                       channel: selectedChannel, level: selectedLevel)
        let savedCounts = savedCountsByLesson()

        ScrollView {
            LazyVStack(alignment: .leading, spacing: Palette.isGarden ? 22 : 28) {
                introduction(name: language?.name ?? languageName)
                if let notice = store.notice {
                    LibraryNoticeRow(notice: notice).libraryFrame()
                }
                if store.isLoading && store.courses.isEmpty {
                    ProgressView("Loading your library…")
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else if store.courses.isEmpty {
                    ContentUnavailableView {
                        Label("Your library", systemImage: "books.vertical")
                    } description: {
                        Text(store.notice == nil
                             ? "Your Plurifold courses and lessons will appear here when they’re available."
                             : "Your library couldn’t load. Check your connection and try again.")
                    }
                } else if language == nil {
                    ContentUnavailableView("No content available", systemImage: "books.vertical",
                        description: Text("Your saved words are still in Saved and Review. Choose another language or pull down to refresh."))
                } else if isCourses {
                    courseShelf(shelf)
                } else {
                    filters(shelf: shelf)
                    if shelf.lessonGroups.isEmpty {
                        ContentUnavailableView(shelf.totalLessonCount == 0 ? "No lessons yet" : "No matching lessons",
                            systemImage: shelf.totalLessonCount == 0 ? "books.vertical" : "magnifyingglass",
                            description: Text(shelf.totalLessonCount == 0
                                ? "Try Courses for structured study in this language."
                                : "Try another search, channel, or ILR level."))
                        if !search.isEmpty || !selectedChannel.isEmpty || !selectedLevel.isEmpty {
                            Button("Clear filters") {
                                search = ""
                                selectedChannel = ""
                                selectedLevel = ""
                            }
                            .font(StudyTypography.font(.subheadline))
                            .frame(minHeight: 44)
                        }
                    }
                    // Section exposes each card to the outer lazy stack. An
                    // enclosing VStack would eagerly load every thumbnail.
                    ForEach(shelf.lessonGroups) { group in
                        Section {
                            ForEach(group.lessons) { item in
                                LibraryLessonRow(lesson: item.lesson,
                                    hasPosition: store.positions[item.lesson.id] != nil,
                                    source: item.source,
                                    savedCount: savedCounts[LibrarySavedCountKey(lesson: item.lesson)] ?? 0)
                            }
                        } header: {
                            levelHeading(group)
                        }
                    }
                }
            }
            .frame(maxWidth: 840, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .studyBackground()
        .tint(Palette.accent)
        .navigationTitle(isCourses ? "Courses" : "Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await store.refresh() }
        .task { await store.refresh() }
        .onChange(of: languageCode) { _, _ in
            selectedChannel = ""
            selectedLevel = ""
            search = ""
            courseSearch = ""
        }
        .onChange(of: shelf.availableChannels) { _, channels in
            if !selectedChannel.isEmpty && !channels.contains(selectedChannel) { selectedChannel = "" }
        }
        .onChange(of: shelf.availableLevels) { _, levels in
            if !selectedLevel.isEmpty && !levels.contains(selectedLevel) { selectedLevel = "" }
        }
    }

    private func introduction(name: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: name)
                .font(.caption2)
            Text(isCourses ? "Courses" : "Library")
                .font(StudyTypography.font(.largeTitle, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Text(isCourses ? "Follow a course at your own pace."
                 : "Reading, listening, and practice in your language.")
                .font(StudyTypography.font(.subheadline))
                .foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                studyScope.librarySection = isCourses ? .lessons : .courses
            } label: {
                Label(isCourses ? "Browse lessons" : "Browse courses",
                      systemImage: isCourses ? "books.vertical" : "book.closed")
                    .font(StudyTypography.font(.subheadline, weight: .medium))
                    .frame(minHeight: 44)
            }
            .buttonStyle(GardenPressStyle())
            .foregroundStyle(Palette.accent)
        }
    }

    @ViewBuilder private func courseShelf(_ shelf: MobileLibraryShelf) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.secondary).accessibilityHidden(true)
            TextField("Find a course or chapter", text: $courseSearch)
                .font(StudyTypography.font(.subheadline))
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Search courses and chapters")
            if !courseSearch.isEmpty {
                Button { courseSearch = "" } label: {
                    Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Clear course search")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Palette.controlRadius))
        .overlay(RoundedRectangle(cornerRadius: Palette.controlRadius).stroke(Palette.line, lineWidth: 1))
        if shelf.courseFolders.isEmpty {
            ContentUnavailableView(courseSearch.isEmpty ? "No courses yet" : "No matching courses",
                systemImage: courseSearch.isEmpty ? "book.closed" : "magnifyingglass",
                description: Text(courseSearch.isEmpty
                    ? "Browse lessons for reading and listening in this language."
                    : "Try another course title or chapter topic."))
        } else {
            sectionHeading("Available courses", subtitle: "\(shelf.courseFolders.count) \(shelf.courseFolders.count == 1 ? "course" : "courses")")
            ForEach(shelf.courseFolders) { folder in
                NavigationLink(value: MobileStudyRoute.course(id: folder.id, search: courseSearch)) {
                    LibraryCourseCard(folder: folder, positions: store.positions)
                }
                .buttonStyle(GardenPressStyle())
            }
        }
    }

    private func filters(shelf: MobileLibraryShelf) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("\(shelf.visibleLessonCount) of \(shelf.totalLessonCount) lessons")
                    .font(StudyTypography.font(.caption))
                    .foregroundStyle(Palette.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.secondary)
                    TextField("Find a lesson, topic, or channel", text: $search)
                        .font(StudyTypography.font(.subheadline))
                        .submitLabel(.search)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Search lessons, topics, and channels")
                    if !search.isEmpty {
                        Button { search = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 48)
                .background(Palette.field, in: RoundedRectangle(cornerRadius: Palette.controlRadius))
                .overlay(RoundedRectangle(cornerRadius: Palette.controlRadius).stroke(Palette.line, lineWidth: 1))
            }
            DisclosureGroup(isExpanded: $showsFilters) {
                VStack(alignment: .leading, spacing: 16) {
                    filterMenu(title: "Channel / network", value: selectedChannel.isEmpty ? "All channels" : selectedChannel) {
                        Picker("Channel / network", selection: $selectedChannel) {
                            Text("All channels").tag("")
                            ForEach(shelf.availableChannels, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    filterMenu(title: "Estimated ILR", value: selectedLevel.isEmpty ? "All ILR levels" : MobileLibraryShelf.levelTitle(selectedLevel)) {
                        Picker("Estimated ILR", selection: $selectedLevel) {
                            Text("All ILR levels").tag("")
                            ForEach(shelf.availableLevels, id: \.self) { level in
                                Text(MobileLibraryShelf.levelTitle(level)).tag(level)
                            }
                        }
                    }
                    if !selectedChannel.isEmpty || !selectedLevel.isEmpty {
                        Button("Reset filters") {
                            selectedChannel = ""
                            selectedLevel = ""
                        }
                        .font(StudyTypography.font(.subheadline))
                        .frame(minHeight: 44)
                    }
                }
                .padding(.top, 10)
            } label: {
                Label(selectedChannel.isEmpty && selectedLevel.isEmpty ? "Filters" : "Filters applied",
                      systemImage: "line.3.horizontal.decrease")
                    .font(StudyTypography.font(.subheadline, weight: .medium))
                    .frame(minHeight: 44)
            }
        }
        .libraryFrame()
    }

    private func filterMenu<Content: View>(title: String, value: String,
                                          @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(StudyTypography.font(.caption))
            Menu(content: content) {
                HStack(spacing: 12) {
                    Text(value).font(StudyTypography.font(.subheadline)).multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down").font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(Palette.ink)
                .background(Palette.field, in: RoundedRectangle(cornerRadius: Palette.controlRadius))
                .overlay(RoundedRectangle(cornerRadius: Palette.controlRadius).stroke(Palette.line, lineWidth: 1))
            }
            .accessibilityLabel(title)
            .accessibilityValue(value)
        }
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(StudyTypography.font(.title2, weight: .semibold)).accessibilityAddTraits(.isHeader)
            Text(subtitle).font(StudyTypography.font(.caption)).foregroundStyle(Palette.secondary)
        }
    }

    private func levelHeading(_ group: MobileLibraryLevelGroup) -> some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text(group.title).font(StudyTypography.font(.subheadline))
                    Spacer()
                    Text(lessonCountLabel(group.lessons.count)).font(StudyTypography.font(.caption))
                        .foregroundStyle(Palette.secondary)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(group.title).font(StudyTypography.font(.subheadline))
                    Text(lessonCountLabel(group.lessons.count)).font(StudyTypography.font(.caption))
                        .foregroundStyle(Palette.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Rectangle().fill(Palette.line).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func savedCountsByLesson() -> [LibrarySavedCountKey: Int] {
        store.words.reduce(into: [:]) { counts, word in
            guard let lessonID = word.sourceLessonID else { return }
            let key = LibrarySavedCountKey(lessonID: lessonID,
                                          languageCode: MobileLanguageKey.normalized(word.languageCode))
            counts[key, default: 0] += 1
        }
    }

    private func lessonCountLabel(_ count: Int) -> String {
        "\(count) \(count == 1 ? "LESSON" : "LESSONS")"
    }


}

private struct LibrarySavedCountKey: Hashable {
    let lessonID: String
    let languageCode: String?

    init(lessonID: String, languageCode: String?) {
        self.lessonID = lessonID
        self.languageCode = languageCode
    }

    init(lesson: MobileLessonSummary) {
        self.init(lessonID: lesson.id, languageCode: MobileLanguageKey.normalized(lesson.languageCode))
    }
}

struct LibraryNoticeRow: View {
    @EnvironmentObject private var store: LiveLibraryStore
    let notice: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(notice, systemImage: "exclamationmark.circle")
                .font(StudyTypography.font(.subheadline))
                .foregroundStyle(Palette.secondary)
            Button("Try again") { Task { await store.refresh() } }
                .disabled(store.isLoading)
                .frame(minHeight: 44)
        }
    }
}

extension View {
    func libraryFrame() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .gardenCard(padding: 16)
    }
}
