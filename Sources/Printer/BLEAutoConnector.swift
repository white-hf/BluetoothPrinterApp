//
//  BLEAutoConnector.swift
//  ScanSystem
//
//  Created by John Tang on 2025-09-22.
//

import Combine
import Foundation

@MainActor
final class BLEAutoConnector: ObservableObject {
    private let ble: PrinterBLEManager
    private let settings: PrintSettingsStore
    private var cancellables = Set<AnyCancellable>()

    init(
        ble: PrinterBLEManager,
        settings: PrintSettingsStore = .shared
    ) {
        self.ble = ble
        self.settings = settings

        ble.$state
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .connected:
                    self.persistCurrentPrinterIfNeeded()
                case .failed(let error):
                    ToastHaptics.shared.show(L10n.bleFailedWithError("\(error)"), style: .error)
                case .disconnected:
                    break
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    func onAppear() {
        Task { [weak self] in
            guard let self else { return }
            let defaultID = self.settings.settings.defaultPeripheralID
            ble.autoConnectIfNeeded(defaultPeripheralID: defaultID)
        }
    }

    func connectOnDemand() {
        let defaultID = settings.settings.defaultPeripheralID
        ble.autoConnectIfNeeded(defaultPeripheralID: defaultID)
    }

    func onDisappear() {
        ble.stopScan()
        if case .connecting = ble.state {
            ble.disconnect()
        }
    }

    func persistCurrentPrinterIfNeeded() {
        guard let identifier = ble.connectedPeripheralIdentifier else { return }
        settings.update { settings in
            settings.defaultPeripheralID = identifier
            settings.defaultPeripheralName = ble.connectedName
        }
    }
}
