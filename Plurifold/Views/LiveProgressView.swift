import SwiftUI

/// Account-backed progress. The numbers measure recorded word-form decisions,
/// not course completion, dictionary headwords, or a predicted fluency level.
struct LiveProgressView: View {
    @EnvironmentObject private var store: LiveLibraryStore
    @EnvironmentObject private var studyScope: MobileStudyScope
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var progress = MobileProgressLoader()
    @State private var filter: MobileProgressFilter = .all

    let onOpenLesson: (String) -> Void
    let onTrophies: () -> Void
    let onBrowse: () -> Void

    private var lessons: [MobileProgressLesson] {
        guard let language = studyScope.language else { return [] }
        return progress.response?.coverageLessons(for: language.code) ?? []
    }

    private var visibleLessons: [MobileProgressLesson] { lessons.filter(filter.includes) }
    private var metricColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let language = studyScope.language {
                    heading(language)

                    if let notice = progress.notice {
                        ProgressLoadNotice(message: notice, hasData: progress.response != nil) {
                            await refresh()
                        }
                    }

                    if progress.isLoading && progress.response == nil {
                        ProgressView("Loading your progress…")
                            .frame(maxWidth: .infinity, minHeight: 160)
                    } else if let response = progress.response {
                        statistics(response.vocabulary)
                        if response.lessons != nil {
                            coverage
                        } else {
                            ContentUnavailableView("Coverage unavailable", systemImage: "chart.bar.xaxis",
                                                   description: Text("Lesson coverage couldn’t be loaded. Pull down to try again."))
                                .gardenCard()
                        }
                    } else if progress.notice == nil {
                        ContentUnavailableView("Your progress", systemImage: "chart.bar.xaxis",
                                               description: Text("Pull down to load your account’s vocabulary and lesson coverage."))
                    }

                    Button(action: onBrowse) {
                        HStack {
                            Text("Explore more lessons")
                            Spacer()
                            Image(systemName: "arrow.right").accessibilityHidden(true)
                        }
                        .font(StudyTypography.font(.subheadline, weight: .semibold))
                        .frame(minHeight: 48)
                        .padding(.horizontal, 18)
                        .foregroundStyle(Palette.accent)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Palette.controlRadius))
                        .overlay(RoundedRectangle(cornerRadius: Palette.controlRadius).stroke(Palette.line.opacity(0.5)))
                    }
                    .buttonStyle(GardenPressStyle())
                } else {
                    ChooseStudyLanguageView()
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(16)
            .frame(maxWidth: .infinity)
        }
        .studyBackground()
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Palette.accent)
        .refreshable { await refresh() }
        .task(id: studyScope.language?.code) {
            filter = .all
            await refresh()
        }
    }

    private func heading(_ language: MobileLanguageOption) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                HStack(spacing: 7) {
                    Text(language.flag).accessibilityHidden(true)
                    Text(LanguageDisplay.nativeName(for: language.code, fallback: language.name))
                        .font(StudyTypography.font(.caption, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Palette.surface.opacity(0.92), in: Capsule())
                Spacer(minLength: 12)
                Button(action: onTrophies) {
                    Label("Your trophies", systemImage: "trophy")
                        .font(StudyTypography.font(.caption, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .foregroundStyle(Palette.accentInk)
                        .background(Palette.accent, in: Capsule())
                }
                .buttonStyle(GardenPressStyle())
            }

            Text("Progress")
                .font(StudyTypography.font(.largeTitle, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text("Your vocabulary and lesson coverage.")
                .font(StudyTypography.font(.body))
                .foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320, alignment: .leading)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 205, alignment: .leading)
        .background {
            if Palette.isGarden {
                GardenSceneBackground(asset: "GardenProgress", alignment: .trailing)
            } else {
                Palette.surface
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Palette.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Palette.cardRadius).stroke(Palette.line.opacity(0.22)))
    }

    private func statistics(_ vocabulary: MobileProgressVocabulary?) -> some View {
        LazyVGrid(columns: metricColumns, spacing: 12) {
            metric("Marked known", count: vocabulary?.known, unit: "word forms", symbol: "book", color: Palette.green)
            metric("Learning", count: vocabulary?.learning, unit: "word forms", symbol: "sun.max", color: Palette.warm)
            metric("Familiar", count: vocabulary?.familiar, unit: "word forms", symbol: "eye", color: .blue)
            metric("Saved phrases", count: vocabulary?.phrases, unit: "saved entries", symbol: "bookmark", color: .purple)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Vocabulary totals")
    }

    private func metric(_ title: String, count: Int?, unit: String, symbol: String, color: Color) -> some View {
        let validCount = count.flatMap { $0 >= 0 ? $0 : nil }
        return VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            Text(title).font(StudyTypography.font(.caption)).foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(MobileProgressVocabulary.display(validCount))
                .font(StudyTypography.font(validCount == nil ? .subheadline : .largeTitle, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(unit).font(StudyTypography.font(.caption2)).foregroundStyle(Palette.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gardenCard(padding: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(validCount.map { "\($0.formatted()) \(unit)" } ?? "Unavailable")
    }

    private var coverage: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Lesson coverage").font(StudyTypography.font(.title2, weight: .semibold))
                Text("The share of unique word forms you’ve marked known.")
                    .font(StudyTypography.font(.footnote))
                    .foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MobileProgressFilter.allCases) { item in
                        Button { filter = item } label: {
                            Text(item.title)
                                .font(StudyTypography.font(.caption, weight: .medium))
                                .padding(.horizontal, 15)
                                .frame(minHeight: 44)
                                .foregroundStyle(filter == item ? Palette.accentInk : Palette.secondary)
                                .background(filter == item ? Palette.accent : Palette.field, in: Capsule())
                        }
                        .buttonStyle(GardenPressStyle())
                        .accessibilityAddTraits(filter == item ? .isSelected : [])
                    }
                }
            }
            .accessibilityLabel("Filter lesson coverage")

            if visibleLessons.isEmpty {
                ContentUnavailableView {
                    Label(lessons.isEmpty ? "No lessons yet" : "No matching lessons", systemImage: "book")
                } description: {
                    Text(lessons.isEmpty
                         ? "Browse the library to find lessons for this language."
                         : filter == .known
                         ? "Lessons appear here when every word form is marked known."
                         : "This filter shows lessons containing words with that status.")
                } actions: {
                    if !lessons.isEmpty {
                        Button("Show all lessons") { filter = .all }
                            .buttonStyle(.bordered)
                    }
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(visibleLessons) { lesson in
                        ProgressCoverageRow(lesson: lesson) { onOpenLesson(lesson.id) }
                    }
                }
            }

            Text("\(visibleLessons.count) of \(lessons.count) \(lessons.count == 1 ? "lesson" : "lessons")")
                .font(StudyTypography.font(.caption)).foregroundStyle(Palette.secondary)
            Text("Only forms marked known count toward coverage. Ignored forms are excluded.")
                .font(StudyTypography.font(.caption2)).foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gardenCard(padding: 16)
    }

    private func refresh() async {
        guard let language = studyScope.language else { return }
        await progress.load(languageCode: language.code, api: store.api)
    }
}

private struct ProgressCoverageRow: View {
    let lesson: MobileProgressLesson
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    thumbnail
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lesson.title)
                            .font(StudyTypography.font(.subheadline, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if let count = lesson.totalWords, count >= 0 {
                            Text("\(count.formatted()) words")
                                .font(StudyTypography.font(.caption2)).foregroundStyle(Palette.secondary)
                        }
                        if let variety = lesson.variety, !variety.isEmpty {
                            Text(variety).font(StudyTypography.font(.caption2)).foregroundStyle(Palette.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.secondary).accessibilityHidden(true)
                }

                if let fraction = lesson.knownFraction {
                    HStack(spacing: 12) {
                        ProgressView(value: fraction).tint(Palette.progress)
                        Text(lesson.percentage).font(StudyTypography.font(.caption, weight: .semibold))
                            .foregroundStyle(Palette.accent).monospacedDigit()
                    }
                }
                Text(lesson.coverageDescription)
                    .font(StudyTypography.font(.caption2)).foregroundStyle(Palette.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Palette.controlRadius))
            .overlay(RoundedRectangle(cornerRadius: Palette.controlRadius).stroke(Palette.line.opacity(0.5)))
            .contentShape(RoundedRectangle(cornerRadius: Palette.controlRadius))
        }
        .buttonStyle(GardenPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(lesson.title)
        .accessibilityValue(lesson.coverageDescription)
        .accessibilityHint("Opens this lesson")
    }

    private var thumbnail: some View {
        AsyncImage(url: lesson.thumbnailURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                Palette.field
                Image(systemName: lesson.mediaSymbol).foregroundStyle(Palette.accent)
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: Palette.isGarden ? 12 : 4))
        .accessibilityHidden(true)
    }
}

struct ProgressLoadNotice: View {
    let message: String
    let hasData: Bool
    let retry: () async -> Void
    @State private var isRetrying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "exclamationmark.circle")
                .font(StudyTypography.font(.footnote))
                .fixedSize(horizontal: false, vertical: true)
            if hasData {
                Text("Showing the last loaded data.")
                    .font(StudyTypography.font(.caption)).foregroundStyle(Palette.secondary)
            }
            Button(isRetrying ? "Retrying…" : "Try again") {
                isRetrying = true
                Task {
                    await retry()
                    isRetrying = false
                }
            }
            .disabled(isRetrying)
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gardenCard(padding: 16)
    }
}
