import SwiftUI

struct LiveCourseView: View {
    @EnvironmentObject private var store: LiveLibraryStore
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
                    Label("Back to library", systemImage: "chevron.left")
                        .font(.subheadline.monospaced())
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.accent)

                if let notice = store.notice { LibraryNoticeRow(notice: notice).libraryFrame() }
                if let course {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "\(course.languageName) course")
                        Text(course.title)
                            .font(.title2.monospaced().weight(.medium))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text("\(allChapters.count) \(allChapters.count == 1 ? "chapter" : "chapters") · Study at your own pace")
                            .font(.caption.monospaced())
                            .foregroundStyle(Palette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    chapterSearch
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Chapters" : "Matching chapters")
                            .font(.headline.monospaced().weight(.regular))
                        Spacer(minLength: 0)
                        Text("\(chapters.count)")
                            .font(.caption.monospaced())
                            .foregroundStyle(Palette.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    ForEach(chapters) { chapter in
                        NavigationLink(value: MobileStudyRoute.lesson(id: chapter.lesson.id)) {
                            CourseOutlineRow(chapter: chapter, hasPosition: store.positions[chapter.lesson.id] != nil)
                        }
                        .buttonStyle(.plain)
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
            .padding(.horizontal, 16)
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

    private var chapterSearch: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Palette.secondary)
                .accessibilityHidden(true)
            TextField("Find a chapter", text: $search)
                .font(.subheadline.monospaced())
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
                .buttonStyle(.plain)
                .foregroundStyle(Palette.secondary)
                .accessibilityLabel("Clear chapter search")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, search.isEmpty ? 12 : 0)
        .frame(minHeight: 48)
        .background(Palette.field, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.line, lineWidth: 1))
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
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d", chapter.number))
                .font(.caption.monospaced())
                .foregroundStyle(Palette.accent)
                .padding(.horizontal, 7)
                .padding(.vertical, 8)
                .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: 3))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(chapter.title)
                    .font(.subheadline.monospaced().weight(.medium))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !chapter.lesson.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(chapter.lesson.subtitle)
                        .font(.caption)
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(2)
                }
                if hasPosition {
                    Label("Reading place saved", systemImage: "bookmark.fill")
                        .font(.caption2.monospaced())
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
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.line, lineWidth: 1))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chapter \(chapter.number), \(chapter.title)")
        .accessibilityValue(hasPosition ? "Reading place saved" : "")
        .accessibilityHint("Opens this chapter")
    }
}
