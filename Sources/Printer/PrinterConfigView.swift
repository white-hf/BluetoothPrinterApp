import SwiftUI

struct PrinterConfigView: View {
    @ObservedObject var settings: PrintSettingsStore
    @ObservedObject var ble: PrinterBLEManager

    @State private var threshold: Double = Double(PrintSettings.default.threshold)
    @State private var chunkSize: Int = PrintSettings.default.chunkSize
    @State private var invert: Bool = PrintSettings.default.invert
    @State private var lsbFirst: Bool = PrintSettings.default.lsbFirst
    @State private var compression: Bool = PrintSettings.default.compressionEnabled
    @State private var tCompleteSeconds: Double = Double(PrintSettings.default.tCompleteSeconds)
    @State private var resolution: PrintSettings.Resolution = PrintSettings.default.resolution
    @State private var showWaybillOverlay: Bool = PrintSettings.default.showWaybillOverlay
    @State private var writeUUIDsText: String = PrintSettings.default.writeCharacteristicUUIDs.joined(separator: "\n")
    @State private var isTestingConnection = false

    var body: some View {
        Form {
            Section("Printer") {
                HStack {
                    Text("Default printer")
                    Spacer()
                    if let name = settings.settings.defaultPeripheralName {
                        Text(name)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Not set")
                            .foregroundColor(.secondary)
                    }
                }
                HStack {
                    Text("Auto confirm (seconds)")
                    Spacer()
                    Stepper(value: $tCompleteSeconds, in: 3...30, step: 1) {
                        Text("\(Int(tCompleteSeconds))")
                            .monospacedDigit()
                    }
                    .frame(width: 140)
                }
                Button("Use current connected printer") {
                    settings.update { settings in
                        settings.defaultPeripheralID = ble.connectedPeripheralIdentifier
                        settings.defaultPeripheralName = ble.connectedName
                    }
                }
                .disabled(ble.connectedPeripheralIdentifier == nil)
            }

            Section("Render & Transfer") {
                HStack {
                    Text("Threshold: \(Int(threshold))")
                    Slider(value: $threshold, in: 80...220, step: 1)
                }
                Toggle("Invert", isOn: $invert)
                Toggle("LSB first", isOn: $lsbFirst)
                Toggle("TSPL compression", isOn: $compression)
                Toggle("Draw filename overlay", isOn: $showWaybillOverlay)
                Picker("Resolution", selection: $resolution) {
                    Text("Standard 800x1200").tag(PrintSettings.Resolution.standard)
                    Text("Fast 600x900").tag(PrintSettings.Resolution.fast)
                }
                Picker("BLE chunk size", selection: $chunkSize) {
                    ForEach([256, 512, 768, 1024, 2048], id: \.self) { size in
                        Text("\(size) bytes").tag(size)
                    }
                }
                .pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Write characteristic UUIDs (comma or newline separated)")
                    TextEditor(text: $writeUUIDsText)
                        .frame(minHeight: 80)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .border(Color.secondary.opacity(0.3))
                }
            }
        }
        .navigationTitle("Print Settings")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    persist()
                }
            }
        }
        .onAppear(perform: load)
        .safeAreaInset(edge: .bottom) {
            Button(action: testConnection) {
                Label("Test Bluetooth", systemImage: "bolt.horizontal")
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
        writeUUIDsText = value.writeCharacteristicUUIDs.joined(separator: "\n")
    }

    private func testConnection() {
        guard settings.settings.defaultPeripheralID != nil else {
            ToastHaptics.shared.show("Set a default printer first", style: .warning)
            return
        }
        isTestingConnection = true
        Task {
            defer { isTestingConnection = false }
            do {
                try await ble.connectIfNeeded(defaultPeripheralID: settings.settings.defaultPeripheralID)
                ToastHaptics.shared.show("Bluetooth connection is healthy", style: .success)
            } catch {
                ToastHaptics.shared.show("Bluetooth test failed: \(error.localizedDescription)", style: .error)
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
            let tokens = writeUUIDsText
                .split(whereSeparator: { $0 == "," || $0.isNewline })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            value.writeCharacteristicUUIDs = tokens.isEmpty ? PrintSettings.default.writeCharacteristicUUIDs : tokens
        }
        ToastHaptics.shared.show("Settings saved", style: .success)
    }
}
