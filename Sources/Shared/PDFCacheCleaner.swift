import Foundation

enum PDFCacheCleaner {
    private static let retentionInterval: TimeInterval = 3 * 24 * 60 * 60 // 3 days

    static func cleanStaleFiles() {
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-retentionInterval)

        var directories: [URL] = [fm.temporaryDirectory]
        if let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            directories.append(caches)
        }
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appFolder = appSupport.appendingPathComponent("BluetoothPrinterApp", isDirectory: true)
            directories.append(appFolder)
        }

        for directory in directories {
            clean(directory: directory, olderThan: cutoff, fileManager: fm)
        }
    }

    private static func clean(directory: URL, olderThan cutoff: Date, fileManager: FileManager) {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "pdf" else { continue }
            do {
                let values = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
                guard values.isRegularFile == true else { continue }
                let modificationDate = values.contentModificationDate ?? Date.distantPast
                if modificationDate < cutoff {
                    try fileManager.removeItem(at: fileURL)
                    print("[Cleaner] Removed stale PDF: \(fileURL.lastPathComponent)")
                }
            } catch {
                // Ignore errors
            }
        }
    }
}
