import SwiftUI

/// Course activities retain their source page, instructions and practice,
/// instead of treating every course entry as an undifferentiated transcript.
@MainActor
struct CourseActivityView: View {
    let courseID: String
    let lessonID: String
    @EnvironmentObject private var store: LiveLibraryStore
    @EnvironmentObject private var studyScope: MobileStudyScope
    @Environment(\.dismiss) private var dismiss
    @State private var lesson: MobileLesson?
    @State private var document = ReadingDocument(paragraphs: [])
    @State private var isLoading = true
    @State private var failure: String?
    @State private var reloadID = UUID()
    @State private var activeLoadID = UUID()
    @State private var selection: PassageSelection?
    @State private var clearSelectionRequest = UUID()
    @State private var selectionNotice: String?
    @State private var showPlayback = false
    @State private var expandedImage: MobileCourseImage?
    @State private var sourcePageIndex = 0

    private var course: MobileCourse? {
        guard let course = store.courses.first(where: { $0.id == courseID }) else { return nil }
        return MobileCourse(id: course.id, title: course.title, languageCode: course.languageCode,
                            languageName: course.languageName,
                            lessons: course.lessons.filter { $0.kind == "course" })
    }
    private var activityIndex: Int? { course?.lessons.firstIndex { $0.id == lessonID } }

