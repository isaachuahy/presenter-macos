---
name: Presenter
description: Native macOS controls for a floating camera preview and local screen recording.
---

# Design System: Presenter

## Overview

Presenter uses a compact menu-bar popover and a separate floating camera panel. Standard macOS controls, SF Symbols, semantic colors, and system typography keep the interface familiar and lightweight. No main window opens at launch.

This document describes the implemented native interface. The Swift sources in `Sources/Presenter/` remain the source of truth. SwiftUI and AppKit semantics are intentionally preserved instead of translated into fixed CSS tokens or web components. No web preview sidecar is supplied.

The camera controls and live Circle and Cutout previews have been inspected. The user confirmed separate baseline and Cutout recordings contain the screen, moving camera, and speech. File metadata verified 1920 × 1080 video and 48 kHz stereo audio. A decoded Cutout movie frame showed the person over the desktop with the camera background removed. Cutout settings and placement persisted across relaunch.

## Colors

The popover follows the macOS appearance and control accent. SwiftUI `.primary` marks active camera status; `.secondary` marks guidance, folder details, and inactive status. Recorder and Cutout errors use `.red` alongside explanatory text. Default controls and dividers retain system styling.

Circle and Rounded use `NSColor.black` behind the preview and `NSColor.white` for the optional border. Running Cutout uses a clear background so the desktop shows through around the person. Status text is white on black for readability. These fixed preview colors belong to the camera surface only.

## Typography

Use system fonts and semantic SwiftUI styles. The app title uses `.title2.weight(.semibold)`, camera status uses `.subheadline`, the Overlay heading uses `.headline`, and instructions and supporting text use `.caption`. Controls retain native label typography.

The camera panel's centered status message uses `NSFont.systemFont(ofSize: 13, weight: .medium)`. Its wrapping text occupies 72% of the panel width. Do not replace semantic text styles with a custom font scale.

## Layout

The scrollable popover is 360 × 650 points, with 16-point outer padding and 14-point vertical spacing between sections. Dividers separate major groups. Internal groups use compact spacing from 5 to 10 points.

Preserve the implemented reading order:

1. Camera state.
2. Recorder action and recovery guidance.
3. Camera controls.
4. Overlay controls.
5. Recording Guide.
6. Folder shortcut.
7. Quit.

Circle and Rounded have Small, Medium, and Large widths of 160, 224, and 320 points. Cutout uses widths of 320, 448, and 640 points so the person is easier to see against the desktop. Circle height equals width; Rounded and Cutout height is 75% of width. Placement starts 24 points from the visible screen's lower-right corner. Saved positions are clamped to connected visible screens, and panel dimensions shrink if necessary to fit.

Fine size adjusts the selected preset from 50% to 150% in 1% steps. Its percentage readout uses monospaced digits, and Reset restores 100%. Choosing another preset also resets the adjustment. The selected preset and adjustment persist across launches. Resizing preserves the panel center where screen bounds permit.

## Elevation & Depth

The menu-bar popover delegates its background, depth, and control treatment to macOS. The camera uses a transparent, borderless, nonactivating `NSPanel` at `.floating` level. Circle and Rounded enable the AppKit window shadow; Cutout disables it. There are no custom shadow tokens. Layout changes disable implicit Core Animation actions so resizing and clipping stay aligned.

## Shapes

Circle clips to a circle; Rounded clips to a rectangle with a 20-point corner radius. Their optional white border is 3 points wide, inset 1.5 points to keep the stroke inside the clipping edge. These camera images use `.resizeAspectFill` and may crop to fill the selected shape.

Cutout displays a transparent person layer with `.resizeAspect`, preserving the image proportions without a geometric border or corner crop while running. Local Vision and Core Image processing remove the camera background. Mirroring applies once to the displayed person. Other controls retain native shapes.

## Components

- **Menu-bar entry:** `MenuBarExtra` uses the `video` SF Symbol and `.window` presentation.
- **Camera status:** a text label pairs with `video.fill` when running and `video.slash` otherwise. The accessibility label explicitly identifies camera status.
- **Recorder action:** a full-width `.borderedProminent` button with `.large` control size opens the native recorder. It reads “Preparing recorder…” and disables while opening. In Cutout, opening waits for the first valid person frame. Command-Shift-R invokes it.
- **Recovery controls:** camera guidance can expose Retry Camera, System Settings, and Open Recorder Without Camera actions. Recorder errors support text selection.
- **Camera controls:** Show Camera uses a switch; the camera picker disables when no camera is connected; Mirror Camera uses a native toggle.
- **Overlay controls:** the Style segmented picker offers Circle, Rounded, and Cutout; a second segmented picker selects size. A native Fine size slider, percentage readout, and Reset button refine the selected preset. The slider exposes its purpose and percentage to accessibility. Cutout shows local background-removal guidance and disables White Border. It shows “Removing background…” until ready, or an error with Retry Cutout. The click-through toggle has conditional text explaining how to restore dragging. Reset Camera Position has a help label.
- **Recording Guide:** a persisted disclosure group holds compact, wrapping instructions. It explains Cutout selection, microphone selection, capture area, stopping, playback checks, and camera cleanup.
- **Folder shortcut:** a standard button opens the chosen folder; an accessible `folder.badge.gearshape` button changes the shortcut. The path truncates in the middle and exposes the full path through help text. Copy states that Screenshot's Save to setting is separate.
- **Camera panel:** dragging moves the panel unless click-through is enabled. Camera status replaces the preview while it is not running. Cutout shows “Removing background…” before a valid frame or “Cutout unavailable” after failure. Style, size, mirroring, and border update through the menu-bar controls.
- **Quit:** a native button with Command-Q sits beside the camera cleanup reminder.

## Do's and Don'ts

- **Do** keep camera state above the recorder action and retain the documented section order.
- **Do** preserve semantic fonts, colors, native focus behavior, accessibility labels, and explanatory text alongside icons.
- **Do** keep the controls reachable when the camera ignores mouse events.
- **Do** describe the recording action as opening Apple's recorder; the user starts and stops capture there.
- **Don't** present the folder shortcut as changing Screenshot's save destination.
- **Don't** imply Presenter knows when Screenshot stops recording.
- **Don't** add decorative chrome, fixed web color approximations, or invented component systems to the native camera surface.
- **Don't** add a geometric border, corner crop, or window shadow to the running Cutout person layer.
- **Don't** extend the confirmed desktop recording results to untested full-screen apps, operating systems, or hardware.
