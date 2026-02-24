import Foundation

struct PrintSettings: Codable, Equatable {
    enum Resolution: String, CaseIterable, Codable {
        case standard
        case fast

        var widthDots: Int {
            switch self {
            case .standard:
                return 800
            case .fast:
                return 600
            }
        }

        var heightDots: Int {
            switch self {
            case .standard:
                return 1200
            case .fast:
                return 900
            }
        }
    }

    var defaultPeripheralID: UUID?
    var defaultPeripheralName: String?
    var threshold: Int
    var invert: Bool
    var lsbFirst: Bool
    var chunkSize: Int
    var compressionEnabled: Bool
    var tCompleteSeconds: Int
    var resolution: Resolution
    var showWaybillOverlay: Bool
    var writeCharacteristicUUIDs: [String]

    static let `default` = PrintSettings(
        defaultPeripheralID: nil,
        defaultPeripheralName: nil,
        threshold: 180,
        invert: false,
        lsbFirst: false,
        chunkSize: 1024,
        compressionEnabled: false,
        tCompleteSeconds: 7,
        resolution: .fast,
        showWaybillOverlay: false,
        writeCharacteristicUUIDs: ["BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F"]
    )
}

@MainActor
final class PrintSettingsStore: ObservableObject {
    static let shared = PrintSettingsStore()

    @Published var settings: PrintSettings {
        didSet { persist(settings) }
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private nonisolated let ioQueue = DispatchQueue(label: "com.bluetoothprinter.settings")
    private let url: URL

    private init(fileManager: FileManager = .default) {
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        let dir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = dir.appendingPathComponent("BluetoothPrinterApp", isDirectory: true)
        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        }
        url = folder.appendingPathComponent("print_settings.json")

        if let data = try? Data(contentsOf: url), !data.isEmpty {
            do {
                settings = try decoder.decode(PrintSettings.self, from: data)
            } catch {
                print("[PrintSettings] Decode failed: \(error)")
                settings = .default
                persist(settings)
            }
        } else {
            settings = .default
            persist(settings)
        }
    }

    func update(_ transform: (inout PrintSettings) -> Void) {
        var copy = settings
        transform(&copy)
        settings = copy
    }

    private func persist(_ settings: PrintSettings) {
        let encoder = self.encoder
        let url = self.url
        ioQueue.async {
            do {
                let data = try encoder.encode(settings)
                try data.write(to: url, options: [.atomic])
            } catch {
                print("[PrintSettings] Persist failed: \(error)")
            }
        }
    }
}
