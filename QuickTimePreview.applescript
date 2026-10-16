-- QuickTime exposes recording-window creation; floating and recorder options remain native manual controls.
tell application "QuickTime Player"
    activate
    new movie recording
end tell

display dialog "In QuickTime, resize and position the live movie preview. Choose View → Float on Top if available. Leave the camera Record button untouched and keep preview monitoring volume muted.\n\nContinue opens the native screen recorder. Select a display or region containing the preview, then choose your microphone and Save to folder in Options." buttons {"Cancel", "Continue"} default button "Continue" with title "QuickTime Recording Check"

tell application "QuickTime Player"
    new screen recording
end tell
