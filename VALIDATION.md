# Presenter validation

Reviewed October 16, 2026. Local environment: macOS 27.0.1, Apple silicon, Apple Swift 6.4. This separates observed results from source inspection and remaining checks.

## Recording and application behavior

| Requirement | Evidence | Result |
| --- | --- | --- |
| Menu-bar app without a main window | Packaged app launch and native control inspection; `MenuBarExtra` and accessory activation in `PresenterApp.swift` | Verified locally |
| Floating camera above ordinary windows | Live Circle and Cutout panels inspected; saved recordings include the camera | Verified locally |
| Screen, moving camera, and speech in one local movie | User playback confirmation for two recordings; independent video/audio metadata inspection | Verified locally |
| Transparent person cutout | User playback confirmation; decoded movie frame shows the desktop around a waving person | Verified locally |
| Camera selection, style, mirroring, size, and position persistence | Preference inspection and quit/relaunch of the packaged app | Verified locally with the available camera |
| Native recorder launcher | User completed recordings through Presenter; `NSWorkspace` opens Screenshot | Verified locally |
| Dragging, click-through, border, and placement controls | Native controls inspected; placement implementation reviewed; eight placement tests passed | Implemented; physical display changes remain untested |
| Camera cleanup | Capture ends on quit; source removes camera inputs/outputs on hide and blocks through cleanup on quit | Quit verified locally; hide path inspected |
| No runtime network service or external package | Package has no dependencies; source has no networking or upload path | Verified by source inspection |
| Camera-only ownership in Presenter | Capture session adds video inputs; Screenshot owns microphone selection and recording | Source inspected; speech verified in saved movies |
| Permission and device recovery | Authorization states, device notifications, interrupted-session handling, and retry controls reviewed | Implemented; revoked permissions and physical device changes remain untested |
| Multiple displays and Spaces | Placement tests cover negative origins, missing displays, small screens, invalid preferences, and no screens; panel collection behavior reviewed | Automated placement verified; physical displays/full-screen/Space transitions remain untested |
| First-use guidance | Persisted Recording Guide in the native popover | Inspected |

The optional QuickTime-only AppleScript compiled successfully. Its complete scripted recording workflow remains untested; Presenter does not depend on it.

## Build and installation

The current scripts passed `zsh -n`, and `Info.plist` passed `plutil -lint`. A clean source copy in a directory with spaces in its path passed all 12 tests: eight placement cases and four person-mask compositing cases. Core Image tests require the normal macOS execution environment on this machine; the workspace sandbox also rendered an unfiltered control image incorrectly.

The current scripts were reviewed for checkout-relative paths, quoted paths, local signing, running-app checks, unrelated-app protection, staged copying, and restoration of the previous installation if replacement fails.

Installer results from that clean copy:

1. `zsh install.sh --no-open` built and installed successfully into a workspace destination with spaces in its path. It did not change `~/Applications` or launch the camera.
2. The installed app passed `codesign --verify --deep --strict --verbose=2`.
3. Repeat installation successfully replaced the prior test installation and passed signature verification again.
4. An unrelated destination app was refused before building or replacing it.
5. A harmless compiled process named Presenter was detected by macOS; the installer refused to replace the app while it ran. The fixture was stopped afterward.
6. `otool -L` showed only system frameworks and system Swift libraries, with no development-checkout library paths.
7. Git's file list contains only the 19 intended source, test, script, and documentation files. Generated apps, build files, recordings, and private validation images are excluded.

These checks ran after the owner's explicit local-verification approval. Swift 6.4 emitted linker warnings about two missing Command Line Tools development search directories; builds, linking, tests, and installed signature verification nevertheless succeeded. No compiler or test failure remains.

The source repository uses `main`. The owner approved public repository creation and source publication to `isaachuahy/presenter-macos` after these local checks passed. Installation instructions are in `README.md`; this setup distributes source that users build on their own Macs.

## Distribution scope

The user requested source-based GitHub installation for now. Developer ID signing, universal prebuilt binaries, notarization, and a downloadable executable release are deferred. Intel Macs and the macOS 14 deployment minimum have not been tested. Do not extend the verified local result to every supported Mac.

## Cutout sizing update, 2026-10-17

Cutout preset widths increased from 160/224/320 to 320/448/640 points. Heights remain 75% of width. The rendered-image limit increased to 1280 pixels to cover the largest preset on a Retina display.

All 12 existing tests passed after the change. The release app rebuilt and passed strict signature verification. Presenter was restarted, and its live Large Cutout was visually inspected; the persisted frame confirmed a 640 × 480-point panel. The saved-movie playback check was not repeated for this sizing update.

## Fine-size slider, 2026-10-17

Small, Medium, and Large remain quick presets. A native slider adjusts the selected preset from 50% to 150% in 1% steps, with a percentage readout and Reset button. Choosing another preset resets the adjustment to 100%. The adjustment is stored separately from the preset and safely normalized when preferences load.

All 14 tests passed, including fine-resize center/aspect preservation and five invalid or out-of-range adjustment cases. The release app rebuilt and passed strict signature verification.

After the owner opened the menu-bar panel, native accessibility actions moved the slider in 1% steps. Large at 125% produced an 800 × 600-point panel. Choosing Medium returned the slider to 100%; the Reset button independently restored 100% after another adjustment. The native layout and percentage readout were visually inspected. Presenter was then quit and relaunched with Large at 110%; its restored 704 × 528-point frame and saved 1.1 adjustment confirmed persistence. The running app remains at that tested Large 110% setting. The saved-movie playback check was not repeated for this sizing-control update.
