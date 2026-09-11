import SwiftUI

/// The disclosure and navigation are siblings. Expanding metadata never starts
/// a lesson, including with VoiceOver or a switch-control click.
struct LibraryLessonRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsDetails = false
    let lesson: MobileLessonSummary
    let hasPosition: Bool
    var source: String? = nil
    var savedCount: Int? = nil
    var showsCover = true

    private var thumbnailURL: URL? {
        guard let raw = lesson.thumbnailURL, let url = URL(string: raw),
              url.scheme?.lowercased() == "https", url.host != nil,
              url.user == nil, url.password == nil else { return nil }
        return url
    }

    private var sourceName: String {
        let value = (source ?? lesson.channel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? lesson.languageName : value
    }

    private var media: (label: String, icon: String)? {
        switch lesson.mediaKind {
        case "video": return ("Video", "video")
        case "audio": return ("Audio", "headphones")
        case "text": return ("Reading", "book")
        default: return nil
        }
    }

    private var vocabulary: (total: Int, unique: Int, new: Int, percent: Int)? {
        guard let total = lesson.wordCount, let unique = lesson.uniqueWordCount,
              let new = lesson.newWordCount, total >= unique, unique >= new, new >= 0 else { return nil }
        let percent = unique > 0 ? Int((Double(new) / Double(unique) * 100).rounded()) : 0
        return (total, unique, new, percent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: MobileStudyRoute.lesson(id: lesson.id)) {
                VStack(alignment: .leading, spacing: 0) {
                    if showsCover { cover }
                    Text(lesson.title)
                        .font(StudyTypography.font(.title3, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(GardenPressStyle())
            .accessibilityLabel(lesson.title)
            .accessibilityHint(hasPosition ? "Continue this lesson" : "Open this lesson")

            if showsDetails {
                details
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }

            HStack(spacing: 12) {
                NavigationLink(value: MobileStudyRoute.lesson(id: lesson.id)) {
                    Label(hasPosition ? "Continue" : "Open lesson", systemImage: "arrow.right")
                        .font(StudyTypography.font(.subheadline, weight: .semibold))
                        .foregroundStyle(Palette.actionGradientInk)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 46)
                        .background(Palette.actionGradient, in: RoundedRectangle(cornerRadius: Palette.controlRadius))
                }
                .buttonStyle(GardenPressStyle())
                .accessibilityLabel("\(hasPosition ? "Continue" : "Open") \(lesson.title)")
                Spacer(minLength: 0)
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { showsDetails.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text(showsDetails ? "Less" : "More")
                        Image(systemName: showsDetails ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(StudyTypography.font(.subheadline))
                    .foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 6)
                    .frame(minHeight: 46)
                    .contentShape(Rectangle())
                }
                .buttonStyle(GardenPressStyle())
                .accessibilityLabel("\(showsDetails ? "Hide" : "Show") details for \(lesson.title)")
                .accessibilityValue(showsDetails ? "Expanded" : "Collapsed")
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Palette.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Palette.cardRadius, style: .continuous).stroke(Palette.line, lineWidth: 1))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(sourceName)
                .font(StudyTypography.font(.caption, weight: .medium))
                .foregroundStyle(Palette.secondary)
            if !lesson.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(lesson.subtitle)
                    .font(StudyTypography.font(.subheadline))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            tags
            if let vocabulary {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("New words")
                        Spacer(minLength: 8)
                        Text("\(vocabulary.percent)%").monospacedDigit()
                    }
                    .font(StudyTypography.font(.subheadline))
                    ProgressView(value: Double(vocabulary.new), total: Double(max(1, vocabulary.unique)))
                        .tint(Palette.progress)
                        .accessibilityLabel("New words")
                        .accessibilityValue("\(vocabulary.new) of \(vocabulary.unique) unique words")
                    Text("\(vocabulary.new) of \(vocabulary.unique) unique words")
                        .font(StudyTypography.font(.caption))
                        .foregroundStyle(Palette.secondary)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { wordCount; savedEntryCount }
                VStack(alignment: .leading, spacing: 6) { wordCount; savedEntryCount }
            }
            .font(StudyTypography.font(.caption))
            .foregroundStyle(Palette.secondary)
            if hasPosition {
                Label("Reading place saved", systemImage: "bookmark.fill")
                    .font(StudyTypography.font(.caption))
                    .foregroundStyle(Palette.accent)
            }
        }
    }

    @ViewBuilder private var wordCount: some View {
        if let total = lesson.wordCount, total >= 0 {
            Text("\(total) \(total == 1 ? "word" : "words")")
        } else if lesson.paragraphCount > 0 {
            Text("\(lesson.paragraphCount) \(lesson.paragraphCount == 1 ? "passage" : "passages")")
        }
    }

    @ViewBuilder private var savedEntryCount: some View {
        if let savedCount, savedCount >= 0 {
            Text("\(savedCount) saved \(savedCount == 1 ? "entry" : "entries")")
        }
    }

    private var tags: some View {
        VStack(alignment: .leading, spacing: 7) {
            let level = MobileLibraryShelf.levelKey(lesson.ilrLevel)
            Text(level == MobileLibraryShelf.unassessedLevel ? "ILR unassessed" : "ILR \(level) est.")
                .libraryTag()
                .accessibilityLabel(level == MobileLibraryShelf.unassessedLevel
                    ? "Material difficulty has not been assessed"
                    : "Estimated material difficulty, ILR \(level)")
            if let dialect = lesson.dialect?.trimmingCharacters(in: .whitespacesAndNewlines), !dialect.isEmpty {
                Text(dialect).libraryTag()
            }
        }
    }

    private var cover: some View {
        Rectangle()
            .fill(Palette.preview)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: media?.icon ?? "book")
                        .font(.system(size: 32, weight: .light))
                    Text(LanguageDisplay.nativeName(for: lesson.languageCode, fallback: lesson.languageName))
                        .font(StudyTypography.font(.title, weight: .medium))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
                .foregroundStyle(Palette.accent)
                .padding(22)
                .padding(.bottom, 22)
            }
            .overlay {
                if let thumbnailURL {
                    GeometryReader { geometry in
                        AsyncImage(url: thumbnailURL) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 8) {
                    Text(lesson.languageCode.split(separator: "-").first?.uppercased() ?? lesson.languageCode.uppercased())
                        .coverBadge()
                    Spacer(minLength: 8)
                    if let media { Label(media.label, systemImage: media.icon).coverBadge() }
                }
                .padding(12)
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

struct LibraryCourseCard: View {
    let folder: MobileCourseFolder
    let positions: [String: Int]

    private var started: Int { folder.course.lessons.filter { positions[$0.id] != nil }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                coursePreview
                VStack(alignment: .leading, spacing: 7) {
                    Eyebrow(text: "Structured study")
                    Text(folder.course.title)
                        .font(StudyTypography.font(.title3, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Label(chapterCount, systemImage: "book.pages")
                .font(StudyTypography.font(.subheadline))
                .foregroundStyle(Palette.secondary)
            if started > 0 {
                Label("\(started) \(started == 1 ? "chapter has" : "chapters have") a saved reading place", systemImage: "bookmark")
                    .font(StudyTypography.font(.caption))
                    .foregroundStyle(Palette.accent)
            }
            HStack {
                Text(started > 0 ? "Continue course" : "View course")
                Spacer(minLength: 8)
                Image(systemName: "arrow.right")
            }
            .font(StudyTypography.font(.subheadline, weight: .semibold))
            .foregroundStyle(Palette.actionGradientInk)
            .padding(.horizontal, 16)
            .frame(minHeight: 46)
            .background(Palette.actionGradient, in: RoundedRectangle(cornerRadius: Palette.controlRadius))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gardenCard(padding: 20)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the chapters in this course")
    }

    private var chapterCount: String {
        folder.chapters.count == folder.course.lessons.count
            ? "\(folder.chapters.count) \(folder.chapters.count == 1 ? "chapter" : "chapters")"
            : "\(folder.chapters.count) of \(folder.course.lessons.count) chapters match"
    }

    private var coursePreview: some View {
        VStack(spacing: 8) {
            Text(LanguageFlag.symbol(for: folder.course.languageCode)).font(.title2)
            Image(systemName: "book.closed")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Palette.accent)
        }
        .frame(width: 76, height: 92)
        .background(Palette.preview, in: RoundedRectangle(cornerRadius: Palette.controlRadius))
        .accessibilityHidden(true)
    }
}

private extension View {
    func libraryTag() -> some View {
        font(StudyTypography.font(.caption))
            .foregroundStyle(Palette.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Palette.field, in: RoundedRectangle(cornerRadius: Palette.isGarden ? 7 : 0))
    }

    func coverBadge() -> some View {
        font(StudyTypography.font(.caption))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 6))
    }
}
