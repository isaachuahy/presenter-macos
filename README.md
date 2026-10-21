# Presenter

A small macOS menu-bar utility for recording your screen with a live camera overlay and microphone speech in one local movie. Choose **Cutout** to remove your camera background, or use a Circle or Rounded preview.

Presenter uses Apple's Screenshot recorder, AVFoundation, Vision, and Core Image. Camera processing stays on your Mac. There are no external packages, subscriptions, or runtime network services.

The packaged app enables App Sandbox and Hardened Runtime. Its only access entitlements are camera capture and read-only access to folders explicitly selected by the user. It has no network, microphone, automation, or broad file-access entitlement. Screenshot and System Settings are opened only from their protected system locations after checking Apple's signature and signing identifier.

## Install from source

Requires **macOS 14 or later**, a camera, and **Swift 6 or later** from Apple's Command Line Tools or Xcode. The installer builds for your Mac's processor; it needs no developer account or admin access to install Presenter.

1. Install Apple's Command Line Tools if needed:

   ```sh
   xcode-select --install
   ```

2. Check that your selected tools provide Swift 6 or later:

   ```sh
   swift --version
   ```

   If the tools are older, update Command Line Tools or Xcode. See [Apple's installation guide](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools).

3. Clone the repository:

   ```sh
   git clone https://github.com/isaachuahy/presenter-macos.git
   ```

4. Enter the checkout:

   ```sh
   cd presenter-macos
   ```

5. Build, install, and open Presenter:

   ```sh
   zsh install.sh
   ```

6. Click the video icon in the macOS menu bar. Presenter opens no main window.

You can also download the source using GitHub's **Code → Download ZIP**, extract it, open Terminal in the extracted folder, and run `zsh install.sh`.

The installer creates `~/Applications/Presenter.app`. It refuses to replace an unrelated app or update Presenter while it is running. By default, installation uses a temporary build directory and removes it afterward. The build removes debug and local symbols, then signs the sandboxed app locally with an ad-hoc signature and Hardened Runtime. This setup is for building on your own Mac; it does not provide a notarized binary download or a verified publisher identity. Do not disable Gatekeeper or remove quarantine protections to install it. If macOS requests camera permission again after rebuilding, allow it in System Settings → Privacy & Security → Camera.

## Record

1. Turn on **Show Camera** and allow Presenter to use the camera.
2. Choose a camera, **Appearance → Cutout**, and a size. Circle and Rounded are also available.
3. Drag the overlay into position. Turn off **More Controls → Click Through Camera** before dragging.
4. Click **Open Screen Recorder**.
5. Choose **Record Entire Screen** or **Record Selected Portion** in Screenshot. Include the overlay in the selected display or region.
6. Select your microphone and **Save to** folder under **Options**.
7. Click Screenshot's **Record** button.
8. Stop with Apple's menu-bar Stop button or **Control-Command-Escape**.
9. Play the saved movie to check the screen, camera movement, and speech.
10. Hide the camera or quit Presenter when finished.

Presenter opens the native recorder; you start and stop recording there. It does not detect recording status, so stopping a recording leaves the camera active until hidden or Presenter quits. The camera starts off each time Presenter launches and turns off during Mac sleep. **More Controls → Resume Camera After Sleep** is off by default; when enabled, it resumes only a camera that was on before sleep. Presenter captures no microphone audio itself.

Use the **Size** slider for one continuous range. **Small**, **Medium**, and **Large** snap the slider to fixed preset sizes; between those points, no preset is selected. The range extends 20% below Small and 20% above Large. For Cutout, that is 256–768 points wide, with presets at 320, 448, and 640. Your size is saved across launches, and existing preset-relative settings carry over within the new range.

The panel keeps **Open Screen Recorder** at the top, with camera, style, and size controls below. **More Controls** holds mirroring, wake resumption, border, click-through, position reset, and folder settings. **Help** in the footer opens the recording guide. The recorder action and footer stay visible while expanded settings scroll.

Set the recording destination in **Screenshot → Options → Save to**. **More Controls → Choose Recordings Shortcut…** selects a separate folder that **Recordings** reveals in Finder. Clicking Recordings before choosing a shortcut opens the folder picker. Applications and other file packages cannot be selected as the shortcut.

Presenter saves read-only access to that explicit selection using a security-scoped bookmark. It does not read or change Screenshot's preferences. If you change Screenshot's destination, choose the matching shortcut folder again in Presenter. This replaces the previous automatic save-location synchronization so Presenter can stay inside App Sandbox. Re-select the shortcut after upgrading from an older version.

On macOS 26 or later, builds made with Swift 6.2 or later use Apple's native Liquid Glass for the whole control panel. The recorder stays a clear primary action within that shared surface. Older tools and systems retain the native popover material.

## Update or uninstall

1. Quit Presenter from its menu-bar panel before updating.
2. Run `git pull --ff-only` in your checkout, or download and extract the updated source ZIP.
3. Run `zsh install.sh` again.

To uninstall, quit Presenter and move `~/Applications/Presenter.app` to Trash. Removing the checkout deletes its source and build files. Recordings remain in the folder you selected in Screenshot. Presenter settings remain in its `local.presenter.utility` app container.

## Build and test

Build without installing:

```sh
zsh build.sh
```

Run placement, person-mask, folder-validation, and Apple-signature tests:

```sh
zsh build.sh test
```

The generated app is `Presenter.app` in the checkout. Quit Presenter before replacing a running copy. Installer options:

```sh
zsh install.sh --no-open
PRESENTER_INSTALL_DIR="$PWD/local-apps" zsh install.sh --no-open
```

Direct `build.sh` commands retain build files in the ignored `.build/` directory for faster development. `PRESENTER_BUILD_ROOT` selects a different build/cache directory; setting it also tells the installer to retain that directory. Neither script uploads files or changes macOS security settings.

Turn off **Show Camera** when finished to stop capture and release Cutout rendering resources. Cutout connects only its processed image pipeline; Circle and Rounded use the native camera preview. Camera resolution and segmentation quality are unchanged.

## Recovery

- **Camera permission denied:** Enable Presenter in System Settings → Privacy & Security → Camera, then choose Retry Camera.
- **No camera, camera busy, or disconnection:** Connect/select a camera or close another camera app, then retry. A missing saved camera falls back to an available one. You can also open the recorder without a camera.
- **Cutout unavailable:** Choose Retry Cutout or switch to Circle/Rounded. Vision's segmentation quality depends on lighting, motion, and the scene.
- **Overlay off-screen:** Choose Reset Camera Position. This also disables click-through so you can drag again.
- **Camera missing from a movie:** Record a whole display or a region containing the overlay. Capturing one app window can omit the separate camera panel.
- **Speech missing or distorted:** Check the selected microphone in Screenshot Options and its level in System Settings → Sound. Presenter cannot monitor the recorder's audio.
- **Full-screen apps/Spaces:** The panel joins Spaces and eligible full-screen apps. Test your specific app; protected surfaces and full-screen video may cover it.

## Verified behavior

The security update was checked on the same Apple silicon Mac on October 20–21, 2026. All 24 tests passed, and the sandboxed release passed deep strict signature verification with Hardened Runtime enabled. Live checks confirmed camera startup, the native Screenshot toolbar, and folder selection/reveal. A separate probe using the same entitlements confirmed denial of an unselected file write and an outbound loopback connection. These checks do not constitute a complete security audit; see `VALIDATION.md` for scope and limitations.

Tested on **macOS 27.0.1, Apple silicon, Swift 6.4** on October 16, 2026:

- Release build and local signature verification succeeded.
- All 12 tests passed: eight placement tests and four Core Image person-mask tests.
- A clean source copy built and installed into a test folder with spaces in its path. Repeat installation passed. The installer refused an unrelated app and refused replacement while a test process named Presenter was running. See `VALIDATION.md` for the verification scope.
- The user confirmed saved movies contain screen movement, camera movement, and speech, including a separate Cutout recording.
- The Cutout movie was independently inspected: 1920 × 1080 video, 48 kHz stereo audio, and a decoded frame showing the person over the desktop with the camera background removed.
- Saved Cutout style, size, mirroring, camera choice, and position survived relaunch. Camera capture ends on quit.
- The optional QuickTime AppleScript compiled successfully; its complete scripted recording workflow has not been tested.

Intel Macs, macOS 14, physical multi-display/device changes, and every full-screen app have not been tested. The minimum deployment target is not a claim of testing on every supported system.

## Source layout

- `Sources/Presenter/PresenterApp.swift`: native menu-bar controls and recording guide.
- `AppModel.swift`: preferences, recorder launcher, folders, and lifecycle.
- `CameraController.swift`: camera authorization, device/session management, and cleanup.
- `CutoutProcessor.swift`: local Vision person segmentation and transparent Core Image compositing.
- `OverlayController.swift`: floating panel, mirroring, style, dragging, and click-through.
- `OverlayPlacement.swift`: placement and display-boundary rules.
- `RecordingFolder.swift`: validated folder selection and read-only security-scoped bookmarks.
- `TrustedSystemApplication.swift`: Apple signature checks and protected system-app launches.
- `Presenter.entitlements`: App Sandbox, camera, and user-selected read-only access.
- `Tests/PresenterTests/`: placement, person-mask, folder-validation, and Apple-signature tests.
- `RESEARCH.md`, `PRODUCT.md`, and `DESIGN.md`: API evidence, scope, and native interface decisions.

`QuickTimePreview.applescript` is an optional baseline: open it in Script Editor, run it, enable QuickTime's View → Float on Top manually, then continue to screen recording. Presenter does not require it.
