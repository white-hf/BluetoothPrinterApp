//
//  PrinterBLEManager.swift
//  ScanSystem
//
//  Created by John Tang on 2025-09-15.
//

import Foundation
import CoreBluetooth
import Combine

// 连接状态
enum BLEConnectionState: Equatable {
    case idle
    case scanning
    case connecting(name: String?)
    case connected(name: String?)
    case failed(error: String)
    case disconnected
}

enum PrinterBLEError: LocalizedError {
    case busy
    case notReady
    case missingCharacteristic
    case connectionFailed(String)
    case invalidParameters

    var errorDescription: String? {
        switch self {
        case .busy:
            return L10n.bleBusy
        case .notReady:
            return L10n.bleNotReady
        case .missingCharacteristic:
            return L10n.bleMissingChar
        case .connectionFailed(let message):
            return message
        case .invalidParameters:
            return L10n.bleInvalidParams
        }
    }
}

// 扫描到的设备模型
struct DiscoveredPeripheral: Identifiable, Equatable {
    let id: UUID
    let peripheral: CBPeripheral
    var name: String
    var advName: String?
    var rssi: Int
    var manufacturerData: Data?
    var serviceUUIDs: [CBUUID]
    
    init(peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        self.id = peripheral.identifier
        self.peripheral = peripheral
        self.rssi = rssi.intValue
        self.advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        self.manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        self.serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        self.name = peripheral.name ?? self.advName ?? L10n.unknown
    }
}

@MainActor
final class PrinterBLEManager: NSObject, ObservableObject {
    // MARK: - Public Published
    @Published var state: BLEConnectionState = .idle
    @Published var devices: [DiscoveredPeripheral] = []
    @Published var connectedName: String?
    @Published var isSending: Bool = false

    var connectedPeripheralIdentifier: UUID? {
        connectedPeripheral?.identifier
    }

    // MARK: - Private
    private var central: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var cancellables = Set<AnyCancellable>()
    private let settingsStore: PrintSettingsStore
    private var writeCharacteristicUUIDs: [CBUUID] = []

    // 用于处理异步发送的队列
    private var dataQueue = [Data]()
    private var isWriting = false
    private var pendingScan: Bool = false
    private var pendingScanTimeout: TimeInterval = 10
    private var sendCompletion: ((Result<Void, Error>) -> Void)?
    private var connectContinuations: [CheckedContinuation<Void, Error>] = []
    private var autoConnectTarget: UUID?

    private func resolveConnectContinuations(_ result: Result<Void, Error>) {
        let continuations = connectContinuations
        connectContinuations.removeAll()
        continuations.forEach { $0.resume(with: result) }
    }

    init(settings: PrintSettingsStore = .shared) {
        self.settingsStore = settings
        self.writeCharacteristicUUIDs = settings.settings.writeCharacteristicUUIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { CBUUID(string: $0) }
        super.init()
        bindSettings()
        self.central = CBCentralManager(delegate: self, queue: .main)
    }

