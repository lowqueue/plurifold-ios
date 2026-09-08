import SwiftUI

struct LiveHomeView: View {
    @EnvironmentObject private var store: LiveLibraryStore
    @EnvironmentObject private var studyScope: MobileStudyScope
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var languages: [MobileLanguageOption] {
        MobileStudyLanguageList(courses: store.courses, words: store.words).languages
    }

    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 148), spacing: 12)]
    }

    var body: some View {
        NavigationStack(path: $studyScope.homePath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your languages")
                            .font(.title2.monospaced().weight(.medium))
                            .foregroundStyle(Palette.ink)
                        Text("Choose a language to open your lessons, saved words, and review.")
                            .font(.footnote.monospaced())
                            .foregroundStyle(Palette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let notice = store.notice {
                        LibraryNoticeRow(notice: notice)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.line, lineWidth: 1))
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
                        LazyVGrid(columns: columns, spacing: 12) {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity)
            }
            .studyBackground()
            .toolbar(studyScope.homePath.isEmpty ? .hidden : .visible, for: .navigationBar)
            .navigationDestination(for: MobileLanguageOption.self) { language in
                LiveLibraryView(languageCode: language.code, languageName: language.name)
            }
            .refreshable { await store.refresh() }
            .task { if !store.hasLoaded { await store.refresh() } }
        }
        .id(studyScope.homeRootID)
    }

    private func languageTile(_ language: MobileLanguageOption) -> some View {
        let isSelected = MobileLanguageKey.normalized(studyScope.language?.code)
            == MobileLanguageKey.normalized(language.code)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(language.flag)
                    .font(.title)
                    .accessibilityHidden(true)
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .accessibilityHidden(true)
            }
            Text(language.name)
                .font(.headline.monospaced().weight(.medium))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                if !language.contentDescription.isEmpty {
                    Text(language.contentDescription)
                }
                Text(savedDescription(language))
            }
            .font(.caption.monospaced())
            .foregroundStyle(Palette.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(14)
        .background(isSelected ? Palette.field : Palette.surface, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(isSelected ? Palette.accent : Palette.line, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityElement(children: .combine)
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityHint("Selects \(language.name) for lessons, words, and review")
    }

    private func savedDescription(_ language: MobileLanguageOption) -> String {
        let count = MobileVocabularyIndex(words: store.words, languageCode: language.code).words.count
        return "\(count) saved \(count == 1 ? "word" : "words")"
    }
}
