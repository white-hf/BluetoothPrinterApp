import SwiftUI

struct PrinterConfigView: View {
    @ObservedObject var settings: PrintSettingsStore
    @ObservedObject var ble: PrinterBLEManager
    @StateObject private var discovery = ServerDiscoveryManager.shared

    @State private var threshold: Double = Double(PrintSettings.default.threshold)
    @State private var chunkSize: Int = PrintSettings.default.chunkSize
    @State private var invert: Bool = PrintSettings.default.invert
    @State private var lsbFirst: Bool = PrintSettings.default.lsbFirst
    @State private var compression: Bool = PrintSettings.default.compressionEnabled
    @State private var tCompleteSeconds: Double = Double(PrintSettings.default.tCompleteSeconds)
    @State private var resolution: PrintSettings.Resolution = PrintSettings.default.resolution
    @State private var showWaybillOverlay: Bool = PrintSettings.default.showWaybillOverlay
    @State private var baseURLString: String = PrintSettings.default.baseURLString
    @State private var writeUUIDsText: String = PrintSettings.default.writeCharacteristicUUIDs.joined(separator: "\n")
    @State private var isTestingConnection = false

    var body: some View {
        Form {
            Section {
                VStack {
                    AppLogoView(size: 80)
                    Text(L10n.appName)
                        .font(.headline)
                    Text("v1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }

            Section(L10n.serverSection) {
                TextField(L10n.baseURLPlaceholder, text: $baseURLString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                
                HStack {
                    Text("Auto Discovery (mDNS)")
                    Spacer()
                    if discovery.isSearching {
                        ProgressView().scaleEffect(0.8)
                    }
                    Button("Refresh") {
                        discovery.startDiscovery()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                LabeledContent("Last Status", value: discovery.lastStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(L10n.printerSection) {
                HStack {
                    Text(L10n.defaultPrinter)
                    Spacer()
                    if let name = settings.settings.defaultPeripheralName {
                        Text(name)
                            .foregroundColor(.secondary)
                    } else {
                        Text(L10n.notSet)
                            .foregroundColor(.secondary)
                    }
                }
                HStack {
                    Text(L10n.autoConfirmSeconds)
                    Spacer()
                    Stepper(value: $tCompleteSeconds, in: 3...30, step: 1) {
                        Text("\(Int(tCompleteSeconds))")
                            .monospacedDigit()
                    }
                    .frame(width: 140)
                }
                Button(L10n.useConnectedPrinter) {
                    settings.update { settings in
                        settings.defaultPeripheralID = ble.connectedPeripheralIdentifier
                        settings.defaultPeripheralName = ble.connectedName
                    }
                }
                .disabled(ble.connectedPeripheralIdentifier == nil)
            }

            Section(L10n.renderSection) {
                HStack {
                    Text("\(L10n.thresholdLabel): \(Int(threshold))")
                    Slider(value: $threshold, in: 80...220, step: 1)
                }
                Toggle(L10n.invertLabel, isOn: $invert)
                Toggle(L10n.lsbFirstLabel, isOn: $lsbFirst)
                Toggle(L10n.compressionLabel, isOn: $compression)
                Toggle(L10n.filenameOverlayLabel, isOn: $showWaybillOverlay)
                Picker(L10n.resolutionLabel, selection: $resolution) {
                    Text(L10n.resStandard).tag(PrintSettings.Resolution.standard)
                    Text(L10n.resFast).tag(PrintSettings.Resolution.fast)
                }
                Picker(L10n.bleChunkSizeLabel, selection: $chunkSize) {
                    ForEach([256, 512, 768, 1024, 2048], id: \.self) { size in
                        Text("\(size) bytes").tag(size)
                    }
                }
                .pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.writeUUIDsLabel)
                    TextEditor(text: $writeUUIDsText)
                        .frame(minHeight: 80)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .border(Color.secondary.opacity(0.3))
                }
            }
        }
        .navigationTitle(L10n.tabSettings)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(L10n.btnSave) {
                    persist()
                }
            }
        }
        .onAppear(perform: load)
        .safeAreaInset(edge: .bottom) {
            Button(action: testConnection) {
                Label(L10n.testBluetooth, systemImage: "bolt.horizontal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isTestingConnection)
            .padding()
            .background(.regularMaterial)
        }
    }

    private func load() {
        let value = settings.settings
        threshold = Double(value.threshold)
        chunkSize = value.chunkSize
        invert = value.invert
        lsbFirst = value.lsbFirst
        compression = value.compressionEnabled
        tCompleteSeconds = Double(value.tCompleteSeconds)
        resolution = value.resolution
        showWaybillOverlay = value.showWaybillOverlay
        baseURLString = value.baseURLString
        writeUUIDsText = value.writeCharacteristicUUIDs.joined(separator: "\n")
    }

    private func testConnection() {
        guard settings.settings.defaultPeripheralID != nil else {
            ToastHaptics.shared.show(L10n.setupPrinterFirst, style: .warning)
            return
        }
        isTestingConnection = true
        Task {
            defer { isTestingConnection = false }
            do {
                try await ble.connectIfNeeded(defaultPeripheralID: settings.settings.defaultPeripheralID)
                ToastHaptics.shared.show(L10n.bleConnectionHealthy, style: .success)
            } catch {
                ToastHaptics.shared.show(L10n.bleFailedWithError(error.localizedDescription), style: .error)
            }
        }
    }

    private func persist() {
        settings.update { value in
            value.threshold = Int(threshold)
            value.chunkSize = chunkSize
            value.invert = invert
            value.lsbFirst = lsbFirst
            value.compressionEnabled = compression
            value.tCompleteSeconds = Int(tCompleteSeconds)
            value.resolution = resolution
            value.showWaybillOverlay = showWaybillOverlay
            value.baseURLString = baseURLString
            let tokens = writeUUIDsText
                .split(whereSeparator: { $0 == "," || $0.isNewline })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            value.writeCharacteristicUUIDs = tokens.isEmpty ? PrintSettings.default.writeCharacteristicUUIDs : tokens
        }
        ToastHaptics.shared.show(L10n.settingsSaved, style: .success)
    }
}