    private func bindSettings() {
        settingsStore.$settings
            .map { settings in
                settings.writeCharacteristicUUIDs
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { CBUUID(string: $0) }
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] values in
                self?.writeCharacteristicUUIDs = values
            }
            .store(in: &cancellables)
    }

    // MARK: - Scanning
    func startScan() {
        guard central.state == .poweredOn else {
            pendingScan = true
            pendingScanTimeout = 10
            state = .failed(error: "Bluetooth Not Ready")
            return
        }
        beginScan(timeout: 10)
    }
    
    func beginScan(timeout: TimeInterval) {
        devices.removeAll()
        state = .scanning
        
        central.scanForPeripherals(withServices: nil,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.stopScan()
        }
        print("[BLE] scanning for all peripherals...")
    }

    func stopScan() {
        guard state == .scanning else { return }
        central.stopScan()
        if case .scanning = state { state = .idle }
        print("[BLE] stop scan")
    }

    // MARK: - Connect / Disconnect
    func autoConnectIfNeeded(defaultPeripheralID: UUID?) {
        guard let uuid = defaultPeripheralID else { return }
        autoConnectTarget = uuid

        if case .connecting = state {
            return
        }

        if let current = connectedPeripheral, current.identifier == uuid, current.state == .connected {
            return
        }

        guard central.state == .poweredOn else {
            pendingScan = true
            pendingScanTimeout = 8
            return
        }

        let retrieved = central.retrievePeripherals(withIdentifiers: [uuid])
        if let target = retrieved.first {
            connectedPeripheral = target
            connectedPeripheral?.delegate = self
            connectedName = target.name
            state = .connecting(name: target.name)
            central.connect(target, options: nil)
        } else {
            beginScan(timeout: 8)
        }
    }

    func connectIfNeeded(defaultPeripheralID: UUID? = nil) async throws {
        if let peripheral = connectedPeripheral,
           peripheral.state == .connected,
           writeChar != nil {
            return
        }

        let target = defaultPeripheralID ?? autoConnectTarget ?? connectedPeripheral?.identifier
        guard let uuid = target else {
            throw PrinterBLEError.notReady
        }

        autoConnectIfNeeded(defaultPeripheralID: uuid)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connectContinuations.append(continuation)
        }
    }

    func connect(_ item: DiscoveredPeripheral) {
        // 先检查是否已经连接
        if connectedPeripheral == item.peripheral && connectedPeripheral?.state == .connected {
            print("[BLE] Already connected to \(item.name)")
            return
        }
        
        autoConnectTarget = item.id
        // 关键改动：先不停止扫描，让它继续运行，直到连接成功或失败
        state = .connecting(name: item.name)
        connectedPeripheral = item.peripheral
        if let n = item.advName, !n.isEmpty {
            connectedName = n
        }
        connectedPeripheral?.delegate = self
        central.connect(item.peripheral, options: nil)
        print("[BLE] Connecting to \(item.name)...")
    }

    func disconnect() {
        stopScan()
        if let p = connectedPeripheral {
            central.cancelPeripheralConnection(p)
        }
        connectedPeripheral = nil
        writeChar = nil
        connectedName = nil
        autoConnectTarget = nil
        state = .disconnected
    }

    // MARK: - Send (异步队列分包)
    func sendInChunksAwait(_ data: Data, chunkSize: Int) async throws {
        guard chunkSize > 0 else { throw PrinterBLEError.invalidParameters }
        guard case .connected = state else { throw PrinterBLEError.notReady }
        guard let _ = writeChar else { throw PrinterBLEError.missingCharacteristic }
        guard dataQueue.isEmpty, !isSending, sendCompletion == nil else {
            throw PrinterBLEError.busy
        }

        let chunks = stride(from: 0, to: data.count, by: chunkSize).map { offset -> Data in
            let upper = min(offset + chunkSize, data.count)
            return data.subdata(in: offset..<upper)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sendCompletion = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            send(commands: chunks)
        }
    }

    // 这是新的公共方法，用于发送命令或大块数据
    func send(commands: [Data]) {
        guard let p = connectedPeripheral,
              let wc = writeChar else {
            print("[BLE] Send failed: Connected peripheral or write characteristic not found.")
            return
        }
        
        // 检查写入类型
        let prefersNoResp = wc.properties.contains(.writeWithoutResponse)
        let writeType: CBCharacteristicWriteType = prefersNoResp ? .withoutResponse : .withResponse
        
        // 打印机通常有20-512字节的MTU
        let mtu = p.maximumWriteValueLength(for: writeType)
        
        // 将所有命令和数据块添加到队列
        self.dataQueue.append(contentsOf: commands)
        
        // 开始发送
        isSending = true
        processQueue()
    }
    
    // 发送队列中的下一个数据块
    private func processQueue() {
        guard let p = connectedPeripheral,
              let wc = writeChar,
              !isWriting,
              !self.dataQueue.isEmpty else {
            if self.dataQueue.isEmpty {
                isSending = false
                if let completion = sendCompletion {
                    sendCompletion = nil
                    completion(.success(()))
                }
                print("[BLE] All data sent successfully.")
            }
            return
        }
        
        isWriting = true
        let chunk = self.dataQueue.removeFirst()
        let writeType: CBCharacteristicWriteType = wc.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        p.writeValue(chunk, for: wc, type: writeType)

        // 如果是 withoutResponse 类型，手动添加一个短暂延迟以进行流控
        // 如果是 withResponse，则等待 didWriteValueFor 回调
        if writeType == .withoutResponse {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.005) {
                self.isWriting = false
                self.processQueue()
            }
        }
    }

    // MARK: - Helper：发送字符串
    func sendCommandString(_ cmd: String, appendCRLF: Bool = true, encoding: String.Encoding = .utf8) {
        let text = appendCRLF ? (cmd.hasSuffix("\n") ? cmd : cmd + "\r\n") : cmd
        if let d = text.data(using: encoding) {
            send(commands: [d])
        }
    }

    // MARK: - 快速自检打印
    func printTestTSPL() {
        guard case .connected = state, writeChar != nil else { return }
        let cmds = [
            "SIZE 100 mm,150 mm",
            "GAP 3 mm,0",
            "DENSITY 8",
            "DIRECTION 1",
            "CLS",
            #"TEXT 40,60,"0",0,1,1,"POLONO PL80E TEST""#,
            #"BARCODE 40,120,"128",100,1,0,2,2,"1Z1234567890""#,
            #"QRCODE 40,260,L,5,A,0,M2,S1,"https://example.com/track/12345""#,
            "PRINT 1"
        ]
        var dataCommands: [Data] = []
        for c in cmds {
            if let d = (c + "\r\n").data(using: .utf8) {
                dataCommands.append(d)
            }
        }
        send(commands: dataCommands)
    }
    
    func clearPrintJob() {
        guard case .connected = state, writeChar != nil else { return }
        sendCommandString("CLS")
        print("[BLE] Sent CLS command to clear print job.")
    }
}

