# Plurifold for iOS

A native SwiftUI app for the same Plurifold account, lessons, and saved vocabulary you use on the website. Requires iOS 17 or later on iPhone or iPad.

The earlier prototype has already reached an iPhone through TestFlight. This source update adds account access and live content. Its new native code still needs the Codemagic build, XCTest run, and device checks described below.

## Install this update from Windows

Start with [NEXT-BUILD.md](NEXT-BUILD.md). **Plurifold-iOS-Live-Update.zip contains the full source project**, including its folders. Upload the extracted contents to the existing GitHub repository and run **Plurifold - TestFlight** in Codemagic.

Your existing Apple integration, certificate, provisioning profile, and bundle ID remain in use. There are no new API secrets to enter. [TESTFLIGHT.md](TESTFLIGHT.md) contains the existing signing references and optional setup instructions for a new environment.

Codemagic runs a finite build job on a cloud Mac. It regenerates the Xcode project, runs the native tests, builds and signs the app, then uploads it to App Store Connect. You can close its browser tab while it works. The installed app runs on your iPhone and connects to Plurifold; Codemagic does not host the app or need to stay running between builds.

## What this build adds

- Email and password sign-in with your existing website account. Session tokens are stored in the device Keychain, refreshed when needed, and validated when restoring a saved login.
- Live published lessons and the signed-in user's private saved lessons. The prepared course catalog contains four course collections with 75 entries, alongside the shared and account-specific library content available to that user.
- Search across lesson titles, courses, languages, channels, and dialects, with a language filter.
- A tap on any word opens its study sheet. Press and hold to select a collocation or longer phrase, adjust the handles, then choose **Explain selection**.
- The website's existing AI definition and question services supply contextual meaning, grammar, usage, and follow-up answers. The app calls Plurifold's authenticated API; provider secrets stay on the server.
- Saved words and phrases, vocabulary status, and reading places share the website's account data. Changes use narrow update operations so they do not replace unrelated study records.
- Recorded audio and video use native playback controls. YouTube lessons use an embedded player with an **Open on YouTube** fallback. Available resource links also remain accessible.
- Device speech can pronounce selected text or read passages using an available voice for the lesson's language.

## First device check

1. Install the new TestFlight build and sign in with your Plurifold email and password.
2. In **Learn**, open a real lesson from your library. Check that the language filter and search show the content you expect.
3. Tap a word that was not pre-underlined. Read the explanation, ask a short follow-up question, and save it.
4. Press and hold a passage, extend the selection to a phrase, then choose **Explain selection**. Save the phrase and find it in **Words**.
5. Open the website with the same account and confirm the saved item appears there after refreshing. Save a reading place in the app, leave the lesson, and use its resume button when you return.
6. Play a recording or YouTube lesson. Check pronunciation separately, then leave the reader and confirm playback stops.
7. Close and reopen the app to check saved sign-in. In **Account**, sign out and back in. A second account should show its own private lessons and study data.

Use **Account → Refresh library and study data**, or pull to refresh the library, when checking website changes. Synchronization occurs on loading, refresh, and successful saves; it is not a continuous live subscription.

## Current scope

The app uses a network connection for sign-in, live lessons, AI, and shared study data. It does not provide downloaded lessons or an offline write queue in this build. Signup and password reset open the existing website flow; return to the app to sign in afterward.

Specialized exercises, handwriting, and live voice practice continue through website links. Their web interfaces have not been rebuilt as native screens. Original prototype lessons and tests remain in the source as fixtures, but the signed-in app opens the live library. The old prototype's device-local words, quiz scores, and progress are not automatically imported into an account.

Saved highlights identify your vocabulary. Native text selection also works on text without any highlight. System voice availability depends on the voices installed on the device. Background playback and lock-screen controls are outside this update.

## Project layout

| Location | Purpose |
| --- | --- |
| `Plurifold/App` | Sign-in gate, account tabs, shared audio coordination, device speech |
| `Plurifold/Networking` | Keychain-backed session and authenticated Plurifold requests |
| `Plurifold/Models/LiveLibrary.swift` | Live content models and serialized study updates |
| `Plurifold/Views` | Sign-in, library, selectable reader, AI sheet, saved words, media |
| `Plurifold/Resources` | Privacy manifest, app icons, original test-fixture catalog |
| `PlurifoldTests` | Session, selection, and original study-store XCTest coverage |
| `scripts/generate_project.py` | Deterministic Xcode project generation and file membership |
| `scripts/test_ios.sh` | Select an installed iPhone simulator and run XCTest |
| `design/AppIcon.svg` | Source of the green letter-and-cursor app icon |
| `codemagic.yaml` | Manual simulator and TestFlight build workflows |

The production origin is `https://www.plurifold.com`. The native client requires the matching mobile API routes on that website. The account configuration supplies only the Supabase public URL and publishable key. Authentication tokens are restricted to the verified Supabase project and approved Plurifold API requests; media and website links do not receive those headers.

## Development and verification

After adding or removing source files, regenerate the project with `python3 scripts/generate_project.py`. Codemagic does this automatically before each build. All app-icon PNGs are included, so icon regeneration tools are not required to build.

On a Mac with Xcode and an iOS 17+ simulator installed, open `Plurifold.xcodeproj`, select the **Plurifold** scheme, and run the app. Run tests with Xcode's **Product → Test**, or use `bash scripts/test_ios.sh` from the project root.

[VALIDATION.md](VALIDATION.md) distinguishes the original successful builds from the checks performed on this update. Local Swift grammar parsing does not replace compilation, XCTest execution, or device verification.
