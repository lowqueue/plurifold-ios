# Plurifold on your iPhone from Windows

The Apple Developer Portal connection is already active. Complete the signing setup below, upload this source update to GitHub, and run the new workflow. No local Mac is needed.

## 1. Create the distribution certificate in Codemagic

From the settings page showing the connected Developer Portal, scroll down to **codemagic.yaml settings**. Open **Code signing identities → iOS certificates → Generate certificate**.

| Field | Value |
| --- | --- |
| Reference name | `plurifold-distribution` |
| Certificate type | **Apple Distribution** |
| App Store Connect API key | `plurifold-apple` |

Click **Create certificate**. Download the certificate and save the password shown with it. Codemagic's documented process then uses the **Upload certificate** tab to import that certificate and password under the reference name `plurifold-distribution`. Confirm it is listed in **iOS certificates**. If your UI has already saved it under that name, use that entry.

The certificate contains the private signing key. Keep it on your computer and in Codemagic, alongside your `.p8` API key. These files do not belong in the GitHub repository.

Reference: [Codemagic signing identities](https://docs.codemagic.io/yaml-code-signing/signing-ios/).

## 2. Create the App Store provisioning profile

Open [Apple Developer → Profiles](https://developer.apple.com/account/resources/profiles/list) and click **+**.

1. Under **Distribution**, choose **App Store Connect** and continue.
2. Choose the App ID matching `com.plurifold.ios.prototype`.
3. Select the **Apple Distribution** certificate just created through Codemagic. It may be shown under your legal name, Jalen Lott, rather than the Codemagic reference name.
4. Name the profile `Plurifold App Store`, generate it, and download the `.mobileprovision` file.
5. In Codemagic, open **Code signing identities → iOS provisioning profiles → Upload**. Upload that file with reference name `plurifold-app-store`.

The profile's certificate should show a matching certificate in Codemagic. This profile authorizes the Plurifold bundle ID to use that signing certificate for App Store Connect uploads, including TestFlight.

Reference: [Apple's App Store provisioning profile instructions](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile/).

## 3. Upload the prepared source changes

Download **Plurifold-TestFlight-Update.zip** and use **Extract All** on Windows. Open the extracted folder until you see `codemagic.yaml`, `Plurifold`, `Plurifold.xcodeproj`, and `scripts` together.

In [lowqueue/plurifold-ios](https://github.com/lowqueue/plurifold-ios), choose **Add file → Upload files**. Drag the extracted files and folders into the upload page at the repository root, preserving their directory structure. Upload the contents, rather than the outer ZIP or an extra containing folder. Commit to **main**, for example with message `Add TestFlight workflow and app icon`.

This is a source update package. It contains changed and added files, not a full replacement repository. Existing lesson and SwiftUI files remain in the repository. The project file is already regenerated, and all icon PNGs are included, so you do not need to run Python or install icon tools on Windows.

| Setting used by the prepared workflow | Exact value |
| --- | --- |
| Apple integration name | `plurifold-apple` |
| Certificate reference | `plurifold-distribution` |
| Provisioning profile reference | `plurifold-app-store` |
| Bundle ID | `com.plurifold.ios.prototype` |
| Project / scheme | `Plurifold.xcodeproj` / `Plurifold` |
| Marketing version | `1.0` |

Reference: [GitHub browser file uploads](https://docs.github.com/en/repositories/working-with-files/managing-files/adding-a-file-to-a-repository).

## 4. Run the iPhone build

Open the **plurifold-ios** application in Codemagic, select **main**, and click **Check for configuration files** or refresh the branch. Start a new build using **Plurifold - TestFlight**.

This workflow imports your uploaded signing files, applies the profile to the Xcode project, builds a signed Release `.ipa`, and uploads it through the Apple integration. The original simulator workflow remains available. A separate build number is assigned on each run using Codemagic's project build counter plus one.

The export is marked **TestFlight Internal Testing Only**. `submit_to_testflight: false` means the workflow does not request external beta review; it still uploads the `.ipa`. You add the processed build to your own internal group in the next step. No public App Store review is requested. External testing or public release will require a future build exported without the internal-only option.

The current app has bundled lessons, on-device speech, and local progress, with no app-provided encryption. Its generated Info.plist sets `ITSAppUsesNonExemptEncryption` to false. Reassess this declaration if encryption features are added later.

References: [Codemagic native iOS workflow](https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/), [App Store Connect uploads](https://docs.codemagic.io/yaml-publishing/app-store-connect/).

## 5. Install with TestFlight

After the upload succeeds, open [App Store Connect](https://appstoreconnect.apple.com/) and choose **Plurifold → TestFlight**. Allow Apple to finish processing the build.

Under **Internal Testing**, create a group such as `Plurifold Personal`. Add yourself as a tester, add the processed build, and follow the invitation or redemption instructions on your iPhone using Apple's **TestFlight** app. Your Account Holder user is eligible for internal testing. If Apple shows an export-compliance question, answer it according to the features in this prototype.

Once installed, follow the short reading, vocabulary, quiz, and persistence checks in `README.md`. This is the first opportunity to confirm the native interface and speech playback on your actual iPhone.

If the build fails, share the failed step's log or the Apple validation error text. A successful simulator build cannot validate distribution certificates, provisioning profiles, or App Store uploads.

Reference: [Apple's internal testing instructions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/).
