import SwiftUI

@main
struct SwiftPrintBLEApp: App {
    @StateObject private var ble: PrinterBLEManager
    @StateObject private var settings = PrintSettingsStore.shared
    @StateObject private var history = LocalJobHistoryStore.shared
    @StateObject private var waybillHistory = WaybillJobHistoryStore.shared
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
                waybillHistory: waybillHistory,
                autoConnector: autoConnector
            )
            .overlay(alignment: toastCenter.toast?.position == .center ? .center : .top) {
                if let toast = toastCenter.toast {
                    ToastBanner(message: toast)
                        .padding(toast.position == .center ? [] : .top, 8) // Corrected padding for center
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
