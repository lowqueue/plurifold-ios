import SwiftUI

struct WordsView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var selectedWord: SavedWord?
    @State private var search = ""

    private var filteredWords: [SavedWord] {
        store.savedWords.filter {
            search.isEmpty || $0.entry.term.localizedCaseInsensitiveContains(search)
                || $0.entry.meaning.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        Group {
            if store.savedWords.isEmpty {
                ContentUnavailableView {
                    Label("Words worth keeping", systemImage: "bookmark")
                } description: {
                    Text("Open a story in Learn, tap an underlined expression, and save it here.")
                }
            } else {
                List {
                    Section {
                        ForEach(filteredWords) { saved in
                            Button { selectedWord = saved } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(saved.entry.term).font(.system(.title3, design: .serif))
                                    Text(saved.entry.meaning).font(.body).foregroundStyle(Palette.secondary)
                                    Text(saved.lessonTitle).font(.caption.monospaced()).foregroundStyle(Palette.secondary)
                                }
                                .padding(.vertical, 8)
                            }
                            .listRowBackground(Palette.surface)
                            .swipeActions {
                                Button("Remove", role: .destructive) {
                                    store.toggleSaved(saved.id)
                                }
                            }
                        }
                    } header: {
                        Text("\(store.savedWords.count) saved expressions")
                    }
                }
                .scrollContentBackground(.hidden)
                .searchable(text: $search, prompt: "Find an expression")
                .overlay {
                    if filteredWords.isEmpty { ContentUnavailableView.search(text: search) }
                }
            }
        }
        .studyBackground()
        .navigationTitle("Your words")
        .sheet(item: $selectedWord) { saved in
            WordSheet(word: saved.entry, languageCode: saved.languageCode)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}
