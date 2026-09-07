import SwiftUI

struct ReaderView: View {
    let course: Course
    let lesson: Lesson
    @EnvironmentObject private var store: StudyStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var speech = SpeechPlayer()
    @State private var selectedWord: VocabularyEntry?
    @State private var showTranslation = false
    @State private var initialParagraph: Int?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "\(course.languageName) / \(lesson.minutes) min")
                        Text(lesson.title).font(.system(.largeTitle, design: .serif).weight(.medium))
                        Text(lesson.subtitle).font(.body).foregroundStyle(Palette.secondary)
                        Text("Tap an underlined expression to explore it.")
                            .font(.subheadline).foregroundStyle(Palette.secondary)
                        if let index = initialParagraph, index > 0 {
                            Button {
                                proxy.scrollTo(lesson.paragraphs[index].id, anchor: .top)
                            } label: {
                                Label("Return to sentence \(index + 1)", systemImage: "arrow.turn.down.right")
                            }
                            .frame(minHeight: 44)
                        }
                    }

                    Toggle("English translation", isOn: $showTranslation)
                        .font(.subheadline.weight(.medium))
                        .tint(Palette.ink)
                        .padding(16)
                        .background(Palette.field.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))

                    ForEach(Array(lesson.paragraphs.enumerated()), id: \.element.id) { index, paragraph in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Eyebrow(text: String(format: "%02d", index + 1))
                                Spacer()
                                Button {
                                    store.recordParagraph(index, for: lesson)
                                    speech.speak(paragraph.text, language: course.languageCode)
                                } label: {
                                    Image(systemName: "speaker.wave.2")
                                        .frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("Listen to sentence \(index + 1)")
                            }
                            Text(linkedText(paragraph.text))
                                .font(.system(.title3, design: .serif))
                                .lineSpacing(8)
                                .tint(Palette.ink)
                                .environment(\.openURL, OpenURLAction { url in
                                    guard url.scheme == "plurifold", url.host == "word",
                                          let word = lesson.vocabulary.first(where: { $0.id == url.lastPathComponent }) else {
                                        return .discarded
                                    }
                                    store.recordParagraph(index, for: lesson)
                                    speech.stop()
                                    selectedWord = word
                                    return .handled
                                })
                            if showTranslation {
                                Text(paragraph.translation)
                                    .font(.body).lineSpacing(5).foregroundStyle(Palette.secondary)
                            }
                            Button {
                                store.recordParagraph(index, for: lesson)
                            } label: {
                                Label(
                                    (store.lastParagraph(for: lesson) ?? -1) >= index ? "Read" : "Mark as read",
                                    systemImage: (store.lastParagraph(for: lesson) ?? -1) >= index ? "checkmark.circle.fill" : "circle"
                                )
                                .font(.subheadline)
                                .frame(minHeight: 44)
                            }
                            .accessibilityHint("Saves your place through sentence \(index + 1)")
                        }
                        .id(paragraph.id)
                        if index < lesson.paragraphs.count - 1 {
                            Rectangle().fill(Palette.line).frame(height: 1)
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Eyebrow(text: "A moment to remember")
                        Text("What stayed with you?").font(.system(.title2, design: .serif))
                        Text("Answer \(lesson.questions.count) short questions to complete this lesson.")
                            .font(.body).foregroundStyle(Palette.secondary)
                        NavigationLink {
                            PracticeView(lesson: lesson)
                        } label: {
                            Label("Check understanding", systemImage: "arrow.right")
                        }
                        .buttonStyle(StudyButtonStyle())
                    }
                    .studyCard()
                }
                .padding(22)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
        .studyBackground()
        .navigationTitle("Reader")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(speech.isSpeaking ? "Listening" : "Listen to the story").font(.subheadline.weight(.semibold))
                    Text("\(course.languageName) · device voice").font(.caption.monospaced()).foregroundStyle(Palette.secondary)
                }
                Spacer()
                Button {
                    if speech.isSpeaking {
                        speech.stop()
                    } else {
                        speech.speak(lesson.paragraphs.map(\.text).joined(separator: " "), language: course.languageCode)
                    }
                } label: {
                    Image(systemName: speech.isSpeaking ? "stop.fill" : "play.fill")
                        .frame(width: 48, height: 48)
                        .background(Palette.field, in: Circle())
                }
                .accessibilityLabel(speech.isSpeaking ? "Stop listening" : "Listen to the whole story")
            }
            .padding(.horizontal, 22).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
        }
        .sheet(item: $selectedWord) { word in
            WordSheet(word: word, languageCode: course.languageCode)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if initialParagraph == nil { initialParagraph = store.lastParagraph(for: lesson) }
        }
        .onDisappear { speech.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { speech.stop() }
        }
        .alert("Listening unavailable", isPresented: Binding(
            get: { speech.notice != nil },
            set: { if !$0 { speech.notice = nil } }
        )) {
            Button("OK", role: .cancel) { speech.notice = nil }
        } message: { Text(speech.notice ?? "") }
    }

    private func linkedText(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        // Longest first preserves a phrase when another entry is one of its words.
        for word in lesson.vocabulary.sorted(by: { $0.term.count > $1.term.count }) {
            let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: word.term) + "(?![\\p{L}\\p{N}])"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let range = Range(match.range, in: text),
                      let lower = AttributedString.Index(range.lowerBound, within: result),
                      let upper = AttributedString.Index(range.upperBound, within: result) else { continue }
                let attributedRange = lower..<upper
                guard result[attributedRange].runs.allSatisfy({ $0.link == nil }) else { continue }
                var attributes = AttributeContainer()
                attributes.link = URL(string: "plurifold://word/\(word.id)")
                attributes.underlineStyle = .single
                if store.isSaved(word.id) { attributes.backgroundColor = Palette.field }
                result[attributedRange].mergeAttributes(attributes)
            }
        }
        return result
    }
}

struct WordSheet: View {
    let word: VocabularyEntry
    let languageCode: String
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var speech = SpeechPlayer()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Eyebrow(text: "In your own words")
                    Text(word.term).font(.system(.largeTitle, design: .serif).weight(.medium))
                    Text(word.meaning).font(.title3)
                    Text(word.note).font(.body).foregroundStyle(Palette.secondary)
                    Text(word.example).font(.system(.title3, design: .serif)).lineSpacing(6).studyCard()
                    Button {
                        if speech.isSpeaking { speech.stop() }
                        else { speech.speak(word.term, language: languageCode) }
                    } label: {
                        Label(speech.isSpeaking ? "Stop pronunciation" : "Hear pronunciation", systemImage: speech.isSpeaking ? "stop.fill" : "speaker.wave.2")
                            .frame(minHeight: 44)
                    }
                    if let notice = speech.notice {
                        Text(notice).font(.subheadline).foregroundStyle(Palette.secondary)
                    }
                    Button {
                        store.toggleSaved(word.id)
                    } label: {
                        Label(store.isSaved(word.id) ? "Saved · tap to remove" : "Save expression", systemImage: store.isSaved(word.id) ? "bookmark.fill" : "bookmark")
                    }
                    .buttonStyle(StudyButtonStyle())
                }
                .padding(24).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .studyBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onDisappear { speech.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { speech.stop() }
        }
    }
}
