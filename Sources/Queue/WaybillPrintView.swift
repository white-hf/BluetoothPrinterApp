import SwiftUI
import AVFoundation
import UIKit

struct WaybillPrintView: View {
    @ObservedObject var ble: PrinterBLEManager
    @ObservedObject var settingsStore: PrintSettingsStore
    @ObservedObject var historyStore: WaybillJobHistoryStore
    @ObservedObject var autoConnector: BLEAutoConnector

    @StateObject private var coordinator: WaybillPrintCoordinator
    @StateObject private var discovery = ServerDiscoveryManager.shared
    @StateObject private var toastCenter = ToastHaptics.shared

    @State private var isScanning = true
    @State private var showHistory = false
    @State private var showConfig = false
    @State private var showConnection = false
    @State private var showPreviewSheet = false
    @State private var permissionAlert = false
    @State private var showShareSheet = false
    @State private var shareURL: URL?

    @State private var lastScannedCode: String = ""
    @State private var lastScannedAt: Date = .distantPast
    @State private var previewImages: [UIImage] = []
    @State private var previewTitle: String = L10n.printPreview
    @State private var seenTNOs: Set<String> = []

    init(
        ble: PrinterBLEManager,
        settings: PrintSettingsStore,
        history: WaybillJobHistoryStore,
        autoConnector: BLEAutoConnector
    ) {
        self.ble = ble
        self.settingsStore = settings
        self.historyStore = history
        self.autoConnector = autoConnector
        _coordinator = StateObject(wrappedValue: WaybillPrintCoordinator(ble: ble, settings: settings, history: history))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusBar
                scannerSection
                primaryButtonsSection
                PrintingNowPanel(
                    coordinator: coordinator,
                    ble: ble,
                    onShowPreview: { image in
                        previewImages = [image]
                        previewTitle = coordinator.currentJob?.tno ?? L10n.printPreview
                        showPreviewSheet = true
                    }
                )
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle(L10n.appName)
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                WaybillJobHistoryView(history: historyStore)
            }
        }
        .sheet(isPresented: $showConfig) {
            NavigationStack {
                PrinterConfigView(settings: settingsStore, ble: ble)
            }
        }
        .sheet(isPresented: $showConnection) {
            NavigationStack {
                PrinterDiscoveryView(ble: ble)
            }
        }
        .sheet(isPresented: $showPreviewSheet) {
            PreviewGalleryView(title: previewTitle, images: previewImages)
        }
        .sheet(isPresented: $showShareSheet, onDismiss: {
            shareURL = nil
        }) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            } else {
                Text(L10n.noFileToShare)
            }
        }
        .alert(L10n.cameraPermissionTitle, isPresented: $permissionAlert) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(L10n.cameraPermissionMsg)
        }
        .onAppear {
            autoConnector.onAppear()
            discovery.startDiscovery()
            Task.detached(priority: .utility) {
                PDFCacheCleaner.cleanStaleFiles()
            }
        }
        .onDisappear {
            isScanning = false
            coordinator.pauseProcessing()
        }
    }

    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Label(connectedDescription, systemImage: connectionIconName)
                    .foregroundStyle(connectionTint)
                Divider().frame(height: 18)
                Label(L10n.queueCount(coordinator.jobs.count), systemImage: "square.stack.3d.up")
                    .foregroundStyle(.primary)
                Spacer()
                if shouldShowConnectionButton {
                    Button(L10n.btnConnect) { showConnection = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            
            HStack(spacing: 8) {
                Image(systemName: "server.rack")
                if let server = discovery.discoveredServers.first {
                    Text(L10n.bleDiscoveryStatus(discovered: server.name))
                        .foregroundColor(.green)
                } else if settingsStore.settings.baseURLString != "http://192.168.1.100:5000" {
                    Text(L10n.manualServerStatus(settingsStore.settings.baseURLString))
                        .foregroundColor(.blue)
                } else {
                    Text(L10n.bleDiscoveryStatus(discovered: nil))
                        .foregroundColor(.orange)
                }
                
                if discovery.isSearching {
                    ProgressView().scaleEffect(0.6)
                }
            }
            .font(.caption)
        }
    }

    private var scannerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            WaybillScannerPreview(isScanning: $isScanning) { code in
                handleScanned(code)
            } onPermissionDenied: {
                permissionAlert = true
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                Text(L10n.scanPrompt)
                    .font(.footnote)
                    .padding(8)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .padding(.top, 8)
            }
            Toggle(isOn: $isScanning) {
                Text(isScanning ? L10n.scannerOn : L10n.scannerPaused)
                    .font(.subheadline)
            }
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        }
    }

    private var primaryButtonsSection: some View {
        HStack(spacing: 12) {
            Button {
                coordinator.start()
                if !coordinator.jobs.isEmpty {
                    ToastHaptics.shared.show(L10n.batchPrintStarted, style: .info)
                }
            } label: {
                Label(L10n.btnStart, systemImage: "printer.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(coordinator.jobs.isEmpty)

            Button(role: .destructive) {
                coordinator.clearQueue()
                seenTNOs.removeAll()
            } label: {
                Label(L10n.btnClear, systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(coordinator.jobs.isEmpty)

            Menu {
                Button { downloadMissingList() } label: {
                    Label(L10n.downloadMissingList, systemImage: "arrow.down.doc")
                }
                Button { showHistory = true } label: {
                    Label(L10n.tabHistory, systemImage: "clock")
                }
                Button { showConfig = true } label: {
                    Label(L10n.tabSettings, systemImage: "gear")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
            }
        }
    }

    private func downloadMissingList() {
        let base = settingsStore.settings.baseURL
        ToastHaptics.shared.show(L10n.downloadMissingStarted, style: .info)
        Task {
            do {
                let destURL = try await LabelAPI().downloadMissingOrdersCSV(baseURL: base)
                self.shareURL = destURL
                self.showShareSheet = true
                ToastHaptics.shared.show(L10n.downloadComplete, style: .success)
            } catch {
                ToastHaptics.shared.show(error.localizedDescription, style: .error)
            }
        }
    }

    private var connectedDescription: String {
        switch ble.state {
        case .connected(let name):
            return L10n.bleConnectedTo(name)
        case .connecting(let name):
            return L10n.bleConnectingTo(name)
        case .failed:
            return L10n.bleFailed
        case .scanning:
            return L10n.bleScanning
        case .disconnected:
            return L10n.bleDisconnected
        default:
            return L10n.notSet
        }
    }

    private var connectionIconName: String {
        switch ble.state {
        case .connected: return "antenna.radiowaves.left.and.right"
        case .connecting: return "dot.radiowaves.left.and.right"
        case .failed: return "exclamationmark.triangle"
        case .scanning: return "wave.3.right"
        default: return "bolt.slash"
        }
    }

    private var connectionTint: Color {
        switch ble.state {
        case .connected: return .green
        case .connecting, .scanning: return .orange
        case .failed: return .red
        default: return .secondary
        }
    }

    private var shouldShowConnectionButton: Bool {
        if case .connected = ble.state { return false }
        return true
    }

    private func handleScanned(_ raw: String) {
        guard isScanning else { return }
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        let now = Date()
        if code == lastScannedCode, now.timeIntervalSince(lastScannedAt) < 1.5 { return }
        lastScannedCode = code
        lastScannedAt = now
        
        if seenTNOs.contains(code) || coordinator.jobs.contains(where: { $0.tno == code }) {
            ToastHaptics.shared.show(L10n.inQueue(code), style: .warning)
            return
        }
        coordinator.enqueue(tno: code)
        seenTNOs.insert(code)
        ToastHaptics.shared.show(L10n.addedToQueue(code), style: .info)
    }
}

// MARK: - Scanner Helper

struct WaybillScannerPreview: UIViewControllerRepresentable {
    @Binding var isScanning: Bool
    let onCode: (String) -> Void
    let onPermissionDenied: () -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onCode = onCode
        controller.onPermissionDenied = onPermissionDenied
        return controller
    }

    func updateUIViewController(_ controller: ScannerViewController, context: Context) {
        if isScanning {
            controller.startScanning()
        } else {
            controller.stopScanning()
        }
    }
}

final class ScannerViewController: UIViewController {
    let engine = ScanEngine()
    var onCode: ((String) -> Void)?
    var onPermissionDenied: (() -> Void)?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        engine.delegate = self
        let layer = engine.makePreviewLayer()
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func startScanning() { engine.start() }
    func stopScanning() { engine.stop() }
}

extension ScannerViewController: ScanEngineDelegate {
    func scanEngine(_ engine: ScanEngine, didOutput code: String) {
        onCode?(code)
    }
    func scanEngineNeedsCameraPermission(_ engine: ScanEngine) {
        onPermissionDenied?()
    }
}

// MARK: - Gallery & Share Helpers

struct PreviewGalleryView: View {
    let title: String
    let images: [UIImage]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if images.isEmpty {
                    Text(L10n.noHistoryYet).foregroundColor(.secondary)
                } else {
                    TabView {
                        ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                            Image(uiImage: image)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .padding()
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.btnClose) { dismiss() }
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