    var body: some View {
        // Keep one scroll container during loading and after content arrives.
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    ProgressView("Opening activity…")
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else if let lesson {
                    activityHeader(lesson)
                    if !lesson.media.isEmpty { playbackButton(lesson) }
                    if let content = lesson.courseContent {
                        sourcePages(content.images)
                        if let exercise = content.exercise, !exercise.items.isEmpty {
                            CourseExerciseView(exercise: exercise)
                        }
                        ForEach(content.sections) { section in
                            activitySection(section, lesson: lesson)
                        }
                    }
                    if !lesson.vocabulary.isEmpty { vocabulary(lesson) }
                    if !document.text.isEmpty { transcript(lesson) }
                    resources(lesson)
                    if let attribution = lesson.courseContent?.sourceAttribution, !attribution.isEmpty {
                        Text(attribution)
                            .font(.caption).foregroundStyle(Palette.secondary)
                    }
                } else {
                    ContentUnavailableView {
                        Label("Activity couldn’t open", systemImage: "book.closed")
                    } description: {
                        Text(failure ?? "Please try again.")
                    } actions: {
                        Button("Try again") { reloadID = UUID() }.buttonStyle(.bordered)
                    }
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollDismissesKeyboard(.interactively)
        .studyBackground()
        .tint(Palette.accent)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) { activityNavigation }
        .task(id: "\(lessonID)|\(reloadID)") { await load() }
        .sheet(item: $selection, onDismiss: clearSelection) { selected in
            if let lesson {
                SelectionInsightSheet(selection: selected, lesson: lesson)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showPlayback) {
            if let lesson {
                LessonPlaybackSheet(lesson: lesson, document: document)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(item: $expandedImage) { image in
            if let url = CourseSourceURL.valid(image.url) {
                CourseSourcePageSheet(title: image.title, url: url)
            }
        }
        .alert("Choose a shorter selection", isPresented: Binding(
            get: { selectionNotice != nil },
            set: { if !$0 { selectionNotice = nil } }
        )) {
            Button("OK", role: .cancel) { selectionNotice = nil }
        } message: {
            Text(selectionNotice ?? "")
        }
    }

    private var activityNavigation: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Label("Course", systemImage: "chevron.left")
                    .font(.subheadline.monospaced())
                    .frame(minHeight: 44)
            }
            .accessibilityLabel("Back to course")
            Spacer(minLength: 4)
            if let index = activityIndex, let course {
                Text("\(index + 1) / \(course.lessons.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(Palette.secondary)
                    .accessibilityLabel("Activity \(index + 1) of \(course.lessons.count)")
                Button { openActivity(at: index - 1, in: course) } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .disabled(index == 0)
                .accessibilityLabel("Previous activity")
                Button { openActivity(at: index + 1, in: course) } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .disabled(index + 1 >= course.lessons.count)
                .accessibilityLabel("Next activity")
            }
        }
        .padding(.horizontal, 16)
        .foregroundStyle(Palette.ink)
        .background(Palette.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
    }

    private func activityHeader(_ lesson: MobileLesson) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let unit = lesson.courseContent?.unitTitle, !unit.isEmpty {
                Eyebrow(text: unit)
            } else {
                Text(lesson.courseContent?.courseTitle ?? course?.title ?? lesson.languageName)
                    .font(.caption.monospaced()).foregroundStyle(Palette.secondary)
            }
            Text(lesson.title)
                .font(.title3.monospaced().weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if !lesson.subtitle.isEmpty {
                Text(introduction(lesson.subtitle)).font(.subheadline).foregroundStyle(Palette.secondary)
                if lesson.subtitle.count > 240 {
                    DisclosureGroup("Lesson guide") {
                        Text(lesson.subtitle).font(.subheadline)
                            .foregroundStyle(Palette.secondary).padding(.top, 10)
                    }
                    .font(.caption.weight(.medium))
                }
            }
            if let instruction = lesson.courseContent?.originalInstruction,
               !instruction.isEmpty, instruction != lesson.subtitle {
                Text(instruction).font(.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func introduction(_ text: String) -> String {
        guard text.count > 240 else { return text }
        let firstLine = text.components(separatedBy: .newlines).first ?? text
        let breaks = [". ", "! ", "? "].compactMap { firstLine.range(of: $0)?.upperBound }
        if let end = breaks.min(), firstLine.distance(from: firstLine.startIndex, to: end) <= 240 {
            return String(firstLine[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if firstLine.count <= 240 { return firstLine }
        return text.prefix(220).split(whereSeparator: \.isWhitespace).dropLast().joined(separator: " ") + "…"
    }

    @ViewBuilder private func sourcePages(_ images: [MobileCourseImage]) -> some View {
        let available = images.filter { CourseSourceURL.valid($0.url) != nil }
        if !available.isEmpty {
            let index = min(max(0, sourcePageIndex), available.count - 1)
            let image = available[index]
            VStack(spacing: 8) {
                if available.count > 1 {
                    HStack(spacing: 8) {
                        Text("Source page \(index + 1) of \(available.count)")
                            .font(.caption.monospaced()).foregroundStyle(Palette.secondary)
                        Spacer(minLength: 0)
                        Button { sourcePageIndex = index - 1 } label: {
                            Image(systemName: "chevron.left").frame(width: 44, height: 44)
                        }
                        .disabled(index == 0)
                        .accessibilityLabel("Previous source page")
                        Button { sourcePageIndex = index + 1 } label: {
                            Image(systemName: "chevron.right").frame(width: 44, height: 44)
                        }
                        .disabled(index + 1 >= available.count)
                        .accessibilityLabel("Next source page")
                    }
                }
                if let url = CourseSourceURL.valid(image.url) {
                    // Decode just the visible page, including multi-page textbooks.
                    CourseSourcePage(image: image, url: url) { expandedImage = image }
                        .id(image.id)
                }
            }
        }
    }

    private func playbackButton(_ lesson: MobileLesson) -> some View {
        let video = lesson.media.contains { ["youtube", "video"].contains($0.kind) }
        return Button {
            clearSelection()
            showPlayback = true
        } label: {
            Label(video ? "Watch video" : "Listen to recording",
                  systemImage: video ? "play.rectangle" : "headphones")
                .font(.subheadline.weight(.medium))
                .frame(minHeight: 44)
                .padding(.horizontal, 14)
                .foregroundStyle(Palette.accent)
                .background(Palette.field, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func activitySection(_ section: MobileCourseSection, lesson: MobileLesson) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(section.title).font(.headline.monospaced()).accessibilityAddTraits(.isHeader)
            if let body = section.body, !body.isEmpty { Text(body).font(.body) }
            ForEach(section.rows) { row in
                Button { select(row.text) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(row.text).font(.body.weight(.medium))
                        if let meaning = row.meaning, !meaning.isEmpty {
                            Text(meaning).font(.subheadline).foregroundStyle(Palette.secondary)
                        }
                        if let note = row.note, !note.isEmpty {
                            Text(note).font(.caption).foregroundStyle(Palette.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens word details")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .studyCard()
    }

    private func vocabulary(_ lesson: MobileLesson) -> some View {
        DisclosureGroup("Words and expressions") {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(lesson.vocabulary.enumerated()), id: \.offset) { _, word in
                    Button { select(word.term) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(word.term).font(.body.weight(.medium))
                            Text(word.meaning).font(.subheadline).foregroundStyle(Palette.secondary)
                            if let note = word.note, !note.isEmpty {
                                Text(note).font(.caption).foregroundStyle(Palette.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens word details")
                }
            }
            .padding(.top, 14)
        }
        .font(.subheadline.weight(.medium))
        .studyCard()
    }

    private func transcript(_ lesson: MobileLesson) -> some View {
        DisclosureGroup("Transcript and word study") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tap a word for its dictionary entry. Hold and drag to study a short phrase.")
                    .font(.caption).foregroundStyle(Palette.secondary)
                SelectablePassage(
                    text: document.text,
                    highlights: lesson.vocabulary.map(\.term) + store.words.filter {
                        MobileLanguageKey.normalized($0.languageCode) == MobileLanguageKey.normalized(lesson.languageCode)
                    }.map(\.term),
                    clearSelectionRequest: clearSelectionRequest,
                    languageCode: lesson.languageCode,
                    onOpenSelection: openSelection
                )
                .fixedSize(horizontal: false, vertical: true)
                let translations = lesson.paragraphs.compactMap(\.translation).filter { !$0.isEmpty }
                if !translations.isEmpty {
                    DisclosureGroup("Meaning") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(translations.enumerated()), id: \.offset) { _, meaning in
                                Text(meaning).font(.subheadline).foregroundStyle(Palette.secondary)
                            }
                        }
                        .padding(.top, 12)
                    }
                    .font(.subheadline.weight(.medium))
                }
            }
            .padding(.top, 14)
        }
        .font(.subheadline.weight(.medium))
        .readingPanel(onBackgroundTap: clearSelection)
    }

    @ViewBuilder private func resources(_ lesson: MobileLesson) -> some View {
        let links = lesson.resources.filter { CourseSourceURL.valid($0.url) != nil }
        if !links.isEmpty {
            DisclosureGroup("Source and resources") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(links) { resource in
                        if let url = CourseSourceURL.valid(resource.url) {
                            Link(destination: url) {
                                Label(resource.title, systemImage: "arrow.up.right.square")
                                    .font(.subheadline).frame(minHeight: 44, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(.top, 10)
            }
            .font(.subheadline.weight(.medium))
            .studyCard()
        }
    }

    private func select(_ text: String) {
        if let range = document.text.range(of: text),
           let selected = PassageSelection(context: document.text, range: NSRange(range, in: document.text)) {
            openSelection(selected)
        } else if let selected = PassageSelection(context: text, range: NSRange(location: 0, length: text.utf16.count)) {
            openSelection(selected)
        }
    }

    private func openSelection(_ selected: PassageSelection) {
        guard let lesson else { return }
        guard !DefinitionSelection.exceedsExplanationWordLimit(selected.text, languageCode: lesson.languageCode),
              selected.range.length <= 800 else {
            selectionNotice = DefinitionSelection.wordLimitMessage
            return
        }
        guard DefinitionSelection.wordCount(in: selected.text, languageCode: lesson.languageCode) > 0 else { return }
        selection = selected
    }

    private func clearSelection() { clearSelectionRequest = UUID() }

    private func openActivity(at index: Int, in course: MobileCourse) {
        guard course.lessons.indices.contains(index) else { return }
        studyScope.openCourseActivity(course.lessons[index].id, in: course)
    }

    private func load() async {
        let requestID = UUID()
        activeLoadID = requestID
        isLoading = true
        failure = nil
        lesson = nil
        do {
            let loaded = try await store.loadLesson(lessonID)
            try Task.checkCancellation()
            guard activeLoadID == requestID else { return }
            // Resource addresses belong to labeled links, never the reading surface.
            let paragraphs = loaded.paragraphs.filter { paragraph in
                !CourseSourceURL.isAddressOnly(paragraph.text)
            }
            document = ReadingDocument(paragraphs: paragraphs, languageCode: loaded.languageCode)
            // Player timeline and word-study offsets must use the same paragraphs.
            lesson = MobileLesson(id: loaded.id, title: loaded.title, subtitle: loaded.subtitle,
                languageCode: loaded.languageCode, languageName: loaded.languageName, dialect: loaded.dialect,
                paragraphCount: paragraphs.count, kind: loaded.kind, channel: loaded.channel,
                paragraphs: paragraphs, media: loaded.media, resources: loaded.resources,
                vocabulary: loaded.vocabulary, courseContent: loaded.courseContent)
            isLoading = false
        } catch is CancellationError { return }
        catch {
            guard activeLoadID == requestID else { return }
            failure = error.localizedDescription
            isLoading = false
        }
    }
}

enum CourseSourceURL {
    static func isAddressOnly(_ source: String) -> Bool {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.contains(where: \.isWhitespace) else { return false }
        if text.hasPrefix("/courses/") {
            let path = URLComponents(string: text)?.path ?? text
            return ["png", "jpg", "jpeg", "webp", "svg", "gif", "pdf", "mp3", "mp4", "m4a"]
                .contains((path as NSString).pathExtension.lowercased())
        }
        guard let components = URLComponents(string: text),
              ["https", "http"].contains(components.scheme?.lowercased() ?? ""),
              let host = components.host, !host.isEmpty else { return false }
        return components.url != nil
    }

    static func valid(_ source: String) -> URL? {
        guard let components = URLComponents(string: source),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil else { return nil }
        return components.url
    }
}

private struct CourseSourcePage: View {
    let image: MobileCourseImage
    let url: URL
    let expand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: expand) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit().padding(8)
                    case .failure:
                        Label("Preview unavailable", systemImage: "photo")
                            .font(.subheadline).foregroundStyle(Palette.secondary)
                    default:
                        ProgressView("Loading source page…").font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .background(Palette.surface)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Enlarge \(image.title)")
            HStack(spacing: 12) {
                Text(image.title).font(.caption).foregroundStyle(Palette.secondary)
                    .lineLimit(2)
                    .accessibilityLabel(image.title)
                Spacer(minLength: 0)
                Button(action: expand) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Enlarge source page")
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Open source page in browser")
            }
            .padding(.horizontal, 12)
            .background(Palette.groupSurface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.line, lineWidth: 1))
    }
}

private struct CourseSourcePageSheet: View {
    let title: String
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var enlarged = false

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
                ScrollView([.horizontal, .vertical]) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                                .frame(width: max(1, viewport.size.width - 24) * (enlarged ? 2 : 1))
                                .onTapGesture(count: 2) { enlarged.toggle() }
                        case .failure:
                            VStack(spacing: 16) {
                                Text("The source page couldn’t load.")
                                Link("Open in browser", destination: url)
                            }
                            .frame(width: max(1, viewport.size.width - 24))
                            .frame(minHeight: 220)
                        default:
                            ProgressView("Loading source page…")
                                .frame(width: max(1, viewport.size.width - 24))
                                .frame(minHeight: 220)
                        }
                    }
                    .padding(12)
                }
            }
            .studyBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(enlarged ? "Fit" : "Zoom", systemImage: enlarged ? "minus.magnifyingglass" : "plus.magnifyingglass") {
                        enlarged.toggle()
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(Palette.accent)
    }
}
