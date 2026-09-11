# Build the Garden iOS update

Use the existing **lowqueue/plurifold-ios** repository, **main** branch, Codemagic app, and internal TestFlight group. The signing configuration and App Store distribution settings are unchanged.

## Release

1. Open **plurifold-ios** in Codemagic and select **main**.
2. Choose **Start new build → Plurifold - TestFlight**.
3. Check that the build overview names the latest Garden iOS commit.
4. After Apple finishes processing, assign the build to the existing internal group if needed, then open **TestFlight → Plurifold → Update**.

The workflow regenerates the project, runs XCTest on an iPhone simulator, signs the Release IPA, and uploads it for internal testing. The GitHub **iOS validation** workflow also builds and tests the app on a Mac without signing.

## What changed

- Garden is the default layout. Account retains Original, Verdant, Vermilion, Blue Hour, and System/Light/Dark lighting. Colorways affect the full screen palette and scenery.
- Native Home provides a language dashboard, a real saved reading place or available starting lesson, and quick links. Courses and Library have separate destinations and search state.
- Lesson cards keep a compact thumbnail, title, and Open/Continue action. More reveals the details. Course chapters and existing reader/media features remain available.
- Progress uses the same account word-form states and known-only coverage as the website. Trophies read account-wide achievement evidence. There are no invented weekly gains, fluency scores, or maxims.
- Welcome has interactive physical language tiles, search and selection, native sign-in and signup, and accessible static alternatives. Confirmation-email signup leaves the app signed out until the user confirms and signs in. Password recovery opens the existing secure website flow.
- Speaking opens the private trial inside the app. The isolated hosted WebRTC room uses native authenticated requests for access, starting/ending calls, and saving phrases. Account tokens never enter the page. Live microphone/audio behavior still needs physical-device validation.
- The drawer has a wider edge target, better slow-drag recognition, scroll/control conflict rejection, interruption handling, and subtle completion feedback.

## Device acceptance checks

- Try Garden and Original with all three colorways in light/dark mode. Rotate the device and increase text size. Home, courses, library, Saved, Review, Progress, Account and welcome should remain readable.
- Drag, flick and select the welcome tiles. Search in English and native names. Enable Reduce Motion, Reduce Transparency and VoiceOver. Verify signup confirmation, sign-in, sign-out, and account separation.
- Select a language, open Courses and Library, search each, expand More, open a lesson and a course chapter. Previous/Next must also work when entering a chapter from Home. Existing transcript selection, dictionary, AI, playback and saved reading places must remain functional.
- Compare Progress with the same language on the website after refreshing. Check Known/Learning/Familiar and saved phrase totals, coverage filters, and account-wide trophies.
- As the owner, open Speaking, grant microphone access, complete a short conversation, save a feedback phrase and find it in Saved after closing the room. Verify rejection of microphone permission, network interruption/retry, backgrounding, dismissal during connection, and switching from lesson audio. Another account must remain outside the private speaking trial.
- Pull slowly from the left edge, stop, reverse, release and catch the settling drawer. Try vertical scrolling near the edge and use sliders/text selection. In a nested reader the edge goes back once; at Home/Library it opens navigation. Modal sheets must prevent hidden navigation.

## Current limits

Course activity drafts/local checks retain their previous behavior; this update does not invent synced course completion. Advanced handwriting and website-specific exercise tools remain on the website. Review keeps the existing native queue behavior. Downloaded lessons, an offline write queue, in-app purchases, background audio and lock-screen controls remain outside this release.
