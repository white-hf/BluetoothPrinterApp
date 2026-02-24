import Foundation
import UIKit

@MainActor
final class LocalFilePrintCoordinator: ObservableObject {
    @Published private(set) var jobs: [LocalPrintJob] = []
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var waitingSince: Date?
    @Published var bannerMessage: String?
    @Published private(set) var currentPreview: UIImage?

    var currentJob: LocalPrintJob? { jobs.first }

    private let ble: PrinterBLEManager
    private let settings: PrintSettingsStore
    private let history: LocalJobHistoryStore
    private let renderer = TSPLRenderer()

    private var currentTask: Task<Void, Never>?
    private var pendingConfirmationJobID: UUID?
    private var autoConfirmTask: Task<Void, Never>?
    private var isPaused = true

    // New dictionary to map job -> imported local file URL.
    private var fileDictionary: [UUID: URL] = [:]

    init(
        ble: PrinterBLEManager,
        settings: PrintSettingsStore,
        history: LocalJobHistoryStore
    ) {
        self.ble = ble
        self.settings = settings
        self.history = history
    }

    func enqueue(displayName: String, localFileURL: URL) {
        let normalized = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        let job = LocalPrintJob(displayName: normalized)
        jobs.append(job)
        fileDictionary[job.id] = localFileURL
        if !isPaused {
            pumpQueue()
        }
    }

    func remove(jobID: UUID) {
        let wasCurrent = currentJob?.id == jobID
        jobs.removeAll { $0.id == jobID }
        fileDictionary.removeValue(forKey: jobID)
        if pendingConfirmationJobID == jobID {
            pendingConfirmationJobID = nil
            autoConfirmTask?.cancel()
            autoConfirmTask = nil
            waitingSince = nil
        }
        if wasCurrent {
            currentPreview = nil
        }
        if currentTask == nil {
            pumpQueue()
        }
    }

    func clearQueue() {
        jobs.removeAll()
        fileDictionary.removeAll()
        pendingConfirmationJobID = nil
        autoConfirmTask?.cancel()
        autoConfirmTask = nil
        waitingSince = nil
        currentTask?.cancel()
        currentTask = nil
        bannerMessage = nil
        isProcessing = false
        isPaused = true
        currentPreview = nil
    }

    func start() {
        isPaused = false
        pumpQueue()
    }

    func pauseProcessing() {
        isPaused = true
        currentTask?.cancel()
        currentTask = nil
        isProcessing = false
        bannerMessage = nil
        autoConfirmTask?.cancel()
        autoConfirmTask = nil
    }

    func confirmCurrentJobCompleted() {
        guard let job = currentJob, job.state == .waitingConfirm else { return }
        history.record(job.updatingState(.success))
        jobs.removeAll { $0.id == job.id }
        fileDictionary.removeValue(forKey: job.id)
        pendingConfirmationJobID = nil
        autoConfirmTask?.cancel()
        autoConfirmTask = nil
        waitingSince = nil
        currentPreview = nil
        ToastHaptics.shared.show("Printed", style: .success)
        pumpQueue()
    }

    func retryCurrentJob() {
        guard let job = currentJob else { return }
        let updated = job.incrementingAttempts(state: .queued)
        replace(job: updated)
        pendingConfirmationJobID = nil
        waitingSince = nil
        autoConfirmTask?.cancel()
        autoConfirmTask = nil
        bannerMessage = nil
        currentPreview = nil
        pumpQueue()
    }

    func skipCurrentJob() {
        guard let job = currentJob else { return }
        history.record(job.updatingState(.skipped))
        jobs.removeAll { $0.id == job.id }
        fileDictionary.removeValue(forKey: job.id)
        pendingConfirmationJobID = nil
        waitingSince = nil
        autoConfirmTask?.cancel()
        autoConfirmTask = nil
        currentPreview = nil
        ToastHaptics.shared.show("Skipped \(job.displayName)", style: .warning)
        pumpQueue()
    }

    func currentJobTimeoutSeconds() -> Int {
        settings.settings.tCompleteSeconds
    }

    private func pumpQueue() {
        guard currentTask == nil else { return }

        cleanupTerminalJobs()

        guard !isPaused else {
            isProcessing = false
            return
        }

        guard let first = jobs.first else {
            isProcessing = false
            bannerMessage = nil
            currentPreview = nil
            return
        }

        switch first.state {
        case .queued:
            startProcessing(jobID: first.id)
        case .failed:
            isProcessing = false
            bannerMessage = first.errorMessage
        case .waitingConfirm:
            isProcessing = false
            waitingSince = waitingSince ?? Date()
        case .rendering, .sending:
            break
        case .success, .skipped:
            cleanupTerminalJobs()
            pumpQueue()
        }
    }

    private func startProcessing(jobID: UUID) {
        guard currentTask == nil else { return }
        currentTask = Task { [weak self] in
            await self?.process(jobID: jobID)
        }
    }

    private func process(jobID: UUID) async {
        defer {
            currentTask = nil
            isProcessing = false
            pumpQueue()
        }

        guard let jobIndex = jobs.index(of: jobID), let fileURL = fileDictionary[jobID] else { return }
        var job = jobs[jobIndex]
        isProcessing = true
        bannerMessage = nil
        currentPreview = nil

        do {
            job = job.updatingState(.rendering)
            replace(job: job)

            let pdfData = try Data(contentsOf: fileURL)
            let output = try renderer.render(pdfData: pdfData, settings: settings.settings, tno: job.displayName)
            currentPreview = renderer.makePreviewImage(from: output, settings: settings.settings)

            try Task.checkCancellation()

            job = job.updatingState(.sending)
            replace(job: job)
            try await ble.connectIfNeeded(defaultPeripheralID: settings.settings.defaultPeripheralID)
            try await ble.sendInChunksAwait(output.data, chunkSize: settings.settings.chunkSize)

            job = job.updatingState(.waitingConfirm)
            replace(job: job)
            pendingConfirmationJobID = job.id
            waitingSince = Date()
            ToastHaptics.shared.show("Sent to printer", style: .info)

            autoConfirmTask?.cancel()
            let timeout = max(1, settings.settings.tCompleteSeconds)
            autoConfirmTask = Task { @MainActor in
                if #available(iOS 16.0, *) {
                    try? await Task.sleep(for: .seconds(Double(timeout)))
                } else {
                    try? await Task.sleep(nanoseconds: UInt64(timeout) * 1_000_000_000)
                }
                if self.pendingConfirmationJobID == job.id,
                   let head = self.jobs.first,
                   head.id == job.id,
                   head.state == .waitingConfirm {
                    self.confirmCurrentJobCompleted()
                }
            }
        } catch is CancellationError {
            return
        } catch {
            job = job.incrementingAttempts(state: .failed, errorMessage: error.localizedDescription)
            replace(job: job)
            history.record(job)
            bannerMessage = error.localizedDescription
            ToastHaptics.shared.show("Print failed: \(error.localizedDescription)", style: .error)
        }
    }

    private func replace(job: LocalPrintJob) {
        if let index = jobs.index(of: job.id) {
            jobs[index] = job
        }
    }

    private func cleanupTerminalJobs() {
        let currentID = currentJob?.id
        var removedCurrent = false
        jobs.removeAll { job in
            switch job.state {
            case .success, .skipped:
                history.record(job)
                fileDictionary.removeValue(forKey: job.id)
                if job.id == currentID {
                    removedCurrent = true
                }
                return true
            default:
                return false
            }
        }
        if removedCurrent {
            currentPreview = nil
            autoConfirmTask?.cancel()
            autoConfirmTask = nil
        }
    }
}
