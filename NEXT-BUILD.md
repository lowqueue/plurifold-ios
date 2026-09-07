# Build the latest Plurifold update

Use the existing GitHub repository, Codemagic application, and TestFlight group. Your signing configuration remains in place.

## Start the build

1. Open [lowqueue/plurifold-ios](https://github.com/lowqueue/plurifold-ios) and confirm branch **main** shows **Add language review, reactive selection, and lean mobile AI**.
2. Open **plurifold-ios** in Codemagic. Select **main** and refresh the configuration if needed.
3. Choose **Start new build → Plurifold - TestFlight**.
4. Confirm the build overview shows the latest GitHub commit. Rebuilding an older commit will not include this update.

Codemagic regenerates the Xcode project, runs the native test suite on its Mac, signs the Release IPA, and uploads it for internal TestFlight testing. You can close its browser tab while it runs. The installed app does not need Codemagic running.

After Apple's processing completes, assign the build to your existing internal testing group if needed. Open **TestFlight → Plurifold → Update** on your iPhone.

## Check this revision

- Hold a player transcript sentence for about **0.45 seconds**. Its original sentence should stay fixed while the player pauses and the study sheet opens.
- Hold a word for **0.2 seconds**, then drag. Neighbouring selected words should join into one blue shape per line, with a small bubble response and one haptic tick as you cross words. Check reversing, multiline dragging, clear, normal scrolling, and Reduce Motion.
- Choose **Italian** on Home. Words and Review should show only Italian. Switch languages and check both tabs again. Review offers **Reveal meaning**, **Again**, and **Got it** for a session round.
- Explain a word, phrase, and sentence, then ask a follow-up. Mobile now requests a compact AI profile. Check meaning and grammar quality in your target languages, as well as response time.

The server needs the matching `mobile-lite` profile on `/api/define` and `/api/ask` before this app revision is installed. This update includes that server change. No API keys belong in the iOS repository.

See [README.md](README.md) for the broader device checklist and [VALIDATION.md](VALIDATION.md) for checks already completed. Local grammar checks do not replace the Codemagic build or iPhone verification.

If a build fails, share the expanded failing-step log and commit. The test artifacts include `build/test-results/xcodebuild-test.log` and the `.xcresult` bundle. Passwords, account tokens, and signing keys are not needed.
