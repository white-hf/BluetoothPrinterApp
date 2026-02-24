import SwiftUI

struct RootTabView: View {
    @ObservedObject var ble: PrinterBLEManager
    @ObservedObject var settings: PrintSettingsStore
    @ObservedObject var history: LocalJobHistoryStore
    @ObservedObject var autoConnector: BLEAutoConnector

    var body: some View {
        TabView {
            NavigationStack {
                LocalFilePrintView(ble: ble, settings: settings, history: history)
            }
            .tabItem {
                Label("Print", systemImage: "printer")
            }

            NavigationStack {
                PrinterDiscoveryView(ble: ble)
            }
            .tabItem {
                Label("Devices", systemImage: "dot.radiowaves.left.and.right")
            }

            NavigationStack {
                PrinterConfigView(settings: settings, ble: ble)
            }
            .tabItem {
                Label("Settings", systemImage: "slider.horizontal.3")
            }

            NavigationStack {
                LocalJobHistoryView(history: history)
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
        }
    }
}
