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
| First-use guidance | Help reveals the Recording Guide in the native popover | Verified locally |

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

## Preset-relative slider, 2026-10-17 (superseded)

Small, Medium, and Large remain quick presets. A native slider adjusts the selected preset from 50% to 150% in 1% steps, with a percentage readout and Reset button. Choosing another preset resets the adjustment to 100%. The adjustment is stored separately from the preset and safely normalized when preferences load.

All 14 tests passed, including fine-resize center/aspect preservation and five invalid or out-of-range adjustment cases. The release app rebuilt and passed strict signature verification.

After the owner opened the menu-bar panel, native accessibility actions moved the slider in 1% steps. Large at 125% produced an 800 × 600-point panel. Choosing Medium returned the slider to 100%; the Reset button independently restored 100% after another adjustment. The native layout and percentage readout were visually inspected. Presenter was then quit and relaunched with Large at 110%; its restored 704 × 528-point frame and saved 1.1 adjustment confirmed persistence. At completion of that check, the app was at Large 110%. The saved-movie playback check was not repeated for this sizing-control update.

## Shared size slider, 2026-10-17 (current)

The owner clarified that presets must be points within one continuous range. The percentage adjustment was replaced by a shared width slider and three preset buttons. Circle/Rounded span 128–384 points with anchors at 160, 224, and 320; Cutout spans 256–768 with anchors at 320, 448, and 640. Custom widths leave all three buttons unselected. Clicking a preset, including an already-selected one, snaps to its exact width without changing the range.

All 16 tests passed, including shared-range invariants, safe invalid widths, center/aspect preservation, and migration from the previous preset-plus-percentage preferences. The release app built and passed strict signature verification. Live checks confirmed Circle preset snaps to 160/224/320, one-point movement below Small and above Large, and selection clearing at custom widths. Cutout snapped to 448 and 640; repeated selection retained the active anchor. The native slider layout and point readout were visually inspected.

The saved Circle 150%-of-Large setting exceeded the new range and was clamped to 384 points. After the interaction checks, Circle at that 384-point width was saved, quit, and relaunched; the restored 384 × 384 frame confirmed the new preference round trip. The saved-movie playback check was not repeated for this control-only update.

## Recorder-first panel redesign, 2026-10-17

The owner approved a recorder-first panel with core controls visible and secondary controls collapsed. The title, recorder action, and footer remain outside the scrollable settings. More Controls holds mirroring, border, click-through, position reset, and folder settings; Help reveals the recording guide. Typography uses three semantic sizes: title, controls, and supporting text. The primary action uses native Liquid Glass when both the compiler and operating system support it, with a standard prominent-button fallback.

All 16 existing tests passed after the redesign. The release binary compiled for the macOS 14 deployment target on this Apple silicon Mac with Swift 6.4 and the macOS 27 SDK. The SDK's State macro plugin was unavailable in Command Line Tools; a type alias explicitly selects the existing state property wrapper. The known Command Line Tools linker search-path warnings remain nonfatal.

After the owner quit Presenter, the app bundle was rebuilt, ad-hoc signed, and passed deep strict signature verification. The owner opened the panel for live inspection. Medium snapped Circle to 224 points; one slider increment produced 225 and cleared the preset selection. More Controls expanded; Help revealed the guide while the recorder action and footer stayed visible. Selecting Cutout doubled the current width and disabled White Border. Circle at 384 points and camera off were restored afterward.

The inspection showed excessive blank space in the collapsed panel. Its height was reduced from 600 to 510 points, and scrolling after Help changes was deferred until the view update. The final release app rebuilt and passed strict signature verification. The final visual pass confirmed that both Circle and Cutout core controls fit without scrolling. Help opened and closed with More Controls both collapsed and expanded; closing it returned to the camera settings. The recorder action and footer remained accessible. The app was left at Circle, 384 points, camera off, with Help and More Controls collapsed.

Older operating systems/toolchains and accessibility preference changes remain untested for this redesign. Saved-movie playback was not repeated for these panel-only changes. The owner subsequently approved publishing the redesign as `a98e305`.

## Appearance and outer-window sizing, 2026-10-17

