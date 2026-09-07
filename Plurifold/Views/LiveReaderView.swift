import SwiftUI

@MainActor
struct LiveReaderView: View {
    let lessonID: String
    @EnvironmentObject private var store: LiveLibraryStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var speech = SpeechPlayer()
    @State private var lesson: MobileLesson?
    @State private var document = ReadingDocument(paragraphs: [])
    @State private var isLoading = true
    @State private var failure: String?
    @State private var reloadID = UUID()
    @State private var activeLoadID = UUID()
    @State private var showTranslations = false
    @State private var selection: PassageSelection?
    @State private var pendingSelection: PassageSelection?
    @State private var clearSelectionRequest = UUID()
    @State private var showPlayback = false
    @State private var readingPosition = 0
    @State private var scrollRequest: ReaderScrollRequest?
    @State private var saveError: String?

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Opening lesson…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let lesson {
                reader(lesson)
            } else {
                ContentUnavailableView {
                    Label("Lesson couldn’t open", systemImage: "book.closed")
                } description: {
                    Text(failure ?? "Please try again.")
                } actions: {
                    Button("Try again") { reloadID = UUID() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .studyBackground()
        .tint(Palette.ink)
        .navigationTitle(lesson?.title ?? "Lesson")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(lessonID)|\(reloadID)") { await load() }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let lesson, !document.text.isEmpty, !isLoading {
                readerBar(lesson)
            }
        }
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
        .alert("Reading place", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .onDisappear { pausePlayback() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { pausePlayback() }
        }
    }

    private func reader(_ lesson: MobileLesson) -> some View {
        GeometryReader { viewport in
            ScrollView {
                // A single text surface allows a selection to cross paragraph boundaries.
                VStack(alignment: .leading, spacing: 28) {
                    header(lesson)
                    if !lesson.media.isEmpty { mediaControls(lesson) }

                    if document.text.isEmpty {
                        ContentUnavailableView("Lesson resources", systemImage: "doc.text",
                                               description: Text("Open this lesson’s available resources below."))
                    } else {
                        SelectablePassage(
                            text: document.text,
                            highlights: studyTerms(lesson),
                            clearSelectionRequest: clearSelectionRequest,
                            onClearSelection: { pendingSelection = nil },
                            languageCode: lesson.languageCode,
                            scrollRequest: scrollRequest,
                            onReadingOffsetChange: { offset in
                                if let position = document.paragraphIndex(atUTF16Offset: offset), position != readingPosition {
                                    readingPosition = position
                                }
                            },
                            onSelect: { pendingSelection = $0 }
                        )
                    }

                    if showTranslations { translations(lesson) }
                    if !lesson.vocabulary.isEmpty {
                        DisclosureGroup("Lesson vocabulary") { glossary(lesson).padding(.top, 14) }
                    }
                    resources(lesson)
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .frame(minHeight: viewport.size.height, alignment: .topLeading)
                .background {
                    Color.clear.contentShape(Rectangle()).onTapGesture(perform: clearSelection)
                }
            }
        }
    }

    private func header(_ lesson: MobileLesson) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: lesson.languageName)
            Text(lesson.title)
                .font(.largeTitle.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if !lesson.subtitle.isEmpty {
                Text(lesson.subtitle).foregroundStyle(Palette.secondary)
            }
            if let channel = lesson.channel, !channel.isEmpty {
                Text(channel).font(.subheadline).foregroundStyle(Palette.secondary)
            }
            if !document.text.isEmpty {
                Text("Tap a word to select it. Hold briefly, then drag to select a phrase. Tap elsewhere to clear.")
                    .font(.footnote).foregroundStyle(Palette.secondary)
                if store.positions[lesson.id] != nil {
                    Button("Resume reading", systemImage: "bookmark.fill") { resume(lesson) }
                        .font(.subheadline)
                }
            }
        }
    }

