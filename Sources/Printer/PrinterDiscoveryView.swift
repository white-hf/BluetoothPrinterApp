import SwiftUI

struct PrinterDiscoveryView: View {
    @ObservedObject var ble: PrinterBLEManager

    var body: some View {
        List {
            Section(header: header) {
                ForEach(ble.devices) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name.isEmpty ? L10n.unknown : item.name)
                                .font(.body)
                                .bold()
                            Text("RSSI: \(item.rssi)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(L10n.btnConnect) {
                            ble.connect(item)
                        }
                    }
                }
            }

            Section(L10n.actions) {
                Button(L10n.btnScan) {
                    ble.startScan()
                }
                .disabled(ble.state == .scanning)

                Button(L10n.btnStopScan, role: .cancel) {
                    ble.stopScan()
                }
                .disabled(!(ble.state == .scanning))

                Button(L10n.btnDisconnect, role: .destructive) {
                    ble.disconnect()
                }
                .disabled(!isConnected)
            }

            Section(L10n.status) {
                statusView
            }
        }
        .navigationTitle(L10n.tabDevices)
        .onAppear {
            if ble.devices.isEmpty {
                ble.startScan()
            }
        }
    }

    private var header: some View {
        HStack {
            Text(L10n.nearbyDevices)
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
            Text(L10n.idle).foregroundColor(.secondary)
        case .scanning:
            Text(L10n.bleScanning).foregroundColor(.blue)
        case .connecting(let name):
            Text(L10n.connectingTo(name)).foregroundColor(.orange)
        case .connected(let name):
            Text(L10n.connectedTo(name)).foregroundColor(.green)
                .bold()
        case .failed(let error):
            Text(L10n.failedWithError(error)).foregroundColor(.red)
        case .disconnected:
            Text(L10n.bleDisconnected).foregroundColor(.secondary)
        }
    }
}
