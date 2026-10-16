# Presenter

A small macOS menu-bar utility for recording your screen with a live camera overlay and microphone speech in one local movie. Choose **Cutout** to remove your camera background, or use a Circle or Rounded preview.

Presenter uses Apple's Screenshot recorder, AVFoundation, Vision, and Core Image. Camera processing stays on your Mac. There are no external packages, subscriptions, or runtime network services.

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

The installer creates `~/Applications/Presenter.app`. It refuses to replace an unrelated app or update Presenter while it is running. Build files stay in the checkout's ignored `.build/` folder. The build signs the app locally with an ad-hoc signature. This setup is for building on your own Mac; it does not provide a notarized binary download. If macOS requests camera permission again after rebuilding, allow it in System Settings → Privacy & Security → Camera.

## Record

1. Turn on **Show Camera** and allow Presenter to use the camera.
2. Choose a camera, **Overlay Style → Cutout**, and a size. Circle and Rounded are also available.
3. Drag the overlay into position. Turn off **Click Through Camera** before dragging.
4. Click **Open Screen Recorder**.
5. Choose **Record Entire Screen** or **Record Selected Portion** in Screenshot. Include the overlay in the selected display or region.
6. Select your microphone and **Save to** folder under **Options**.
7. Click Screenshot's **Record** button.
8. Stop with Apple's menu-bar Stop button or **Control-Command-Escape**.
9. Play the saved movie to check the screen, camera movement, and speech.
10. Hide the camera or quit Presenter when finished.

Presenter opens the native recorder; you start and stop recording there. It does not detect recording status. The camera stays active until hidden or Presenter quits, pauses during Mac sleep, and resumes on wake when enabled. Presenter captures no microphone audio itself.

**Open Recordings Folder** is a Finder shortcut, initially Desktop. Its folder button changes only that shortcut. Set the actual recording destination separately in Screenshot → Options → Save to.

## Update or uninstall

1. Quit Presenter from its menu-bar panel before updating.
2. Run `git pull --ff-only` in your checkout, or download and extract the updated source ZIP.
3. Run `zsh install.sh` again.

To uninstall, quit Presenter and move `~/Applications/Presenter.app` to Trash. Removing the checkout deletes its source and build files. Recordings remain in the folder you selected in Screenshot. Preferences remain under `local.presenter.utility`.

## Build and test

Build without installing:

```sh
zsh build.sh
```

Run the 12 placement and person-mask tests:

```sh
zsh build.sh test
```

The generated app is `Presenter.app` in the checkout. Quit Presenter before replacing a running copy. Installer options:

```sh
zsh install.sh --no-open
PRESENTER_INSTALL_DIR="$PWD/local-apps" zsh install.sh --no-open
```

`PRESENTER_BUILD_ROOT` optionally changes the build/cache directory. Neither script uploads files or changes macOS security settings.

## Recovery

- **Camera permission denied:** Enable Presenter in System Settings → Privacy & Security → Camera, then choose Retry Camera.
- **No camera, camera busy, or disconnection:** Connect/select a camera or close another camera app, then retry. A missing saved camera falls back to an available one. You can also open the recorder without a camera.
- **Cutout unavailable:** Choose Retry Cutout or switch to Circle/Rounded. Vision's segmentation quality depends on lighting, motion, and the scene.
- **Overlay off-screen:** Choose Reset Camera Position. This also disables click-through so you can drag again.
- **Camera missing from a movie:** Record a whole display or a region containing the overlay. Capturing one app window can omit the separate camera panel.
- **Speech missing or distorted:** Check the selected microphone in Screenshot Options and its level in System Settings → Sound. Presenter cannot monitor the recorder's audio.
- **Full-screen apps/Spaces:** The panel joins Spaces and eligible full-screen apps. Test your specific app; protected surfaces and full-screen video may cover it.

## Verified behavior

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
- `Tests/PresenterTests/`: placement and person-mask tests.
- `RESEARCH.md`, `PRODUCT.md`, and `DESIGN.md`: API evidence, scope, and native interface decisions.

`QuickTimePreview.applescript` is an optional baseline: open it in Script Editor, run it, enable QuickTime's View → Float on Top manually, then continue to screen recording. Presenter does not require it.
