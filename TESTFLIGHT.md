# Plurifold TestFlight setup reference

The existing Apple membership, App Store Connect app, Codemagic signing setup, and TestFlight installation are working. For the next update, follow [NEXT-BUILD.md](NEXT-BUILD.md). The certificate and profile instructions later in this document are optional reference for a new or replacement setup.

## Current build settings

| Setting | Exact value |
| --- | --- |
| Full-source package | `Plurifold-iOS-Live-Update.zip` |
| GitHub repository | `lowqueue/plurifold-ios` |
| Branch | `main` |
| Codemagic workflow | **Plurifold - TestFlight** |
| Apple integration name | `plurifold-apple` |
| Certificate reference | `plurifold-distribution` |
| Provisioning profile reference | `plurifold-app-store` |
| Bundle ID | `com.plurifold.ios.prototype` |
| Project / scheme | `Plurifold.xcodeproj` / `Plurifold` |
| Marketing version | `1.0` |

The new package contains the complete source project. Extract it and upload the contents with their folders preserved at the repository root. The earlier `Plurifold-TestFlight-Update.zip` was only an icon and distribution patch; use the new live-update package for this build.

## What the workflow does

**Plurifold - TestFlight** regenerates the Xcode project, runs the included native tests on an installed iPhone simulator, configures your existing signing identities, archives the Release app, exports an IPA, and uploads it to App Store Connect. A failing test stops the job before distribution. Test logs and the result bundle are included in the build artifacts.

The native tests cover authentication persistence and recovery, concurrent refresh, sign-out races, account isolation, Unicode word/phrase selection, and the original study-store behavior. They are prepared for this workflow and have not been executed in the Linux development workspace.

Build numbers come from Codemagic's project build counter plus one. If another system uploads future builds, coordinate its build numbers with this counter.

The export is marked **TestFlight Internal Testing Only**. `submit_to_testflight: false` prevents an external beta-review request; it does not prevent the IPA upload. `submit_to_app_store: false` leaves public App Store submission disabled. Add the processed build to the existing internal testing group when needed. External testing or public release will require a future build exported without the internal-only option.

The app now signs in to the website account, loads live lessons, uses the existing server-side AI services, and synchronizes saved vocabulary and reading places. It uses Apple's networking for HTTPS and includes no custom cryptographic implementation. The project retains `ITSAppUsesNonExemptEncryption = NO`; review that declaration if the app's encryption features change.

References: [Codemagic native iOS workflow](https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/), [App Store Connect publishing](https://docs.codemagic.io/yaml-publishing/app-store-connect/).

## Optional: create or replace the distribution certificate

Skip this section when `plurifold-distribution` is already configured and valid.

In Codemagic account settings, open **Code signing identities → iOS certificates → Generate certificate**.

| Field | Value |
| --- | --- |
| Reference name | `plurifold-distribution` |
| Certificate type | **Apple Distribution** |
| App Store Connect API key | `plurifold-apple` |

Choose **Create certificate**. Download the certificate and save its password. If the generated certificate is not already listed under that reference name, use **Upload certificate** to import it and its password. The signing key belongs in your local secure storage and Codemagic, not in the source repository.

Reference: [Codemagic signing identities](https://docs.codemagic.io/yaml-code-signing/signing-ios/).

## Optional: create or replace the provisioning profile

Skip this section when `plurifold-app-store` already matches the valid distribution certificate.

1. Open [Apple Developer → Profiles](https://developer.apple.com/account/resources/profiles/list) and click **+**.
2. Under **Distribution**, choose **App Store Connect**.
3. Select the App ID matching `com.plurifold.ios.prototype`.
4. Select the matching **Apple Distribution** certificate. Apple may display the legal account-holder name instead of Codemagic's reference name.
5. Name the profile `Plurifold App Store`, generate it, and download its `.mobileprovision` file.
6. In Codemagic, open **Code signing identities → iOS provisioning profiles → Upload**. Upload the file under reference name `plurifold-app-store`.
7. Confirm that Codemagic shows a matching certificate for this profile.

Reference: [Apple's App Store profile instructions](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile/).

## Optional: create the first internal testing group

For a new testing setup, open [App Store Connect](https://appstoreconnect.apple.com/), choose **Plurifold → TestFlight**, and allow the uploaded build to finish processing. Under **Internal Testing**, create a group such as `Plurifold Personal`, add your eligible App Store Connect user, and add the processed build.

Follow the invitation on the iPhone using Apple's **TestFlight** app. For later builds, reuse the group. If Apple requests export-compliance information, answer for the current app's features.

Reference: [Apple's internal testing instructions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/).
