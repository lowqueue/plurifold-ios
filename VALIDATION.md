# Validation record

Updated on 2026-09-07. The development workspace runs Linux and has no Xcode or native iOS simulator. Historical build results and current source checks are separated below.

## Current review, reactive selection, and mobile AI update

- Playback sentence hold is 0.45 seconds. Its frozen sentence target and pause behavior remain.
- Selected words join across spaces into a rounded fill per visual line. A 0.26-second local bubble pulse responds to touched words without modifying text or line wrapping. Reduce Motion and VoiceOver suppress the pulse. Clear, cancellation, text replacement, and view removal cancel it.
- Home supplies one language to both Words and Review. Choice resets per account. Saved-only languages remain reachable after their lessons disappear. Review is an in-memory round with Reveal / Again / Got it; it does not write mastery or SRS changes.
- Native AI requests carry `profile: mobile-lite`, send up to 1,200 UTF-16 units of context and two recent follow-up turns. The server uses GPT-4.1 nano with compact prompts, 650/280-token definition/answer budgets and a separate mobile cache. AI remains available during free testing; payments are not part of this revision.

Completed checks:

- All 42 Swift files parsed without grammar errors: 33 app sources and nine test files. This is not Swift typechecking or native compilation.
- The regenerated Xcode project validates 116 object references and includes all new source/test files.
- There are 68 XCTest methods. Twenty added cases cover language scope/navigation/account reset, review filtering/requeue/refresh/removal, joined highlight geometry, endpoint repainting, and reaction cancellation. These await Codemagic execution.
- Eleven focused server tests pass: five mobile AI route/profile checks and six existing mobile content/study integration checks. Tests mock the provider and verify authentication, fixed model selection, compact request budgets, cache isolation, website profile preservation, and rejection of incomplete output. They do not measure live model quality or latency.
- The website production build passes with the mobile server profile. A separate full-repository TypeScript check reports existing Cloudflare runtime-type and unrelated reader/worker errors; it reports no diagnostics in the changed AI files. Native code keeps all API credentials on the server. The supplied icon, signing configuration, and explicit CGFloat sizing correction remain intact.

Use Codemagic for compilation and XCTest, then check the 0.45-second hold, bubble appearance, joined multiline selections, haptics, Reduce Motion, language switching, review flow, and actual AI answers on the iPhone. Review progress lasts for the current view session, not across launches.

## Previous Home, selection, and color update

- The phrase hold is now 0.20 seconds. A reused, prewarmed selection feedback generator ticks when dragging begins and when the endpoint enters a different word, including shortening and reversing. Repeated samples on one word, blank space, and cancelled gestures do not emit ticks. Selection changes still do not request AI responses.
- Playback sentence study opens after a one-second hold. The sentence is captured on touch-down and following stays frozen while holding/studying it; the existing pause and return behavior remains.
- Signed-in Home lists available languages with flags. Each destination receives only its selected language's courses and lessons. Empty, unknown, or removed language choices cannot become an unfiltered library. Courses keep their chapter folders. Words and Account retain their existing roles.
- The website's current `app/colorways.css` supplied the Blue Hour light/dark palette, with green course accents and gold details. Language, course, and lesson entries have visible borders. One frame surrounds the continuous transcript; the reader does not add passage bubbles. The website source was inspected read-only and was not changed.

Completed source checks:

- All 37 Swift files parsed without grammar errors: 30 app sources and seven test files. This is not native compilation or Swift typechecking.
- The regenerated Xcode project validated 106 object references and includes the Home view, language catalog, and its tests. All Swift source paths were verified and the shared scheme parsed as XML.
- The suite now contains 48 XCTest methods. Two new word-feedback tests cover boundary changes, shrinking, reversal, stationary samples, and gesture lifecycle. Three new language-catalog tests cover deduplication/counts, unavailable content, and invalid or removed language isolation. XCTest has not been run locally.
- Independent source review checked the one-second hold and frozen target, haptic timing, and the reading-panel hit targets. Its padding is included in the existing coordinate conversions for bookmarks and autoscroll; its stroke ignores touch input and clearing is attached to the background.
- The supplied icon and explicit `CGFloat.greatestFiniteMagnitude` correction remain intact. No signing, backend, or Codemagic workflow change was needed. Whitespace checks passed.

