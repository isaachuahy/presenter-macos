import AppKit
import Security

enum TrustedSystemApplication: CaseIterable, Sendable {
    case screenshot
    case settings

    var name: String {
        switch self {
        case .screenshot: "Screenshot"
        case .settings: "System Settings"
        }
    }

    var url: URL {
        let path = switch self {
        case .screenshot: "/System/Applications/Utilities/Screenshot.app"
        case .settings: "/System/Applications/System Settings.app"
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    var identifier: String {
        switch self {
        case .screenshot: "com.apple.screenshot.launcher"
        case .settings: "com.apple.systempreferences"
        }
    }

    /// Opens the verified system app, preventing substitution by another running installation.
    @MainActor
    func open() async throws {
        let location = try await Task.detached(priority: .userInitiated) { try verifiedURL() }.value
        try Task.checkCancellation()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.allowsRunningApplicationSubstitution = false
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            NSWorkspace.shared.openApplication(at: location, configuration: configuration) { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    /// Returns the protected system installation only after verifying Apple's signature and signing identifier.
    func verifiedURL() throws -> URL {
        guard url.resolvingSymlinksInPath().standardizedFileURL == url.standardizedFileURL,
              Self.hasAppleSignature(at: url, for: self) else {
            throw VerificationError(application: name)
        }
        return url
    }

    /// Checks all architectures against Apple proper, excluding third-party Developer ID signatures.
    static func hasAppleSignature(at url: URL, for application: Self) -> Bool {
        var code: SecStaticCode?
        var requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess,
              let code,
              SecRequirementCreateWithString(
                "anchor apple and identifier \"\(application.identifier)\"" as CFString, [], &requirement
              ) == errSecSuccess,
              let requirement else { return false }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate)
        return SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess
    }

    private struct VerificationError: LocalizedError {
        let application: String

        var errorDescription: String? {
            "Could not verify Apple’s \(application) at its system location. Open it directly from macOS."
        }
    }
}
