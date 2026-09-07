import SwiftUI

struct LiveCourseView: View {
    @EnvironmentObject private var store: LiveLibraryStore
    let courseID: String
    @State private var search: String

    init(courseID: String, initialSearch: String = "") {
        self.courseID = courseID
        _search = State(initialValue: initialSearch)
    }

    private var course: MobileCourse? {
        store.courses.first { $0.id == courseID }
    }

    private var folder: MobileCourseFolder? {
        MobileLibraryIndex(courses: course.map { [$0] } ?? [], search: search).courseFolders.first
    }

    var body: some View {
        List {
            if let notice = store.notice {
                Section {
                    LibraryNoticeRow(notice: notice)
                        .listRowBackground(Palette.surface)
                }
            }
            if let course {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(course.title)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        Text(course.languageName)
                            .font(.subheadline)
                            .foregroundStyle(Palette.secondary)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                if let folder {
                    Section {
                        ForEach(folder.chapters) { lesson in
                            NavigationLink {
                                LiveReaderView(lessonID: lesson.id)
                            } label: {
                                LibraryLessonRow(lesson: lesson, hasPosition: store.positions[lesson.id] != nil)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowBackground(Color.clear)
                        }
                    } header: {
                        Text(folder.chapters.count == folder.course.lessons.count ? "Chapters" : "Matching chapters")
                            .textCase(nil)
                            .foregroundStyle(Palette.secondary)
                    }
                } else {
                    ContentUnavailableView("No matching chapters", systemImage: "magnifyingglass",
                                           description: Text("Try another search term or clear the search to see all chapters."))
                        .listRowBackground(Color.clear)
                }
            } else {
                ContentUnavailableView("Course unavailable", systemImage: "folder",
                                       description: Text("Return to your library and refresh to see available courses."))
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .studyBackground()
        .tint(Palette.accent)
        .navigationTitle("Course")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Chapters in this course")
        .refreshable { await store.refresh() }
    }
}
