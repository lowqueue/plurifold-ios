import Foundation

/// A structured course keeps its full chapter list as well as the current
/// matches, so searching never promotes chapters into standalone lessons.
struct MobileCourseFolder: Identifiable {
    let course: MobileCourse
    let chapters: [MobileLessonSummary]
    var id: String { course.id }
}

struct MobileLibraryIndex {
    let courseFolders: [MobileCourseFolder]
    let lessonGroups: [MobileCourse]

    var isEmpty: Bool { courseFolders.isEmpty && lessonGroups.isEmpty }

    init(courses: [MobileCourse], search: String = "", languageCode: String = "") {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        var folders: [MobileCourseFolder] = []
        var groups: [MobileCourse] = []

        for course in courses {
            guard languageCode.isEmpty || course.languageCode == languageCode else { continue }
            let groupMatches = query.isEmpty || course.title.localizedStandardContains(query)
                || course.languageName.localizedStandardContains(query)
            func matches(_ lesson: MobileLessonSummary) -> Bool {
                groupMatches || lesson.title.localizedStandardContains(query)
                    || lesson.subtitle.localizedStandardContains(query)
                    || (lesson.channel?.localizedStandardContains(query) ?? false)
                    || (lesson.dialect?.localizedStandardContains(query) ?? false)
            }
            func group(with lessons: [MobileLessonSummary]) -> MobileCourse {
                MobileCourse(id: course.id, title: course.title,
                             languageCode: course.languageCode, languageName: course.languageName,
                             lessons: lessons)
            }

            // Use the API's explicit kind, not title keywords or a fixed list
            // of current textbook IDs. Mixed future groups are safely split.
            let allChapters = course.lessons.filter { $0.kind == "course" }
            let matchingChapters = allChapters.filter(matches)
            if !matchingChapters.isEmpty {
                folders.append(MobileCourseFolder(course: group(with: allChapters),
                                                  chapters: matchingChapters))
            }
            let lessons = course.lessons.filter { $0.kind != "course" && matches($0) }
            if !lessons.isEmpty { groups.append(group(with: lessons)) }
        }

        courseFolders = folders
        lessonGroups = groups
    }
}
