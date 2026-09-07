# Plurifold for iOS

A native SwiftUI app for the same Plurifold account, lessons, and saved vocabulary you use on the website. Requires iOS 17 or later on iPhone or iPad.

The live app has reached an iPhone through TestFlight. This revision opens dictionary-first details by pulling down from a highlight or its nearby control. The pull responds to distance, including very slow movement. AI explanations require an explicit button press. Saved desktop meanings, language-specific Words and Review, reactive phrase selection, and the 0.45-second playback sentence hold remain included. Run Codemagic to compile and test this revision before installing it.

## Install this update from Windows

Start with [NEXT-BUILD.md](NEXT-BUILD.md). Build the latest **main** commit from [lowqueue/plurifold-ios](https://github.com/lowqueue/plurifold-ios) using **Plurifold - TestFlight** in Codemagic. No manual file upload is needed for an update already committed to the repository.

Your existing Apple integration, certificate, provisioning profile, and bundle ID remain in use. There are no new API secrets to enter. [TESTFLIGHT.md](TESTFLIGHT.md) contains the existing signing references and optional setup instructions for a new environment.

Codemagic runs a finite build job on a cloud Mac. It regenerates the Xcode project, runs the native tests, builds and signs the app, then uploads it to App Store Connect. You can close its browser tab while it works. The installed app runs on your iPhone and connects to Plurifold; Codemagic does not host the app or need to stay running between builds.

## What this build adds

- Email and password sign-in with your existing website account. Session tokens are stored in the device Keychain, refreshed when needed, and validated when restoring a saved login.
- Live published lessons and the signed-in user's private saved lessons. The prepared course catalog contains four course collections with 75 entries, alongside the shared and account-specific library content available to that user.
- **Home** shows the available languages with flags. Choose a language to open its **Courses** and **Lessons**; there is no **All languages** option. Each course opens as a folder containing its chapters; independent lessons stay grouped by channel. Search, Words, and Review stay within the chosen language. Return to Home or use Change in Words/Review to switch languages. No vocabulary is shown until you choose one; signing out resets the choice.
- The website's **Blue Hour** light and dark colors, green course accents, gold details, and visible lesson borders. The complete transcript sits in one reading panel with continuous paragraph spacing, without passage cards, numbers, or repeated controls.
- Tap a word to select it. Hold a new word still for about **0.2 seconds**, then drag in any direction to select a phrase. A light haptic marks dragging and each new word under your finger. After selecting, pull down from the highlight or its nearby **Pull down for details** control. Progress follows the distance you pull, with no speed requirement. You can also tap the nearby control. Ordinary swipes away from the selection scroll; there is no Select mode or bottom Explain button. Tapping blank space, the selected word again, or **Clear selection** removes the active selection. Closing details also clears it.
- Pale blue marks show individual words and gold marks show lesson vocabulary and saved terms. Selected neighbouring words join across spaces into one blue highlight per visual line. The touched word briefly swells and brightens as you drag. Reduce Motion disables the pulse. Clearing restores the separate vocabulary marks without changing text or line wrapping.
- **Dictionary** shows English-language Wiktionary senses for individual words, with source-page links, contributor attribution, and CC BY-SA 4.0 licensing. Where Wiktionary supplies a verified form link, the app can also show the dictionary headword (for example, `olen → olema`). Save an individual dictionary meaning without generating AI. Attribution stays in the saved note across devices. Coverage and regional labels vary; a missing entry or unavailable service is shown explicitly.
- **Your saved definition** appears immediately when the term, language, kind, and variety match a saved account entry. Its original saved context stays separate from the current lesson. Existing saved meanings are not overwritten by a dictionary lookup or new AI answer.
- Completed AI lookups from desktop can appear as **Earlier AI explanation from your account** after you choose **Explain with AI**, when the selection, language, variety, scope, and full normalized context match. A canceled/failed highlight has no completed definition to reuse. Different passages are not treated as the same contextual explanation.
- Opening details checks only the dictionary. Dictionary meanings appear first, and **Your saved definition** remains available beneath them. **Explain with AI** requests contextual interpretation, collocations, or additional grammar, reusing a matching earlier explanation where possible. The redundant **From this lesson** panel has been removed. The authenticated AI services keep definitions and follow-up questions available during free testing. Mobile requests use the server-controlled `mobile-lite` profile: GPT-4.1 nano, shorter instructions and schema, 1,200 UTF-16 units of context, up to two form rows, and the latest two follow-up turns. Definitions have a 650-token output cap and answers 280; the website retains its existing profile and cache. Provider secrets stay on the server. Model quality and latency still need live language testing.
- **Review** uses saved words and phrases from the selected language. Reveal meaning, then choose Again to requeue a card or Got it to finish it for the current round. This is session practice; it does not yet store mastery ratings or a spaced-repetition schedule.
- Saved words and phrases, vocabulary status, and reading places share the website's account data. Changes use narrow update operations so they do not replace unrelated study records.
- The main reader shows **Watch video** or **Listen to recording**. It opens a large panel from the bottom with playback above the transcript. Press the player's Play control to begin. A recording menu appears only when multiple sources exist; YouTube retains its **Open on YouTube** fallback.
- Playback follows passages with valid source timestamps. Manually scrolling switches following off; **Follow audio** returns to the current passage. Untimed lessons remain manually scrolled, without invented timing.
- Hold a sentence in the player transcript for **0.45 seconds** to pause and open **Study sentence**. The target is captured when the hold begins, so playback cannot replace it. Select individual words or phrases, or choose **Sentence details**. **Back to player** returns to the paused player; resume using its Play control.
- One reader bar provides device-voice **Listen** and **Reader options** for saving/resuming your place and showing supplied translations. Listen reads the paragraph at the top of the visible text.

## First device check

1. Install the new TestFlight build and sign in with your Plurifold email and password.
2. In **Home**, choose a language using its flag tile. Open a course folder and verify its chapters are inside it. Return to **Lessons** and open a video lesson. Check search, including a chapter title, and return Home to switch languages. Only content in the chosen language should appear.
3. Check word boundaries and the single reading-panel border in both light and dark appearance. Tap a word, then tap blank space or the panel padding to clear it. Select the word twice to clear it again. Hold for about 0.2 seconds and drag over **in questo video**, including forward, backward, and multiline selections. Watch the selection join across spaces and pulse at the touched word. Feel for one light tick on each new word; holding still should be silent. Enable Reduce Motion and check that selection still works without the pulse. Ordinary swipes should scroll without selecting a phrase.
4. Select a word or phrase, lift your finger, then slowly pull down from the highlight. Check the nearby progress indicator, pulling back to cancel, and opening details at the threshold. Repeat using the nearby control and in the video sentence study view. Dictionary should appear first; no AI explanation should appear until **Explain with AI** is pressed, including terms previously explained on desktop. Check **Your saved definition**, save a dictionary sense, and verify its source and license in Words/Review and on desktop. Try Estonian **olen** and Georgian **გამარჯობა**. Missing forms should show a clear no-entry message. Close details and confirm selection clears.
5. Open **Watch video**, start playback, and verify the transcript follows timed passages. Scroll manually, then use **Follow audio**. Hold a sentence near a passage transition for about 0.45 seconds: the correct sentence should open, and the player should pause. Study a phrase and return to the player; its position should remain where it paused.
6. Save the phrase and find it in **Words**, **Review**, and on the website after refreshing. In Review, reveal it, choose Again, then Got it. Switch Home from Italian to Estonian and verify that neither tab shows Italian cards. Scroll into a later paragraph, use **Reader options → Save my place**, leave the lesson, then return and use **Resume reading**.
7. Check an untimed course recording, multiple-track playback, device-voice Listen, closing the player, and backgrounding the app. Closing the player stops playback; reopening creates a fresh player.
8. Close and reopen the app to check saved sign-in. In **Account**, sign out and back in. A second account should show its own private lessons and study data.

Use **Account → Refresh library and study data**, or pull to refresh the library, when checking website changes. Synchronization occurs on loading, returning to the foreground, refresh, and successful saves. Foreground refresh waits for native writes to finish. It is not a continuous live subscription.

## Current scope

The app uses a network connection for sign-in, live lessons, AI, and shared study data. It does not provide downloaded lessons or an offline write queue in this build. In-App Purchases and membership entitlements are not implemented yet; AI remains available to signed-in free testers. Signup and password reset open the existing website flow; return to the app to sign in afterward.

Specialized exercises, handwriting, and live voice practice continue through website links. Their web interfaces have not been rebuilt as native screens. Original prototype lessons and tests remain in the source as fixtures, but the signed-in app opens Home. The old prototype's device-local words, quiz scores, and progress are not automatically imported into an account.

Every word can be selected regardless of its vocabulary status. VoiceOver retains native text-selection tools with a **Study selection** action and an accessible details control. System voice availability depends on installed voices. Background playback and lock-screen controls are outside this update. Following uses the source's passage timings, which may cover more than one sentence; it does not synthesize word-level timestamps.

## Project layout

| Location | Purpose |
| --- | --- |
| `Plurifold/App` | Sign-in gate, account tabs, shared audio coordination, device speech |
| `Plurifold/Networking` | Keychain-backed session and authenticated Plurifold requests |
| `Plurifold/Models/LiveLibrary.swift` | Live content models and serialized study updates |
| `Plurifold/Models/MobileLanguageCatalog.swift` | Available Home languages, flags, and language-scoped destinations |
| `Plurifold/Models/MobileStudyScope.swift` | Shared language and tab navigation, reset per signed-in account |
| `Plurifold/Models/TermDefinitions.swift` | Saved-definition matching, dictionary results, source links, and attribution |
| `Plurifold/Models/MobileVocabularyReview.swift` | Language-filtered vocabulary and session review queue |
| `Plurifold/Models/MobileLibraryIndex.swift` | Course folders, lesson groups, and search classification |
| `Plurifold/Models/ReadingDocument.swift` | Continuous text and original paragraph offsets for reading places |
| `Plurifold/Models/LessonTranscriptTimeline.swift` | Source-timestamp matching, gaps, and backward seeking |
| `Plurifold/Views/LessonPlaybackSheet.swift` | Player panel, following transcript, and sentence hold |
| `Plurifold/Views/SentenceStudySheet.swift` | Fixed sentence selection and contextual explanations |
| `Plurifold/Views` | Sign-in, library, selectable reader, AI sheet, saved words, media |
| `Plurifold/Resources` | Privacy manifest, app icons, original test-fixture catalog |
| `PlurifoldTests` | Session, selection, paragraph mapping, course organization, and study-store XCTest coverage |
| `scripts/generate_project.py` | Deterministic Xcode project generation and file membership |
| `scripts/test_ios.sh` | Select an installed iPhone simulator and run XCTest |
| `design/AppIcon.svg` | User-supplied monochrome p-and-block-cursor icon source |
| `codemagic.yaml` | Manual simulator and TestFlight build workflows |

The production origin is `https://www.plurifold.com`. The native client requires the matching mobile API routes on that website, including `/api/mobile/dictionary` and the `lookupOnly` / `cacheContext` options on `/api/define`. The website continues using its existing AI model; GPT-4.1 nano is the mobile generation profile. The account configuration supplies only the Supabase public URL and publishable key. Authentication tokens are restricted to the verified Supabase project and approved Plurifold API requests; media and website links do not receive those headers.

## Development and verification

After adding or removing source files, regenerate the project with `python3 scripts/generate_project.py`. Codemagic does this automatically before each build. All app-icon PNGs are included, so icon regeneration tools are not required to build.

The supplied SVG is preserved unchanged in `design/AppIcon.svg`, including its blinking cursor. The app icon catalog contains static PNG exports with the cursor visible and an opaque white background. Run `python3 scripts/generate_app_icon.py` to regenerate those exports from the source.

On a Mac with Xcode and an iOS 17+ simulator installed, open `Plurifold.xcodeproj`, select the **Plurifold** scheme, and run the app. Run tests with Xcode's **Product → Test**, or use `bash scripts/test_ios.sh` from the project root.

[VALIDATION.md](VALIDATION.md) distinguishes the original successful builds from the checks performed on this update. Local Swift grammar parsing does not replace compilation, XCTest execution, or device verification.

## Dictionary source

Dictionary excerpts come from [Wiktionary contributors](https://en.wiktionary.org/wiki/Wiktionary:About), through the [Wikimedia REST API](https://www.mediawiki.org/wiki/Wikimedia_REST_API), under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Source HTML is converted to plain text, styles and scripts are removed, and the number of senses is limited. The app labels those changes and preserves contributor, entry, source, and license information when saving a dictionary meaning. This is a community-edited source; a dictionary match does not certify the separate AI explanation.

The server caches public dictionary results, caps response sizes and concurrent upstream requests, and honors provider cooldowns. It sends only a word to Wiktionary, with no account token or lesson context. Its REST definition endpoint is experimental, so unavailable results have a retry path and AI remains available separately. A locally indexed dictionary dataset and offline lookup are future work.
