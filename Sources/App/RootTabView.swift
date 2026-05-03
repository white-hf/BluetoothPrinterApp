import SwiftUI

struct RootTabView: View {
    @ObservedObject var ble: PrinterBLEManager
    @ObservedObject var settings: PrintSettingsStore
    @ObservedObject var history: LocalJobHistoryStore
    @ObservedObject var waybillHistory: WaybillJobHistoryStore
    @ObservedObject var autoConnector: BLEAutoConnector

    var body: some View {
        TabView {
            NavigationStack {
                WaybillPrintView(
                    ble: ble,
                    settings: settings,
                    history: waybillHistory,
                    autoConnector: autoConnector
                )
            }
            .tabItem {
                Label(L10n.tabScan, systemImage: "qrcode.viewfinder")
            }

            NavigationStack {
                LocalFilePrintView(ble: ble, settings: settings, history: history)
            }
            .tabItem {
                Label(L10n.tabLocal, systemImage: "doc.badge.plus")
            }

            NavigationStack {
                PrinterDiscoveryView(ble: ble)
            }
            .tabItem {
                Label(L10n.tabDevices, systemImage: "antenna.radiowaves.left.and.right")
            }

            NavigationStack {
                PrinterConfigView(settings: settings, ble: ble)
            }
            .tabItem {
                Label(L10n.tabSettings, systemImage: "gearshape.2")
            }
        }
    }
}
