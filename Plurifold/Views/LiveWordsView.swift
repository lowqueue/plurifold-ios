import SwiftUI

struct LiveWordsView: View {
    @EnvironmentObject private var store: LiveLibraryStore
    @State private var search = ""
    @State private var selectedWord: MobileSavedWord?

    private var filteredWords: [MobileSavedWord] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.words }
        return store.words.filter { word in
            [word.term, word.meaning, word.note, word.languageName, word.sourceLessonTitle ?? ""]
                .contains { $0.localizedStandardContains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let notice = store.notice {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(notice, systemImage: "exclamationmark.circle")
                                .font(.subheadline)
                                .foregroundStyle(Palette.secondary)
                            Button("Refresh") { Task { await store.refresh() } }
                                .disabled(store.isLoading)
                        }
                        .listRowBackground(Palette.surface)
                    }
                }

                if store.isLoading && store.words.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Loading saved words…").padding(.vertical, 36)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                } else if store.words.isEmpty {
                    Section {
                        ContentUnavailableView("Your saved words", systemImage: "bookmark",
                                               description: Text("Save a word or phrase while reading a lesson. Your saved vocabulary is shared with your Plurifold account."))
                            .listRowBackground(Color.clear)
                    }
                } else if filteredWords.isEmpty {
                    Section {
                        ContentUnavailableView.search(text: search)
                            .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(filteredWords) { word in
                            Button { selectedWord = word } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(word.term).font(.headline).foregroundStyle(Palette.ink)
                                        Spacer(minLength: 12)
                                        Text(word.languageName).font(.caption).foregroundStyle(Palette.secondary)
                                    }
                                    Text(word.meaning)
                                        .font(.subheadline)
                                        .foregroundStyle(Palette.secondary)
                                        .lineLimit(3)
                                    if let title = word.sourceLessonTitle, !title.isEmpty {
                                        Text(title).font(.caption).foregroundStyle(Palette.secondary).lineLimit(1)
                                    }
                                }
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Palette.surface)
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await store.removeWord(word.id) }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .disabled(store.isSaving)
                            }
                        }
                    } header: {
                        Text("\(filteredWords.count) saved \(filteredWords.count == 1 ? "item" : "items")")
                            .textCase(nil)
                    } footer: {
                        Text("Swipe left to remove a saved word from your account.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .studyBackground()
            .tint(Palette.ink)
            .navigationTitle("Words")
            .searchable(text: $search, prompt: "Words, meanings, languages")
            .refreshable { await store.refresh() }
            .task { if !store.hasLoaded { await store.refresh() } }
            .toolbar {
                if store.isSaving {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView().accessibilityLabel("Saving changes")
                    }
                }
            }
            .sheet(item: $selectedWord) { word in
                LiveSavedWordDetail(word: word)
            }
        }
    }
}

private struct LiveSavedWordDetail: View {
    let word: MobileSavedWord
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var speech = SpeechPlayer()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: word.languageName)
                        Text(word.term).font(.largeTitle.weight(.semibold)).textSelection(.enabled)
                        if let pronunciation = word.pronunciation, !pronunciation.isEmpty {
                            Text(pronunciation).font(.body.monospaced()).foregroundStyle(Palette.secondary)
                        }
                        if let partOfSpeech = word.partOfSpeech, !partOfSpeech.isEmpty {
                            Text(partOfSpeech).font(.subheadline.italic()).foregroundStyle(Palette.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(word.meaning).font(.title3).textSelection(.enabled)
                        if !word.note.isEmpty {
                            Text(word.note).foregroundStyle(Palette.secondary).textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .studyCard()

                    Button {
                        if speech.isSpeaking { speech.stop() }
                        else { speech.speak(word.term, language: word.languageCode) }
                    } label: {
                        Label(speech.isSpeaking ? "Stop pronunciation" : "Hear pronunciation",
                              systemImage: speech.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                    }
                    .buttonStyle(StudyButtonStyle())
                    if let notice = speech.notice {
                        Text(notice).font(.footnote).foregroundStyle(Palette.secondary)
                    }

                    if !word.context.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow(text: "In context")
                            Text(word.context).textSelection(.enabled)
                            if let title = word.sourceLessonTitle, !title.isEmpty {
                                Text(title).font(.caption).foregroundStyle(Palette.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .studyCard()
                    }
                }
                .padding(24)
            }
            .studyBackground()
            .navigationTitle("Saved word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onDisappear { speech.stop() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { speech.stop() } }
        }
        .tint(Palette.ink)
    }
}
