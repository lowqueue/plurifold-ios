# Install the live Plurifold update

Your signing setup already works. Use the existing GitHub repository, Codemagic application, and TestFlight group.

This package adds course folders, a continuous reader, direct media playback, and touch-and-drag word selection. The existing website API, Unicode correction, and supplied app icon remain in use. Download the ZIP again to get this revision, then commit the upload and start a new build.

## 1. Extract the full source ZIP

Download **Plurifold-iOS-Live-Update.zip**. In Windows File Explorer, right-click it and choose **Extract All**, then open the extracted folder.

Locate the level containing `codemagic.yaml`, `README.md`, and these five folders together:

- `Plurifold`
- `Plurifold.xcodeproj`
- `PlurifoldTests`
- `scripts`
- `design`

This package contains the full project. Do not upload the ZIP itself or add an extra containing folder around the project.

## 2. Upload it to the existing GitHub repository

1. Open [lowqueue/plurifold-ios](https://github.com/lowqueue/plurifold-ios), select branch **main**, and return to the repository's top-level file list.
2. Choose **Add file → Upload files**.
3. From the extracted folder, select all of its files and folders and drag them into GitHub's upload area. Wait for the upload queue to finish.
4. Confirm that nested files are included, especially `Plurifold/Views/SelectablePassage.swift`, `Plurifold/Views/LiveCourseView.swift`, `Plurifold/Models/ReadingDocument.swift`, and `PlurifoldTests/MobileLibraryIndexTests.swift`. Root documents alone are not the complete update.
5. Enter **Improve reader selection and organize course chapters** as the commit message. Select **Commit directly to the main branch** and click **Commit changes**.
6. Wait for GitHub to return to the repository. Refresh it and confirm that a new commit appears. Open **Plurifold → Models → ReadingDocument.swift** and **Plurifold → Views → LiveCourseView.swift** to verify that the new folders and files reached the repository.

If GitHub's upload button stalls again, check whether that commit actually appeared before starting a build. A reliable alternative is GitHub Desktop: clone this same repository, copy the extracted project contents into the clone, replace matching files, then **Commit to main → Push origin**. Both steps are required to send the changes to GitHub.

Reference: [GitHub's upload instructions](https://docs.github.com/en/repositories/working-with-files/managing-files/adding-a-file-to-a-repository).

## 3. Start a new Codemagic build

1. Open your **plurifold-ios** application in Codemagic.
2. Select branch **main** and refresh the configuration if needed.
3. Click **Start new build** and choose **Plurifold - TestFlight**.
4. Confirm the build overview shows the new GitHub commit. A rerun of the previous commit cannot include these source changes.

The workflow regenerates the Xcode project, runs XCTest on an installed iPhone simulator, applies the existing signing identities, builds a signed Release IPA, and uploads it for internal TestFlight testing. The test step makes this build longer than the original simulator-only build.

You can close the browser tab. Codemagic continues the job on its cloud Mac and stops the job when it finishes. No local Mac or continuously running Codemagic session is needed to use the installed app.

## 4. Update the app on your iPhone

After Codemagic's upload succeeds, allow Apple to process the new build in **App Store Connect → Plurifold → TestFlight**. Add it to your existing internal testing group if it has not been assigned automatically.

Open **TestFlight** on your iPhone, select **Plurifold**, and tap **Update** or **Install**. Sign in with your website account, then follow the first device check in [README.md](README.md).

The bundle ID remains `com.plurifold.ios.prototype`, so this build updates the existing app. This workflow does not request a public App Store release or external beta review.

## If a step fails

Open the failed step in Codemagic and share its expanded log. For the new test step, the artifacts include `build/test-results/xcodebuild-test.log` and the `.xcresult` bundle. An Apple publishing rejection appears in the **Publishing** log. Include the build's commit so the failure can be matched to the actual source.

If installation succeeds but sign-in or live content fails, share the message visible in the app and the action that produced it. Passwords, account tokens, and signing keys are not needed for troubleshooting.