The reported transparent bands were reproduced: after expansion, the outer window could retain its 650-point height around the centered 510-point collapsed content. The scene now uses `.windowResizability(.contentSize)` so its window follows the content dimensions. Apple documents this strategy as deriving both minimum and maximum window sizes from the content. [WindowResizability](https://developer.apple.com/documentation/swiftui/windowresizability).

The release app rebuilt, was ad-hoc signed, and passed deep strict signature verification. Live inspection confirmed that More Controls and Help expand and collapse without leaving the outer bands. Explicit Light and Dark system appearances were compared, including Circle and Cutout core controls, expanded settings, disabled White Border, and the Help guide. Typography, spacing, preset selection semantics, and pinned actions remained consistent. These were visual and accessibility-tree checks, not a measured contrast certification. No custom colors or appearance override were added. The existing 16-test result covers the unchanged sizing and compositing logic; the test suite was not rerun for this scene-only modifier.

The original Auto appearance was restored and confirmed in System Settings. Presenter was left at Circle, 384 points, camera off, with Help and More Controls collapsed. The owner subsequently approved publishing this fix as `acb313c`.

## Shared Liquid Glass panel, 2026-10-17

The owner requested Liquid Glass for the panel itself. On macOS 26 or later with Swift 6.2 or later, the panel content now uses one native regular glass effect with a 20-point corner radius, and clears the standard window backing. The recorder uses a standard filled prominent button inside this shared surface. Older systems/toolchains keep their native popover material. Apple recommends regular glass for text-heavy popovers and applies both material and foreground effects through `.glassEffect`. [Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [glassEffect](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)).

The release app compiled for the macOS 14 deployment target, was ad-hoc signed, and passed strict signature verification. Live Light and Dark inspection confirmed the new glass surface, its rounded edge treatment, unchanged text hierarchy, accessible controls, the disabled Cutout border state, and wrapping Help text. More Controls and Help expanded and collapsed while the recorder and footer stayed fixed. The compact panel returned without transparent outer bands. These checks are local visual and accessibility-tree observations; minimum-OS runtime, older-toolchain builds, accessibility preference changes, and numerical contrast remain unverified. The material-only update did not change camera, sizing, recording, or compositing logic, so the existing 16-test suite was not rerun.

Auto appearance was restored and confirmed. The user's current Cutout style, 527-point width, and enabled camera were preserved; Help and More Controls were left collapsed. The owner subsequently approved publishing this update as `adf5114`.

## Shared recording save location, 2026-10-17

Presenter now reads Screenshot's recording destination instead of maintaining a separate folder shortcut. Change Save Location updates the native shared file destination; Recordings reloads and opens the current folder. Activation, window focus, and folder/recorder actions refresh the displayed destination. Non-folder outputs are shown explicitly, and unavailable folders produce recovery guidance. The picker explains that the shared folder also applies to still screenshots saved as files and takes effect when the recorder is next opened.

All 23 tests passed: the existing 16 placement, sizing, and compositing cases plus seven destination tests. The new tests cover Desktop fallback, recording-specific precedence, app outputs, malformed paths and file URLs, writable-folder updates without changing unrelated options, rejected selections, and changes made by a separate process. Preference-writing tests use isolated domains and temporary directories rather than the user's Screenshot preferences.

Live checks used two temporary folders. Choosing Chosen in Presenter through Presenter's picker made that folder appear in Screenshot's native Save to menu. Choosing Chosen in Screenshot through the native picker made Presenter display that folder. The owner then clicked Recordings and confirmed Finder opened Chosen in Screenshot. During the first automated folder-opening attempt, the synchronous NSWorkspace call blocked in Launch Services. The final release build uses its asynchronous URL-opening API; Presenter remained responsive, and the owner's physical folder-opening check passed. The final asynchronous change compiled successfully; the 23-test run preceded that API-only adjustment.

The release app was rebuilt, ad-hoc signed, and passed deep strict signature verification. After verification, the exact original values and absence of all seven location/target preference keys were restored from the local baseline and checked for equality. The recording destination is back to Desktop. The user's Cutout style, 527-point width, enabled camera, and Auto appearance were preserved. Saved-movie playback was not repeated for this destination-only change.

Screenshot's preference key names are observed behavior rather than a public Apple API contract. Native integration was verified on macOS 27.0.1; older supported systems remain untested. An already-open Screenshot toolbar may cache its prior destination, so changes should be made before opening the recorder. The owner subsequently approved publishing this update as `e579a41`.

## Memory and storage, 2026-10-17

Cutout's Core Image context is now created on the first processed frame, reused while active, and cleared and released on suspension or a change to a native preview style. The native preview layer connects only for running Circle/Rounded previews; Cutout no longer keeps that hidden capture branch connected. The balanced Vision request, 8-bit mask, supported 720p capture preset, and 1280-pixel render limit are unchanged.

The same FaceTime HD Camera and 527-point Cutout size were measured with `vmmap -summary`. Three original steady-state samples were 281.6, 282.5, and 281.6 MB of physical footprint. The retained resource strategy measured 274.2, 271.4, and 272.1 MB, about 3–4% less. A cold launch before camera use measured 20.6 MB; no matching original cold-launch sample was taken. These are observations on one Mac, not fixed memory limits.

After warm switching among Circle, Rounded, and Cutout, the camera-off footprint settled at approximately 115 MB. The earlier 105.5 MB original reading followed only one Cutout cycle, so it does not establish a comparable idle-memory reduction. An allocator pressure-relief experiment did not materially improve the warm result and was removed. No reduction in warm idle memory is claimed.

Live accessibility checks confirmed camera start, Cutout becoming ready, switching through Circle/Rounded and back to ready Cutout, camera stop, and restart after resource teardown. No camera or Cutout error appeared. All 23 placement, compositing, and destination tests passed after the retained lifecycle changes. The suite also passed with the subsequent allocator probe before that probe was removed; the final release was rebuilt from the simpler retained strategy. No new unit test claims to measure AVFoundation/Vision's process-wide footprint. Saved-movie playback and physical device/display transitions were not repeated for this update.

The stripped, ad-hoc signed app occupies approximately 332 KB on disk, down from 756 KB. The default installer built and installed successfully into the workspace test destination with spaces in its path, then removed its temporary build directory. Repeat installation also succeeded. Explicit `PRESENTER_BUILD_ROOT` continues to retain a developer-selected cache; direct build/test commands retain their normal development cache. Shell syntax checks passed, and the packaged app passed deep strict signature verification.

Only known generated development caches were deleted from the workspace. Intermediate storage fell from approximately 2.1 GB to 4.1 MB, including retained diagnostic samples and small test fixtures. Saved recordings, source history, and user preferences were preserved. Camera off and Cutout at 527 points were restored after the live checks. Camera permission had to be renewed after ad-hoc signing, and the owner allowed it. Older supported macOS versions and Intel Macs remain untested. The owner subsequently approved publishing this update as `ad01e37`.

## Sandbox and launch safeguards, 2026-10-20

The owner approved the security changes and explicitly chose App Sandbox plus Hardened Runtime over automatic Screenshot save-location synchronization. Presenter no longer reads or writes Screenshot's preferences. Its Recordings shortcut uses a user-selected, read-only security-scoped bookmark and a Finder-specific reveal API. Validation rejects applications, other file packages, symlinks to applications, missing directories, ordinary files, and remote URL schemes/hosts. Camera startup is off on every launch; wake resumption is an opt-in setting.

The launcher verifies Apple's signature and the exact signing identifier for the fixed Screenshot and System Settings installations, checks all architectures, rejects symlinked installations, and disables substitution by another running installation. A canceled recorder task checks cancellation after signature validation before requesting launch.

All 24 tests passed: the existing 16 placement and compositing tests plus four folder-safety tests and four Apple-signature tests. The signature tests checked the actual system installations, a different Apple app, a missing path, and a disposable ad-hoc app bearing Screenshot's signing identifier. No impostor fixture was launched. Corrupt and absent bookmarks were checked to ensure they cannot run the folder action. The unit runner does not claim to test the open panel's sandbox grants; the signed GUI app's bookmark checks are recorded below.

The release app built and installed into a workspace path with spaces, passed deep strict signature verification, and reported `adhoc,runtime` signing flags. Its only entitlements are App Sandbox, camera, and user-selected read-only file access. A temporary native probe reused the production system-app verifier and the exact entitlements. It confirmed denial of an unselected fixture-file write and an outbound loopback connection (`EPERM`), while Apple system-app verification succeeded inside Sandbox. The fixture remained unchanged, and the temporary probe app and fixture were removed afterward. This policy probe validates the entitlement boundary; it is not a complete penetration test of Presenter.

Live checks completed on October 21. The menu-bar panel started with Camera off and Resume Camera After Sleep disabled. Its first-use Recordings action opened the native folder picker. Selecting a disposable folder with spaces in its path saved the bookmark and revealed that folder in Finder. The owner then selected Desktop as the lasting shortcut. After quitting with the camera active and relaunching the same signed build, Camera was off, the Desktop bookmark resolved, and Recordings revealed Desktop in Finder. Cutout at 527 points, mirroring, border, and click-through settings survived the Sandbox upgrade and relaunch. Help and More Controls were left collapsed.

The owner allowed the renewed camera permission prompted by the changed ad-hoc signature. The camera reached its running state, Cutout's preparation guidance cleared without an error, and a second camera start also succeeded. Open Screen Recorder launched Apple's native Screenshot toolbar from inside Sandbox; its recording controls were inspected and the toolbar was canceled without recording. Presenter exited fully when quit. Saved-movie playback was not repeated for this security update.

Screenshot's seven location/target settings matched the pre-test XML-plist digest after the live folder and recorder checks. Temporary build/test caches were removed. Physical sleep/wake, Intel Macs, and the minimum macOS 14 runtime remain untested. The app remains a locally built ad-hoc distribution with no Developer ID or notarization. This update has not been pushed to GitHub.
