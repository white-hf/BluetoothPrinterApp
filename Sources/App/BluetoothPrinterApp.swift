import SwiftUI

@main
struct BluetoothPrinterAppEntry: App {
    @StateObject private var ble: PrinterBLEManager
    @StateObject private var settings = PrintSettingsStore.shared
    @StateObject private var history = LocalJobHistoryStore.shared
    @StateObject private var toastCenter = ToastHaptics.shared
    @StateObject private var autoConnector: BLEAutoConnector

    init() {
        let manager = PrinterBLEManager()
        _ble = StateObject(wrappedValue: manager)
        _autoConnector = StateObject(wrappedValue: BLEAutoConnector(ble: manager))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(
                ble: ble,
                settings: settings,
                history: history,
                autoConnector: autoConnector
            )
            .overlay(alignment: .top) {
                if let toast = toastCenter.toast {
                    ToastBanner(message: toast)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: toastCenter.toast)
            .onAppear {
                autoConnector.onAppear()
            }
        }
    }
}
