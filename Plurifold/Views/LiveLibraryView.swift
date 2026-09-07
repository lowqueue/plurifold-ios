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

    private var filteredCourses: [MobileCourse] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.courses.compactMap { course in
            guard language.isEmpty || course.languageCode == language else { return nil }
            let courseMatches = query.isEmpty || course.title.localizedStandardContains(query)
                || course.languageName.localizedStandardContains(query)
            let lessons = course.lessons.filter { lesson in
                courseMatches || lesson.title.localizedStandardContains(query)
                    || lesson.subtitle.localizedStandardContains(query)
                    || (lesson.channel?.localizedStandardContains(query) ?? false)
                    || (lesson.dialect?.localizedStandardContains(query) ?? false)
            }
            guard !lessons.isEmpty else { return nil }
            return MobileCourse(id: course.id, title: course.title, languageCode: course.languageCode,
                                languageName: course.languageName, lessons: lessons)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let notice = store.notice {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(notice, systemImage: "exclamationmark.circle")
                                .font(.subheadline)
                                .foregroundStyle(Palette.secondary)
                            Button("Try again") { Task { await store.refresh() } }
                                .disabled(store.isLoading)
                        }
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
                } else if filteredCourses.isEmpty {
                    Section {
                        ContentUnavailableView("No matching lessons", systemImage: "magnifyingglass",
                                               description: Text("Try another language or search term."))
                            .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(filteredCourses) { course in
                        Section {
                            ForEach(course.lessons) { lesson in
                                NavigationLink {
                                    LiveReaderView(lessonID: lesson.id)
                                } label: {
                                    lessonRow(lesson)
                                }
                                .listRowBackground(Palette.surface)
                            }
                        } header: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(course.languageName).font(.caption.monospaced())
                                Text(course.title).font(.headline)
                            }
                            .textCase(nil)
                            .foregroundStyle(Palette.secondary)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
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

    private func lessonRow(_ lesson: MobileLessonSummary) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(lesson.title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !lesson.subtitle.isEmpty {
                Text(lesson.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(3)
            }
            if let channel = lesson.channel, !channel.isEmpty {
                Label(channel, systemImage: "person.crop.rectangle")
                    .font(.caption)
                    .foregroundStyle(Palette.secondary)
            }
            HStack(spacing: 12) {
                if lesson.paragraphCount > 0 {
                    Text("\(lesson.paragraphCount) \(lesson.paragraphCount == 1 ? "passage" : "passages")")
                }
                if store.positions[lesson.id] != nil {
                    Label("Continue reading", systemImage: "bookmark.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(Palette.secondary)
        }
        .padding(.vertical, 8)
    }
}
