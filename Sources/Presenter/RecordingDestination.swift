import Foundation

enum RecordingDestination: Equatable {
    case folder(URL)
    case application(String)
    case unavailable

    var folderURL: URL? {
        if case let .folder(url) = self { return url }
        return nil
    }

    var description: String {
        switch self {
        case let .folder(url): url.path
        case let .application(name): "Opens in \(name)"
        case .unavailable: "Choose a recording save folder."
        }
    }
}

struct ScreenshotSaveLocation {
    let domain: String
    let desktopURL: URL

    init(
        domain: String = "com.apple.screencapture",
        desktopURL: URL? = nil
    ) {
        self.domain = domain
        self.desktopURL = desktopURL
            ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
    }

    /// Reads Screenshot's recording destination, including non-folder output modes.
    func read() -> RecordingDestination {
        guard synchronize() else { return .unavailable }
        return Self.destination(from: values(), desktopURL: desktopURL)
    }

    /// Sets Screenshot's shared file destination. Existing folders must be writable.
    func setFolder(_ url: URL) throws {
        guard url.isFileURL, url.path.hasPrefix("/"),
              url.host == nil || url.host == "" || url.host == "localhost" else {
            throw SaveLocationError.invalidFolder
        }
        let folder = URL(fileURLWithPath: url.standardizedFileURL.path, isDirectory: true)
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &directory), directory.boolValue else {
            throw SaveLocationError.invalidFolder
        }
        guard FileManager.default.isWritableFile(atPath: folder.path) else {
            throw SaveLocationError.notWritable
        }
        guard synchronize() else { throw SaveLocationError.saveFailed }

        // These Screenshot preference keys mirror its native folder picker, but aren't a public API contract.
        let changes = [
            "location": folder.path,
            "location-last": folder.path,
            "location-screenrecording": folder.path,
            "location-screenshot": folder.path,
            "target": "file",
            "target-screenrecording": "file"
        ]
        let previous = values(keys: Array(changes.keys))
        CFPreferencesSetMultiple(changes as CFDictionary, nil, domain as CFString,
                                 kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard synchronize(), read() == .folder(folder) else {
            let absentKeys = changes.keys.filter { previous[$0] == nil }
            CFPreferencesSetMultiple(previous as CFDictionary, absentKeys as CFArray, domain as CFString,
                                     kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            _ = synchronize()
            throw SaveLocationError.saveFailed
        }
    }

    static func destination(from preferences: [String: Any], desktopURL: URL) -> RecordingDestination {
        let rawTarget = preferences["target-screenrecording"] ?? preferences["target"] ?? "file"
        guard let target = rawTarget as? String else { return .unavailable }
        switch target {
        case "file": break
        case "preview": return .application("QuickTime Player")
        case "mail": return .application("Mail")
        case "messages": return .application("Messages")
        case "clipboard": return .application("Clipboard")
        default: return .unavailable
        }

        guard let value = preferences["location-screenrecording"] ?? preferences["location"] else {
            return .folder(desktopURL.standardizedFileURL)
        }
        guard let path = value as? String, !path.isEmpty else { return .unavailable }
        if path.hasPrefix("file:") {
            guard let url = URL(string: path), url.isFileURL, url.path.hasPrefix("/"),
                  url.host == nil || url.host == "" || url.host == "localhost" else { return .unavailable }
            return .folder(url.standardizedFileURL)
        }
        let expanded = (path as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") else { return .unavailable }
        return .folder(URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL)
    }

    private func values(keys: [String] = ["target-screenrecording", "target", "location-screenrecording", "location"]) -> [String: Any] {
        CFPreferencesCopyMultiple(keys as CFArray, domain as CFString,
                                  kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String: Any] ?? [:]
    }

    private func synchronize() -> Bool {
        CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
}

private enum SaveLocationError: LocalizedError {
    case invalidFolder
    case notWritable
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .invalidFolder: "That folder is unavailable. Choose an existing folder for recordings."
        case .notWritable: "That folder cannot be written to. Choose another recording save folder."
        case .saveFailed: "Could not update Screenshot’s save location. Choose it in Screenshot → Options → Save to, then reopen Presenter."
        }
    }
}