Codemagic must compile and run the native tests before installing this revision. Check the actual 0.2-second hold, word-crossing haptics, ordinary scrolling, one-second sentence study near a cue transition, light/dark borders, tapping panel padding to clear, and Home language navigation on the iPhone. Haptic feedback depends on device support and settings; its physical feel cannot be verified in this Linux workspace.

## Earlier Codemagic compile correction

The supplied `test_sign_in_and_text_selection(1).log` reports one blocking compiler error at `SelectablePassage.swift:646`: `CGSize(width: 0, height: .greatestFiniteMagnitude)` is ambiguous between CGFloat and Double. The three failed build commands listed at the end are consequences of that same error. XCTest was cancelled before execution; this log contains no runtime crash or test result.

Both text-sizing expressions now specify `CGFloat.greatestFiniteMagnitude`. Only `Plurifold/Views/SelectablePassage.swift` changes executable source. Its Swift grammar and the patch's whitespace were checked, but the corrected source must still compile and run the 43 tests in Codemagic. The unrelated traitCollectionDidChange deprecation warning remains non-blocking. No tests or build gates were removed.

## Earlier player and selection revision

The supplied LingQ recording shows a transcript-first reader, a player panel sliding up from the bottom, following text, and a separate sentence study view. The supplied Plurifold recording shows a persistent selection after dismissing its explanation and little visual distinction between active and vocabulary highlights. There are no touch indicators, so exact input latency or hold duration cannot be measured from these recordings.

This revision:

- Moves media into a large playback sheet opened by Watch video or Listen to recording. Nothing plays automatically when opening a lesson.
- Reports absolute native/YouTube playback time to a cached passage timeline. Only passage transitions update transcript state. Explicit gaps remain gaps; missing final end times do not produce endless following. Untimed text receives no fabricated timing.
- Freezes a sentence value on touch-down, suspends transcript following while it is held, and pauses playback before opening the sentence study sheet after a two-second hold. Selections map back to the original document's UTF-16 offsets. Returning to the player keeps it paused.
- Removes the Select toggle. Quick taps select words; a stationary 0.35-second hold arms any-direction phrase dragging. Early swipes release scrolling. Explain is a separate action, so gesture updates never trigger AI requests.
- Draws blue word marks, gold vocabulary marks, and stronger active marks with cached TextKit geometry. Dragging changes display regions only, without editing attributed text or rebuilding token ranges. This removes an identified source of rendering work, but is not a measured device-speed improvement.
- Clears active selection on empty-space taps, repeated word taps, Clear, and explanation dismissal. Blank-space targets fill short reader/study viewports. Vocabulary marks persist separately.

Completed checks:

- All 34 Swift files parsed without grammar errors: 28 app sources and six test files. No native typechecking, simulator rendering, or device benchmark was possible locally.
- The regenerated Xcode project validated 100 object references, file paths, and source/resource membership. All new models, views, and tests are included.
- Embedded YouTube JavaScript passed a local lifecycle check for one clock timer, paused seeks, unchanged timestamps, invalid values, suspend/resume, and disposal. Existing URL/origin validation, no-autoplay behavior, and bridge cleanup remain.
- Source review checked memberwise argument order, nested sheet lifecycle, immutable sentence targets, scrolling/following, source-range bounds, and full-viewport clearing. The negative-range and short-sheet clearing issues found during review were corrected.
- The existing Codemagic workflow remains the required native test gate before signing/uploading. `git diff --check` passed.

There are **43 XCTest methods**: seven session, fifteen selection/geometry, six timing, two sentence-mapping, four course-organization, and nine study-store tests. New coverage exercises hold-versus-scroll decisions, tap-to-clear, incremental display ranges, geometry hit testing, timing gaps/duplicates/backward seeking, and sentence source mapping. These tests have been added but have not been executed in this Linux workspace.

That revision still required native compilation, XCTest, and device checks for gestures, clearing, long-document scrolling, following, sentence study across cue transitions, and VoiceOver/Dynamic Type. The current hold durations and device checks are listed at the top of this record. The YouTube API must load for clock callbacks; following is limited to the timing granularity supplied by each lesson. The desktop/mobile website is unchanged.

## Earlier reader and course organization update

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

The **Plurifold - TestFlight** workflow runs all 48 current tests before signing and uploading the IPA.

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

Follow [NEXT-BUILD.md](NEXT-BUILD.md) to build the latest repository commit using a new **Plurifold - TestFlight** build. Keep the new build's commit, test results, publishing result, and device observations with this record when they become available.
