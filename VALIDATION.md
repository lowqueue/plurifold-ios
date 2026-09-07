# Validation record

Updated on 2026-09-07. The development workspace runs Linux and has no Xcode or native iOS simulator. Historical build results and current source checks are separated below.

## Reader and course organization update

The user's iPhone screenshots and recording show the live library and working embedded playback. This revision changes that source without changing the website or signing setup:

- A single-source lesson displays its player directly; only multiple-source lessons show a recording menu. Playback remains user initiated.
- The reader uses one continuous text surface with paragraph breaks. A shared reader bar replaces the repeated sentence cards, passage numbers, and per-passage buttons.
- A custom recognizer highlights on touch-down, expands by whole words during dragging, and submits a selection only after UIKit recognizes the completed release. Initial vertical movement scrolls in normal reading mode; Select mode captures drags in any direction. Cancellation clears the highlight and stops edge autoscrolling.
- Cached word ranges use normalized language codes. Existing composed-character validation remains in force. Original paragraph offsets still drive saved-place and device-speech behavior.
- Courses retain their chapters inside folders. Independent lessons are separate, and filtering/searching preserves the hierarchy using the API's explicit content kind.
- Opening a definition pauses mounted players without replacing them. A YouTube iframe playback-start callback stops device speech. The bridge checks its source and payload and is removed when the player is dismantled.

Completed checks for this revision:

- All 28 Swift files (24 app sources and four test files) parsed without grammar errors. This is not Swift typechecking or Apple-framework compilation.
- Project regeneration validated 88 object references and all source/resource paths; all new Swift files are included in the appropriate target. The shared scheme parsed successfully.
- Codemagic configuration passed the official schema check, and workflow scripts passed Bash syntax checks. The existing native test gate still runs before signing and uploading.
- Focused source review covered touch cancellation, gesture failure requirements, Unicode ranges, continuous paragraph mapping, course classification, media identity, and audio handoff. A JavaScript callback check covered playing versus paused/cued YouTube states.
- `git diff --check` reported no whitespace errors.

The suite contains 31 XCTest methods: seven session tests, eleven selection/document tests, four course-organization tests, and nine original study-store tests. Nine new tests cover whole-word forward/backward drags across paragraphs, whitespace snapping, scroll/selection direction decisions, tokenizer language normalization, bookmark offsets, and course search/classification. These tests have been added, not executed locally.

Codemagic must still compile this revision and execute XCTest. The iPhone check must verify actual touch responsiveness, cross-line and cross-paragraph dragging, edge autoscroll, ordinary vertical scrolling, saved-place resume, direct media controls, and speech/video handoff. If YouTube's iframe API script fails to load, its playback-start callback cannot coordinate speech even if the embedded video itself remains usable. Dynamic Type, VoiceOver, and iPad layout also need native verification.

## Replacement app icon

The supplied `AppIcon(1).svg` replaces the original icon source in `design/AppIcon.svg` without changing its bytes. All 13 PNG sizes in `AppIcon.appiconset` were regenerated for the existing 18 iPhone, iPad, and App Store slots. The PNGs retain the source geometry and color, use an opaque white background, and show the cursor in its visible state. PNG dimensions, RGB encoding without transparency, asset references, and the rendered artwork were checked. The original SVG retains its animation; the exported app icons are static.

## Earlier Codemagic result and selection correction

The supplied `test_sign_in_and_text_selection.log` confirms that the app and test bundle compiled using Xcode 26.6 and the iOS 26.5 simulator SDK. All seven session tests, all nine study-store tests, and four of five selection tests passed: 20 of 21 tests in total.

The sole failure was `testInvalidRangesAndWhitespaceCannotCreateSelections`: the range `{1, 1}` inside `🌍 ciao` selected the whole emoji even though it starts halfway through its UTF-16 surrogate pair. The initializer now verifies that NSString's composed-character range exactly matches the requested range before converting it to Swift indices. This keeps the stored range and selected text consistent.