// MARK: - CBCentralManagerDelegate
extension PrinterBLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unsupported:
            state = .failed(error: "Bluetooth Unsupported")
        case .unauthorized:
            state = .failed(error: "Bluetooth Unauthorized")
        case .poweredOff:
            state = .failed(error: "Bluetooth Off")
        case .poweredOn:
            print("[BLE] poweredOn")
            if pendingScan {
                pendingScan = false
                beginScan(timeout: pendingScanTimeout)
            }
            if let target = autoConnectTarget {
                autoConnectIfNeeded(defaultPeripheralID: target)
            }
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        
        var newItem = DiscoveredPeripheral(
            peripheral: peripheral,
            advertisementData: advertisementData,
            rssi: RSSI
        )
        
        let isPrinter = newItem.name.contains("PL80E") || newItem.advName?.contains("PL80E") ?? false
        
        if isPrinter {
             if newItem.name == "Unknown" || newItem.name.isEmpty {
                  newItem.name = "Polono PL80E"
             }

            if let target = autoConnectTarget, peripheral.identifier == target {
                connect(newItem)
            }
            
            if let idx = devices.firstIndex(where: { $0.id == peripheral.identifier }) {
                var old = devices[idx]
                old.rssi = newItem.rssi
                if let newAdvName = newItem.advName, newAdvName.isEmpty == false {
                    old.advName = newAdvName
                }
                if let newName = peripheral.name, newName.isEmpty == false {
                    old.name = newName
                }
                devices[idx] = old
            } else {
                devices.append(newItem)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[BLE] Successfully connected to \(peripheral.name ?? "unknown")")
        // 关键改动：在连接成功后，停止扫描
        stopScan()
        connectedName = peripheral.name
        state = .connected(name: peripheral.name)
        
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let message = error?.localizedDescription ?? "Connect failed"
        print("[BLE] Failed to connect to \(peripheral.name ?? "unknown"): \(message)")
        state = .failed(error: message)
        resolveConnectContinuations(.failure(PrinterBLEError.connectionFailed(message)))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let message = error?.localizedDescription ?? "Disconnected"
        print("[BLE] Disconnected from \(peripheral.name ?? "unknown"): \(message)")
        state = .disconnected
        writeChar = nil
        connectedPeripheral = nil
        connectedName = nil
        if let completion = sendCompletion {
            sendCompletion = nil
            completion(.failure(PrinterBLEError.notReady))
        }
        if !connectContinuations.isEmpty {
            resolveConnectContinuations(.failure(PrinterBLEError.connectionFailed(message)))
        }
    }
}

// MARK: - CBPeripheralDelegate
extension PrinterBLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        print("[BLE] Discovered services for \(peripheral.name ?? "unknown"): \(services.map { $0.uuid })")
        for s in services {
            peripheral.discoverCharacteristics(nil, for: s)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        
        guard let characteristics = service.characteristics else { return }
        print("[BLE] Discovered characteristics for service \(service.uuid): \(characteristics.map { $0.uuid })")
        
        for c in characteristics {
            if writeCharacteristicUUIDs.contains(c.uuid) {
                writeChar = c
                print("[BLE] Found configured write characteristic: \(c.uuid)")
                self.state = .connected(name: peripheral.name)
                resolveConnectContinuations(.success(()))
                return
            }
        }
        
        if writeChar == nil {
            for c in characteristics {
                if c.properties.contains(.write) || c.properties.contains(.writeWithoutResponse) {
                    writeChar = c
                    print("[BLE] Found fallback write characteristic: \(c.uuid)")
                    self.state = .connected(name: peripheral.name)
                    resolveConnectContinuations(.success(()))
                    return
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let e = error {
            print("[BLE] Write value error: \(e.localizedDescription)")
            state = .failed(error: "Write error: \(e.localizedDescription)")
            self.dataQueue.removeAll()
            if let completion = sendCompletion {
                sendCompletion = nil
                completion(.failure(e))
            }
        } else {
            print("[BLE] write value success.")
        }
        
        // 只有当有响应时，才继续发送下一个数据块
        isWriting = false
        processQueue()
    }
}
