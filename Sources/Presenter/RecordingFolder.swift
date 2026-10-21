import Foundation

enum RecordingFolder {
    /// Accepts existing local directories and rejects packages, including applications and symlinks to them.
    static func validate(_ url: URL) throws -> URL {
        guard url.isFileURL, url.path.hasPrefix("/"),
              url.host == nil || url.host == "" || url.host == "localhost" else {
            throw RecordingFolderError.unavailable
        }
        let folder = url.resolvingSymlinksInPath().standardizedFileURL
        let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isApplicationKey])
        guard values.isDirectory == true, values.isPackage != true, values.isApplication != true else {
            throw RecordingFolderError.unavailable
        }
        return folder
    }
}

struct RecordingFolderStore {
    private let defaults: UserDefaults
    private let key = "recordingsFolderBookmark"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Stores read-only access to a folder explicitly selected through the native open panel.
    func select(_ url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        _ = try RecordingFolder.validate(url)
        let bookmark = try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil, relativeTo: nil
        )
        defaults.set(bookmark, forKey: key)
    }

    /// Runs an action while the saved folder's security-scoped access is active; returns nil if none is selected.
    func withFolder<Value>(_ action: (URL) -> Value) throws -> Value? {
        guard let bookmark = defaults.data(forKey: key) else { return nil }
        var stale = false
        let url = try URL(
            resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI],
            relativeTo: nil, bookmarkDataIsStale: &stale
        )
        guard url.startAccessingSecurityScopedResource() else {
            throw RecordingFolderError.accessExpired
        }
        defer { url.stopAccessingSecurityScopedResource() }
        let folder = try RecordingFolder.validate(url)
        if stale { try select(url) }
        return action(folder)
    }
}

private enum RecordingFolderError: LocalizedError {
    case unavailable
    case accessExpired

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Choose an existing folder for the Recordings shortcut. Applications and other packages cannot be used."
        case .accessExpired:
            "Folder access has expired. Choose the Recordings shortcut again under More Controls."
        }
    }
}
