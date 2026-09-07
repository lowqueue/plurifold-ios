# Plurifold for iOS

A native SwiftUI app for the same Plurifold account, lessons, and saved vocabulary you use on the website. Requires iOS 17 or later on iPhone or iPad.

The live app has reached an iPhone through TestFlight. This update addresses the reader and library feedback from that build: direct media playback, continuous paragraphs, immediate touch selection, and course folders. The supplied app icon and Unicode selection correction remain included. Run Codemagic to compile and test this revision before installing it.

## Install this update from Windows

Start with [NEXT-BUILD.md](NEXT-BUILD.md). **Plurifold-iOS-Live-Update.zip contains the full source project**, including its folders. Upload the extracted contents to the existing GitHub repository and run **Plurifold - TestFlight** in Codemagic.

Your existing Apple integration, certificate, provisioning profile, and bundle ID remain in use. There are no new API secrets to enter. [TESTFLIGHT.md](TESTFLIGHT.md) contains the existing signing references and optional setup instructions for a new environment.

Codemagic runs a finite build job on a cloud Mac. It regenerates the Xcode project, runs the native tests, builds and signs the app, then uploads it to App Store Connect. You can close its browser tab while it works. The installed app runs on your iPhone and connects to Plurifold; Codemagic does not host the app or need to stay running between builds.

## What this build adds

- Email and password sign-in with your existing website account. Session tokens are stored in the device Keychain, refreshed when needed, and validated when restoring a saved login.
- Live published lessons and the signed-in user's private saved lessons. The prepared course catalog contains four course collections with 75 entries, alongside the shared and account-specific library content available to that user.
- Separate **Courses** and **Lessons** sections. Each course opens as a folder containing its chapters; independent lessons stay grouped by channel. Search and language filtering keep that hierarchy intact.
- Continuous source text with paragraph spacing, without passage cards, numbers, or repeated controls.
- Touch a word for immediate highlighting and lift your finger to open its study sheet. Drag horizontally across words to select a phrase; once the drag starts, it can continue across lines and paragraphs. Turn on **Select** in the reader bar to start selection drags in any direction. With Select off, vertical swipes scroll normally.
- The website's existing AI definition and question services supply contextual meaning, grammar, usage, and follow-up answers. The app calls Plurifold's authenticated API; provider secrets stay on the server.
- Saved words and phrases, vocabulary status, and reading places share the website's account data. Changes use narrow update operations so they do not replace unrelated study records.
- The first recording's player appears directly, with no autoplay. A recording menu appears only for lessons with multiple sources. Audio and video use native playback controls; YouTube uses an embedded player with an **Open on YouTube** fallback.
- One reader bar provides **Listen**, **Select**, and a **Reader options** menu for saving/resuming your place and showing supplied translations. Listen reads the paragraph at the top of the visible text using the device voice.

## First device check

1. Install the new TestFlight build and sign in with your Plurifold email and password.
2. In **Learn**, open a course folder and verify its chapters are inside it. Return to **Lessons** and open a video lesson. Check language filtering and search, including searching for a chapter title.
3. Tap a word that was not highlighted. Check immediate highlight feedback, then read the explanation, ask a follow-up question, and save it. AI response time still depends on the network and server.
4. Touch and drag over **in questo video**, then release. Check that the complete phrase is explained without a long press or native selection handles. Turn on **Select** and try a drag across lines and paragraphs, including backward selection. Turn it off and check that vertical swipes scroll without opening a definition.
5. Save the phrase and find it in **Words** and on the website after refreshing. Scroll into a later paragraph, use **Reader options → Save my place**, leave the lesson, then return and use **Resume reading**.
6. Check that a single-source lesson shows its player immediately. Start playback, open a definition, and verify the player pauses and keeps its position. Check **Listen**, switching between device speech and media, and leaving the reader. Test the recording menu in a lesson with multiple tracks.
7. Close and reopen the app to check saved sign-in. In **Account**, sign out and back in. A second account should show its own private lessons and study data.

Use **Account → Refresh library and study data**, or pull to refresh the library, when checking website changes. Synchronization occurs on loading, refresh, and successful saves; it is not a continuous live subscription.

## Current scope

The app uses a network connection for sign-in, live lessons, AI, and shared study data. It does not provide downloaded lessons or an offline write queue in this build. Signup and password reset open the existing website flow; return to the app to sign in afterward.

Specialized exercises, handwriting, and live voice practice continue through website links. Their web interfaces have not been rebuilt as native screens. Original prototype lessons and tests remain in the source as fixtures, but the signed-in app opens the live library. The old prototype's device-local words, quiz scores, and progress are not automatically imported into an account.

Saved highlights identify your vocabulary; every word can be selected regardless of its saved status. VoiceOver retains native text-selection tools and an **Explain selection** action. System voice availability depends on the voices installed on the device. Background playback and lock-screen controls are outside this update.

## Project layout

| Location | Purpose |
| --- | --- |
| `Plurifold/App` | Sign-in gate, account tabs, shared audio coordination, device speech |
| `Plurifold/Networking` | Keychain-backed session and authenticated Plurifold requests |
| `Plurifold/Models/LiveLibrary.swift` | Live content models and serialized study updates |
| `Plurifold/Models/MobileLibraryIndex.swift` | Course folders, lesson groups, and search classification |
| `Plurifold/Models/ReadingDocument.swift` | Continuous text and original paragraph offsets for reading places |
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
