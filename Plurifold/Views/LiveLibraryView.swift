import SwiftUI

struct LiveLibraryView: View {
    @EnvironmentObject private var store: LiveLibraryStore
    @State private var search = ""
    @State private var language = ""

    private var languages: [(code: String, name: String)] {
        var names: [String: String] = [:]
        for course in store.courses { names[course.languageCode] = course.languageName }
        return names.map { (code: $0.key, name: $0.value) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var index: MobileLibraryIndex {
        MobileLibraryIndex(courses: store.courses, search: search, languageCode: language)
    }

    var body: some View {
        NavigationStack {
            List {
                if let notice = store.notice {
                    Section {
                        LibraryNoticeRow(notice: notice)
                            .listRowBackground(Palette.surface)
                    }
                }

                if !languages.isEmpty {
                    Section {
                        Picker("Language", selection: $language) {
                            Text("All languages").tag("")
                            ForEach(languages, id: \.code) { option in
                                Text(option.name).tag(option.code)
                            }
                        }
                        .listRowBackground(Palette.field)
                    }
                }

                if store.isLoading && store.courses.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Loading your library…").padding(.vertical, 36)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                } else if store.courses.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("Your library", systemImage: "books.vertical")
                        } description: {
                            Text(store.notice == nil
                                 ? "Your Plurifold courses and lessons will appear here when they’re available."
                                 : "Your library couldn’t load. Check your connection and try again.")
                        }
                        .listRowBackground(Color.clear)
                    }
                } else if index.isEmpty {
                    Section {
                        ContentUnavailableView("No matching content", systemImage: "magnifyingglass",
                                               description: Text("Try another language or search term."))
                            .listRowBackground(Color.clear)
                    }
                } else {
                    if !index.courseFolders.isEmpty {
                        Section {
                            ForEach(index.courseFolders) { folder in
                                NavigationLink {
                                    LiveCourseView(courseID: folder.id, initialSearch: search)
                                } label: {
                                    courseRow(folder)
                                }
                                .listRowBackground(Palette.surface)
                            }
                        } header: {
                            categoryHeader("Courses", subtitle: "Foundations and guided study", icon: "folder")
                        }
                    }

                    if !index.lessonGroups.isEmpty {
                        Section {
                            ForEach(index.lessonGroups) { group in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(group.title).font(.headline)
                                    if language.isEmpty {
                                        Text(group.languageName).font(.caption)
                                    }
                                }
                                .foregroundStyle(Palette.secondary)
                                .padding(.top, 12)
                                .padding(.bottom, 3)
                                .accessibilityAddTraits(.isHeader)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)

                                ForEach(group.lessons) { lesson in
                                    NavigationLink {
                                        LiveReaderView(lessonID: lesson.id)
                                    } label: {
                                        LibraryLessonRow(lesson: lesson, hasPosition: store.positions[lesson.id] != nil)
                                    }
                                    .listRowBackground(Palette.surface)
                                }
                            }
                        } header: {
                            categoryHeader("Lessons", subtitle: "Videos, audio, and reading", icon: "play.rectangle")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .studyBackground()
            .tint(Palette.ink)
            .navigationTitle("Learn")
            .searchable(text: $search, prompt: "Lessons, courses, channels")
            .refreshable { await store.refresh() }
            .task { if !store.hasLoaded { await store.refresh() } }
            .onChange(of: store.courses) { _, _ in
                if !language.isEmpty, !languages.contains(where: { $0.code == language }) { language = "" }
            }
        }
    }

    private func categoryHeader(_ title: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.ink)
            Text(subtitle).font(.caption).foregroundStyle(Palette.secondary)
        }
        .textCase(nil)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func courseRow(_ folder: MobileCourseFolder) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundStyle(Palette.ink)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(folder.course.title)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(folder.course.languageName)
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondary)
                if folder.chapters.count == folder.course.lessons.count {
                    Text("\(folder.chapters.count) \(folder.chapters.count == 1 ? "chapter" : "chapters")")
                        .font(.caption)
                        .foregroundStyle(Palette.secondary)
                } else {
                    Text("\(folder.chapters.count) of \(folder.course.lessons.count) chapters match")
                        .font(.caption)
                        .foregroundStyle(Palette.secondary)
                }
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the chapters in this course")
    }
}

struct LibraryLessonRow: View {
    let lesson: MobileLessonSummary
    let hasPosition: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(lesson.title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !lesson.subtitle.isEmpty {
                Text(lesson.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 12) {
                if lesson.paragraphCount > 0 {
                    Text("\(lesson.paragraphCount) \(lesson.paragraphCount == 1 ? "passage" : "passages")")
                }
                if hasPosition {
                    Label("Continue reading", systemImage: "bookmark.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(Palette.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct LibraryNoticeRow: View {
    @EnvironmentObject private var store: LiveLibraryStore
    let notice: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(notice, systemImage: "exclamationmark.circle")
                .font(.subheadline)
                .foregroundStyle(Palette.secondary)
            Button("Try again") { Task { await store.refresh() } }
                .disabled(store.isLoading)
        }
    }
}
