import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct LocalFilePrintView: View {
    @ObservedObject var ble: PrinterBLEManager
    @ObservedObject var settings: PrintSettingsStore
    @ObservedObject var history: LocalJobHistoryStore

    @StateObject private var toastCenter = ToastHaptics.shared
    @StateObject private var coordinator: LocalFilePrintCoordinator

    @State private var showFileImporter = false
    @State private var showPreview = false
    @State private var previewImage: UIImage?
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(ble: PrinterBLEManager, settings: PrintSettingsStore, history: LocalJobHistoryStore) {
        self.ble = ble
        self.settings = settings
        self.history = history
        _coordinator = StateObject(wrappedValue: LocalFilePrintCoordinator(ble: ble, settings: settings, history: history))
    }

    var body: some View {
        List {
            Section("Connection") {
                Label(connectionDescription, systemImage: connectionIcon)
                    .foregroundColor(connectionTint)
                if ble.connectedPeripheralIdentifier == nil {
                    Text("Go to Devices tab and connect a printer first.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Section("Queue") {
                Button {
                    showFileImporter = true
                } label: {
                    Label("Choose PDF files", systemImage: "doc.badge.plus")
                }

                HStack {
                    Button("Start") { coordinator.start() }
                        .buttonStyle(.borderedProminent)
                        .disabled(coordinator.jobs.isEmpty)
                    Button("Pause") { coordinator.pauseProcessing() }
                        .buttonStyle(.bordered)
                    Button("Clear", role: .destructive) { coordinator.clearQueue() }
                        .buttonStyle(.bordered)
                        .disabled(coordinator.jobs.isEmpty)
                }

                if coordinator.jobs.isEmpty {
                    Text("No files queued.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(coordinator.jobs) { job in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(job.displayName)
                                .font(.subheadline)
                            Text(stateText(job.state))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let message = job.errorMessage, !message.isEmpty {
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }

            if let job = coordinator.currentJob {
                Section("Current Job") {
                    Text(job.displayName).font(.headline)
                    if job.state == .waitingConfirm {
                        let elapsed = coordinator.waitingSince.map { Int(now.timeIntervalSince($0)) } ?? 0
                        let remain = max(coordinator.currentJobTimeoutSeconds() - elapsed, 0)
                        Text("Waiting confirmation (\(remain)s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        if coordinator.currentPreview != nil {
                            Button("Preview") {
                                previewImage = coordinator.currentPreview
                                showPreview = previewImage != nil
                            }
                            .buttonStyle(.bordered)
                        }
                        if job.state == .waitingConfirm {
                            Button("Confirm") { coordinator.confirmCurrentJobCompleted() }
                                .buttonStyle(.borderedProminent)
                            Button("Retry") { coordinator.retryCurrentJob() }
                                .buttonStyle(.bordered)
                            Button("Skip", role: .destructive) { coordinator.skipCurrentJob() }
                                .buttonStyle(.bordered)
                        }
                    }

                    if let banner = coordinator.bannerMessage {
                        Text(banner)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle("Local PDF Printing")
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
        .sheet(isPresented: $showPreview) {
            NavigationStack {
                Group {
                    if let image = previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .padding()
                    } else {
                        Text("No preview available")
                            .foregroundColor(.secondary)
                    }
                }
                .navigationTitle("Print Preview")
            }
        }
        .onReceive(timer) { value in
            now = value
        }
        .onDisappear {
            coordinator.pauseProcessing()
            toastCenter.toast = nil
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if urls.isEmpty { return }
            for source in urls {
                do {
                    let imported = try ImportedPDFStore.shared.importFile(from: source)
                    coordinator.enqueue(displayName: imported.displayName, localFileURL: imported.localURL)
                } catch {
                    ToastHaptics.shared.show("Import failed: \(error.localizedDescription)", style: .error)
                }
            }
            ToastHaptics.shared.show("Added \(urls.count) file(s)", style: .success)
        case .failure(let error):
            ToastHaptics.shared.show("File picker error: \(error.localizedDescription)", style: .error)
        }
    }

    private func stateText(_ state: LocalPrintJobState) -> String {
        switch state {
        case .queued: return "Queued"
        case .rendering: return "Rendering"
        case .sending: return "Sending"
        case .waitingConfirm: return "Waiting confirm"
        case .success: return "Success"
        case .failed: return "Failed"
        case .skipped: return "Skipped"
        }
    }

    private var connectionDescription: String {
        switch ble.state {
        case .connected(let name):
            return "Connected: \(name ?? "-")"
        case .connecting(let name):
            return "Connecting: \(name ?? "-")"
        case .scanning:
            return "Scanning..."
        case .failed(let error):
            return "Failed: \(error)"
        case .disconnected:
            return "Disconnected"
        default:
            return "Not connected"
        }
    }

    private var connectionIcon: String {
        switch ble.state {
        case .connected:
            return "antenna.radiowaves.left.and.right"
        case .connecting:
            return "dot.radiowaves.left.and.right"
        case .failed:
            return "exclamationmark.triangle"
        case .scanning:
            return "wave.3.right"
        default:
            return "bolt.slash"
        }
    }

    private var connectionTint: Color {
        switch ble.state {
        case .connected:
            return .green
        case .connecting, .scanning:
            return .orange
        case .failed:
            return .red
        default:
            return .secondary
        }
    }
}
