import SwiftUI

struct LiveLibraryView: View {
    @EnvironmentObject private var store: LiveLibraryStore
    @State private var search = ""
    let languageCode: String
    let languageName: String

    private var catalog: MobileLanguageCatalog { MobileLanguageCatalog(courses: store.courses) }
    private var language: MobileLanguageOption? { catalog.language(for: languageCode) }

    private var index: MobileLibraryIndex {
        MobileLibraryIndex(courses: catalog.courses(for: languageCode), search: search)
    }

    var body: some View {
        List {
            if let notice = store.notice {
                Section {
                    LibraryNoticeRow(notice: notice)
                        .listRowBackground(Palette.surface)
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
            } else if language == nil {
                Section {
                    ContentUnavailableView("Language unavailable", systemImage: "globe",
                                           description: Text("Return to Home to choose an available language, or pull down to refresh."))
                        .listRowBackground(Color.clear)
                }
            } else if index.isEmpty {
                Section {
                    ContentUnavailableView("No matching content", systemImage: "magnifyingglass",
                                           description: Text("Try another search term to find courses and lessons in \(languageName)."))
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
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowBackground(Color.clear)
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
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                .listRowBackground(Color.clear)
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
        .tint(Palette.accent)
        .navigationTitle(language?.name ?? languageName)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Lessons, courses, channels")
        .refreshable { await store.refresh() }
        .task { if !store.hasLoaded { await store.refresh() } }
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
                .foregroundStyle(Palette.green)
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.courseSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line, lineWidth: 1))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(Palette.green)
                .frame(width: 4).padding(.vertical, 8).allowsHitTesting(false)
        }
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line, lineWidth: 1))
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
