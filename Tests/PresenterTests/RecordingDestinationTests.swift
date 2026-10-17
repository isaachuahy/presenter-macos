import Foundation
import Testing
@testable import Presenter

struct RecordingDestinationTests {
    private let desktop = URL(fileURLWithPath: "/Users/example/Desktop", isDirectory: true)

    @Test func defaultsToDesktopWithoutUsingTheScreenshotOnlyFolder() {
        let result = ScreenshotSaveLocation.destination(
            from: ["location-screenshot": "/somewhere/else"], desktopURL: desktop
        )
        #expect(result == .folder(desktop))
    }

    @Test func recordingSettingsTakePrecedenceOverSharedSettings() {
        let preferences = [
            "target": "preview", "target-screenrecording": "file",
            "location": "/old/folder", "location-screenrecording": "/new/folder"
        ]
        let result = ScreenshotSaveLocation.destination(from: preferences, desktopURL: desktop)
        #expect(result.folderURL?.path == "/new/folder")
    }

    @Test func appOutputsNeverMasqueradeAsAFolder() {
        for (target, name) in [("preview", "QuickTime Player"), ("mail", "Mail"), ("clipboard", "Clipboard")] {
            let result = ScreenshotSaveLocation.destination(
                from: ["target-screenrecording": target, "location": "/old/folder"], desktopURL: desktop
            )
            #expect(result == .application(name))
            #expect(result.folderURL == nil)
        }
        #expect(ScreenshotSaveLocation.destination(from: ["target": "future-output"], desktopURL: desktop) == .unavailable)
    }

    @Test func pathsHandleTildesSpacesAndFileURLs() {
        let tilde = ScreenshotSaveLocation.destination(from: ["location": "~/Movies/My Recordings"], desktopURL: desktop)
        #expect(tilde.folderURL?.path == NSHomeDirectory() + "/Movies/My Recordings")
        let fileURL = ScreenshotSaveLocation.destination(from: ["location": "file:///tmp/My%20Recordings/"], desktopURL: desktop)
        #expect(fileURL.folderURL?.path == "/tmp/My Recordings")
        for invalid in ["", "relative/folder", "file:relative", "file://server/folder", "https://example.com", 42] as [Any] {
            #expect(ScreenshotSaveLocation.destination(from: ["location": invalid], desktopURL: desktop) == .unavailable)
        }
    }

    @Test func choosingAFolderUpdatesNativeSettingsWithoutChangingOtherOptions() throws {
        try withSettings { settings, root in
            CFPreferencesSetMultiple(["target-screenshot": "mail", "showsClicks": true] as CFDictionary,
                                     nil, settings.domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            _ = CFPreferencesSynchronize(settings.domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            let folder = root.appendingPathComponent("Folder With Spaces", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            try settings.setFolder(URL(fileURLWithPath: folder.path, isDirectory: false))

            let freshReader = ScreenshotSaveLocation(domain: settings.domain)
            #expect(freshReader.read() == .folder(folder))
            let preferences = UserDefaults(suiteName: settings.domain)!
            #expect(preferences.string(forKey: "location-screenshot") == folder.path)
            #expect(preferences.string(forKey: "target-screenshot") == "mail")
            #expect(preferences.bool(forKey: "showsClicks"))
        }
    }

    @Test func invalidFolderSelectionLeavesThePreviousDestinationIntact() throws {
        try withSettings { settings, root in
            try settings.setFolder(root)
            let file = root.appendingPathComponent("file.txt")
            try Data("test".utf8).write(to: file)
            for invalid in [root.appendingPathComponent("missing"), file, URL(string: "https://example.com")!] {
                #expect(throws: (any Error).self) { try settings.setFolder(invalid) }
                #expect(settings.read() == .folder(root))
            }
        }
    }

    @Test func externalPreferenceChangesAreReadWithoutRestartingPresenter() throws {
        try withSettings { settings, root in
            try settings.setFolder(root)
            let external = root.appendingPathComponent("Changed Elsewhere", isDirectory: true)
            try FileManager.default.createDirectory(at: external, withIntermediateDirectories: false)
            let writer = Process()
            writer.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            writer.arguments = ["write", settings.domain, "location-screenrecording", "-string", external.path]
            try writer.run()
            writer.waitUntilExit()
            #expect(writer.terminationStatus == 0)
            #expect(settings.read() == .folder(external))
        }
    }

    private func withSettings(_ body: (ScreenshotSaveLocation, URL) throws -> Void) throws {
        let domain = "local.presenter.tests." + UUID().uuidString
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer {
            let keys = CFPreferencesCopyKeyList(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            CFPreferencesSetMultiple(nil, keys, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            _ = CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            try? FileManager.default.removeItem(at: root)
        }
        try body(ScreenshotSaveLocation(domain: domain), root)
    }
}
