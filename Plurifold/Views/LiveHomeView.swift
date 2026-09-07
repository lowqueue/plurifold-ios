import SwiftUI

struct LiveHomeView: View {
    @EnvironmentObject private var store: LiveLibraryStore
    @EnvironmentObject private var studyScope: MobileStudyScope

    private var languages: [MobileLanguageOption] {
        MobileStudyLanguageList(courses: store.courses, words: store.words).languages
    }

    var body: some View {
        NavigationStack(path: $studyScope.homePath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(Palette.warm).frame(width: 32, height: 4)
                        Text("Choose a language")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(Palette.ink)
                        Text("Your lessons, saved words, and review stay with the language you choose.")
                            .font(.subheadline)
                            .foregroundStyle(Palette.secondary)
                    }

                    if let notice = store.notice {
                        LibraryNoticeRow(notice: notice)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .studyCard()
                    }

                    if store.isLoading && languages.isEmpty {
                        ProgressView("Loading your languages…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else if languages.isEmpty {
                        ContentUnavailableView {
                            Label("Your languages", systemImage: "globe")
                        } description: {
                            Text(store.notice == nil
                                 ? "Languages will appear here as courses and lessons become available."
                                 : "Your library couldn’t load. Check your connection and try again.")
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                            ForEach(languages) { language in
                                Button { studyScope.selectLanguage(language) } label: {
                                    languageTile(language)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .studyBackground()
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: MobileLanguageOption.self) { language in
                LiveLibraryView(languageCode: language.code, languageName: language.name)
            }
            .refreshable { await store.refresh() }
            .task { if !store.hasLoaded { await store.refresh() } }
        }
        .id(studyScope.homeRootID)
    }

    private func languageTile(_ language: MobileLanguageOption) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(language.flag)
                    .font(.system(size: 38))
                    .accessibilityHidden(true)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .accessibilityHidden(true)
            }
            Text(language.name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(language.contentDescription.isEmpty ? savedDescription(language) : language.contentDescription)
                .font(.caption)
                .foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if MobileLanguageKey.normalized(studyScope.language?.code) == MobileLanguageKey.normalized(language.code) {
                Label("Selected", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.green)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
        .studyCard()
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Selects \(language.name) for lessons, words, and review")
    }

    private func savedDescription(_ language: MobileLanguageOption) -> String {
        let count = MobileVocabularyIndex(words: store.words, languageCode: language.code).words.count
        return "\(count) saved \(count == 1 ? "word" : "words")"
    }
}
