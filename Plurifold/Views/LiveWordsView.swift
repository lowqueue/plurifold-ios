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
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: Palette.isGarden ? 8 : 6) {
                                            Text(word.term)
                                                .font(StudyTypography.font(.headline, weight: .semibold))
                                                .foregroundStyle(Palette.ink)
                                            Text(word.meaning)
                                                .font(StudyTypography.font(.subheadline))
                                                .foregroundStyle(Palette.secondary)
                                                .lineLimit(3)
                                            if let title = word.sourceLessonTitle, !title.isEmpty {
                                                Label(title, systemImage: "book.closed")
                                                    .font(StudyTypography.font(.caption))
                                                    .foregroundStyle(Palette.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        if Palette.isGarden {
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Palette.secondary)
                                                .accessibilityHidden(true)
                                        }
                                    }
                                    .padding(.vertical, Palette.isGarden ? 12 : 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(GardenPressStyle())
                                .listRowBackground(Palette.surface)
                                .listRowSeparatorTint(Palette.line)
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
                                .font(StudyTypography.font(.caption, weight: .medium))
                                .textCase(nil)
                        } footer: {
                            Text("Swipe left to remove a saved word from your account.")
                                .font(StudyTypography.font(.caption))
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
            .listSectionSpacing(Palette.isGarden ? 20 : 12)
            .scrollContentBackground(.hidden)
            .studyBackground()
            .tint(Palette.accent)
            .navigationTitle("Saved")
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
            Text(LanguageDisplay.nativeName(for: language.code, fallback: language.name))
                .font(StudyTypography.font(.headline, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Change") { studyScope.showLanguagePicker() }
                .font(StudyTypography.font(.subheadline, weight: .medium))
                .frame(minHeight: 44)
                .padding(.horizontal, Palette.isGarden ? 12 : 0)
                .background(Palette.isGarden ? Palette.accentSoft : .clear, in: Capsule())
                .buttonStyle(GardenPressStyle())
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
                .buttonStyle(StudyButtonStyle())
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
                        Text(word.term)
                            .font(StudyTypography.font(.largeTitle, weight: .semibold))
                            .textSelection(.enabled)
                        if let pronunciation = word.pronunciation, !pronunciation.isEmpty {
                            Text(pronunciation).font(.body.monospaced()).foregroundStyle(Palette.secondary)
                        }
                        if let partOfSpeech = word.partOfSpeech, !partOfSpeech.isEmpty {
                            Text(partOfSpeech)
                                .font(StudyTypography.font(.subheadline).italic())
                                .foregroundStyle(Palette.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(word.meaning).font(StudyTypography.font(.title3)).textSelection(.enabled)
                        if !word.note.isEmpty {
                            Text(word.note).font(StudyTypography.font(.body))
                                .foregroundStyle(Palette.secondary).textSelection(.enabled)
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
                        Text(notice).font(StudyTypography.font(.footnote)).foregroundStyle(Palette.secondary)
                    }

                    if !word.context.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow(text: "In context")
                            Text(word.context).font(StudyTypography.font(.body)).textSelection(.enabled)
                            if let title = word.sourceLessonTitle, !title.isEmpty {
                                Text(title).font(StudyTypography.font(.caption)).foregroundStyle(Palette.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .studyCard()
                    }
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(Palette.isGarden ? 20 : 24)
                .frame(maxWidth: .infinity)
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
        .tint(Palette.accent)
    }
}