    private func mediaControls(_ lesson: MobileLesson) -> some View {
        let hasVideo = lesson.media.contains { ["youtube", "video"].contains($0.kind) }
        return Button {
            speech.stop()
            clearSelection()
            showPlayback = true
        } label: {
            Label(hasVideo ? "Watch video" : "Listen to recording",
                  systemImage: hasVideo ? "play.rectangle" : "play.circle")
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityHint("Opens the player and transcript")
    }

    private func readerBar(_ lesson: MobileLesson) -> some View {
        VStack(spacing: 6) {
            if let pendingSelection {
                ReaderSelectionBar(selection: pendingSelection,
                                   onExplain: { openSelection(pendingSelection) }, onClear: clearSelection)
            }
            HStack(spacing: 14) {
                Button {
                    readCurrentParagraph(lesson)
                } label: {
                    Label(speech.isSpeaking ? "Stop" : "Listen",
                          systemImage: speech.isSpeaking ? "stop.fill" : "speaker.wave.2")
                        .frame(minHeight: 44)
                }
                .accessibilityHint("Reads the paragraph currently at the top of the reader using the device voice")
                Spacer(minLength: 0)
                Menu {
                    Button("Save my place", systemImage: "bookmark") { savePlace(lesson) }
                        .disabled(store.isSaving || lesson.paragraphs.isEmpty)
                    if store.positions[lesson.id] != nil {
                        Button("Resume saved place", systemImage: "bookmark.fill") { resume(lesson) }
                    }
                    if lesson.paragraphs.contains(where: { !($0.translation ?? "").isEmpty }) {
                        Toggle("Show translations", isOn: $showTranslations)
                    }
                } label: {
                    Image(systemName: store.isSaving ? "hourglass" : "ellipsis.circle")
                        .font(.title3).frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Reader options")
            }
            .font(.subheadline)
            if let notice = speech.notice {
                Text(notice).font(.caption).foregroundStyle(Palette.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(.regularMaterial)
    }

    private func readCurrentParagraph(_ lesson: MobileLesson) {
        if speech.isSpeaking { speech.stop(); return }
        guard !lesson.paragraphs.isEmpty else { return }
        clearSelection()
        let position = min(max(0, readingPosition), lesson.paragraphs.count - 1)
        speech.speak(lesson.paragraphs[position].text, language: lesson.languageCode)
    }

    private func savePlace(_ lesson: MobileLesson) {
        let position = min(max(0, readingPosition), max(0, lesson.paragraphs.count - 1))
        Task {
            await store.recordPosition(lessonID: lessonID, position: position)
            saveError = store.positions[lessonID] == position
                ? "Your reading place is saved."
                : (store.notice ?? "Your reading place couldn’t be saved. Please try again.")
        }
    }

    private func resume(_ lesson: MobileLesson) {
        guard let saved = store.positions[lesson.id], !document.paragraphRanges.isEmpty else { return }
        let position = min(max(0, saved), document.paragraphRanges.count - 1)
        scrollRequest = ReaderScrollRequest(utf16Offset: document.paragraphRanges[position].location)
    }

    @ViewBuilder private func translations(_ lesson: MobileLesson) -> some View {
        let available = lesson.paragraphs.compactMap(\.translation).filter { !$0.isEmpty }
        if !available.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Translation").font(.headline)
                Text(available.joined(separator: "\n\n"))
                    .foregroundStyle(Palette.secondary).textSelection(.enabled)
            }
        }
    }

    private func glossary(_ lesson: MobileLesson) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(lesson.vocabulary.enumerated()), id: \.offset) { _, word in
                Button {
                    if let range = document.text.range(of: word.term, options: .caseInsensitive),
                       let selected = PassageSelection(context: document.text, range: NSRange(range, in: document.text)) {
                        openSelection(selected)
                    } else if let selected = PassageSelection(context: word.term,
                                                              range: NSRange(location: 0, length: word.term.utf16.count)) {
                        openSelection(selected)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(word.term).font(.headline)
                        Text(word.meaning).foregroundStyle(Palette.secondary)
                        if let note = word.note, !note.isEmpty {
                            Text(note).font(.subheadline).foregroundStyle(Palette.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private func resources(_ lesson: MobileLesson) -> some View {
        let available = lesson.resources.compactMap { resource -> ReaderResource? in
            guard let parts = URLComponents(string: resource.url), parts.scheme?.lowercased() == "https",
                  let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
                  let url = parts.url else { return nil }
            return ReaderResource(id: resource.id, title: resource.title, url: url)
        }
        if !available.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Resources").font(.headline)
                ForEach(available) { resource in
                    Link(destination: resource.url) {
                        Label(resource.title, systemImage: "arrow.up.right.square")
                            .frame(minHeight: 44, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func openSelection(_ selected: PassageSelection) {
        pausePlayback()
        selection = selected
    }

    private func pausePlayback() {
        speech.stop()
    }

    private func clearSelection() {
        pendingSelection = nil
        clearSelectionRequest = UUID()
    }

    private func studyTerms(_ lesson: MobileLesson) -> [String] {
        lesson.vocabulary.map(\.term) + store.words.filter { $0.languageCode == lesson.languageCode }.map(\.term)
    }

    private func load() async {
        let requestID = UUID()
        activeLoadID = requestID
        isLoading = true
        failure = nil
        lesson = nil
        document = ReadingDocument(paragraphs: [])
        readingPosition = 0
        scrollRequest = nil
        clearSelection()
        showPlayback = false
        pausePlayback()
        defer { if activeLoadID == requestID { isLoading = false } }
        do {
            let loaded = try await store.loadLesson(lessonID)
            try Task.checkCancellation()
            guard activeLoadID == requestID else { return }
            document = ReadingDocument(paragraphs: loaded.paragraphs, languageCode: loaded.languageCode)
            lesson = loaded
        } catch is CancellationError { return }
        catch { if activeLoadID == requestID { failure = error.localizedDescription } }
    }
}

private struct ReaderResource: Identifiable {
    let id: String
    let title: String
    let url: URL
}
