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
    @State private var selectionMode = false
    @State private var selection: PassageSelection?
    @State private var selectedMediaID = ""
    @State private var mediaPauseRequest = UUID()
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
        .sheet(item: $selection) { selected in
            if let lesson {
                SelectionInsightSheet(selection: selected, lesson: lesson)
                    .presentationDetents([.medium, .large])
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
                        highlights: store.words.filter { $0.languageCode == lesson.languageCode }.map(\.term),
                        selectionMode: selectionMode,
                        languageCode: lesson.languageCode,
                        scrollRequest: scrollRequest,
                        onReadingOffsetChange: { offset in
                            if let position = document.paragraphIndex(atUTF16Offset: offset), position != readingPosition {
                                readingPosition = position
                            }
                        },
                        onSelect: openSelection
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
                Text("Tap a word, or drag across words to explain a phrase. Turn on Select for dragging in any direction.")
                    .font(.footnote).foregroundStyle(Palette.secondary)
                if store.positions[lesson.id] != nil {
                    Button("Resume reading", systemImage: "bookmark.fill") { resume(lesson) }
                        .font(.subheadline)
                }
            }
        }
    }

    private func mediaControls(_ lesson: MobileLesson) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // One source is already chosen. Additional tracks remain available only
            // when a lesson actually contains alternatives.
            if lesson.media.count > 1 {
                Picker("Recording", selection: $selectedMediaID) {
                    ForEach(lesson.media) { media in Text(media.title).tag(media.id) }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedMediaID) { _, _ in speech.stop() }
            }
            if let media = lesson.media.first(where: { $0.id == selectedMediaID }) ?? lesson.media.first {
                LessonMediaPlayer(media: media, showsTitle: false, pauseRequest: mediaPauseRequest,
                                  onPlaybackStarted: { speech.stop() })
                    .id(media.id)
            }
        }
    }

    private func readerBar(_ lesson: MobileLesson) -> some View {
        VStack(spacing: 6) {
            if selectionMode {
                Text("Drag across words. Lift your finger for the explanation.")
                    .font(.caption).foregroundStyle(Palette.secondary)
                    .accessibilityLabel("Select mode is on. Drag in any direction to select words.")
            }
            HStack(spacing: 14) {
                Button {
                    selectionMode.toggle()
                } label: {
                    Label("Select", systemImage: selectionMode ? "hand.draw.fill" : "hand.draw")
                        .fontWeight(selectionMode ? .semibold : .regular)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                        .background(selectionMode ? Palette.field : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityValue(selectionMode ? "On" : "Off")
                .accessibilityHint("Enables phrase selection with vertical as well as horizontal drags")
                Spacer(minLength: 0)
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
        mediaPauseRequest = UUID()
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
        mediaPauseRequest = UUID()
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
        pausePlayback()
        defer { if activeLoadID == requestID { isLoading = false } }
        do {
            let loaded = try await store.loadLesson(lessonID)
            try Task.checkCancellation()
            guard activeLoadID == requestID else { return }
            document = ReadingDocument(paragraphs: loaded.paragraphs)
            selectedMediaID = loaded.media.first?.id ?? ""
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
