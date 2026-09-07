# Validation record

Checked on 2026-09-07 in a Linux workspace.

## Completed checks

- Parsed all 11 Swift source files with the tree-sitter Swift grammar: no syntax errors reported. This does not type-check Apple frameworks.
- Regenerated the Xcode project and verified all 52 internal project object references and referenced source/resource files.
- Parsed the shared Xcode scheme as XML and the privacy manifest as a property list.
- Checked the bundled JSON catalog: 1 collection, 2 lessons, 12 passages, 24 vocabulary entries, 6 questions. IDs are unique, answer indexes are valid, and each vocabulary expression occurs in its lesson.
- Compared all six original Bologna story sentences against the existing website source; they match.
- Performed an independent source review and corrected attributed-text mutation, navigation destination stability, audio interruption handling, empty-question validation, stale speech errors, and repeated quiz advancement.

## Not yet verified

- Xcode build, linking, code signing, simulator launch, and physical iPhone/iPad launch.
- 9 XCTest methods are included but have not run. They cover persistence, invalid data, score bounds, reading state, and reset behavior.
- Native rendering, Dynamic Type layout, VoiceOver, touch targets, actual system voices, and device audio behavior.

The source and project-structure checks do not establish that the app compiles or runs. Open the project on a Mac and run the build and tests in README.md before relying on it.
