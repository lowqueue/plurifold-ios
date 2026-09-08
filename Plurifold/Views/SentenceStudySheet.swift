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
    @State private var selectionNotice: String?

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
                                if let contextual = document.selection(in: sentence, localRange: selected.range) {
                                    openSelection(contextual)
                                }
                            }
                        )
                        .readingPanel(onBackgroundTap: clearSelection)
                        Text("Tap a word for dictionary details. Hold briefly and drag in any direction; release 2–14 words for an AI explanation. Tap elsewhere to clear.")
                            .font(.footnote).foregroundStyle(Palette.secondary)
                        Button("Sentence details", systemImage: "text.magnifyingglass") {
                            if let selected = PassageSelection(context: document.text, range: sentence.range) {
                                openSelection(selected)
                            }
                        }
                        .buttonStyle(.bordered)
                        if let selectionNotice {
                            Text(selectionNotice).font(.footnote).foregroundStyle(Palette.secondary)
                                .accessibilityLabel(selectionNotice)
                        }
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
        selectionNotice = nil
    }

    private func openSelection(_ selected: PassageSelection) {
        if DefinitionSelection.exceedsExplanationWordLimit(selected.text, languageCode: lesson.languageCode) {
            selectionNotice = DefinitionSelection.wordLimitMessage
            return
        }
        guard selected.range.length <= 800 else {
            selectionNotice = "Select a shorter phrase for a focused explanation."
            return
        }
        guard DefinitionSelection.wordCount(in: selected.text, languageCode: lesson.languageCode) > 0 else { return }
        selectionNotice = nil
        explanation = selected
    }
}
