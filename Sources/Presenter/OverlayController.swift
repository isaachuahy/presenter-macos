import AppKit
@preconcurrency import AVFoundation

@MainActor
private final class CameraPreviewView: NSView {
    private let preview: AVCaptureVideoPreviewLayer
    private let person = CALayer()
    private let border = CAShapeLayer()
    private let message = NSTextField(wrappingLabelWithString: "Starting camera…")
    private var shape: OverlayShape = .circle
    private var showsBorder = true
    private var state: CameraState = .stopped
    private var cutoutError: String?

    override var mouseDownCanMoveWindow: Bool { true }

    init(session: AVCaptureSession) {
        preview = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        preview.videoGravity = .resizeAspectFill
        layer?.addSublayer(preview)
        person.contentsGravity = .resizeAspect
        person.masksToBounds = true
        layer?.addSublayer(person)
        border.fillColor = nil
        border.strokeColor = NSColor.white.cgColor
        border.lineWidth = 3
        layer?.addSublayer(border)
        message.textColor = .white
        message.backgroundColor = .black
        message.drawsBackground = true
        message.font = .systemFont(ofSize: 13, weight: .medium)
        message.alignment = .center
        message.translatesAutoresizingMaskIntoConstraints = false
        addSubview(message)
        NSLayoutConstraint.activate([
            message.centerXAnchor.constraint(equalTo: centerXAnchor),
            message.centerYAnchor.constraint(equalTo: centerYAnchor),
            message.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.72)
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Camera preview. Drag to reposition; use Presenter in the menu bar for controls.")
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        preview.frame = bounds
        person.frame = bounds
        let radius: CGFloat = switch shape {
        case .circle: min(bounds.width, bounds.height) / 2
        case .rounded: 20
        case .cutout: state.isRunning ? 0 : 20
        }
        layer?.cornerRadius = radius
        border.frame = bounds
        border.path = CGPath(
            roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5),
            cornerWidth: max(0, radius - 1.5), cornerHeight: max(0, radius - 1.5), transform: nil
        )
        CATransaction.commit()
    }

    func configure(shape: OverlayShape, border: Bool, mirrored: Bool, state: CameraState, cutoutError: String?) {
        self.shape = shape
        self.state = state
        self.cutoutError = cutoutError
        showsBorder = border
        self.border.isHidden = !showsBorder || shape == .cutout
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        person.setAffineTransform(CGAffineTransform(scaleX: mirrored ? -1 : 1, y: 1))
        CATransaction.commit()
        if let connection = preview.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
        updateVisibility()
        needsLayout = true
    }

    func displayCutout(_ image: CGImage?, error: String?) {
        cutoutError = error
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        person.contents = image
        CATransaction.commit()
        updateVisibility()
    }

    private func updateVisibility() {
        let isCutout = shape == .cutout
        preview.isHidden = isCutout || !state.isRunning
        person.isHidden = !isCutout || !state.isRunning
        layer?.backgroundColor = isCutout && state.isRunning ? NSColor.clear.cgColor : NSColor.black.cgColor
        message.isHidden = state.isRunning && (!isCutout || person.contents != nil)
        if !state.isRunning {
            message.stringValue = state.title
        } else if isCutout {
            message.stringValue = cutoutError == nil ? "Removing background…" : "Cutout unavailable"
        }
    }
}

@MainActor
final class OverlayController: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private let preview: CameraPreviewView
    private let defaults: UserDefaults
    private var size: OverlaySize = .medium
    private var sizeScale = 1.0
    private var shape: OverlayShape = .circle

    init(session: AVCaptureSession, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preview = CameraPreviewView(session: session)
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        super.init()
        panel.contentView = preview
        panel.delegate = self
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .canJoinAllApplications]
        panel.title = "Presenter Camera"
    }

    func configure(
        shape: OverlayShape, size: OverlaySize, sizeScale: Double, border: Bool,
        mirrored: Bool, clickThrough: Bool, state: CameraState, cutoutError: String?
    ) {
        let dimensionsChanged = self.shape != shape || self.size != size
            || self.sizeScale != sizeScale || panel.frame.isEmpty
        self.shape = shape
        self.size = size
        self.sizeScale = sizeScale
        preview.configure(shape: shape, border: border, mirrored: mirrored, state: state, cutoutError: cutoutError)
        panel.ignoresMouseEvents = clickThrough
        panel.hasShadow = shape != .cutout
        if dimensionsChanged { restorePlacement() }
        panel.invalidateShadow()
    }

    func displayCutout(_ image: CGImage?, error: String?) {
        preview.displayCutout(image, error: error)
    }

    func show() {
        restorePlacement()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    /// Restores the saved placement in AppKit points, clamping to currently connected visible screens.
    func restorePlacement(reset: Bool = false) {
        let saved = defaults.string(forKey: "overlayFrame").map(NSRectFromString)
        let preferred = reset ? nil : (panel.frame.isEmpty ? saved : panel.frame)
        let screens = NSScreen.screens.map(\.visibleFrame)
        let frame = OverlayPlacement.frame(
            preferred: preferred, size: size.dimensions(for: shape, scale: sizeScale), screens: screens
        )
        panel.setFrame(frame, display: true)
        savePlacement()
    }

    func windowDidMove(_ notification: Notification) {
        savePlacement()
    }

    private func savePlacement() {
        if !panel.frame.isEmpty {
            defaults.set(NSStringFromRect(panel.frame), forKey: "overlayFrame")
        }
    }
}
