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

The popover follows the macOS appearance and control accent. SwiftUI `.primary` marks control labels; `.secondary` marks camera status, guidance, and folder details. Recorder and Cutout errors use `.red` alongside explanatory text. Default controls and dividers retain system styling.

Circle and Rounded use `NSColor.black` behind the preview and `NSColor.white` for the optional border. Running Cutout uses a clear background so the desktop shows through around the person. Status text is white on black for readability. These fixed preview colors belong to the camera surface only.

## Typography

Use system fonts and semantic SwiftUI styles. The title uses `.title2.weight(.semibold)` (17 points on macOS). Controls and labels use `.body` (13 points); section headings and the recorder action use the same size with semibold weight. Camera status, instructions, and secondary details use `.subheadline` (12 points). The size measurement alone uses monospaced digits. Controls retain native focus and label behavior.

The camera panel's centered status message uses `NSFont.systemFont(ofSize: 13, weight: .medium)`. Its wrapping text occupies 72% of the panel width. Do not replace semantic text styles with a custom font scale.

## Layout

The popover is 360 × 510 points with core controls visible. Expanding More Controls or Help increases its height to 650 points. The scene uses `.windowResizability(.contentSize)` so its outer window follows those dimensions when controls collapse, without leaving transparent bands around the content. The header, recorder action, and footer remain fixed while the middle settings area scrolls. Outer padding and spacing between sections are 16 points. Dividers separate groups; internal spacing ranges from 5 to 12 points.

Preserve the implemented reading order:

1. Presenter title and quiet camera state.
2. Open Screen Recorder and a short microphone hint, followed by any recovery guidance.
3. Show Camera and camera selection.
4. Appearance: style, continuous size slider, and preset buttons.
5. More Controls, initially collapsed: mirroring, border, click-through, position reset, and folder shortcut settings.
6. Recording Guide, revealed by Help in the footer.
7. Fixed footer: Recordings, Help, and Quit.

Circle and Rounded have Small, Medium, and Large widths of 160, 224, and 320 points. Cutout uses widths of 320, 448, and 640 points so the person is easier to see against the desktop. Circle height equals width; Rounded and Cutout height is 75% of width. Placement starts 24 points from the visible screen's lower-right corner. Saved positions are clamped to connected visible screens, and panel dimensions shrink if necessary to fit.

Size uses one continuous range, independent of the preset buttons. Circle and Rounded span 128–384 points; Cutout spans 256–768 points. Small, Medium, and Large are fixed points inside the range: pressing a preset snaps to its width, while other values leave all three buttons unselected. The readout shows width in points with monospaced digits. The slider supports one-point accessibility adjustments, and its value persists across launches. Existing preset-relative settings migrate to the equivalent width where it fits the new range. Resizing preserves the panel center where screen bounds permit.

## Elevation & Depth

On macOS 26 and later, builds made with Swift 6.2 or later give the whole panel one native `.glassEffect(.regular, in: .rect(cornerRadius: 20))` surface. The window's standard backing is cleared with `.containerBackground(.clear, for: .window)` so it does not obscure the glass. The system supplies the material, edge treatment, and foreground adaptation. The recorder uses a standard `.borderedProminent` filled button within that shared surface; do not add another glass layer to each control or settings group.

Older systems and toolchains retain the native system popover material. The minimum remains macOS 14. Native materials, semantic colors, and controls handle appearance and accessibility preferences. Do not approximate the glass with custom blur, opacity, gradients, borders, or shadows.

The camera uses a transparent, borderless, nonactivating `NSPanel` at `.floating` level. Circle and Rounded enable the AppKit window shadow; Cutout disables it. There are no custom shadow tokens. Layout changes disable implicit Core Animation actions so resizing and clipping stay aligned.

## Shapes

Circle clips to a circle; Rounded clips to a rectangle with a 20-point corner radius. Their optional white border is 3 points wide, inset 1.5 points to keep the stroke inside the clipping edge. These camera images use `.resizeAspectFill` and may crop to fill the selected shape.

Cutout displays a transparent person layer with `.resizeAspect`, preserving the image proportions without a geometric border or corner crop while running. Local Vision and Core Image processing remove the camera background. Mirroring applies once to the displayed person. Other controls retain native shapes.

## Components

- **Menu-bar entry:** `MenuBarExtra` uses the `video` SF Symbol and `.window` presentation.
- **Camera status:** a text label pairs with `video.fill` when running and `video.slash` otherwise. The accessibility label explicitly identifies camera status.
- **Recorder action:** a full-width native prominent button with `.large` control size stays above the scrollable settings. It reads “Preparing recorder…” and disables while opening. In Cutout, opening waits for the first valid person frame. Command-Shift-R invokes it.
- **Recovery controls:** camera guidance can expose Retry Camera, System Settings, and Open Recorder Without Camera actions. Recorder errors support text selection.
- **Camera controls:** Show Camera uses a switch; the camera picker disables when no camera is connected. Mirror Camera is under More Controls.
- **Overlay controls:** the Style segmented picker offers Circle, Rounded, and Cutout. Size has one native slider with a point-width readout and three native toggle-style preset buttons below it. Their selected states follow the current width; clicking a preset snaps the slider to that point. The slider exposes its purpose and width to accessibility. Cutout shows local background-removal guidance and disables White Border. It shows “Removing background…” until ready, or an error with Retry Cutout. The click-through toggle has conditional text explaining how to restore dragging. Reset Camera Position has a help label.
- **Recording Guide:** Help reveals compact, wrapping instructions and scrolls them into view. The guide starts hidden. It explains Cutout selection, microphone selection, capture area, stopping, playback checks, and camera cleanup.
- **Folder shortcut:** Recordings in the footer opens the chosen folder. Choose Recordings Folder under More Controls changes the shortcut. The path truncates in the middle and exposes the full path through help text. Copy states that Screenshot's Save to setting is separate.
- **Camera panel:** dragging moves the panel unless click-through is enabled. Camera status replaces the preview while it is not running. Cutout shows “Removing background…” before a valid frame or “Cutout unavailable” after failure. Style, size, mirroring, and border update through the menu-bar controls.
- **Quit:** a native footer button supports Command-Q.

## Do's and Don'ts

- **Do** keep the recorder action immediately accessible and retain the documented section order.
- **Do** preserve semantic fonts, colors, native focus behavior, accessibility labels, and explanatory text alongside icons.
- **Do** keep the controls reachable when the camera ignores mouse events.
- **Do** describe the recording action as opening Apple's recorder; the user starts and stops capture there.
- **Don't** present the folder shortcut as changing Screenshot's save destination.
- **Don't** imply Presenter knows when Screenshot stops recording.
- **Don't** add decorative chrome, fixed web color approximations, or invented component systems to the native camera surface.
- **Don't** add a geometric border, corner crop, or window shadow to the running Cutout person layer.
- **Don't** extend the confirmed desktop recording results to untested full-screen apps, operating systems, or hardware.
