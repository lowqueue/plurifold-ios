import SwiftUI

/// Trophies use the website's persisted completion evidence across languages.
/// Merely opening a lesson or a local review card never earns an award here.
struct LiveTrophiesView: View {
    @EnvironmentObject private var store: LiveLibraryStore
    @StateObject private var progress = MobileProgressLoader()
    @State private var filter: TrophyFilter = .all

    private var trophies: [MobileProgressTrophy] {
        var seen: Set<String> = []
        return (progress.response?.trophies ?? []).filter { !$0.id.isEmpty && seen.insert($0.id).inserted }
    }
    private var earned: Int { trophies.filter(\.isEarned).count }
    private var visible: [MobileProgressTrophy] { trophies.filter(filter.includes) }
    private var categories: [String] {
        var seen: Set<String> = []
        return visible.map(\.category).filter { seen.insert($0).inserted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heading

                if let notice = progress.notice {
                    ProgressLoadNotice(message: notice, hasData: progress.response?.trophies != nil) {
                        await refresh()
                    }
                }

                if progress.isLoading && progress.response == nil {
                    ProgressView("Loading your trophies…")
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if progress.response?.trophies != nil {
                    if trophies.isEmpty {
                        ContentUnavailableView("No trophies available", systemImage: "trophy",
                                               description: Text("Pull down to check for your account’s latest trophies."))
                    } else {
                        filters
                        if visible.isEmpty {
                            ContentUnavailableView {
                                Label(filter == .earned ? "No earned trophies yet" : "All trophies earned", systemImage: "trophy")
                            } description: {
                                Text(filter == .earned
                                     ? "Open All to see the activity required for each trophy."
                                     : "Open Earned to see your recorded awards.")
                            } actions: {
                                Button("Show all trophies") { filter = .all }
                                    .buttonStyle(.bordered)
                            }
                        } else {
                            ForEach(categories, id: \.self) { category in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(category).font(StudyTypography.font(.headline, weight: .semibold))
                                    ForEach(visible.filter { $0.category == category }) { trophy in
                                        trophyCard(trophy)
                                    }
                                }
                            }
                        }
                    }
                } else if progress.notice == nil && !progress.isLoading {
                    ContentUnavailableView("Trophies unavailable", systemImage: "trophy",
                                           description: Text("Your trophy history couldn’t be loaded. Pull down to try again."))
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(16)
            .frame(maxWidth: .infinity)
        }
        .studyBackground()
        .navigationTitle("Trophies")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Palette.accent)
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "trophy")
                    .font(.title2)
                    .foregroundStyle(Palette.accent)
                    .frame(width: 50, height: 50)
                    .background(Palette.field, in: RoundedRectangle(cornerRadius: Palette.controlRadius))
                    .accessibilityHidden(true)
                Spacer()
                Text("All languages")
                    .font(StudyTypography.font(.caption, weight: .medium))
                    .foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Palette.field, in: Capsule())
            }
            Text("Your trophies").font(StudyTypography.font(.largeTitle, weight: .bold))
            Text("Recorded reviews, practice, writing, and course activities.")
                .font(StudyTypography.font(.body)).foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if progress.response?.trophies != nil && !trophies.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(earned)").font(StudyTypography.font(.largeTitle, weight: .semibold)).monospacedDigit()
                    Text("of \(trophies.count) earned").font(StudyTypography.font(.subheadline)).foregroundStyle(Palette.secondary)
                }
                ProgressView(value: Double(earned), total: Double(trophies.count))
                    .tint(Palette.progress)
                    .accessibilityLabel("Trophies earned")
                    .accessibilityValue("\(earned) of \(trophies.count)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gardenCard()
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TrophyFilter.allCases) { item in
                    Button { filter = item } label: {
                        Text(item.title)
                            .font(StudyTypography.font(.subheadline, weight: .medium))
                            .frame(minHeight: 44)
                            .padding(.horizontal, 18)
                            .foregroundStyle(filter == item ? Palette.accentInk : Palette.secondary)
                            .background(filter == item ? Palette.accent : Palette.field, in: Capsule())
                    }
                    .buttonStyle(GardenPressStyle())
                    .accessibilityAddTraits(filter == item ? .isSelected : [])
                }
            }
        }
        .accessibilityLabel("Filter trophies")
    }

    private func trophyCard(_ trophy: MobileProgressTrophy) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: trophy.systemImage)
                .font(.title2)
                .foregroundStyle(trophy.isEarned ? Palette.accent : Palette.secondary)
                .frame(width: 46, height: 46)
                .background(trophy.isEarned ? Palette.field : Palette.background, in: RoundedRectangle(cornerRadius: Palette.controlRadius))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 9) {
                Text(trophy.title)
                    .font(StudyTypography.font(.headline, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(trophy.requirement)
                    .font(StudyTypography.font(.subheadline))
                    .foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if trophy.isEarned {
                    Label("Earned", systemImage: "checkmark.circle.fill")
                        .font(StudyTypography.font(.caption, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                    if trophy.source == "backfill" {
                        Text("Recognized from earlier activity")
                            .font(StudyTypography.font(.caption2)).foregroundStyle(Palette.secondary)
                    } else if let date = trophy.earnedDate {
                        Text(date, format: .dateTime.month(.abbreviated).day().year())
                            .font(StudyTypography.font(.caption2)).foregroundStyle(Palette.secondary)
                    }
                } else if let fraction = trophy.progressFraction, let description = trophy.progressDescription {
                    ProgressView(value: fraction).tint(Palette.progress)
                        .accessibilityLabel(trophy.title)
                        .accessibilityValue(description)
                    Text(description)
                        .font(StudyTypography.font(.caption)).foregroundStyle(Palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Progress unavailable")
                        .font(StudyTypography.font(.caption)).foregroundStyle(Palette.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gardenCard(padding: 16)
        .accessibilityElement(children: .combine)
    }

    private func refresh() async { await progress.load(languageCode: nil, api: store.api) }
}

private enum TrophyFilter: String, CaseIterable, Identifiable {
    case all, earned, available
    var id: Self { self }
    var title: String {
        switch self {
        case .all: "All"
        case .earned: "Earned"
        case .available: "To earn"
        }
    }
    func includes(_ trophy: MobileProgressTrophy) -> Bool {
        switch self {
        case .all: true
        case .earned: trophy.isEarned
        case .available: !trophy.isEarned
        }
    }
}
