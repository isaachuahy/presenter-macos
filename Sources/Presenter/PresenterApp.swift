import SwiftUI

@main
struct PresenterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra("Presenter", systemImage: "video") {
            PresenterControls(model: model)
        }
        .menuBarExtraStyle(.window)
        .windowResizability(.contentSize)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        AppModel.shared.launch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppModel.shared.shutdown()
    }
}

// Command Line Tools can omit the plugin for the SDK's same-named State macro.
private typealias ControlState<Value> = SwiftUI.State<Value>

private struct PresenterControls: View {
    @ObservedObject var model: AppModel
    @ObservedObject var camera: CameraController
    @ControlState private var showMoreControls = false
    @ControlState private var showGuide = false

    init(model: AppModel) {
        self.model = model
        camera = model.camera
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                header
                recording
            }
            .padding(16)

            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        cameraControls.id("controls")
                        Divider()
                        overlayControls
                        Divider()
                        moreControls
                        if showGuide {
                            Divider()
                            guide.id("guide")
                        }
                    }
                    .padding(16)
                }
                .onChange(of: showGuide) { _, expanded in
                    Task { @MainActor in
                        await Task.yield()
                        guard showGuide == expanded else { return }
                        proxy.scrollTo(expanded ? "guide" : "controls", anchor: .top)
                    }
                }
            }
            Divider()
            footer.padding(16)
        }
        .font(.body)
        .frame(width: 360, height: showMoreControls || showGuide ? 650 : 510)
        .onAppear { camera.refreshDevices() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Presenter").font(.title2.weight(.semibold))
            Spacer()
            Label(cameraStatus, systemImage: camera.state.isRunning ? "video.fill" : "video.slash")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .accessibilityLabel("Camera status: \(camera.state.title)")
                .help(camera.state.title)
        }
    }

    private var cameraStatus: String {
        switch camera.state {
        case .running: "Camera on"
        case .starting: "Starting camera…"
        case .stopped: "Camera off"
        default: "Camera unavailable"
        }
    }

    private var recording: some View {
        VStack(alignment: .leading, spacing: 8) {
            primaryRecorderButton
                .controlSize(.large)
                .disabled(model.openingRecorder)
                .keyboardShortcut("r", modifiers: [.command, .shift])

            Text("Choose your microphone in Screenshot Options.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let error = model.error {
                Text(error).font(.subheadline).foregroundStyle(.red).textSelection(.enabled)
            }
            if let guidance = camera.state.guidance {
                Text(guidance).font(.subheadline).textSelection(.enabled)
                HStack {
                    Button("Retry Camera", action: model.retryCamera)
                    if camera.state == .denied {
                        Button("System Settings…", action: model.openCameraSettings)
                    }
                }
                Button("Open Recorder Without Camera", action: model.openRecorderWithoutCamera)
                    .disabled(model.openingRecorder)
            }
        }
    }

    @ViewBuilder
    private var primaryRecorderButton: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            recorderButton.buttonStyle(.glassProminent)
        } else {
            recorderButton.buttonStyle(.borderedProminent)
        }
        #else
        recorderButton.buttonStyle(.borderedProminent)
        #endif
    }

    private var recorderButton: some View {
        Button(action: model.openRecorder) {
            Label(model.openingRecorder ? "Preparing recorder…" : "Open Screen Recorder", systemImage: "record.circle")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 24)
        }
    }

    private var cameraControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Show Camera", isOn: $model.overlayVisible)
                .toggleStyle(.switch)
            Picker("Camera", selection: Binding(get: { camera.selectedID }, set: camera.select)) {
                if camera.choices.isEmpty {
                    Text("No camera connected").tag("")
                }
                ForEach(camera.choices) { choice in Text(choice.name).tag(choice.id) }
            }
            .disabled(camera.choices.isEmpty)
        }
    }

    private var overlayControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Appearance").font(.body.weight(.semibold))
            Picker("Style", selection: $model.shape) {
                ForEach(OverlayShape.allCases) { shape in Text(shape.rawValue).tag(shape) }
            }
            .pickerStyle(.segmented)
            if model.shape == .cutout {
                Text("Removes your camera background on this Mac.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let error = camera.cutoutError {
                    Text(error).font(.subheadline).foregroundStyle(.red)
                    Button("Retry Cutout", action: model.retryCamera)
                } else if model.overlayVisible, camera.state.isRunning, !camera.isCutoutReady {
                    Text("Removing background…").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Size")
                    Spacer()
                    Text("\(Int(model.overlayWidth.rounded())) pt")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.overlayWidth, in: model.sizeRange)
                    .accessibilityLabel("Camera size")
                    .accessibilityValue("\(Int(model.overlayWidth.rounded())) points")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: model.overlayWidth += 1
                        case .decrement: model.overlayWidth -= 1
                        @unknown default: break
                        }
                    }
                    .help("Choose any size, or snap to Small, Medium, or Large below.")
                HStack(spacing: 6) {
                    ForEach(OverlaySize.allCases) { size in
                        Toggle(isOn: Binding(
                            get: { model.selectedSize == size },
                            set: { _ in model.selectSize(size) }
                        )) {
                            Text(size.rawValue).frame(maxWidth: .infinity)
                        }
                        .toggleStyle(.button)
                        .help("\(Int(size.dimensions(for: model.shape).width)) points wide")
                    }
                }
            }
        }
    }

    private var moreControls: some View {
        DisclosureGroup(isExpanded: $showMoreControls) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Mirror Camera", isOn: $model.mirrored)
                Toggle("White Border", isOn: $model.showsBorder)
                    .disabled(model.shape == .cutout)
                    .help("Borders apply to Circle and Rounded styles.")
                Toggle("Click Through Camera", isOn: $model.clickThrough)
                if model.clickThrough {
                    Text("Turn this off to drag the camera. These controls stay available in the menu bar.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button("Reset Camera Position", action: model.resetPosition)
                    .help("Move the camera onto the main display and allow dragging.")
                Divider()
                folderControls
            }
            .padding(.top, 12)
        } label: {
            Text("More Controls").font(.body.weight(.semibold))
        }
    }

    private var guide: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recording Guide").font(.body.weight(.semibold))
            VStack(alignment: .leading, spacing: 10) {
                Text("1. Show the camera and allow camera access when macOS asks. Choose Cutout to remove the background, then drag the preview into place.")
                Text("2. Open Screen Recorder. Choose Record Entire Screen or Record Selected Portion and include the camera. Single-window recording may leave it out.")
                Text("3. In Options, select a microphone and Save to folder. Allow microphone access if macOS asks, then click Record.")
                Text("4. Stop with the menu-bar Stop button or Control-Command-Escape. Play the saved movie to check picture and speech.")
                Text("Presenter cannot detect when Screenshot stops. Hide the camera when finished to release it.")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var folderControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button("Choose Recordings Folder…", action: model.chooseRecordingsFolder)
                .help("Choose the same Save to folder in Screenshot Options.")
            Text("This shortcut does not change Screenshot’s Save to setting.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(model.folderPath)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(model.folderPath)
        }
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Button(action: model.openRecordingsFolder) {
                Label("Recordings", systemImage: "folder")
            }
            .accessibilityLabel("Open Recordings Folder")
            Spacer()
            Button { showGuide.toggle() } label: {
                Label("Help", systemImage: "questionmark.circle")
            }
            .foregroundStyle(showGuide ? Color.accentColor : Color.primary)
            .accessibilityValue(showGuide ? "Guide shown" : "Guide hidden")
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .buttonStyle(.borderless)
    }
}
