# Validation record

Updated on 2026-09-07. Local checks use a Linux workspace; the simulator build below ran on Codemagic's Mac mini M2.

## Completed checks

- Parsed all 11 Swift source files with the tree-sitter Swift grammar: no syntax errors reported. This does not type-check Apple frameworks.
- Regenerated the original Xcode project and verified its 52 internal project object references and referenced source/resource files.
- Parsed the shared Xcode scheme as XML and the privacy manifest as a property list.
- Checked the bundled JSON catalog: 1 collection, 2 lessons, 12 passages, 24 vocabulary entries, 6 questions. IDs are unique, answer indexes are valid, and each vocabulary expression occurs in its lesson.
- Compared all six original Bologna story sentences against the existing website source; they match.
- Performed an independent source review and corrected attributed-text mutation, navigation destination stability, audio interruption handling, empty-question validation, stale speech errors, and repeated quiz advancement.

## Confirmed simulator build

- The user's Codemagic screenshot shows a successful build at `a9e0550`, workflow **Plurifold - first simulator build**, build index 1, on a Mac mini M2.
- Build ID: `6a9ee25b7dc162e48e3dff37`. Total duration: 1 minute 38 seconds. Output: `Plurifold-simulator.zip`, 894.15 KB.
- This confirms compilation and simulator packaging for that commit. It does not confirm app launch, rendering, XCTest results, physical-device signing, or Apple upload.

## Distribution update checks

- The new `codemagic.yaml` passes Codemagic's current official JSON schema. Both workflows parse, all four shell scripts pass `bash -n`, and the original simulator workflow's configuration is unchanged.
- The icon catalog has 18 entries referencing 13 PNG files. Every size matches its asset slot, including the 1024-pixel App Store icon, and every PNG uses RGB without an alpha channel. The vector and rendered icon were visually inspected.
- The updated project generator validates 54 PBX object references and all source/resource paths, including the asset catalog directory. Regeneration produces identical project bytes.
- Both Python scripts parse, the shared scheme parses as XML, and the existing privacy manifest parses as a property list.
- SwiftUI code, models, tests, and lesson content are unchanged from the successful simulator commit.
- `git diff --check` reports no whitespace errors.

## Still to verify on Apple infrastructure

- A native build of the new icon/distribution configuration, code signing, Apple upload, simulator launch, and physical iPhone/iPad launch.
- 9 XCTest methods are included but have not run. They cover persistence, invalid data, score bounds, reading state, and reset behavior.
- Native rendering, Dynamic Type layout, VoiceOver, touch targets, actual system voices, and device audio behavior.

Run the **Plurifold - TestFlight** workflow after adding the signing files, then perform the device checks in `README.md`. The original compile result does not establish that the new distribution configuration has passed Apple's validation.
