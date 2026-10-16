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

private struct PresenterControls: View {
    @ObservedObject var model: AppModel
    @ObservedObject var camera: CameraController
    @AppStorage("showRecordingGuide") private var showGuide = true

    init(model: AppModel) {
        self.model = model
        camera = model.camera
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                recording
                Divider()
                cameraControls
                Divider()
                overlayControls
                Divider()
                guide
                Divider()
                folderControls
                HStack {
                    Text("Camera stops when hidden or on quit.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                        .keyboardShortcut("q")
                }
            }
            .padding(16)
        }
        .frame(width: 360, height: 650)
        .onAppear { camera.refreshDevices() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Presenter").font(.title2.weight(.semibold))
            Label(camera.state.title, systemImage: camera.state.isRunning ? "video.fill" : "video.slash")
                .font(.subheadline)
                .foregroundStyle(camera.state.isRunning ? .primary : .secondary)
                .lineLimit(2)
                .accessibilityLabel("Camera status: \(camera.state.title)")
        }
    }

    private var recording: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: model.openRecorder) {
                Label(model.openingRecorder ? "Preparing recorder…" : "Open Screen Recorder", systemImage: "record.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.openingRecorder)
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Text("Choose Record Entire Screen or Record Selected Portion. Set your microphone and save location in Options, then click Record.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let error = model.error {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
            if let guidance = camera.state.guidance {
                Text(guidance).font(.caption).textSelection(.enabled)
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
            Toggle("Mirror Camera", isOn: $model.mirrored)
        }
    }

    private var overlayControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Overlay").font(.headline)
            Picker("Style", selection: $model.shape) {
                ForEach(OverlayShape.allCases) { shape in Text(shape.rawValue).tag(shape) }
            }
            .pickerStyle(.segmented)
            if model.shape == .cutout {
                Text("Removes the camera background on this Mac. Borders apply to Circle and Rounded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let error = camera.cutoutError {
                    Text(error).font(.caption).foregroundStyle(.red)
                    Button("Retry Cutout", action: model.retryCamera)
                } else if model.overlayVisible, camera.state.isRunning, !camera.isCutoutReady {
                    Text("Removing background…").font(.caption).foregroundStyle(.secondary)
                }
            }
            Picker("Size", selection: $model.size) {
                ForEach(OverlaySize.allCases) { size in Text(size.rawValue).tag(size) }
            }
            .pickerStyle(.segmented)
            Toggle("White Border", isOn: $model.showsBorder)
                .disabled(model.shape == .cutout)
            Toggle("Click Through Camera", isOn: $model.clickThrough)
            if model.clickThrough {
                Text("Turn this off to drag the camera. These controls stay available in the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Reset Camera Position", action: model.resetPosition)
                .help("Move the camera onto the main display and allow dragging.")
        }
    }

    private var guide: some View {
        DisclosureGroup("Recording Guide", isExpanded: $showGuide) {
            VStack(alignment: .leading, spacing: 8) {
                Text("1. Show the camera and allow camera access when macOS asks. Choose Cutout to remove the background, then drag the preview into place.")
                Text("2. Open Screen Recorder. Choose Record Entire Screen or Record Selected Portion and include the camera. Single-window recording may leave it out.")
                Text("3. In Options, select a microphone and Save to folder. Allow microphone access if macOS asks, then click Record.")
                Text("4. Stop with the menu-bar Stop button or Control-Command-Escape. Play the saved movie to check picture and speech.")
                Text("Presenter cannot detect when Screenshot stops. Hide the camera when finished to release it.")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .padding(.top, 6)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var folderControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Folder shortcut · set Save to separately in Screenshot Options.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Open Recordings Folder", action: model.openRecordingsFolder)
                Spacer()
                Button(action: model.chooseRecordingsFolder) {
                    Image(systemName: "folder.badge.gearshape")
                }
                .accessibilityLabel("Choose recordings folder shortcut")
                .help("Choose the same Save to folder in Screenshot Options.")
            }
            Text(model.folderPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(model.folderPath)
        }
    }
}
