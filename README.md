# Plurifold for iOS

A native SwiftUI app for the same Plurifold account, lessons, and saved vocabulary you use on the website. Requires iOS 17 or later on iPhone or iPad.

The live app has reached an iPhone through TestFlight. This revision responds to the LingQ comparison and the latest Plurifold recording: a transcript-first reader, a separate player panel, fixed sentence study, clearer word boundaries, and simpler selection without a mode toggle. Course folders, the supplied icon, and the Unicode correction remain included. Run Codemagic to compile and test this revision before installing it.

## Install this update from Windows

Start with [NEXT-BUILD.md](NEXT-BUILD.md). **Plurifold-iOS-Live-Update.zip contains the full source project**, including its folders. Upload the extracted contents to the existing GitHub repository and run **Plurifold - TestFlight** in Codemagic.

Your existing Apple integration, certificate, provisioning profile, and bundle ID remain in use. There are no new API secrets to enter. [TESTFLIGHT.md](TESTFLIGHT.md) contains the existing signing references and optional setup instructions for a new environment.

Codemagic runs a finite build job on a cloud Mac. It regenerates the Xcode project, runs the native tests, builds and signs the app, then uploads it to App Store Connect. You can close its browser tab while it works. The installed app runs on your iPhone and connects to Plurifold; Codemagic does not host the app or need to stay running between builds.

## What this build adds

- Email and password sign-in with your existing website account. Session tokens are stored in the device Keychain, refreshed when needed, and validated when restoring a saved login.
- Live published lessons and the signed-in user's private saved lessons. The prepared course catalog contains four course collections with 75 entries, alongside the shared and account-specific library content available to that user.
- Separate **Courses** and **Lessons** sections. Each course opens as a folder containing its chapters; independent lessons stay grouped by channel. Search and language filtering keep that hierarchy intact.
- Continuous source text with paragraph spacing, without passage cards, numbers, or repeated controls.
- Tap a word to select it. Hold still for about **0.35 seconds**, then drag in any direction to select a phrase. Ordinary swipes scroll; there is no Select mode. Tap **Explain** to request a definition. Tapping blank space, the selected word again, or **Clear selection** removes the active selection. Closing a definition also clears it.
- Pale blue marks show individual words, gold marks show lesson vocabulary and saved terms, and stronger blue marks show the current selection. Clearing the selection preserves vocabulary marks. Text characters and paragraph spacing remain unchanged.
- The website's existing AI definition and question services supply contextual meaning, grammar, usage, and follow-up answers. The app calls Plurifold's authenticated API; provider secrets stay on the server.
- Saved words and phrases, vocabulary status, and reading places share the website's account data. Changes use narrow update operations so they do not replace unrelated study records.
- The main reader shows **Watch video** or **Listen to recording**. It opens a large panel from the bottom with playback above the transcript. Press the player's Play control to begin. A recording menu appears only when multiple sources exist; YouTube retains its **Open on YouTube** fallback.
- Playback follows passages with valid source timestamps. Manually scrolling switches following off; **Follow audio** returns to the current passage. Untimed lessons remain manually scrolled, without invented timing.
- Hold a sentence in the player transcript for **two seconds** to pause and open **Study sentence**. The target is captured when the hold begins, so playback cannot replace it. Select individual words or phrases, or choose **Explain sentence**. **Back to player** returns to the paused player; resume using its Play control.
- One reader bar provides device-voice **Listen** and **Reader options** for saving/resuming your place and showing supplied translations. Listen reads the paragraph at the top of the visible text.

## First device check

1. Install the new TestFlight build and sign in with your Plurifold email and password.
2. In **Learn**, open a course folder and verify its chapters are inside it. Return to **Lessons** and open a video lesson. Check language filtering and search, including searching for a chapter title.
3. Check that word boundaries are visible. Tap a word, then tap blank space to clear it. Select the word twice to clear it again. Hold briefly and drag over **in questo video**, including forward, backward, and multiline selections. Ordinary swipes should scroll without selecting a phrase.
4. Select a word or phrase, press **Explain**, ask a follow-up question, and save it. Close the explanation and confirm the active selection is cleared. Check blank-space clearing below a short sentence as well. AI response time still depends on the network and server.
5. Open **Watch video**, start playback, and verify the transcript follows timed passages. Scroll manually, then use **Follow audio**. Hold a sentence near a passage transition for two seconds: the correct sentence should open, and the player should pause. Study a phrase and return to the player; its position should remain where it paused.
6. Save the phrase and find it in **Words** and on the website after refreshing. Scroll into a later paragraph, use **Reader options → Save my place**, leave the lesson, then return and use **Resume reading**.
7. Check an untimed course recording, multiple-track playback, device-voice Listen, closing the player, and backgrounding the app. Closing the player stops playback; reopening creates a fresh player.
8. Close and reopen the app to check saved sign-in. In **Account**, sign out and back in. A second account should show its own private lessons and study data.

Use **Account → Refresh library and study data**, or pull to refresh the library, when checking website changes. Synchronization occurs on loading, refresh, and successful saves; it is not a continuous live subscription.

## Current scope

The app uses a network connection for sign-in, live lessons, AI, and shared study data. It does not provide downloaded lessons or an offline write queue in this build. Signup and password reset open the existing website flow; return to the app to sign in afterward.

Specialized exercises, handwriting, and live voice practice continue through website links. Their web interfaces have not been rebuilt as native screens. Original prototype lessons and tests remain in the source as fixtures, but the signed-in app opens the live library. The old prototype's device-local words, quiz scores, and progress are not automatically imported into an account.

Every word can be selected regardless of its vocabulary status. VoiceOver retains native text-selection tools with a **Study selection** action, followed by the reader's **Explain** button. System voice availability depends on installed voices. Background playback and lock-screen controls are outside this update. Following uses the source's passage timings, which may cover more than one sentence; it does not synthesize word-level timestamps.

## Project layout

| Location | Purpose |
| --- | --- |
| `Plurifold/App` | Sign-in gate, account tabs, shared audio coordination, device speech |
| `Plurifold/Networking` | Keychain-backed session and authenticated Plurifold requests |
| `Plurifold/Models/LiveLibrary.swift` | Live content models and serialized study updates |
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

The production origin is `https://www.plurifold.com`. The native client requires the matching mobile API routes on that website. The account configuration supplies only the Supabase public URL and publishable key. Authentication tokens are restricted to the verified Supabase project and approved Plurifold API requests; media and website links do not receive those headers.

## Development and verification

After adding or removing source files, regenerate the project with `python3 scripts/generate_project.py`. Codemagic does this automatically before each build. All app-icon PNGs are included, so icon regeneration tools are not required to build.

The supplied SVG is preserved unchanged in `design/AppIcon.svg`, including its blinking cursor. The app icon catalog contains static PNG exports with the cursor visible and an opaque white background. Run `python3 scripts/generate_app_icon.py` to regenerate those exports from the source.

On a Mac with Xcode and an iOS 17+ simulator installed, open `Plurifold.xcodeproj`, select the **Plurifold** scheme, and run the app. Run tests with Xcode's **Product → Test**, or use `bash scripts/test_ios.sh` from the project root.

[VALIDATION.md](VALIDATION.md) distinguishes the original successful builds from the checks performed on this update. Local Swift grammar parsing does not replace compilation, XCTest execution, or device verification.
