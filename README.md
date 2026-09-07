# Plurifold for iOS

A first native SwiftUI prototype, now using version 1.0 for the App Store Connect record. Built around Plurifold's Verdant palette, monospaced interface details, and a quiet reading surface.

**Status:** the original simulator build succeeded in Codemagic on September 7, 2026, at commit `a9e0550`. That build compiled and packaged the app; it did not launch the simulator or run XCTest. The icon and TestFlight workflow added afterward still need their first signed build and device check.

## Windows and iPhone setup

Follow [TESTFLIGHT.md](TESTFLIGHT.md) to configure the distribution certificate and profile in Codemagic, upload the project update to GitHub, and install the first TestFlight build on your iPhone. The workflow uses the existing `plurifold-apple` integration. Signing files remain in Codemagic.

There are two manual workflows in `codemagic.yaml`: **Plurifold - first simulator build** and **Plurifold - TestFlight**. The second archives a Release build for iPhone/iPad and uploads it to App Store Connect for internal testing. Build numbers come from Codemagic's project build counter plus one. If builds are later uploaded from another system, coordinate their build numbers before uploading again.

## Open it on a Mac

1. Unzip the folder and open **Plurifold.xcodeproj** in **Xcode 16 or later**.
2. Select the **Plurifold** scheme and an **iPhone simulator** running iOS 17 or later. If Xcode offers to download the iOS simulator runtime, install it.
3. Press **⌘R** or the Run triangle.

The existing project is ready to open. You do not need to run a project generator, install JavaScript packages, enter API keys, or sign into Plurifold. A paid Apple Developer membership is not needed for the simulator.

For a physical iPhone, connect it to the Mac, select it as the run destination, and choose your Apple development team under the Plurifold target's **Signing & Capabilities**. Xcode may ask for Developer Mode on the phone. `com.plurifold.ios.prototype` is a prototype bundle identifier; change it if Xcode requires a unique identifier for your team. No team or signing credentials are included.

## Try this path

1. In **Learn**, open **Un caffè a Bologna**.
2. Tap an underlined expression, then **Save expression**. Its definition opens in a draggable native sheet.
3. Use **English translation**, listen to a sentence, and mark it as read to remember your position.
4. Choose **Check understanding** and answer the three questions. Finishing saves lesson completion and your best score.
5. Open **Words** to find saved expressions and hear their pronunciation. Open **Progress** to see your results.
6. Quit and reopen the app to check that saved words and progress remain.
7. Try **Una mattina a Bologna**, the original, more demanding Plurifold story.

## Included

- One Italian collection containing two complete lessons, twelve passages, twenty-four vocabulary entries, and six comprehension questions.
- SwiftUI navigation, native sheets, searchable saved vocabulary, and swipe-to-remove actions.
- On-device speech synthesis with an available Italian system voice. This is synthesized speech, not a recording from the website. A device may need to download an Italian voice before listening works.
- Device-local saved expressions, reading position, completion, and best quiz scores.
- Adaptive light/dark green colors, Dynamic Type fonts, VoiceOver labels, and a cursor that respects Reduce Motion.
- iPhone and iPad targets. The layout uses a readable maximum width on larger screens.

Native appearance, large text, accessibility behavior, sound, and navigation still need simulator/device verification.

## Prototype boundaries

The app does not connect to your website account or cloud progress. It has no backend credentials and makes no application network requests. Lessons are bundled with the app. Speech availability depends on installed system voices.

Audio stops when the app becomes inactive, you leave its screen, an audio interruption starts, or headphones disconnect. Background playback and lock-screen controls are future work.

This slice does not yet include imported lessons/media, AI definitions, speaking practice, handwriting, full courses, or website synchronization. It includes an app icon and an internal TestFlight workflow; signing resources and a successful Apple upload are still required. The workflow does not submit a public App Store release.

## Content provenance

**Una mattina a Bologna** keeps the `demo-bologna` ID and original six Italian sentences from the website's `app/reader-client.tsx` (`demoSentences` and `demoLesson`). Its twelve selected glossary meanings derive from `demoGlossary`. The website classifies the original at ILR 1 in `lib/ilr.ts`.

**Un caffè a Bologna** is a newly written beginner adaptation with its own `original-caffe-bologna` ID. It is not an existing published course. English sentence translations, comprehension questions, and most explanatory notes were authored for this prototype. The original `pioveva` grammar note and `portici` pronunciation were reused from Plurifold. No third-party textbook pages, video transcripts, or recorded audio are bundled.

The Verdant colors follow the current website's `lib/colorways.ts`: `#D5E2CA`, `#294435`, and `#F5F8EF`. The original website checkout was read for reference and was not modified by this task.

## Project layout

| Location | Purpose |
| --- | --- |
| `Plurifold/App` | Entry point, shared state, and speech playback |
| `Plurifold/Models` | Catalog decoding/validation and local study storage |
| `Plurifold/Views` | Library, reader, word sheets, practice, and progress |
| `Plurifold/Resources/catalog.json` | Bundled lesson content |
| `Plurifold/Resources/PrivacyInfo.xcprivacy` | App-specific UserDefaults declaration; no tracking |
| `Plurifold/Resources/Assets.xcassets` | Checked-in iPhone/iPad/App Store icon sizes |
| `PlurifoldTests` | XCTest coverage for storage and content validation |
| `scripts/generate_project.py` | Optional deterministic project regeneration after adding/removing files |
| `design/AppIcon.svg` | Vector source of the green p-and-cursor icon |
| `scripts/generate_app_icon.py` | Optional icon regeneration with CairoSVG; not needed for builds |
| `TESTFLIGHT.md` | Windows setup, signing file names, upload, and installation |

Local progress uses the `plurifold.ios.prototype.study.v1` UserDefaults key. Resetting lesson progress preserves saved expressions. Storage is intentionally separate from website data; deleting the app can remove its local study record.

After adding or removing Swift files or resources, run `python3 scripts/generate_project.py` or update target membership in Xcode. Changing an existing Swift file or `catalog.json` does not require regeneration. Keep content IDs stable so saved words and progress remain attached to the same content. Each lesson must include at least one question.

## Verification on a Mac

Build an unsigned simulator app:

```sh
xcodebuild -project Plurifold.xcodeproj -scheme Plurifold -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build build CODE_SIGNING_ALLOWED=NO
```

Run tests with **⌘U** in Xcode. For the command line, list available simulators, then replace `SIMULATOR_UDID` with the ID of an installed iOS 17+ simulator:

```sh
xcrun simctl list devices available
xcodebuild -project Plurifold.xcodeproj -scheme Plurifold -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' -derivedDataPath build test CODE_SIGNING_ALLOWED=NO
```

Before expanding the app, check sheet links, saved-word updates, quiz navigation, persistence after relaunch, speech replacement/interruption, VoiceOver, and the largest Dynamic Type sizes on an iPhone and iPad. The results of checks possible in this workspace are recorded in `VALIDATION.md`.

Framework references: [SwiftUI](https://developer.apple.com/swiftui/), [NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack), [speech synthesis](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer), [audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions).
