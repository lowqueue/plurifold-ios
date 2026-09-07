import SwiftUI

struct LiveWordsView: View {
    @EnvironmentObject private var store: LiveLibraryStore
    @EnvironmentObject private var studyScope: MobileStudyScope
    @State private var search = ""
    @State private var selectedWord: MobileSavedWord?

    private var languageWords: [MobileSavedWord] {
        MobileVocabularyIndex(words: store.words, languageCode: studyScope.language?.code).words
    }

    private var filteredWords: [MobileSavedWord] {
        MobileVocabularyIndex(words: store.words, languageCode: studyScope.language?.code, search: search).words
    }

    var body: some View {
        NavigationStack {
            List {
                if let language = studyScope.language {
                    Section {
                        StudyLanguageHeader(language: language)
                            .listRowBackground(Palette.surface)
                    }
                    if let notice = store.notice {
                        Section {
                            LibraryNoticeRow(notice: notice)
                                .listRowBackground(Palette.surface)
                        }
                    }
                    if store.isLoading && languageWords.isEmpty {
                        Section {
                            HStack {
                                Spacer()
                                ProgressView("Loading saved words…").padding(.vertical, 36)
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        }
                    } else if languageWords.isEmpty {
                        Section {
                            ContentUnavailableView("Your \(language.name) words", systemImage: "bookmark",
                                                   description: Text("Save a word or phrase while reading in \(language.name). It will appear here and in Review."))
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
                                        Text(word.term).font(.headline).foregroundStyle(Palette.ink)
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
                } else {
                    Section {
                        ChooseStudyLanguageView()
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .studyBackground()
            .tint(Palette.accent)
            .navigationTitle("Words")
            .searchable(text: $search, prompt: "Words and meanings in this language")
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
            .onChange(of: studyScope.language?.code) { _, _ in
                search = ""
                selectedWord = nil
            }
            .onChange(of: languageWords) { _, words in
                if let selectedWord {
                    // Refresh an open detail too, or dismiss it if the word was removed.
                    self.selectedWord = words.first { $0.id == selectedWord.id }
                }
            }
        }
    }
}

struct StudyLanguageHeader: View {
    @EnvironmentObject private var studyScope: MobileStudyScope
    let language: MobileLanguageOption

    var body: some View {
        HStack(spacing: 12) {
            Text(language.flag).font(.title2).accessibilityHidden(true)
            Text(language.name).font(.headline).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Change") { studyScope.showLanguagePicker() }
                .font(.subheadline)
                .accessibilityLabel("Change study language")
        }
        .foregroundStyle(Palette.ink)
        .tint(Palette.accent)
    }
}

struct ChooseStudyLanguageView: View {
    @EnvironmentObject private var studyScope: MobileStudyScope

    var body: some View {
        ContentUnavailableView {
            Label("Choose your language", systemImage: "globe")
        } description: {
            Text("Choose a language on Home to see its saved words and review them.")
        } actions: {
            Button("Choose a language") { studyScope.showLanguagePicker() }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
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
