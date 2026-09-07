# Validation record

Updated on 2026-09-07. The development workspace runs Linux and has no Xcode or native iOS simulator. Historical build results and current source checks are separated below.

## Replacement app icon

The supplied `AppIcon(1).svg` replaces the original icon source in `design/AppIcon.svg` without changing its bytes. All 13 PNG sizes in `AppIcon.appiconset` were regenerated for the existing 18 iPhone, iPad, and App Store slots. The PNGs retain the source geometry and color, use an opaque white background, and show the cursor in its visible state. PNG dimensions, RGB encoding without transparency, asset references, and the rendered artwork were checked. The original SVG retains its animation; the exported app icons are static.

## Latest Codemagic result and selection correction

The supplied `test_sign_in_and_text_selection.log` confirms that the app and test bundle compiled using Xcode 26.6 and the iOS 26.5 simulator SDK. All seven session tests, all nine study-store tests, and four of five selection tests passed: 20 of 21 tests in total.

The sole failure was `testInvalidRangesAndWhitespaceCannotCreateSelections`: the range `{1, 1}` inside `🌍 ciao` selected the whole emoji even though it starts halfway through its UTF-16 surrogate pair. The initializer now verifies that NSString's composed-character range exactly matches the requested range before converting it to Swift indices. This keeps the stored range and selected text consistent.

An additional test accepts complete emoji and accented characters while rejecting every partial UTF-16 subrange for a surrogate-pair emoji, decomposed accent, variation selector, skin-tone/ZWJ emoji, flag, and decomposed Japanese character. The suite now contains 22 tests. Post-fix native compilation and execution are pending the next Codemagic run; the failing test remains enabled.

## Current live-account update

Completed checks for the prepared update:

- All 24 Swift files, including the three test files, parsed with the tree-sitter Swift grammar without syntax errors. This is grammar validation, not Swift typechecking or Apple-framework compilation.
- The Codemagic YAML passed the official schema check. Its shell scripts passed Bash syntax checks.
- The Xcode project was regenerated and source/resource membership checked, including the new networking, live reader, selection, audio, and test files.
- The companion web integration suite passed all 34 tests for mobile content, study synchronization, and the shared lesson library. The six mobile integration tests also passed again after the final validation fixes.
- The native session and API code were reviewed for refresh serialization, rejected credentials, temporary network failures, stale results after sign-out, and signing back into the same account.
- The reader selection code was checked for valid UTF-16 boundaries and explicit phrase lookup. Media and speech lifecycle review identified shared audio-session ownership and was followed by an audio coordinator update.
- `git diff --check` reported no whitespace errors.

The prepared course catalog contains four course collections with 75 entries. The signed-in library also includes the published and private saved lessons authorized for that account. The matching website update passed its production build and is published as Plurifold version 84, source commit `d3fbb7fa79f6bd0bcfa66bc96f709e4981457b51`. Live checks passed for public account configuration, authenticated endpoint protection, invalid-token rejection, and the signed-out website entry. A real live-account session on the iPhone remains to be checked.

## Native test gate still to run

The source contains 22 XCTest methods: seven authentication/session tests, six word/phrase selection tests, and nine original study-store tests. The **Plurifold - TestFlight** workflow runs them before signing and uploading the IPA.

The supplied Codemagic log establishes native compilation and simulator test execution for the preceding source revision. This Linux workspace can validate Swift grammar but cannot run Xcode or the new regression test. The post-fix source still requires Codemagic verification and a device check.

The next Codemagic run must establish compilation and test results. The next iPhone check must establish real account sign-in, authorized content loading, AI responses, website synchronization, text selection handles, media playback, audio handoff, and persistence across app restarts. Large Dynamic Type sizes, VoiceOver, light/dark appearance, and iPad layout also need Apple-device verification.

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
