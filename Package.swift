// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Presenter",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Presenter", targets: ["Presenter"])],
    targets: [
        .executableTarget(name: "Presenter"),
        .testTarget(name: "PresenterTests", dependencies: ["Presenter"])
    ]
)
