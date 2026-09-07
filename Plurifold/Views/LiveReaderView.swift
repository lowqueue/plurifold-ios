import SwiftUI

@MainActor
struct LiveReaderView: View {
    let lessonID: String
    @EnvironmentObject private var store: LiveLibraryStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var speech = SpeechPlayer()
    @State private var lesson: MobileLesson?
    @State private var isLoading = true
    @State private var failure: String?
    @State private var reloadID = UUID()
    @State private var activeLoadID = UUID()
    @State private var showTranslations = false
    @State private var selection: PassageSelection?
    @State private var selectedMedia: MobileMedia?
    @State private var speechRequest: ReaderSpeechRequest?
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
        .task(id: speechRequest?.id) {
            // The selected media is removed from this view before device speech begins.
            guard let request = speechRequest, selection == nil, selectedMedia == nil else { return }
            speech.speak(request.text, language: request.languageCode)
        }
        .sheet(item: $selection) { selected in
            if let lesson {
                SelectionInsightSheet(selection: selected, lesson: lesson)
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
        .onDisappear { stopPlayback() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { stopPlayback() }
        }
    }

    private func reader(_ lesson: MobileLesson) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    header(lesson, proxy: proxy)
                    if !lesson.media.isEmpty { mediaControls(lesson) }

                    if lesson.paragraphs.isEmpty {
                        ContentUnavailableView("Lesson resources", systemImage: "doc.text",
                                               description: Text("This lesson has no reading passages. Open its available resources below."))
                    } else {
                        ForEach(Array(lesson.paragraphs.enumerated()), id: \.element.id) { index, paragraph in
                            passage(paragraph, index: index, lesson: lesson)
                                .id(paragraph.id)
                        }
                    }

                    if !lesson.vocabulary.isEmpty { glossary(lesson) }
                    resources(lesson)
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func header(_ lesson: MobileLesson, proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow(text: lesson.languageName)
            Text(lesson.title)
                .font(.largeTitle.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if !lesson.subtitle.isEmpty {
                Text(lesson.subtitle).foregroundStyle(Palette.secondary)
            }
            if let channel = lesson.channel, !channel.isEmpty {
                Label(channel, systemImage: "person.crop.rectangle")
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondary)
            }
            if !lesson.paragraphs.isEmpty {
                Text("Tap any word to study it. To study a phrase, press and hold, adjust the selection handles, then choose Explain selection.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondary)
                if lesson.paragraphs.contains(where: { !($0.translation ?? "").isEmpty }) {
                    Toggle("Show translations", isOn: $showTranslations)
                        .font(.subheadline)
                }
                if let saved = store.positions[lesson.id] {
                    let position = min(max(0, saved), lesson.paragraphs.count - 1)
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                            proxy.scrollTo(lesson.paragraphs[position].id, anchor: .top)
                        }
                    } label: {
                        Label("Resume at passage \(position + 1)", systemImage: "bookmark.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func mediaControls(_ lesson: MobileLesson) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Menu {
                ForEach(lesson.media) { media in
                    Button(media.title) {
                        speech.stop()
                        speechRequest = nil
                        selectedMedia = media
                    }
                }
            } label: {
                Label(selectedMedia == nil ? "Choose a recording" : "Change recording", systemImage: "play.rectangle")
                    .frame(minHeight: 44)
            }
            if let media = selectedMedia, selection == nil {
                LessonMediaPlayer(media: media)
                    .id(media.id)
                Button("Close player", systemImage: "xmark.circle") { selectedMedia = nil }
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .studyCard()
    }

    private func passage(_ paragraph: MobileParagraph, index: Int, lesson: MobileLesson) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Passage \(index + 1)")
                .font(.caption.monospaced())
                .foregroundStyle(Palette.secondary)
            SelectablePassage(
                text: paragraph.text,
                highlights: store.words.filter { $0.languageCode == lesson.languageCode }.map(\.term),
                onSelect: openSelection
            )
            if showTranslations, let translation = paragraph.translation, !translation.isEmpty {
                Text(translation)
                    .font(.body)
                    .foregroundStyle(Palette.secondary)
                    .textSelection(.enabled)
                    .padding(.top, 4)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    speechButton(paragraph, languageCode: lesson.languageCode)
                    Spacer(minLength: 0)
                    placeButton(index: index, lessonID: lesson.id)
                }
                VStack(alignment: .leading, spacing: 10) {
                    speechButton(paragraph, languageCode: lesson.languageCode)
                    placeButton(index: index, lessonID: lesson.id)
                }
            }
            .font(.subheadline)

            if speechRequest?.paragraphID == paragraph.id, let notice = speech.notice {
                Text(notice).font(.footnote).foregroundStyle(Palette.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .studyCard()
    }

    private func speechButton(_ paragraph: MobileParagraph, languageCode: String) -> some View {
        let isSpeaking = speech.isSpeaking && speechRequest?.paragraphID == paragraph.id
        return Button {
            if isSpeaking {
                speech.stop()
                speechRequest = nil
            } else {
                speech.stop()
                selectedMedia = nil
                speechRequest = ReaderSpeechRequest(paragraphID: paragraph.id, text: paragraph.text,
                                                    languageCode: languageCode)
            }
        } label: {
            Label(isSpeaking ? "Stop voice" : "Device voice",
                  systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2")
                .frame(minHeight: 44)
        }
        .accessibilityLabel(isSpeaking ? "Stop reading this passage" : "Read this passage with the device voice")
    }

    private func placeButton(index: Int, lessonID: String) -> some View {
        let saved = store.positions[lessonID] == index
        return Button {
            Task {
                await store.recordPosition(lessonID: lessonID, position: index)
                if store.positions[lessonID] != index {
                    saveError = store.notice ?? "Your reading place couldn’t be saved. Please try again."
                }
            }
        } label: {
            Label(saved ? "Place saved" : "Save my place", systemImage: saved ? "bookmark.fill" : "bookmark")
                .frame(minHeight: 44)
        }
        .disabled(store.isSaving || saved)
    }

    private func glossary(_ lesson: MobileLesson) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Lesson vocabulary").font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
            ForEach(Array(lesson.vocabulary.enumerated()), id: \.offset) { _, word in
                Button {
                    if let paragraph = lesson.paragraphs.first(where: { $0.text.range(of: word.term, options: .caseInsensitive) != nil }),
                       let range = paragraph.text.range(of: word.term, options: .caseInsensitive),
                       let selected = PassageSelection(context: paragraph.text, range: NSRange(range, in: paragraph.text)) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .studyCard()
    }

    @ViewBuilder
    private func resources(_ lesson: MobileLesson) -> some View {
        let available = lesson.resources.compactMap { resource -> ReaderResource? in
            guard let parts = URLComponents(string: resource.url), parts.scheme?.lowercased() == "https",
                  let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
                  let url = parts.url else { return nil }
            return ReaderResource(id: resource.id, title: resource.title, url: url)
        }
        if !available.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Resources").font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                ForEach(available) { resource in
                    Link(destination: resource.url) {
                        Label(resource.title, systemImage: "arrow.up.right.square")
                            .frame(minHeight: 44, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .studyCard()
        }
    }

    private func openSelection(_ selected: PassageSelection) {
        stopPlayback()
        selection = selected
    }

    private func stopPlayback() {
        speech.stop()
        speechRequest = nil
        selectedMedia = nil
    }

    private func load() async {
        let requestID = UUID()
        activeLoadID = requestID
        isLoading = true
        failure = nil
        lesson = nil
        stopPlayback()
        defer { if activeLoadID == requestID { isLoading = false } }
        do {
            let loaded = try await store.loadLesson(lessonID)
            try Task.checkCancellation()
            guard activeLoadID == requestID else { return }
            lesson = loaded
        } catch is CancellationError { return }
        catch { if activeLoadID == requestID { failure = error.localizedDescription } }
    }
}

private struct ReaderSpeechRequest: Identifiable {
    let id = UUID()
    let paragraphID: String
    let text: String
    let languageCode: String
}

private struct ReaderResource: Identifiable {
    let id: String
    let title: String
    let url: URL
}
