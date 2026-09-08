# Build the latest Plurifold update

Use the existing GitHub repository, Codemagic application, and TestFlight group. Your signing configuration remains in place.

## Start the build

1. Open [lowqueue/plurifold-ios](https://github.com/lowqueue/plurifold-ios) and confirm branch **main** shows **Make the sidebar follow touch with rounded spring motion**.
2. Open **plurifold-ios** in Codemagic. Select **main** and refresh the configuration if needed.
3. Choose **Start new build → Plurifold - TestFlight**.
4. Confirm the build overview shows the latest GitHub commit. Rebuilding an older commit will not include this update.

Codemagic regenerates the Xcode project, runs the native test suite on its Mac, signs the Release IPA, and uploads it for internal TestFlight testing. You can close its browser tab while it runs. The installed app does not need Codemagic running.

After Apple's processing completes, assign the build to your existing internal testing group if needed. Open **TestFlight → Plurifold → Update** on your iPhone.

## Check this revision

- From Home, a language library, Words, Review, and Account, swipe right from the physical left edge. The sidebar should follow your finger immediately as you pull slowly, stop, or reverse. On release, its position and speed should decide whether it springs open or closed. The hamburger opens the same panel. Tap outside it, use Close, or drag left across the drawer to dismiss it. The closing drag should follow your finger too.
- Open a course, then a chapter. Each left-edge swipe should go back exactly one screen: chapter → outline → library. Only the next swipe at the library opens the sidebar. Check a standalone video lesson too; its native back button must still work without a double pop.
- Leave a chapter in Home's stack, switch to Words or Review, and edge-swipe. It must open the sidebar without popping the inactive chapter. Sidebar Words/Review should keep the selected language; Home allows a different language and Library returns to that language's library.
- Try tiny, cancelled, reversed, and mostly vertical edge movements, plus normal text selection and scrolling away from the edge. Swipe rapidly twice, switch tabs during a gesture, background the app, and try the edge with the player, dictionary/AI details, source image, or account sheet open. No hidden destination should change under a modal sheet.
- Pull past the fully open position to check gentle bounded resistance. Reverse before releasing, and catch the panel while it is springing open or closed. It should continue from its visible position without jumping. Check the rounded top and bottom corners, small outer insets, continuous outline, and gradually dimming background.
- Test the sidebar in each colorway, portrait/landscape, and larger text. Test Reduce Motion, the menu/Close buttons with VoiceOver, and the accessibility escape gesture. Sidebar content should scroll independently while the screen behind it remains inactive.

- Open Georgian → GeoFL A1 → Point and identify, then Match words to objects. The activity should show the original worksheet and instructions, with audio available above it. Enlarge the source and use Done to close it.
- Use Previous and Next, then Back to course. Each activity should start at its top, the outline should retain its place, and chapter changes must not accumulate a stack of readers or move the tab bar.
- Open Estonian and Japanese courses. Page controls should show one source image at a time; patterns and supplied meanings remain readable in the chosen colorway. Test larger text and a failed image connection.
- Try a Georgian fill-in or choice exercise and an Estonian question. Blank answers are skipped; editing clears that answer's result; Reveal and Clear remain separate. These checks use the authored answer keys locally. Exercise drafts and results are local to the current activity; this update does not sync course completion or replace the website's handwriting and word-search tools.
- Open Transcript and word study for the existing dictionary and short-phrase AI selection. Show supplied meanings, open Words and expressions, and check audio stops when dismissing the player.

- From Home, open each available language. Open a standalone lesson and a nested course chapter, then go back. Use the header to switch language while inside a reader, return Home, and select the same language again. The stack should change destinations without replacing its navigation host. The reported crash has no attached native crash log, so its resolution still needs this device check.
- Confirm the top-left header shows the full lowercase `plurifold` wordmark with one narrow block cursor immediately after the final letter, matching the website. The cursor should blink every 1.1 seconds, remain visible with Reduce Motion, and resume after backgrounding. Check all colorways and larger text; the wordmark must not shift as the cursor blinks.

- Open a language from Home. Check the Library cover cards, channel/ILR filters, real word coverage, saved-entry counts, and separate course folders. Test a lesson without an image and offline image loading; it should retain the language cover.
- Scroll down. The masthead, account initial, and language switcher should remain accessible. Choose another language while in a course or reader; the new language's library must replace the old destination. Words and Review must follow the new language.
- Tap your initial at top right. Try Verdant, Vermilion, and Blue Hour with Light, Dark, and System. Close and relaunch: the selection should persist. Set Vermilion + Light to match the website recording.
- Change colorway from an open reader, dismiss Account, and confirm the same reading place, selection, and player state remain. Check the word-details control and system Light/Dark changes. Test larger text and VoiceOver for header controls, cards, and theme choices.

- Hold a player transcript sentence for about **0.45 seconds**. Its original sentence should stay fixed while the player pauses and the study sheet opens.
- Hold a word for **0.2 seconds**, then drag. Neighbouring selected words should join into one blue shape per line, with a small bubble response and one haptic tick as you cross words. Check reversing, multiline dragging, clear, normal scrolling, and Reduce Motion.
- Highlight **2 words**, then **14 words**, and release. Each should open AI automatically. Select **15 words** or a paragraph: the app should show the short-selection message without requesting AI. Downward dragging should extend the highlight freely. Repeat in Study sentence. One word still offers a nearby Word details button.
- Choose **Italian** on Home. Words and Review should show only Italian. Switch languages and check both tabs again. Review offers **Reveal meaning**, **Again**, and **Got it** for a session round.
- Save a meaning on desktop, return to the app, and open that term. Check **Your saved definition** and its original context.
- Complete a desktop phrase lookup without saving it. Select the same phrase in the same passage on mobile and check **Earlier AI explanation from your account**. For a single word, AI remains behind Explain with AI. Different contexts require their own explanation.
- Try Estonian **olen**, **lapsed**, Georgian **გამარჯობა**, or **ია**. Inspect Dictionary and the linked source, then save one meaning. Attribution should remain visible in Words/Review and on desktop. Some forms, such as **ბავშვებო**, have no entry; a missing entry must be distinct from a temporary connection failure.
- Type a follow-up in Ask. Use the X, keyboard Done, and a tap outside the editor to dismiss the keyboard without closing details or losing the draft. Ask and Save should still respond. The From this lesson panel remains absent.

The matching server update includes `/api/mobile/dictionary` and read-only reuse of earlier explanations through `/api/define`. New mobile AI generation still uses `mobile-lite`; dictionary lookup and saved meanings do not require generating AI. No API keys belong in the iOS repository.

See [README.md](README.md) for the broader device checklist and [VALIDATION.md](VALIDATION.md) for checks already completed. Local grammar checks do not replace the Codemagic build or iPhone verification.

If a build fails, share the expanded failing-step log and commit. The test artifacts include `build/test-results/xcodebuild-test.log` and the `.xcresult` bundle. Passwords, account tokens, and signing keys are not needed.
