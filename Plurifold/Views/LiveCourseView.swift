import SwiftUI

struct LiveCourseView: View {
    @EnvironmentObject private var store: LiveLibraryStore
    let courseID: String
    @State private var search: String

    init(courseID: String, initialSearch: String = "") {
        self.courseID = courseID
        _search = State(initialValue: initialSearch)
    }

    private var course: MobileCourse? { store.courses.first { $0.id == courseID } }
    private var folder: MobileCourseFolder? {
        MobileLibraryIndex(courses: course.map { [$0] } ?? [], search: search).courseFolders.first
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                if let notice = store.notice { LibraryNoticeRow(notice: notice).libraryFrame() }
                if let course {
                    VStack(alignment: .leading, spacing: 14) {
                        Eyebrow(text: "\(course.languageName) course")
                        Text(course.title)
                            .font(.title.monospaced())
                            .foregroundStyle(Palette.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("Build your foundation, one chapter at a time.")
                            .font(.subheadline.monospaced())
                            .foregroundStyle(Palette.secondary)
                    }
                    .padding(.vertical, 6)
                    if let folder {
                        HStack(alignment: .firstTextBaseline) {
                            Text(folder.chapters.count == folder.course.lessons.count ? "Chapters" : "Matching chapters")
                                .font(.headline.monospaced().weight(.regular))
                            Spacer()
                            Text("\(folder.chapters.count)")
                                .font(.caption.monospaced())
                                .foregroundStyle(Palette.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)
                        Rectangle().fill(Palette.line).frame(height: 1)
                        ForEach(folder.chapters) { lesson in
                            NavigationLink {
                                LiveReaderView(lessonID: lesson.id)
                            } label: {
                                LibraryLessonRow(lesson: lesson, hasPosition: store.positions[lesson.id] != nil,
                                                 source: course.title, savedCount: savedCount(for: lesson),
                                                 showsCover: false)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        ContentUnavailableView("No matching chapters", systemImage: "magnifyingglass",
                            description: Text("Try another search term or clear the search to see all chapters."))
                    }
                } else {
                    ContentUnavailableView("Course unavailable", systemImage: "folder",
                        description: Text("Return to your library and refresh to see available courses."))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .studyBackground()
        .tint(Palette.accent)
        .navigationTitle("Course")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .searchable(text: $search, prompt: "Chapters in this course")
        .refreshable { await store.refresh() }
    }

    private func savedCount(for lesson: MobileLessonSummary) -> Int {
        store.words.filter {
            $0.sourceLessonID == lesson.id
                && MobileLanguageKey.normalized($0.languageCode) == MobileLanguageKey.normalized(lesson.languageCode)
        }.count
    }
}
