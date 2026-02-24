import Foundation

@MainActor
final class LocalJobHistoryStore: ObservableObject {
    static let shared = LocalJobHistoryStore()

    @Published private(set) var jobs: [LocalPrintJob] = []

    private let persistenceURL: URL
    private nonisolated let ioQueue = DispatchQueue(label: "com.bluetoothprinter.history")
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let maxEntries = 500

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

        persistenceURL = folder.appendingPathComponent("print_history.json")

        if let data = try? Data(contentsOf: persistenceURL), !data.isEmpty {
            do {
                jobs = try decoder.decode([LocalPrintJob].self, from: data)
            } catch {
                print("[HistoryStore] Failed to decode history: \(error)")
                jobs = []
            }
        }
    }

    func record(_ job: LocalPrintJob) {
        var snapshot = jobs
        if let idx = snapshot.firstIndex(where: { $0.id == job.id }) {
            snapshot[idx] = job
        } else {
            snapshot.insert(job, at: 0)
        }
        if snapshot.count > maxEntries {
            snapshot = Array(snapshot.prefix(maxEntries))
        }
        jobs = snapshot
        persist(snapshot)
    }

    func removeAll() {
        jobs.removeAll()
        persist([])
    }

    private func persist(_ snapshot: [LocalPrintJob]) {
        let encoder = self.encoder
        let url = persistenceURL
        ioQueue.async {
            do {
                let data = try encoder.encode(snapshot)
                try data.write(to: url, options: [.atomic])
            } catch {
                print("[HistoryStore] Persist error: \(error)")
            }
        }
    }
}
