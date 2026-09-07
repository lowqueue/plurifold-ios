import SwiftUI

struct LiveHomeView: View {
    @EnvironmentObject private var store: LiveLibraryStore

    private var catalog: MobileLanguageCatalog { MobileLanguageCatalog(courses: store.courses) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(Palette.warm).frame(width: 32, height: 4)
                        Text("Choose a language")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(Palette.ink)
                        Text("Find your next lesson or continue a course.")
                            .font(.subheadline)
                            .foregroundStyle(Palette.secondary)
                    }

                    if let notice = store.notice {
                        LibraryNoticeRow(notice: notice)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .studyCard()
                    }

                    if store.isLoading && catalog.languages.isEmpty {
                        ProgressView("Loading your languages…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else if catalog.languages.isEmpty {
                        ContentUnavailableView {
                            Label("Your languages", systemImage: "globe")
                        } description: {
                            Text(store.notice == nil
                                 ? "Languages will appear here as courses and lessons become available."
                                 : "Your library couldn’t load. Check your connection and try again.")
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                            ForEach(catalog.languages) { language in
                                NavigationLink {
                                    LiveLibraryView(languageCode: language.code, languageName: language.name)
                                } label: {
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
            .refreshable { await store.refresh() }
            .task { if !store.hasLoaded { await store.refresh() } }
        }
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
            Text(language.contentDescription)
                .font(.caption)
                .foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
        .studyCard()
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(language.name) courses and lessons")
    }
}
