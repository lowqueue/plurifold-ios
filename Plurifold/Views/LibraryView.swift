import SwiftUI

private struct LessonRoute: Hashable {
    let courseID: String
    let lessonID: String
}

struct LibraryView: View {
    @EnvironmentObject private var store: StudyStore

    private var course: Course { store.selectedCourse }
    private var nextLesson: Lesson {
        course.lessons.first { !store.completedLessonIDs.contains($0.id) } ?? course.lessons[0]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Wordmark()
                        Spacer(minLength: 12)
                        courseControl
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Wordmark()
                        courseControl
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    Eyebrow(text: "Your reading room")
                    Text(course.title).font(.system(.largeTitle, design: .serif).weight(.medium))
                    Text(course.subtitle).font(.body).foregroundStyle(Palette.secondary)
                }

                NavigationLink(value: LessonRoute(courseID: course.id, lessonID: nextLesson.id)) {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack {
                            Eyebrow(text: store.lastParagraph(for: nextLesson) == nil ? "Begin a story" : "Back to your story")
                            Spacer()
                            Image(systemName: "sun.horizon").font(.title2)
                        }
                        Text(nextLesson.title)
                            .font(.system(.title, design: .serif).weight(.medium))
                            .multilineTextAlignment(.leading)
                        Text(nextLesson.subtitle)
                            .font(.body).foregroundStyle(Palette.secondary)
                            .multilineTextAlignment(.leading)
                        HStack {
                            Label("\(nextLesson.minutes) min", systemImage: "clock")
                                .font(.subheadline.monospaced())
                            Spacer()
                            Label("Open reader", systemImage: "arrow.right")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .padding(24)
                    .background(Palette.field, in: RoundedRectangle(cornerRadius: 24))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Eyebrow(text: "In this collection")
                        Spacer()
                        Text("\(course.lessons.filter { store.completedLessonIDs.contains($0.id) }.count)/\(course.lessons.count)")
                            .font(.subheadline.monospaced()).foregroundStyle(Palette.secondary)
                            .accessibilityLabel("\(course.lessons.filter { store.completedLessonIDs.contains($0.id) }.count) of \(course.lessons.count) lessons completed")
                    }
                    ForEach(Array(course.lessons.enumerated()), id: \.element.id) { index, lesson in
                        NavigationLink(value: LessonRoute(courseID: course.id, lessonID: lesson.id)) {
                            HStack(alignment: .center, spacing: 16) {
                                Text(String(format: "%02d", index + 1))
                                    .font(.title3.monospaced()).foregroundStyle(Palette.secondary)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(lesson.title).font(.headline).multilineTextAlignment(.leading)
                                    Text("\(lesson.minutes) min · \(lesson.vocabulary.count) expressions")
                                        .font(.subheadline).foregroundStyle(Palette.secondary)
                                    ProgressView(value: store.progress(for: lesson))
                                        .tint(Palette.ink)
                                        .accessibilityLabel("Reading progress")
                                }
                                Image(systemName: store.completedLessonIDs.contains(lesson.id) ? "checkmark.circle.fill" : "chevron.right")
                                    .accessibilityHidden(true)
                            }
                            .studyCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .studyBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: LessonRoute.self) { route in
            if let destinationCourse = store.catalog.courses.first(where: { $0.id == route.courseID }),
               let destinationLesson = destinationCourse.lessons.first(where: { $0.id == route.lessonID }) {
                ReaderView(course: destinationCourse, lesson: destinationLesson)
            }
        }
    }

    @ViewBuilder private var courseControl: some View {
        if store.catalog.courses.count > 1 {
            Menu {
                Picker("Course", selection: Binding(
                    get: { store.selectedCourseID },
                    set: { store.chooseCourse($0) }
                )) {
                    ForEach(store.catalog.courses) { course in
                        Text(course.languageName).tag(course.id)
                    }
                }
            } label: {
                Label(course.languageName, systemImage: "chevron.down")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14).frame(minHeight: 44)
                    .background(Palette.field, in: Capsule())
            }
        } else {
            Text(course.languageName)
                .font(.subheadline.monospaced())
                .padding(.horizontal, 14).frame(minHeight: 44)
                .background(Palette.field, in: Capsule())
        }
    }
}
