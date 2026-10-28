# dflt-brwsr

A small native macOS app for changing your default browser from **Shortcuts**.
No window, Dock icon, menu bar item, browser extension, or shell action is needed.

## Requirements

- macOS 13 Ventura or later.
- Xcode 16 or later with its command-line tools selected, to build the project.
- No third-party packages. An Apple Development signing certificate and its team must be configured in Xcode for Shortcuts execution.

## Build and set up

Open `DefaultBrowser.xcodeproj` and select the **DefaultBrowser** app target. Under **Signing & Capabilities**, enable **Automatically manage signing**, select your personal Apple account's team, and use an **Apple Development** signing certificate. **Do not use “Sign to Run Locally.”** Add your Apple account in **Xcode → Settings → Accounts** if needed.

Select the **DefaultBrowser** scheme and **My Mac**, and run it. The app runs in the background, so no window will appear.

Or build from Terminal, in this repository:

```sh
DEVELOPMENT_TEAM=YOUR_TEAM_ID sh scripts/build.sh
```

Alternatively, create `Config/Signing.local.xcconfig` (gitignored) containing `DEVELOPMENT_TEAM = YOUR_TEAM_ID`, then run `sh scripts/build.sh`. The shared signing configuration already selects automatic signing with Apple Development.

The build script verifies the signature and its Team ID before reporting a usable app. It produces an app for Apple Silicon and Intel at:

```text
.build/xcode/Build/Products/Release/Default Browser.app
```

Copy **Default Browser.app** to `/Applications` or `~/Applications`, then open that copy once. Keep it installed so saved Shortcuts can find its actions. For development, running the app from Xcode is sufficient; avoid keeping multiple built copies installed.

App Intents requires a certificate-backed signature with a **Team ID** on this Mac. Ad-hoc signing can make actions appear in Shortcuts while their execution fails. A free Personal Team can provide development signing; a paid membership is not required just to develop locally. Distribution to other Macs requires your own Developer ID signing and notarization. App Sandbox is disabled because this utility changes system app associations.

## Use in Shortcuts

1. Open **Shortcuts** and create a shortcut.
2. Search for **Default Browser** in the action library (or look under **Apps → Default Browser**).
3. Add **Set Default Browser** and choose an installed browser in its **Browser** parameter.
4. Run the shortcut and respond to any macOS confirmation dialog.

The picker discovers installed apps that handle **both HTTP and HTTPS**. It supports any registered browser, including alternative browsers and preview channels, without a hardcoded list. Browser choices are saved by bundle identifier and resolved again when the shortcut runs.

| Action | Output |
| --- | --- |
| **Set Default Browser** | The browser, after verifying both protocols use it |
| **Get Default Browser** | The current browser, or an error if HTTP and HTTPS differ or are unset |
| **List Installed Browsers** | A list of installed browser entities |

Browser outputs expose **Name** and **Bundle Identifier** for use in subsequent Shortcuts actions.

### Example shortcuts

**Switch to Safari:** Add **Set Default Browser**, choose **Safari**, and optionally assign a keyboard shortcut in the shortcut's details. Duplicate it and choose another browser for a second keyboard shortcut.

**Choose each time:** Set the **Browser** parameter to **Ask Each Time**. Alternatively, chain **List Installed Browsers → Choose from List → Set Default Browser**, passing the chosen item into the Browser parameter.

**Save and restore:** Run **Get Default Browser** before switching. Save its output in a Shortcuts variable, then pass that variable to another **Set Default Browser** action later in the same shortcut. This does not automatically restore your browser if the shortcut stops early.

### macOS confirmation and failure behavior

Switching uses Apple's public `NSWorkspace.setDefaultApplication` API. **macOS may ask for consent; silent switching is not guaranteed.** The app waits for the system response and checks the resulting HTTP and HTTPS defaults before returning success. It skips protocols already assigned to the selected browser.

The two protocol changes are separate system operations. If you decline a prompt or a change fails partway through, HTTP and HTTPS can temporarily use different browsers. The error includes their current values. Run **Set Default Browser** again to finish the change or choose your previous browser to restore it. The app does not silently roll back, which could trigger additional consent dialogs.

This utility changes the handlers for web links. It does not change HTML file associations or settings inside browsers.

If actions do not appear, check that the app is installed, open it once, and quit and reopen Shortcuts. If a saved browser is removed, choose a different browser in the action.

If Shortcuts says it **“couldn't communicate with the app”**, first check the installed copy's signature:

```sh
python3 scripts/verify-signing.py "/Applications/Default Browser.app"
```

Version 0.1.0 was incorrectly built with ad-hoc signing. On the affected Mac, system logs show `Unable to get teamId` followed by App Intents connection failures. Rebuild with your Apple Development certificate, quit the old **Default Browser** process in Activity Monitor, replace the app in Applications, open the new copy once, and reopen Shortcuts. Test **Get Default Browser** first; it does not change any settings.

## Development and verification

```sh
# Tests use a mock workspace; they never change your default browser.
swift test

# Build the app, including App Intents metadata extraction.
sh scripts/build.sh
python3 scripts/verify-metadata.py
python3 scripts/verify-signing.py
```

In a restricted environment that cannot launch SwiftPM's nested build sandbox, use `swift test --disable-sandbox` for these local, dependency-free tests.

The tests cover browser discovery, duplicate installations, missing browsers, split defaults, consent errors, partial changes, idempotent switching, delayed system updates, and verification failures. CI builds an **unsigned** app in `.build/xcode-unsigned` with `sh scripts/build.sh --unsigned` and checks that all three background actions, their App Shortcuts entries, and the browser entity query are exported. This CI product cannot run Shortcuts actions and is kept separate from the signed app.

To manually verify on your Mac:

1. Run **List Installed Browsers** and check the picker matches installed browsers.
2. Run **Get Default Browser** and compare with System Settings.
3. Set a different browser, accept macOS prompts, then run **Get Default Browser** again.
4. Run the setter again for that same browser; it should finish without requesting another change.
5. Switch back to the original browser. You can also decline a change and check the reported state.

The automated tests do not exercise real consent dialogs or Shortcuts execution. Those require this manual check.

### Project layout

- `App/`: background app lifecycle, browser entity and query, three App Intents, and App Shortcuts provider.
- `Sources/BrowserCore/`: browser discovery and switching logic behind an injectable workspace adapter. Compiled directly into the app and separately as a Swift package for tests.
- `Tests/BrowserCoreTests/`: tests without system setting changes.
- `DefaultBrowser.xcodeproj/`: app target and shared build scheme. Build with this project to get an installable app with extracted App Intents metadata; the Swift package alone does not produce that app.
- `Config/`: automatic development signing, with an optional local team override.
- `scripts/`: release build, metadata verification, and signing verification.

## References

- [Apple: setting the default app for a URL scheme](https://developer.apple.com/documentation/appkit/nsworkspace/setdefaultapplication(at:toopenurlswithscheme:completion:))
- [Apple: App Intents and App Shortcuts](https://developer.apple.com/documentation/appintents/acceleratingappinteractionswithappintents)
- [Apple: development signing with a Personal Team](https://developer.apple.com/forums/thread/763141)

## License

This project is licensed under the [MIT License](LICENSE).
