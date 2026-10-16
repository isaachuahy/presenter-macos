@preconcurrency import AVFoundation
import Combine

struct CameraChoice: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
}

enum CameraState: Equatable, Sendable {
    case stopped
    case starting
    case running(String)
    case denied
    case restricted
    case unavailable(String)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var title: String {
        switch self {
        case .stopped: "Camera off"
        case .starting: "Starting camera…"
        case .running(let name): name
        case .denied: "Camera permission needed"
        case .restricted: "Camera access restricted"
        case .unavailable: "Camera unavailable"
        }
    }

    var guidance: String? {
        switch self {
        case .denied:
            "Allow Presenter in System Settings → Privacy & Security → Camera, then retry."
        case .restricted:
            "Camera access is restricted by this Mac’s policy."
        case .unavailable(let reason): reason
        default: nil
        }
    }
}

// AVFoundation session mutations stay on this serial queue; only its stable reference goes to the preview layer.
private final class CameraCapture: @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "Presenter.camera", qos: .userInitiated)
    private let cutout = CutoutProcessor()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var cutoutEnabled = false

    func setCutoutEnabled(_ enabled: Bool, report: @escaping @Sendable (CutoutResult) -> Void) {
        queue.async { [self] in
            cutoutEnabled = enabled
            cutout.configure(enabled: enabled, report: report)
            guard !session.inputs.isEmpty else { return }
            session.beginConfiguration()
            let configured = configureVideoOutput()
            session.commitConfiguration()
            if !configured {
                report(.failure("This camera cannot provide frames for Cutout. Choose Circle or Rounded."))
            }
        }
    }

    func start(
        deviceID: String, cutoutEnabled: Bool,
        cutoutReport: @escaping @Sendable (CutoutResult) -> Void,
        report: @escaping @Sendable (CameraState) -> Void
    ) {
        queue.async { [self] in
            guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
                releaseCamera()
                report(.denied)
                return
            }
            guard let device = AVCaptureDevice(uniqueID: deviceID), device.isConnected else {
                releaseCamera()
                report(.unavailable("Connect a camera, then choose Retry Camera."))
                return
            }
            do {
                let input = try AVCaptureDeviceInput(device: device)
                videoOutput.setSampleBufferDelegate(nil, queue: nil)
                if session.isRunning { session.stopRunning() }
                self.cutoutEnabled = cutoutEnabled
                cutout.configure(enabled: cutoutEnabled, report: cutoutReport)
                session.beginConfiguration()
                session.inputs.forEach(session.removeInput)
                let canAdd = session.canAddInput(input)
                if canAdd {
                    session.addInput(input)
                    if session.canSetSessionPreset(.hd1280x720) {
                        session.sessionPreset = .hd1280x720
                    }
                }
                let outputConfigured = canAdd && configureVideoOutput()
                session.commitConfiguration()
                guard canAdd else {
                    releaseCamera()
                    report(.unavailable("This camera cannot provide a preview. Choose another camera."))
                    return
                }
                guard outputConfigured else {
                    releaseCamera()
                    report(.unavailable("This camera cannot provide Cutout frames. Choose Circle or Rounded, then retry."))
                    return
                }
                session.startRunning()
                if session.isRunning {
                    report(.running(device.localizedName))
                } else {
                    releaseCamera()
                    report(.unavailable("The camera did not start. Close other camera apps, then retry."))
                }
            } catch {
                releaseCamera()
                report(.unavailable(error.localizedDescription))
            }
        }
    }

    func stop() {
        queue.async { [self] in releaseCamera() }
    }

    func stopAndWait() {
        queue.sync { releaseCamera() }
    }

    private func releaseCamera() {
        if session.isRunning { session.stopRunning() }
        session.beginConfiguration()
        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)
        session.commitConfiguration()
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
        cutout.suspend()
    }

    private func configureVideoOutput() -> Bool {
        if !cutoutEnabled {
            if session.outputs.contains(videoOutput) { session.removeOutput(videoOutput) }
            videoOutput.setSampleBufferDelegate(nil, queue: nil)
            return true
        }
        if !session.outputs.contains(videoOutput) {
            guard session.canAddOutput(videoOutput) else { return false }
            session.addOutput(videoOutput)
        }
        let formats = videoOutput.availableVideoPixelFormatTypes
        let preferred = [kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                         kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                         kCVPixelFormatType_32BGRA]
        if let format = preferred.first(where: formats.contains) {
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: format]
        }
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(cutout, queue: cutout.queue)
        if let connection = videoOutput.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
        return true
    }
}

@MainActor
final class CameraController: ObservableObject {
    @Published private(set) var choices: [CameraChoice] = []
    @Published private(set) var selectedID = ""
    @Published private(set) var state: CameraState = .stopped
    @Published private(set) var cutoutError: String?
    @Published private(set) var isCutoutReady = false
    var onStateChange: ((CameraState) -> Void)?
    var onCutoutFrame: ((CGImage?) -> Void)?

