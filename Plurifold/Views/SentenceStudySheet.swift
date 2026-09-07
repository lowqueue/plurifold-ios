import SwiftUI

/// A value snapshot: playback cannot replace the sentence being studied.
@MainActor
struct SentenceStudySheet: View {
    let sentence: ReadingSentence
    let document: ReadingDocument
    let lesson: MobileLesson
    @EnvironmentObject private var store: LiveLibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var pendingSelection: PassageSelection?
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
                            onClearSelection: { pendingSelection = nil },
                            languageCode: lesson.languageCode,
                            onSelect: { selected in
                                pendingSelection = document.selection(in: sentence, localRange: selected.range)
                            }
                        )
                        Text("Tap a word, or hold briefly and drag across a phrase. Tap elsewhere to clear your selection.")
                            .font(.footnote).foregroundStyle(Palette.secondary)
                        Button("Explain sentence", systemImage: "text.magnifyingglass") {
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
            .safeAreaInset(edge: .bottom) {
                if let pendingSelection {
                    ReaderSelectionBar(selection: pendingSelection,
                                       onExplain: { explanation = pendingSelection }, onClear: clearSelection)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(.regularMaterial)
                }
            }
            .sheet(item: $explanation, onDismiss: clearSelection) { selected in
                SelectionInsightSheet(selection: selected, lesson: lesson)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .tint(Palette.ink)
    }

    private func clearSelection() {
        pendingSelection = nil
        clearSelectionRequest = UUID()
    }
}
