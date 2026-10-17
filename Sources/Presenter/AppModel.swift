import AppKit
import Combine

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    let camera: CameraController
    private let overlay: OverlayController
    private let defaults: UserDefaults
    private let saveLocation = ScreenshotSaveLocation()
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
    @Published private var sizeWidth: Double { didSet { persistOverlay() } }
    @Published var mirrored: Bool { didSet { persistOverlay() } }
    @Published var showsBorder: Bool { didSet { persistOverlay() } }
    @Published var clickThrough: Bool { didSet { persistOverlay() } }
    @Published private(set) var openingRecorder = false
    @Published private(set) var error: String?
    @Published private(set) var recordingDestination: RecordingDestination

    var overlayWidth: Double {
        get { sizeWidth * shape.sizeMultiplier }
        set { sizeWidth = OverlaySize.clampedWidth(newValue.rounded() / shape.sizeMultiplier) }
    }

    var sizeRange: ClosedRange<Double> {
        let multiplier = shape.sizeMultiplier
        return (OverlaySize.widthRange.lowerBound * multiplier)...(OverlaySize.widthRange.upperBound * multiplier)
    }

    var selectedSize: OverlaySize? {
        OverlaySize.allCases.first { $0.width == sizeWidth }
    }

    func selectSize(_ preset: OverlaySize) {
        sizeWidth = preset.width
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        camera = CameraController(defaults: defaults)
        overlay = OverlayController(session: camera.session, defaults: defaults)
        overlayVisible = defaults.bool(forKey: "overlayVisible")
        shape = defaults.string(forKey: "overlayShape").flatMap(OverlayShape.init(rawValue:)) ?? .circle
        let previousSize = defaults.string(forKey: "overlaySize").flatMap(OverlaySize.init(rawValue:)) ?? .medium
        sizeWidth = OverlaySize.restoredWidth(
            saved: defaults.object(forKey: "overlayWidth") as? Double,
            preset: previousSize, legacyScale: defaults.object(forKey: "overlaySizeScale") as? Double ?? 1
        )
        mirrored = defaults.object(forKey: "mirrored") as? Bool ?? true
        showsBorder = defaults.object(forKey: "showsBorder") as? Bool ?? true
        clickThrough = defaults.bool(forKey: "clickThrough")
        recordingDestination = saveLocation.read()
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
        for notification in [NSApplication.didBecomeActiveNotification, NSWindow.didBecomeKeyNotification] {
            observers.append(NotificationCenter.default.addObserver(
                forName: notification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refreshRecordingDestination() }
            })
        }
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

    /// Reloads Screenshot's destination so folder actions follow changes made in its Options menu.
    func refreshRecordingDestination() {
        let current = saveLocation.read()
        if current != recordingDestination { recordingDestination = current }
    }

    /// Opens Screenshot's current recording folder, or explains why no folder is available.
    func openRecordingsFolder() {
        refreshRecordingDestination()
        guard let folder = recordingDestination.folderURL else {
            error = "Screenshot is not saving recordings to a folder. Choose a recording save location under More Controls."
            return
        }
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &directory), directory.boolValue else {
            error = "The recording folder is unavailable. Choose another save location under More Controls."
            return
        }
        NSWorkspace.shared.open(folder, configuration: .init()) { [weak self] _, openError in
            guard let reason = openError?.localizedDescription else { return }
            Task { @MainActor [weak self] in
                self?.error = "Finder could not open the recording folder: \(reason)"
            }
        }
    }

    /// Changes Screenshot's shared save folder, then refreshes every Presenter folder action.
    func chooseRecordingsFolder() {
        refreshRecordingDestination()
        let panel = NSOpenPanel()
        panel.title = "Choose Recording Save Location"
        panel.message = "This updates Screenshot’s Save to folder, including screenshots saved as files. It applies when you next open the recorder."
        panel.prompt = "Use Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = recordingDestination.folderURL
        NSApplication.shared.activate()
        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url, let self else { return }
            do {
                try saveLocation.setFolder(url)
                refreshRecordingDestination()
                error = nil
            } catch {
                self.error = error.localizedDescription
            }
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
        refreshRecordingDestination()
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
        defaults.set(sizeWidth, forKey: "overlayWidth")
        defaults.set(mirrored, forKey: "mirrored")
        defaults.set(showsBorder, forKey: "showsBorder")
        defaults.set(clickThrough, forKey: "clickThrough")
        updateOverlay()
        finishPendingRecorder()
    }

    private func updateOverlay() {
        camera.setCutoutEnabled(shape == .cutout)
        overlay.configure(
            shape: shape, width: sizeWidth, border: showsBorder, mirrored: mirrored,
            clickThrough: clickThrough, state: camera.state, cutoutError: camera.cutoutError
        )
    }
}