    var session: AVCaptureSession { capture.session }
    private let capture = CameraCapture()
    private let defaults: UserDefaults
    private var wantsPreview = false
    private var generation = 0
    private var cutoutRevision = 0
    private var cutoutEnabled = false
    private let frameDelivery = DispatchSemaphore(value: 1)
    private var observers: [NSObjectProtocol] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedID = defaults.string(forKey: "cameraID") ?? ""
        refreshDevices()
        let center = NotificationCenter.default
        for event in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            observers.append(center.addObserver(forName: event, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refreshDevices() }
            })
        }
        observers.append(center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: .main
        ) { [weak self] notification in
            let reason = (notification.userInfo?[AVCaptureSessionErrorKey] as? NSError)?.localizedDescription
                ?? "Camera capture stopped. Choose Retry Camera."
            Task { @MainActor [weak self] in self?.captureFailed(reason) }
        })
        observers.append(center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.captureFailed("Camera capture was interrupted. Close other camera apps, then retry.")
            }
        })
        observers.append(center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, wantsPreview else { return }
                show()
            }
        })
    }

    /// Requests camera access if needed and starts video-only preview. No microphone input is created.
    func show() {
        wantsPreview = true
        generation += 1
        let request = generation
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: startAuthorized(request: request)
        case .notDetermined:
            setState(.starting)
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self, wantsPreview, generation == request else { return }
                    if granted { startAuthorized(request: request) } else { setState(.denied) }
                }
            }
        case .denied: capture.stop(); setState(.denied)
        case .restricted: capture.stop(); setState(.restricted)
        @unknown default: capture.stop(); setState(.unavailable("Unknown camera permission state."))
        }
    }

    /// Stops preview and releases camera inputs. Pending permission and startup callbacks are ignored.
    func hide() {
        wantsPreview = false
        generation += 1
        capture.stop()
        setState(.stopped)
    }

    func select(_ id: String) {
        guard choices.contains(where: { $0.id == id }), id != selectedID else { return }
        selectedID = id
        defaults.set(id, forKey: "cameraID")
        if wantsPreview { show() }
    }

    /// Enables person segmentation without changing the native microphone or screen recorder.
    func setCutoutEnabled(_ enabled: Bool) {
        guard enabled != cutoutEnabled else { return }
        cutoutEnabled = enabled
        cutoutError = nil
        isCutoutReady = false
        onCutoutFrame?(nil)
        capture.setCutoutEnabled(enabled, report: makeCutoutReporter())
    }

    func refreshDevices() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video, position: .unspecified
        )
        choices = discovery.devices.map { CameraChoice(id: $0.uniqueID, name: $0.localizedName) }
        let previous = selectedID
        if !choices.contains(where: { $0.id == selectedID }) {
            selectedID = choices.first?.id ?? ""
            if !selectedID.isEmpty { defaults.set(selectedID, forKey: "cameraID") }
        }
        if wantsPreview, previous != selectedID || !state.isRunning { show() }
    }

    func shutdown() {
        wantsPreview = false
        generation += 1
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        capture.stopAndWait()
    }

    private func startAuthorized(request: Int) {
        guard !selectedID.isEmpty else {
            capture.stop()
            setState(.unavailable("No camera found. Connect a camera, then choose Retry Camera."))
            return
        }
        setState(.starting)
        capture.start(deviceID: selectedID, cutoutEnabled: cutoutEnabled, cutoutReport: makeCutoutReporter()) { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self, wantsPreview, generation == request else { return }
                setState(state)
            }
        }
    }

    private func captureFailed(_ reason: String) {
        guard wantsPreview else { return }
        generation += 1
        capture.stop()
        setState(.unavailable(reason))
    }

    private func setState(_ state: CameraState) {
        self.state = state
        if !state.isRunning {
            isCutoutReady = false
            cutoutError = nil
            onCutoutFrame?(nil)
        }
        onStateChange?(state)
    }

    private func makeCutoutReporter() -> @Sendable (CutoutResult) -> Void {
        cutoutRevision += 1
        let revision = cutoutRevision
        let request = generation
        return { [weak self, frameDelivery] result in
            // Keep only one image in flight so a busy main actor cannot accumulate camera textures.
            guard frameDelivery.wait(timeout: .now()) == .success else { return }
            Task { @MainActor [weak self] in
                defer { frameDelivery.signal() }
                guard let self, cutoutEnabled, generation == request, cutoutRevision == revision else { return }
                switch result {
                case .frame(let image):
                    guard state.isRunning else { return }
                    if cutoutError != nil { cutoutError = nil }
                    if !isCutoutReady { isCutoutReady = true }
                    onCutoutFrame?(image)
                case .failure(let reason):
                    if cutoutError != reason { cutoutError = reason }
                    isCutoutReady = false
                    onCutoutFrame?(nil)
                }
            }
        }
    }
}
