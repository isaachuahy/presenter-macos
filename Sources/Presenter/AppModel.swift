import AppKit
import Combine

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    let camera: CameraController
    private let overlay: OverlayController
    private let defaults: UserDefaults
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var pendingRecorder = false
    private var launched = false

    @Published var overlayVisible: Bool {
        didSet {
            guard oldValue != overlayVisible else { return }
            defaults.set(overlayVisible, forKey: "overlayVisible")
            if overlayVisible {
                updateOverlay()
                overlay.show()
                camera.show()
            } else {
                pendingRecorder = false
                openingRecorder = false
                overlay.hide()
                camera.hide()
            }
        }
    }
    @Published var shape: OverlayShape { didSet { persistOverlay() } }
    @Published var size: OverlaySize { didSet { persistOverlay() } }
    @Published var mirrored: Bool { didSet { persistOverlay() } }
    @Published var showsBorder: Bool { didSet { persistOverlay() } }
    @Published var clickThrough: Bool { didSet { persistOverlay() } }
    @Published private(set) var openingRecorder = false
    @Published private(set) var error: String?
    @Published private(set) var folderPath: String

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        camera = CameraController(defaults: defaults)
        overlay = OverlayController(session: camera.session, defaults: defaults)
        overlayVisible = defaults.bool(forKey: "overlayVisible")
        shape = defaults.string(forKey: "overlayShape").flatMap(OverlayShape.init(rawValue:)) ?? .circle
        size = defaults.string(forKey: "overlaySize").flatMap(OverlaySize.init(rawValue:)) ?? .medium
        mirrored = defaults.object(forKey: "mirrored") as? Bool ?? true
        showsBorder = defaults.object(forKey: "showsBorder") as? Bool ?? true
        clickThrough = defaults.bool(forKey: "clickThrough")
        folderPath = defaults.string(forKey: "recordingsFolder")
            ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.path
            ?? NSHomeDirectory()
        camera.onStateChange = { [weak self] state in self?.cameraChanged(state) }
        camera.onCutoutFrame = { [weak self] image in
            guard let self else { return }
            overlay.displayCutout(image, error: camera.cutoutError)
            finishPendingRecorder()
        }
    }

    func launch() {
        guard !launched else { return }
        launched = true
        updateOverlay()
        if overlayVisible {
            overlay.show()
            camera.show()
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.overlay.restorePlacement() }
        })
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pendingRecorder = false
                self?.openingRecorder = false
                self?.camera.hide()
                self?.overlay.hide()
            }
        })
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, overlayVisible else { return }
                overlay.show()
                camera.show()
            }
        })
    }

    /// Opens Apple's recording UI after the camera starts. The user selects the mic and confirms Record.
    func openRecorder() {
        guard !openingRecorder else { return }
        error = nil
        openingRecorder = true
        pendingRecorder = true
        if camera.state.isRunning {
            finishPendingRecorder()
        } else if overlayVisible {
            if camera.state != .starting { camera.show() }
        } else {
            overlayVisible = true
        }
    }

    func openRecorderWithoutCamera() {
        guard !openingRecorder else { return }
        overlayVisible = false
        error = nil
        openingRecorder = true
        launchScreenshot()
    }

    func retryCamera() {
        if overlayVisible { camera.show() } else { overlayVisible = true }
    }

    func resetPosition() {
        clickThrough = false
        overlay.restorePlacement(reset: true)
    }

    func openCameraSettings() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens the user's folder shortcut. Screenshot's own Options menu controls where recordings are saved.
    func openRecordingsFolder() {
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderPath, isDirectory: &directory), directory.boolValue else {
            error = "The folder is unavailable. Choose a folder, then select that location in Screenshot Options."
            return
        }
        if !NSWorkspace.shared.open(URL(fileURLWithPath: folderPath, isDirectory: true)) {
            error = "Finder could not open the folder. Choose another folder and try again."
        }
    }

    func chooseRecordingsFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Recordings Folder Shortcut"
        panel.message = "Choose the same folder in Screenshot → Options → Save to. This shortcut does not change Screenshot settings."
        panel.prompt = "Choose Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: folderPath, isDirectory: true)
        NSApplication.shared.activate()
        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            self?.folderPath = url.path
            self?.defaults.set(url.path, forKey: "recordingsFolder")
        }
    }

    func shutdown() {
        pendingRecorder = false
        overlay.hide()
        camera.shutdown()
        observers.forEach(NotificationCenter.default.removeObserver)
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        observers.removeAll()
        workspaceObservers.removeAll()
    }

    private func cameraChanged(_ state: CameraState) {
        updateOverlay()
        guard pendingRecorder else { return }
        switch state {
        case .running:
            finishPendingRecorder()
        case .denied, .restricted, .unavailable:
            pendingRecorder = false
            openingRecorder = false
        default: break
        }
    }

    private func finishPendingRecorder() {
        guard pendingRecorder else { return }
        if shape == .cutout, camera.cutoutError != nil {
            pendingRecorder = false
            openingRecorder = false
            return
        }
        guard camera.state.isRunning, shape != .cutout || camera.isCutoutReady else { return }
        pendingRecorder = false
        launchScreenshot()
    }

    private func launchScreenshot() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.screenshot.launcher") else {
            openingRecorder = false
            error = "Screenshot was not found. Press Shift-Command-5 to open the native recorder."
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { [weak self] _, launchError in
            let reason = launchError?.localizedDescription
            Task { @MainActor [weak self] in
                self?.openingRecorder = false
                if let reason { self?.error = "Could not open Screenshot: \(reason). Press Shift-Command-5." }
            }
        }
    }

    private func persistOverlay() {
        defaults.set(shape.rawValue, forKey: "overlayShape")
        defaults.set(size.rawValue, forKey: "overlaySize")
        defaults.set(mirrored, forKey: "mirrored")
        defaults.set(showsBorder, forKey: "showsBorder")
        defaults.set(clickThrough, forKey: "clickThrough")
        updateOverlay()
        finishPendingRecorder()
    }

    private func updateOverlay() {
        camera.setCutoutEnabled(shape == .cutout)
        overlay.configure(
            shape: shape, size: size, border: showsBorder, mirrored: mirrored,
            clickThrough: clickThrough, state: camera.state, cutoutError: camera.cutoutError
        )
    }
}
