import SwiftUI

struct LiveLibraryView: View {
    @EnvironmentObject private var store: LiveLibraryStore
    @State private var search = ""
    @State private var selectedChannel = ""
    @State private var selectedLevel = ""
    let languageCode: String
    let languageName: String

    var body: some View {
        // One catalog/shelf snapshot per render; every row and filter reads the
        // same result instead of sorting and grouping the library repeatedly.
        let catalog = MobileLanguageCatalog(courses: store.courses)
        let languageKey = MobileLanguageKey.normalized(languageCode)
        let language = catalog.languages.first {
            MobileLanguageKey.normalized($0.code) == languageKey
        }
        let shelf = MobileLibraryShelf(courses: catalog.courses(for: language?.code ?? languageCode),
                                       search: search, channel: selectedChannel, level: selectedLevel)
        let savedCounts = savedCountsByLesson()

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
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
                    ContentUnavailableView("No lessons available", systemImage: "books.vertical",
                        description: Text("Your saved words are still in Words and Review. Choose another language or pull down to refresh."))
                } else {
                    if !shelf.courseFolders.isEmpty {
                        sectionHeading("Courses", subtitle: "Foundations and guided study")
                        ForEach(shelf.courseFolders) { folder in
                            NavigationLink(value: MobileStudyRoute.course(id: folder.id, search: "")) {
                                courseRow(folder)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    sectionHeading("Lessons", subtitle: "Explore your language through real content")
                    filters(shelf: shelf)
                    if shelf.lessonGroups.isEmpty {
                        ContentUnavailableView("No matching lessons", systemImage: "magnifyingglass",
                            description: Text("Try another search, channel, or ILR level."))
                        if !search.isEmpty || !selectedChannel.isEmpty || !selectedLevel.isEmpty {
                            Button("Clear filters") {
                                search = ""
                                selectedChannel = ""
                                selectedLevel = ""
                            }
                            .font(.subheadline.monospaced())
                            .frame(minHeight: 44)
                        }
                    }
                    // Section exposes each card to the outer lazy stack. An
                    // enclosing VStack would eagerly load every thumbnail.
                    ForEach(shelf.lessonGroups) { group in
                        Section {
                            ForEach(group.lessons) { item in
                                NavigationLink(value: MobileStudyRoute.lesson(id: item.lesson.id)) {
                                    LibraryLessonRow(lesson: item.lesson,
                                        hasPosition: store.positions[item.lesson.id] != nil,
                                        source: item.source,
                                        savedCount: savedCounts[LibrarySavedCountKey(lesson: item.lesson)] ?? 0)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            levelHeading(group)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .studyBackground()
        .tint(Palette.accent)
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await store.refresh() }
        .task { await store.refresh() }
        .onChange(of: languageCode) { _, _ in
            selectedChannel = ""
            selectedLevel = ""
            search = ""
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
            Eyebrow(text: "\(name) curriculum")
                .font(.caption2)
            Text("Library")
                .font(.largeTitle.monospaced())
                .accessibilityAddTraits(.isHeader)
            Text("Reading, listening, and practice. Continue where you left off.")
                .font(.subheadline.monospaced())
                .foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func filters(shelf: MobileLibraryShelf) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Library filters").font(.subheadline.monospaced())
                Text("\(shelf.visibleLessonCount) of \(shelf.totalLessonCount) lessons")
                    .font(.caption.monospaced())
                    .foregroundStyle(Palette.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Search").font(.caption.monospaced())
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.secondary)
                    TextField("Lessons, courses, channels", text: $search)
                        .font(.subheadline.monospaced())
                        .submitLabel(.search)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !search.isEmpty {
                        Button { search = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .frame(width: 32, height: 44)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 48)
                .background(Palette.field)
                .overlay(Rectangle().stroke(Palette.line, lineWidth: 1))
            }
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
        }
        .libraryFrame()
    }

    private func filterMenu<Content: View>(title: String, value: String,
                                          @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption.monospaced())
            Menu(content: content) {
                HStack(spacing: 12) {
                    Text(value).font(.subheadline.monospaced()).multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down").font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(Palette.ink)
                .background(Palette.field)
                .overlay(Rectangle().stroke(Palette.line, lineWidth: 1))
            }
            .accessibilityLabel(title)
            .accessibilityValue(value)
        }
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title2.monospaced()).accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.caption.monospaced()).foregroundStyle(Palette.secondary)
        }
    }

    private func levelHeading(_ group: MobileLibraryLevelGroup) -> some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text(group.title).font(.subheadline.monospaced())
                    Spacer()
                    Text(lessonCountLabel(group.lessons.count)).font(.caption.monospaced())
                        .foregroundStyle(Palette.secondary)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(group.title).font(.subheadline.monospaced())
                    Text(lessonCountLabel(group.lessons.count)).font(.caption.monospaced())
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

    private func courseRow(_ folder: MobileCourseFolder) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "folder")
                .font(.title2)
                .foregroundStyle(Palette.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(folder.course.title)
                    .font(.headline.monospaced().weight(.regular))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(folder.chapters.count == folder.course.lessons.count
                     ? "\(folder.chapters.count) \(folder.chapters.count == 1 ? "chapter" : "chapters")"
                     : "\(folder.chapters.count) of \(folder.course.lessons.count) chapters match")
                    .font(.caption.monospaced())
                    .foregroundStyle(Palette.secondary)
                Label("Open course", systemImage: "arrow.up.right")
                    .font(.caption.monospaced())
                    .foregroundStyle(Palette.accent)
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .libraryFrame()
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the chapters in this course")
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
                .font(.subheadline)
                .foregroundStyle(Palette.secondary)
            Button("Try again") { Task { await store.refresh() } }
                .disabled(store.isLoading)
                .frame(minHeight: 44)
        }
    }
}

