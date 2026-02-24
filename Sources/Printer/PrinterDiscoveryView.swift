import SwiftUI

struct PrinterDiscoveryView: View {
    @ObservedObject var ble: PrinterBLEManager

    var body: some View {
        List {
            Section(header: header) {
                ForEach(ble.devices) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name.isEmpty ? "Unknown" : item.name)
                                .font(.body)
                                .bold()
                            Text("RSSI: \(item.rssi)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Connect") {
                            ble.connect(item)
                        }
                    }
                }
            }

            Section("Actions") {
                Button("Scan") {
                    ble.startScan()
                }
                .disabled(ble.state == .scanning)

                Button("Stop Scan", role: .cancel) {
                    ble.stopScan()
                }
                .disabled(!(ble.state == .scanning))

                Button("Disconnect", role: .destructive) {
                    ble.disconnect()
                }
                .disabled(!isConnected)
            }

            Section("Status") {
                statusView
            }
        }
        .navigationTitle("Bluetooth Printers")
        .onAppear {
            if ble.devices.isEmpty {
                ble.startScan()
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Nearby devices")
            Spacer()
            if ble.state == .scanning {
                ProgressView()
            }
        }
    }

    private var isConnected: Bool {
        if case .connected = ble.state { return true }
        return false
    }

    @ViewBuilder
    private var statusView: some View {
        switch ble.state {
        case .idle:
            Text("Idle").foregroundColor(.secondary)
        case .scanning:
            Text("Scanning...").foregroundColor(.blue)
        case .connecting(let name):
            Text("Connecting → \(name ?? "-")").foregroundColor(.orange)
        case .connected(let name):
            Text("Connected: \(name ?? "-")").foregroundColor(.green)
                .bold()
        case .failed(let error):
            Text("Failed: \(error)").foregroundColor(.red)
        case .disconnected:
            Text("Disconnected").foregroundColor(.secondary)
        }
    }
}
