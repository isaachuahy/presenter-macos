import Foundation
import Testing
@testable import Presenter

struct RecordingFolderTests {
    @Test func ordinaryDirectoryWithSpacesIsAccepted() throws {
        try withFolder { folder, _ in
            let validated = try RecordingFolder.validate(folder)
            #expect(validated.path == folder.resolvingSymlinksInPath().path)
        }
    }

    @Test func applicationsAndSymlinksToApplicationsAreRejected() throws {
        let application = URL(fileURLWithPath: "/System/Applications/Calculator.app", isDirectory: true)
        #expect(throws: (any Error).self) { try RecordingFolder.validate(application) }
        try withFolder { folder, store in
            let link = folder.appendingPathComponent("Looks Like A Folder", isDirectory: true)
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: application)
            #expect(throws: (any Error).self) { try RecordingFolder.validate(link) }
            #expect(throws: (any Error).self) { try store.select(link) }
        }
    }

    @Test func filesMissingFoldersAndRemoteURLsAreRejected() throws {
        try withFolder { folder, _ in
            let file = folder.appendingPathComponent("recording.mov")
            try Data().write(to: file)
            for invalid in [file, folder.appendingPathComponent("missing"),
                            URL(string: "https://example.com")!, URL(string: "file://server/folder")!] {
                #expect(throws: (any Error).self) { try RecordingFolder.validate(invalid) }
            }
        }
    }

    @Test func absentOrCorruptBookmarksNeverRunTheFolderAction() throws {
        let suite = "local.presenter.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RecordingFolderStore(defaults: defaults)
        let absent = try store.withFolder { _ in true }
        #expect(absent == nil)
        defaults.set(Data("invalid bookmark".utf8), forKey: "recordingsFolderBookmark")
        var ran = false
        #expect(throws: (any Error).self) { try store.withFolder { _ in ran = true } }
        #expect(!ran)
    }

    private func withFolder(_ body: (URL, RecordingFolderStore) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Presenter Folder " + UUID().uuidString, isDirectory: true)
        let suite = "local.presenter.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: folder)
        }
        try body(folder, RecordingFolderStore(defaults: defaults))
    }
}
