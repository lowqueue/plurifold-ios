# Build the latest Plurifold update

Use the existing GitHub repository, Codemagic application, and TestFlight group. Your signing configuration remains in place.

## Start the build

1. Open [lowqueue/plurifold-ios](https://github.com/lowqueue/plurifold-ios) and confirm branch **main** shows **Bring the website library and colorways to iOS**.
2. Open **plurifold-ios** in Codemagic. Select **main** and refresh the configuration if needed.
3. Choose **Start new build → Plurifold - TestFlight**.
4. Confirm the build overview shows the latest GitHub commit. Rebuilding an older commit will not include this update.

Codemagic regenerates the Xcode project, runs the native test suite on its Mac, signs the Release IPA, and uploads it for internal TestFlight testing. You can close its browser tab while it runs. The installed app does not need Codemagic running.

After Apple's processing completes, assign the build to your existing internal testing group if needed. Open **TestFlight → Plurifold → Update** on your iPhone.

## Check this revision

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
