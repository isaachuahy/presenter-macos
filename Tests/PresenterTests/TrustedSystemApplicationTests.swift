import Foundation
import Testing
@testable import Presenter

struct TrustedSystemApplicationTests {
    @Test func nativeSystemInstallationsPassVerification() throws {
        for application in TrustedSystemApplication.allCases {
            let verified = try application.verifiedURL()
            #expect(verified == application.url)
        }
    }

    @Test func differentAppleApplicationIsRejected() {
        let calculator = URL(fileURLWithPath: "/System/Applications/Calculator.app", isDirectory: true)
        #expect(!TrustedSystemApplication.hasAppleSignature(at: calculator, for: .screenshot))
    }

    @Test func missingApplicationIsRejected() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".app")
        #expect(!TrustedSystemApplication.hasAppleSignature(at: missing, for: .screenshot))
    }

    @Test func adHocApplicationWithMatchingIdentifierIsRejected() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let application = root.appendingPathComponent("Impostor.app", isDirectory: true)
        let contents = application.appendingPathComponent("Contents", isDirectory: true)
        let executableDirectory = contents.appendingPathComponent("MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: executableDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.copyItem(
            at: URL(fileURLWithPath: "/usr/bin/true"), to: executableDirectory.appendingPathComponent("Impostor")
        )
        let info = ["CFBundleIdentifier": "com.apple.screenshot.launcher", "CFBundleExecutable": "Impostor",
                    "CFBundlePackageType": "APPL", "CFBundleName": "Impostor"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        let signer = Process()
        signer.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        signer.arguments = ["--force", "--sign", "-", "--identifier", "com.apple.screenshot.launcher", application.path]
        try signer.run()
        signer.waitUntilExit()
        try #require(signer.terminationStatus == 0)
        #expect(!TrustedSystemApplication.hasAppleSignature(at: application, for: .screenshot))
    }
}
