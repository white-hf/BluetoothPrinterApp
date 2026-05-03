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
            Section(L10n.connectionSection) {
                Label(connectionDescription, systemImage: connectionIcon)
                    .foregroundColor(connectionTint)
                if ble.connectedPeripheralIdentifier == nil {
                    Text(L10n.bleSetupFirst)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Section(L10n.queueSection) {
                Button {
                    showFileImporter = true
                } label: {
                    Label(L10n.choosePDFFiles, systemImage: "doc.badge.plus")
                }

                HStack {
                    Button(L10n.btnStart) { coordinator.start() }
                        .buttonStyle(.borderedProminent)
                        .disabled(coordinator.jobs.isEmpty)
                    Button(L10n.btnPause) { coordinator.pauseProcessing() }
                        .buttonStyle(.bordered)
                    Button(L10n.btnClear, role: .destructive) { coordinator.clearQueue() }
                        .buttonStyle(.bordered)
                        .disabled(coordinator.jobs.isEmpty)
                }

                if coordinator.jobs.isEmpty {
                    Text(L10n.queueEmpty)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(coordinator.jobs) { job in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(job.displayName)
                                .font(.subheadline)
                            Text(job.state.stateDescription)
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
                Section(L10n.currentJobSection) {
                    Text(job.displayName).font(.headline)
                    if job.state == .waitingConfirm {
                        let elapsed = coordinator.waitingSince.map { Int(now.timeIntervalSince($0)) } ?? 0
                        let remain = max(coordinator.currentJobTimeoutSeconds() - elapsed, 0)
                        Text(L10n.waitConfirmation + " (\(remain)s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        if coordinator.currentPreview != nil {
                            Button(L10n.btnPreview) {
                                previewImage = coordinator.currentPreview
                                showPreview = previewImage != nil
                            }
                            .buttonStyle(.bordered)
                        }
                        if job.state == .waitingConfirm {
                            Button(L10n.btnConfirm) { coordinator.confirmCurrentJobCompleted() }
                                .buttonStyle(.borderedProminent)
                            Button(L10n.btnRetry) { coordinator.retryCurrentJob() }
                                .buttonStyle(.bordered)
                            Button(L10n.btnSkip, role: .destructive) { coordinator.skipCurrentJob() }
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
        .navigationTitle(L10n.tabLocal)
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
                        Text(L10n.noPreview)
                            .foregroundColor(.secondary)
                    }
                }
                .navigationTitle(L10n.printPreview)
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
                    ToastHaptics.shared.show(L10n.importFailed(error.localizedDescription), style: .error)
                }
            }
            ToastHaptics.shared.show(L10n.addedFiles(urls.count), style: .success)
        case .failure(let error):
            ToastHaptics.shared.show(L10n.filePickerError(error.localizedDescription), style: .error)
        }
    }

    private var connectionDescription: String {
        switch ble.state {
        case .connected(let name):
            return L10n.bleConnectedTo(name)
        case .connecting(let name):
            return L10n.bleConnectingTo(name)
        case .scanning:
            return L10n.bleScanning
        case .failed(let error):
            return L10n.bleFailedWithError("\(error)")
        case .disconnected:
            return L10n.bleDisconnected
        default:
            return L10n.notSet
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