extension View {
    func libraryFrame() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.line, lineWidth: 1))
    }
}

struct LibraryLessonRow: View {
    let lesson: MobileLessonSummary
    let hasPosition: Bool
    var source: String? = nil
    var savedCount: Int? = nil
    var showsCover = true

    private var thumbnailURL: URL? {
        guard let raw = lesson.thumbnailURL, let url = URL(string: raw),
              url.scheme?.lowercased() == "https", url.host != nil,
              url.user == nil, url.password == nil else { return nil }
        return url
    }
    private var media: (label: String, icon: String)? {
        switch lesson.mediaKind {
        case "video": return ("Video", "video")
        case "audio": return ("Audio", "headphones")
        case "text": return ("Reading", "book")
        default: return nil
        }
    }
    private var vocabulary: (total: Int, unique: Int, new: Int, percent: Int)? {
        guard let total = lesson.wordCount, let unique = lesson.uniqueWordCount,
              let new = lesson.newWordCount, total >= unique, unique >= new, new >= 0 else { return nil }
        let percent = unique > 0 ? Int((Double(new) / Double(unique) * 100).rounded()) : 0
        return (total, unique, new, percent)
    }
    private var sourceName: String {
        let value = (source ?? lesson.channel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? lesson.languageName : value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsCover {
                cover
                Rectangle().fill(Palette.line).frame(height: 1)
            }
            VStack(alignment: .leading, spacing: 14) {
                Text(sourceName)
                    .font(.caption.monospaced())
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
                Text(lesson.title)
                    .font(.title3.monospaced())
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                tags
                if let vocabulary {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("New words")
                            Spacer(minLength: 8)
                            Text("\(vocabulary.percent)%").monospacedDigit()
                        }
                        .font(.subheadline.monospaced())
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Palette.field)
                                Rectangle().fill(Palette.accent)
                                    .frame(width: geometry.size.width * CGFloat(vocabulary.percent) / 100)
                            }
                        }
                        .frame(height: 3)
                        .accessibilityHidden(true)
                        Text("\(vocabulary.new) of \(vocabulary.unique) unique words")
                            .font(.caption.monospaced())
                            .foregroundStyle(Palette.secondary)
                    }
                    .padding(.top, 2)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) { wordCount; savedEntryCount }
                    VStack(alignment: .leading, spacing: 6) { wordCount; savedEntryCount }
                }
                .font(.caption.monospaced())
                .foregroundStyle(Palette.secondary)
                if hasPosition {
                    Label("Reading place saved", systemImage: "bookmark.fill")
                        .font(.caption.monospaced())
                        .foregroundStyle(Palette.accent)
                }
            }
            .padding(18)
            Rectangle().fill(Palette.line).frame(height: 1)
            HStack(spacing: 8) {
                Text(hasPosition ? "Continue" : "Open lesson")
                Image(systemName: "arrow.up.right")
            }
            .font(.subheadline.monospaced())
            .foregroundStyle(Palette.accent)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        }
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.line, lineWidth: 1))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(hasPosition ? "Continue reading this lesson" : "Open this lesson")
    }

    @ViewBuilder private var wordCount: some View {
        if let total = lesson.wordCount, total >= 0 {
            Text("\(total) \(total == 1 ? "word" : "words")")
        } else if lesson.paragraphCount > 0 {
            Text("\(lesson.paragraphCount) \(lesson.paragraphCount == 1 ? "passage" : "passages")")
        }
    }

    @ViewBuilder private var savedEntryCount: some View {
        if let savedCount, savedCount >= 0 {
            Text("\(savedCount) saved \(savedCount == 1 ? "entry" : "entries")")
        }
    }

    private var tags: some View {
        VStack(alignment: .leading, spacing: 7) {
            let level = MobileLibraryShelf.levelKey(lesson.ilrLevel)
            Text(level == MobileLibraryShelf.unassessedLevel ? "ILR unassessed" : "ILR \(level) est.")
                .libraryTag()
                .accessibilityLabel(level == MobileLibraryShelf.unassessedLevel
                    ? "Material difficulty has not been assessed"
                    : "Estimated material difficulty, ILR \(level)")
            if let dialect = lesson.dialect?.trimmingCharacters(in: .whitespacesAndNewlines), !dialect.isEmpty {
                Text(dialect).libraryTag()
            }
        }
    }

    private var cover: some View {
        Rectangle()
            .fill(Palette.band)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("plurifold▌").font(.caption.monospaced())
                    Text(LanguageDisplay.nativeName(for: lesson.languageCode, fallback: lesson.languageName))
                        .font(.title.monospaced())
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
                .foregroundStyle(Palette.bandInk)
                .padding(20)
                .padding(.bottom, 22)
            }
            .overlay {
                if let thumbnailURL {
                    GeometryReader { geometry in
                        AsyncImage(url: thumbnailURL) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 8) {
                    Text(lesson.languageCode.split(separator: "-").first?.uppercased() ?? lesson.languageCode.uppercased())
                        .coverBadge()
                    Spacer(minLength: 8)
                    if let media { Label(media.label, systemImage: media.icon).coverBadge() }
                }
                .padding(12)
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

private extension View {
    func libraryTag() -> some View {
        font(.caption.monospaced())
            .foregroundStyle(Palette.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .overlay(Rectangle().stroke(Palette.line, lineWidth: 1))
    }

    func coverBadge() -> some View {
        font(.caption.monospaced())
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white.opacity(0.3), lineWidth: 1))
    }
}
