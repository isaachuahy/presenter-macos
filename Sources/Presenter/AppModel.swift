import AppKit
import Combine

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    let camera: CameraController
    private let overlay: OverlayController
    private let defaults: UserDefaults
    private let recordings: RecordingFolderStore
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var pendingRecorder = false
    private var launched = false
    private var resumeOnWake = false
    private var recorderLaunchTask: Task<Void, Never>?

    @Published var overlayVisible: Bool {
        didSet {
            guard oldValue != overlayVisible else { return }
            if overlayVisible {
                updateOverlay()
                overlay.show()
                camera.show()
            } else {
                resumeOnWake = false
                recorderLaunchTask?.cancel()
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
    @Published var resumeCameraAfterWake: Bool {
        didSet {
            defaults.set(resumeCameraAfterWake, forKey: "resumeCameraAfterWake")
            if !resumeCameraAfterWake { resumeOnWake = false }
        }
    }
    @Published private(set) var openingRecorder = false
    @Published private(set) var error: String?
    @Published private(set) var recordingsFolderPath: String?

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
        recordings = RecordingFolderStore(defaults: defaults)
        camera = CameraController(defaults: defaults)
        overlay = OverlayController(session: camera.session, defaults: defaults)
        overlayVisible = false
        defaults.removeObject(forKey: "overlayVisible")
        shape = defaults.string(forKey: "overlayShape").flatMap(OverlayShape.init(rawValue:)) ?? .circle
        let previousSize = defaults.string(forKey: "overlaySize").flatMap(OverlaySize.init(rawValue:)) ?? .medium
        sizeWidth = OverlaySize.restoredWidth(
            saved: defaults.object(forKey: "overlayWidth") as? Double,
            preset: previousSize, legacyScale: defaults.object(forKey: "overlaySizeScale") as? Double ?? 1
        )
        mirrored = defaults.object(forKey: "mirrored") as? Bool ?? true
        showsBorder = defaults.object(forKey: "showsBorder") as? Bool ?? true
        clickThrough = defaults.bool(forKey: "clickThrough")
        resumeCameraAfterWake = defaults.bool(forKey: "resumeCameraAfterWake")
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
        refreshRecordingsFolder()
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
                guard let self else { return }
                let resume = overlayVisible && resumeCameraAfterWake
                pendingRecorder = false
                openingRecorder = false
                recorderLaunchTask?.cancel()
                overlayVisible = false
                resumeOnWake = resume
            }
        })
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let resume = resumeOnWake && resumeCameraAfterWake
                resumeOnWake = false
                if resume { overlayVisible = true }
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
        Task { [weak self] in
            do { try await TrustedSystemApplication.settings.open() }
            catch { self?.error = error.localizedDescription }
        }
    }

    /// Restores only the user's explicit, read-only folder selection inside Presenter's sandbox.
    func refreshRecordingsFolder() {
        do { recordingsFolderPath = try recordings.withFolder { $0.path } }
        catch {
            recordingsFolderPath = nil
            self.error = "The Recordings shortcut is unavailable. Choose its folder again under More Controls."
        }
    }

    /// Reveals the selected folder in Finder without invoking its default application handler.
    func openRecordingsFolder() {
        do {
            let revealed: Void? = try recordings.withFolder { folder in
                recordingsFolderPath = folder.path
                NSWorkspace.shared.activateFileViewerSelecting([folder])
            }
            if revealed == nil { chooseRecordingsFolder() }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Selects a read-only Finder shortcut; Screenshot owns its recording destination.
    func chooseRecordingsFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Recordings Shortcut"
        panel.message = "Choose the folder you use in Screenshot → Options → Save to. This shortcut does not change the recording destination."
        panel.prompt = "Use Shortcut"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        NSApplication.shared.activate()
        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url, let self else { return }
            do {
                try recordings.select(url)
                recordingsFolderPath = url.path
                error = nil
                openRecordingsFolder()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func shutdown() {
        recorderLaunchTask?.cancel()
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
        recorderLaunchTask?.cancel()
        recorderLaunchTask = Task { [weak self] in
            do {
                try await TrustedSystemApplication.screenshot.open()
                guard !Task.isCancelled else { return }
                self?.openingRecorder = false
            } catch {
                guard !Task.isCancelled else { return }
                self?.openingRecorder = false
                self?.error = "Could not open Apple’s recorder: \(error.localizedDescription) Press Shift-Command-5."
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
