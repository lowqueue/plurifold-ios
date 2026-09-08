import Foundation

struct MobileLibraryLessonItem: Identifiable {
    let lesson: MobileLessonSummary
    let source: String
    var id: String { lesson.id }
}

struct MobileLibraryLevelGroup: Identifiable {
    let level: String
    let lessons: [MobileLibraryLessonItem]
    var id: String { level }
    var title: String { MobileLibraryShelf.levelTitle(level) }
}

/// A lesson shelf mirrors the website's channel and material-difficulty filters.
/// Course chapters remain in their folders and never enter these lesson counts.
struct MobileLibraryShelf {
    static let unassessedLevel = "unassessed"
    private static let orderedLevels = ["0", "0+", "1", "1+", "2", "2+", "3", "3+", "4", "4+", "5"]

    let courseFolders: [MobileCourseFolder]
    let lessonGroups: [MobileLibraryLevelGroup]
    let availableChannels: [String]
    let availableLevels: [String]
    let totalLessonCount: Int
    let visibleLessonCount: Int

    init(courses: [MobileCourse], search: String = "", channel: String = "", level: String = "") {
        let fullIndex = MobileLibraryIndex(courses: courses)
        let searchedIndex = MobileLibraryIndex(courses: courses, search: search)
        courseFolders = searchedIndex.courseFolders

        func items(in groups: [MobileCourse]) -> [MobileLibraryLessonItem] {
            groups.flatMap { group in
                group.lessons.map { lesson in
                    let channel = lesson.channel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let groupTitle = group.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    return MobileLibraryLessonItem(lesson: lesson,
                        source: channel.isEmpty ? (groupTitle.isEmpty ? "Other sources" : groupTitle) : channel)
                }
            }
        }
        let all = items(in: fullIndex.lessonGroups)
        availableChannels = Set(all.map(\.source)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        availableLevels = Set(all.map { Self.levelKey($0.lesson.ilrLevel) }).sorted(by: Self.levelSort)
        totalLessonCount = all.count

        let filtered = items(in: searchedIndex.lessonGroups).filter {
            (channel.isEmpty || $0.source == channel) && (level.isEmpty || Self.levelKey($0.lesson.ilrLevel) == level)
        }
        visibleLessonCount = filtered.count
        let groups = Dictionary(grouping: filtered) { Self.levelKey($0.lesson.ilrLevel) }
        lessonGroups = groups.keys.sorted(by: Self.levelSort).map {
            MobileLibraryLevelGroup(level: $0, lessons: groups[$0] ?? [])
        }
    }

    static func levelTitle(_ level: String) -> String {
        level == unassessedLevel ? "ILR unassessed" : "Estimated ILR \(level)"
    }

    static func levelKey(_ value: String?) -> String {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              orderedLevels.contains(value) else { return unassessedLevel }
        return value
    }

    private static func levelSort(_ lhs: String, _ rhs: String) -> Bool {
        (orderedLevels.firstIndex(of: lhs) ?? orderedLevels.count)
            < (orderedLevels.firstIndex(of: rhs) ?? orderedLevels.count)
    }
}