An additional test accepts complete emoji and accented characters while rejecting every partial UTF-16 subrange for a surrogate-pair emoji, decomposed accent, variation selector, skin-tone/ZWJ emoji, flag, and decomposed Japanese character. That correction brought the earlier suite to 22 tests. Both the correction and its regression test remain in this revision.

## Earlier live-account source checks

Completed checks for the earlier live-account update:

- All 24 Swift files, including the three test files, parsed with the tree-sitter Swift grammar without syntax errors. This is grammar validation, not Swift typechecking or Apple-framework compilation.
- The Codemagic YAML passed the official schema check. Its shell scripts passed Bash syntax checks.
- The Xcode project was regenerated and source/resource membership checked, including the new networking, live reader, selection, audio, and test files.
- The companion web integration suite passed all 34 tests for mobile content, study synchronization, and the shared lesson library. The six mobile integration tests also passed again after the final validation fixes.
- The native session and API code were reviewed for refresh serialization, rejected credentials, temporary network failures, stale results after sign-out, and signing back into the same account.
- The reader selection code was checked for valid UTF-16 boundaries and explicit phrase lookup. Media and speech lifecycle review identified shared audio-session ownership and was followed by an audio coordinator update.
- `git diff --check` reported no whitespace errors.

The prepared course catalog contained four course collections with 75 entries. The signed-in library also included the published and private saved lessons authorized for that account. The matching website update passed its production build and was published as Plurifold version 84, source commit `d3fbb7fa79f6bd0bcfa66bc96f709e4981457b51`. Live checks passed for public account configuration, authenticated endpoint protection, invalid-token rejection, and the signed-out website entry. The user's later screenshots show real lessons loading on the iPhone. This UI revision makes no website changes.

## Native test gate still to run

The **Plurifold - TestFlight** workflow runs all 31 current tests before signing and uploading the IPA.

The supplied Codemagic log establishes native compilation and simulator test execution for its own source revision. This Linux workspace can validate Swift grammar but cannot run Xcode or the new regression tests. The reader/course update still requires Codemagic verification and a device check.

The next iPhone check should also verify that existing account sign-in, authorized content loading, AI responses, website synchronization, and persistence across app restarts continue to work. Follow the device steps in README.md.

## Historical original prototype checks

Before the live-account work, the original source passed these checks:

- Eleven Swift files parsed without grammar errors.
- The original generator verified 52 project object references and source/resource paths.
- The shared Xcode scheme parsed as XML and the privacy manifest parsed as a property list.
- The bundled fixture catalog contained one collection, two lessons, twelve passages, twenty-four vocabulary entries, and six questions. IDs, answer indexes, and glossary occurrences were checked.
- The six original Bologna story sentences matched the website source used for that prototype.
- Source review covered attributed text, stable navigation destinations, audio interruptions, empty-question validation, stale speech errors, and repeated quiz advancement.

Those bundled lessons remain historical fixtures. They are not the signed-in live library and their local study data is not migrated into an account by this update.

## Historical successful builds and installation

The first Codemagic simulator build succeeded at commit `a9e0550`, using **Plurifold - first simulator build** on a Mac mini M2:

| Item | Result |
| --- | --- |
| Build ID | `6a9ee25b7dc162e48e3dff37` |
| Build index | `1` |
| Duration | 1 minute 38 seconds |
| Artifact | `Plurifold-simulator.zip`, 894.15 KB |

That result established compilation and simulator packaging for its own commit, without an XCTest run or simulator launch.

The later signed upload initially failed Apple's icon validation while GitHub still held old project folders. The icon update included 18 catalog entries referencing 13 correctly sized RGB PNG files, including the 1024-pixel App Store icon. The project added the asset catalog to its resources and selected the `AppIcon` set. After the folders reached GitHub, the user confirmed that the TestFlight app worked on the iPhone.

That installation establishes the earlier signing and distribution path. It does not establish compilation, native test results, or device behavior for the new live-account source.

## Next verification

Follow [NEXT-BUILD.md](NEXT-BUILD.md) to commit the full source package and start a new **Plurifold - TestFlight** build. Keep the new build's commit, test results, publishing result, and device observations with this record when they become available.
