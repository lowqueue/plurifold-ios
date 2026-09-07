import SwiftUI

/// The player exists only on this sheet; the main reader remains transcript first.
@MainActor
struct LessonPlaybackSheet: View {
    let lesson: MobileLesson
    let document: ReadingDocument
    private let timeline: LessonTranscriptTimeline
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedMediaID: String
    @State private var pauseRequest = UUID()
    @State private var activeParagraph: Int?
    @State private var followsPlayback = true
    @State private var heldSentence: ReadingSentence?
    @State private var studySentence: ReadingSentence?
    @State private var followRequest = UUID()
    @State private var clock = PlaybackClock()

    init(lesson: MobileLesson, document: ReadingDocument) {
        self.lesson = lesson
        self.document = document
        timeline = LessonTranscriptTimeline(paragraphs: lesson.paragraphs)
        let preferred = lesson.media.first { ["youtube", "video"].contains($0.kind) } ?? lesson.media.first
        _selectedMediaID = State(initialValue: preferred?.id ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                player
                    .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 10)
                HStack {
                    Text("Transcript").font(.headline)
                    Spacer()
                    if timeline.hasTimings {
                        Button {
                            followsPlayback.toggle()
                            if followsPlayback { followRequest = UUID() }
                        } label: {
                            Label(followsPlayback ? "Following" : "Follow audio",
                                  systemImage: followsPlayback ? "location.fill" : "location")
                                .font(.caption).frame(minHeight: 44)
                        }
                        .accessibilityValue(followsPlayback ? "On" : "Off")
                    }
                }
                .padding(.horizontal, 24)
                Text("Hold a sentence for two seconds to study its words.")
                    .font(.footnote).foregroundStyle(Palette.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24).padding(.bottom, 12)
                transcript
            }
            .studyBackground()
            .navigationTitle(lesson.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { pauseRequest = UUID(); dismiss() }
                }
            }
            .sheet(item: $studySentence, onDismiss: {
                heldSentence = nil
                refreshCurrentParagraph()
            }) { sentence in
                SentenceStudySheet(sentence: sentence, document: document, lesson: lesson)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: selectedMediaID) { _, _ in
                activeParagraph = nil
                clock.time = nil
                heldSentence = nil
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { pauseRequest = UUID(); heldSentence = nil }
            }
            .onDisappear { pauseRequest = UUID() }
        }
        .tint(Palette.ink)
    }

    private var player: some View {
        VStack(spacing: 8) {
            if lesson.media.count > 1 {
                Picker("Recording", selection: $selectedMediaID) {
                    ForEach(lesson.media) { Text($0.title).tag($0.id) }
                }
                .pickerStyle(.menu)
            }
            if let media = lesson.media.first(where: { $0.id == selectedMediaID }) {
                LessonMediaPlayer(media: media, showsTitle: false, pauseRequest: pauseRequest,
                    onPlaybackStarted: {
                        // A delayed play notification must not restart sound behind study.
                        if studySentence != nil { pauseRequest = UUID() }
                    },
                    onPlaybackTimeChanged: { time in
                        clock.time = time
                        refreshCurrentParagraph()
                    })
                    .id(media.id)
            }
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    ForEach(Array(document.sentencesByParagraph.enumerated()), id: \.offset) { index, sentences in
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(sentences) { sentence in sentenceRow(sentence) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(index)
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 12)
            }
            .simultaneousGesture(DragGesture(minimumDistance: 12).onChanged { _ in
                if followsPlayback { followsPlayback = false }
            })
            .onChange(of: activeParagraph) { _, _ in follow(using: proxy) }
            .onChange(of: followRequest) { _, _ in follow(using: proxy) }
        }
    }

    private func sentenceRow(_ sentence: ReadingSentence) -> some View {
        let current = activeParagraph == sentence.paragraphIndex
        let held = heldSentence?.id == sentence.id
        return Text(sentence.text)
            .font(.title3).lineSpacing(5)
            .foregroundStyle(current || held ? Palette.ink : Palette.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
            .background(held ? Palette.field : Color.clear)
            .overlay(alignment: .leading) {
                if current {
                    Capsule().fill(Palette.secondary).frame(width: 3).offset(x: -12)
                }
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 2, maximumDistance: 16, pressing: { pressing in
                if pressing {
                    // Snapshot on touch-down, before a timing event can advance the transcript.
                    heldSentence = sentence
                } else if studySentence == nil {
                    heldSentence = nil
                    refreshCurrentParagraph()
                }
            }, perform: {
                openStudy(heldSentence ?? sentence)
            })
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Hold to pause playback and study this sentence")
            .accessibilityAction(named: Text("Study sentence")) { openStudy(sentence) }
    }

    private func refreshCurrentParagraph() {
        guard heldSentence == nil, studySentence == nil else { return }
        let next = clock.time.flatMap { timeline.paragraphIndex(at: $0) }
        if next != activeParagraph { activeParagraph = next }
    }

    private func follow(using proxy: ScrollViewProxy) {
        guard followsPlayback, heldSentence == nil, studySentence == nil,
              let activeParagraph else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            proxy.scrollTo(activeParagraph, anchor: .center)
        }
    }

    private func openStudy(_ sentence: ReadingSentence) {
        pauseRequest = UUID()
        studySentence = sentence
    }
}

/// Non-published time avoids rebuilding the transcript at every player tick.
@MainActor
private final class PlaybackClock {
    var time: Double?
}
