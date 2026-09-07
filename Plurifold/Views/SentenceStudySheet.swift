import SwiftUI

/// A value snapshot: playback cannot replace the sentence being studied.
@MainActor
struct SentenceStudySheet: View {
    let sentence: ReadingSentence
    let document: ReadingDocument
    let lesson: MobileLesson
    @EnvironmentObject private var store: LiveLibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var explanation: PassageSelection?
    @State private var clearSelectionRequest = UUID()

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Playback is paused.")
                            .font(.subheadline).foregroundStyle(Palette.secondary)
                        SelectablePassage(
                            text: sentence.text,
                            highlights: lesson.vocabulary.map(\.term)
                                + store.words.filter { $0.languageCode == lesson.languageCode }.map(\.term),
                            clearSelectionRequest: clearSelectionRequest,
                            languageCode: lesson.languageCode,
                            onOpenSelection: { selected in
                                explanation = document.selection(in: sentence, localRange: selected.range)
                            }
                        )
                        .readingPanel(onBackgroundTap: clearSelection)
                        Text("Tap a word, or hold briefly and drag across a phrase. Then pull down on the highlight for details. Tap elsewhere to clear.")
                            .font(.footnote).foregroundStyle(Palette.secondary)
                        Button("Sentence details", systemImage: "text.magnifyingglass") {
                            explanation = PassageSelection(context: document.text, range: sentence.range)
                        }
                        .buttonStyle(.bordered)
                        .disabled(sentence.range.length > 800)
                        Spacer(minLength: 48)
                    }
                    .padding(24)
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: viewport.size.height, alignment: .topLeading)
                    .background {
                        Color.clear.contentShape(Rectangle()).onTapGesture(perform: clearSelection)
                    }
                }
            }
            .studyBackground()
            .navigationTitle("Study sentence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Back to player") { dismiss() }
                }
            }
            .sheet(item: $explanation, onDismiss: clearSelection) { selected in
                SelectionInsightSheet(selection: selected, lesson: lesson)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .tint(Palette.accent)
    }

    private func clearSelection() {
        clearSelectionRequest = UUID()
    }
}
