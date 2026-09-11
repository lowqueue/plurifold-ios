import SwiftUI

struct LiveCourseView: View {
    @EnvironmentObject private var store: LiveLibraryStore
    @EnvironmentObject private var studyScope: MobileStudyScope
    @Environment(\.dismiss) private var dismiss
    let courseID: String
    @State private var search: String

    init(courseID: String, initialSearch: String = "") {
        self.courseID = courseID
        _search = State(initialValue: initialSearch)
    }

    var body: some View {
        let course = store.courses.first { $0.id == courseID }
        let folder = MobileLibraryIndex(courses: course.map { [$0] } ?? [], search: search).courseFolders.first
        let allChapters = course?.lessons.filter { $0.kind == "course" } ?? []
        let matchingIDs = Set(folder?.chapters.map(\.id) ?? [])
        // Keep chapter numbers tied to the course order while filtering.
        let chapters = allChapters.enumerated().compactMap { index, lesson in
            matchingIDs.contains(lesson.id) ? CourseOutlineChapter(number: index + 1, lesson: lesson) : nil
        }

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Button { dismiss() } label: {
                    Label(studyScope.librarySection == .courses ? "Back to courses" : "Back to library", systemImage: "chevron.left")
                        .font(StudyTypography.font(.subheadline))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(GardenPressStyle())
                .foregroundStyle(Palette.accent)

                if let notice = store.notice { LibraryNoticeRow(notice: notice).libraryFrame() }
                if let course {
                    courseHeader(course, chapters: allChapters)
                    chapterSearch
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Chapters" : "Matching chapters")
                            .font(StudyTypography.font(.headline, weight: .semibold))
                        Spacer(minLength: 0)
                        Text("\(chapters.count)")
                            .font(StudyTypography.font(.caption))
                            .foregroundStyle(Palette.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    ForEach(chapters) { chapter in
                        NavigationLink(value: MobileStudyRoute.lesson(id: chapter.lesson.id)) {
                            CourseOutlineRow(chapter: chapter, hasPosition: store.positions[chapter.lesson.id] != nil)
                        }
                        .buttonStyle(GardenPressStyle())
                    }
                    if chapters.isEmpty {
                        ContentUnavailableView(allChapters.isEmpty ? "No chapters available" : "No matching chapters",
                            systemImage: allChapters.isEmpty ? "book.closed" : "magnifyingglass",
                            description: Text(allChapters.isEmpty
                                ? "Pull down to refresh this course."
                                : "Try another search term or clear the search to see all chapters."))
                    }
                } else {
                    ContentUnavailableView("Course unavailable", systemImage: "folder",
                        description: Text("Return to your library and refresh to see available courses."))
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .studyBackground()
        .tint(Palette.accent)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await store.refresh() }
    }

    private func courseHeader(_ course: MobileCourse, chapters: [MobileLessonSummary]) -> some View {
        let savedChapters = chapters.filter { store.positions[$0.id] != nil }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Text(LanguageFlag.symbol(for: course.languageCode)).font(.title3)
                    .accessibilityHidden(true)
                Eyebrow(text: LanguageDisplay.nativeName(for: course.languageCode, fallback: course.languageName))
            }
            Text(course.title)
                .font(StudyTypography.font(.title, weight: .bold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Label("\(chapters.count) \(chapters.count == 1 ? "chapter" : "chapters")", systemImage: "book.pages")
                .font(StudyTypography.font(.subheadline))
                .foregroundStyle(Palette.secondary)
            if !savedChapters.isEmpty {
                Text("Reading places saved in \(savedChapters.count) of \(chapters.count) chapters.")
                    .font(StudyTypography.font(.caption))
                    .foregroundStyle(Palette.secondary)
            }
            if let chapter = savedChapters.first ?? chapters.first {
                NavigationLink(value: MobileStudyRoute.lesson(id: chapter.id)) {
                    Label(savedChapters.isEmpty ? "Start course" : "Continue reading", systemImage: "arrow.right")
                        .font(StudyTypography.font(.subheadline, weight: .semibold))
                        .foregroundStyle(Palette.actionGradientInk)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 46)
                        .background(Palette.actionGradient, in: RoundedRectangle(cornerRadius: Palette.controlRadius))
                }
                .buttonStyle(GardenPressStyle())
                .accessibilityHint("Opens \(chapter.title)")
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { GardenSceneBackground(asset: "GardenBotanical") }
        .clipShape(RoundedRectangle(cornerRadius: Palette.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Palette.cardRadius, style: .continuous).stroke(Palette.line, lineWidth: 1))
    }

    private var chapterSearch: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Palette.secondary)
                .accessibilityHidden(true)
            TextField("Find a chapter", text: $search)
                .font(StudyTypography.font(.subheadline))
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Search chapters in this course")
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(GardenPressStyle())
                .foregroundStyle(Palette.secondary)
                .accessibilityLabel("Clear chapter search")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, search.isEmpty ? 12 : 0)
        .frame(minHeight: 52)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Palette.controlRadius))
        .overlay(RoundedRectangle(cornerRadius: Palette.controlRadius).stroke(Palette.line, lineWidth: 1))
    }
}

private struct CourseOutlineChapter: Identifiable {
    let number: Int
    let lesson: MobileLessonSummary
    var id: String { lesson.id }

    var title: String {
        let stripped = lesson.title.replacingOccurrences(of: #"^\s*\d+(?:[.)]\s*|\s+[-–:]\s+)"#,
            with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? lesson.title : stripped
    }
}

private struct CourseOutlineRow: View {
    let chapter: CourseOutlineChapter
    let hasPosition: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(String(format: "%02d", chapter.number))
                .font(StudyTypography.font(.subheadline, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Palette.accent)
                .frame(minWidth: 38, minHeight: 42)
                .background(Palette.preview, in: RoundedRectangle(cornerRadius: Palette.controlRadius))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(chapter.title)
                    .font(StudyTypography.font(.headline, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !chapter.lesson.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(chapter.lesson.subtitle)
                        .font(StudyTypography.font(.subheadline))
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(2)
                }
                if hasPosition {
                    Label("Reading place saved", systemImage: "bookmark.fill")
                        .font(StudyTypography.font(.caption))
                        .foregroundStyle(Palette.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Palette.secondary)
                .padding(.top, 7)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .gardenCard(padding: 16)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chapter \(chapter.number), \(chapter.title)")
        .accessibilityValue(hasPosition ? "Reading place saved" : "")
        .accessibilityHint("Opens this chapter")
    }
}
