import Foundation

struct ImportedPDF {
    let displayName: String
    let localURL: URL
}

final class ImportedPDFStore {
    static let shared = ImportedPDFStore()

    private let folder: URL
    private let fileManager: FileManager

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let appFolder = base.appendingPathComponent("BluetoothPrinterApp", isDirectory: true)
        let importedFolder = appFolder.appendingPathComponent("ImportedPDFs", isDirectory: true)
        if !fileManager.fileExists(atPath: importedFolder.path) {
            try? fileManager.createDirectory(at: importedFolder, withIntermediateDirectories: true, attributes: nil)
        }
        folder = importedFolder
    }

    func importFile(from sourceURL: URL) throws -> ImportedPDF {
        let ext = sourceURL.pathExtension.isEmpty ? "pdf" : sourceURL.pathExtension
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let safeName = baseName.isEmpty ? "Label" : baseName
        let destination = folder.appendingPathComponent("\(safeName)-\(UUID().uuidString).\(ext)")

        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try fileManager.copyItem(at: sourceURL, to: destination)
        return ImportedPDF(displayName: sourceURL.lastPathComponent, localURL: destination)
    }
}
