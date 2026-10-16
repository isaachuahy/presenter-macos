# Presenter

## Purpose

A lightweight macOS menu-bar utility for local screen recordings with a live webcam overlay and microphone speech in one movie. The supplied goal objective is the product specification.

## Platform and mechanism

Native macOS 14 or newer, Swift 6, SwiftUI, AppKit, and AVFoundation. The app displays a camera-only floating panel. Apple's Screenshot app records the desktop, microphone, and visible panel and saves the movie locally.

The user clarified that a true person cutout is required: retain the person and make the camera background transparent, like FaceTime screen sharing. Vision supplies a local person mask and Core Image composites the cutout. Circle and Rounded remain available as simpler styles.

## Confirmed constraints

- No external packages, network services, subscriptions, or custom encoding pipeline.
- No separate camera movie or microphone session in Presenter.
- The user starts and stops recording with native macOS controls.
- The overlay supports camera selection, mirroring, size, Circle/Rounded/Cutout style, border for geometric styles, dragging, click-through, and saved preferences.
- No main window opens at launch. Guidance lives inside the menu-bar popover.
- Implementation proceeds one source file at a time. No push is authorized.
- Distribution starts with a source-based GitHub checkout and one local install command. Prebuilt downloads and notarization are deferred at the user's request.

## Interface direction

Use standard macOS controls, semantic system colors, system typography, and SF Symbols. The popover follows system light/dark appearance. Camera state is visible above the recording action. Guidance explains microphone selection, recording area, stopping, and cleanup. The overlay adds only the camera image and optional white border to the desktop.

## Assumptions and open checks

- “Presenter” is a working app name; no branding was supplied.
- Target macOS 14+ to use current camera discovery APIs without compatibility branches.
- Whole-display or region recording must contain the overlay. Single-window capture can omit it.
- The user confirmed the baseline saved movie contains screen, moving camera, and speech. Its video and audio tracks were inspected independently.
- The user also confirmed a saved Cutout recording contains the screen, moving person, and speech. A decoded movie frame independently showed the desktop around the person with the camera background removed.
- Full-screen behavior, multiple physical devices, Intel Macs, and the macOS 14 minimum target still require empirical checks. See RESEARCH.md.
