import Foundation
import UIKit

@MainActor
final class WaybillPrintCoordinator: ObservableObject {
    @Published private(set) var jobs: [WaybillPrintJob] = []
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var waitingSince: Date?
    @Published var bannerMessage: String?
    @Published private(set) var currentPreview: UIImage?

    var currentJob: WaybillPrintJob? { jobs.first }
    var queueCount: Int { max(jobs.count - 1, 0) }

    private let ble: PrinterBLEManager
    private let settings: PrintSettingsStore
    private let history: WaybillJobHistoryStore
    private let renderer = TSPLRenderer()
    private let api = LabelAPI()
    private let discovery = ServerDiscoveryManager.shared

    private var currentTask: Task<Void, Never>?
    private var pendingConfirmationJobID: UUID?
    private var autoConfirmTask: Task<Void, Never>?
    private var isPaused = true

    init(
        ble: PrinterBLEManager,
        settings: PrintSettingsStore = .shared,
        history: WaybillJobHistoryStore = .shared
    ) {
        self.ble = ble
        self.settings = settings
        self.history = history
    }

    private func getEffectiveBaseURL() -> URL? {
        // If settings has a valid non-default URL, use it
        if let settingsURL = settings.settings.baseURL, 
           settings.settings.baseURLString != "http://192.168.1.100:5000" {
            return settingsURL
        }
        // Otherwise, use the first discovered server
        return discovery.discoveredServers.first?.url ?? settings.settings.baseURL
    }

    func enqueue(tno: String) {
        let normalized = tno.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        // Avoid duplicates in the queue
        if jobs.contains(where: { $0.tno == normalized }) { return }
        
        let job = WaybillPrintJob(tno: normalized)
        jobs.append(job)
        if !isPaused {
            pumpQueue()
        }
    }

    func remove(jobID: UUID) {
        let wasCurrent = currentJob?.id == jobID
        jobs.removeAll { $0.id == jobID }
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
        history.record(job.updatingState(.success, errorMessage: nil))
        jobs.removeAll { $0.id == job.id }
        pendingConfirmationJobID = nil
        autoConfirmTask?.cancel()
        autoConfirmTask = nil
        waitingSince = nil
        currentPreview = nil
        ToastHaptics.shared.show(L10n.printComplete, style: .success)
        pumpQueue()
        }

    func retryCurrentJob() {
        guard let job = currentJob else { return }
        var updated = job.incrementingAttempts(state: .queued, errorMessage: nil)
        updated.errorMessage = nil
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
        let resolved = job.updatingState(.skipped, errorMessage: nil)
        history.record(resolved)
        jobs.removeAll { $0.id == job.id }
        pendingConfirmationJobID = nil
        waitingSince = nil
        autoConfirmTask?.cancel()
        autoConfirmTask = nil
        currentPreview = nil
        ToastHaptics.shared.show(L10n.skippedJob(job.tno), style: .warning)
        pumpQueue()
    }

    func currentJobTimeoutSeconds() -> Int {
        settings.settings.tCompleteSeconds
    }

    // MARK: - Pipeline

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
        case .downloading, .rendering, .sending:
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

        guard let jobIndex = jobs.index(of: jobID) else { return }
        var job = jobs[jobIndex]
        isProcessing = true
        bannerMessage = nil
        currentPreview = nil

        do {
            job = job.updatingState(.downloading, errorMessage: nil)
            replace(job: job)
            let baseURL = getEffectiveBaseURL()
            let pdfData: Data
            do {
                pdfData = try await api.downloadLabel(tno: job.tno, baseURL: baseURL)
            } catch {
                if Self.isNotFound(error) {
                    let message = L10n.noWaybillFound(job.tno)
                    let skipped = job.updatingState(.skipped, errorMessage: message)
                    history.record(skipped)
                    jobs.removeAll { $0.id == job.id }
                    pendingConfirmationJobID = nil
                    waitingSince = nil
                    currentPreview = nil
                    ToastHaptics.shared.show(message, style: .warning)
                    return
                } else {
                    throw error
                }
            }

            job = job.updatingState(.rendering, errorMessage: nil)
            replace(job: job)
            let output = try renderer.render(pdfData: pdfData, settings: settings.settings, tno: job.tno)
            currentPreview = renderer.makePreviewImage(from: output, settings: settings.settings)

            try Task.checkCancellation()

            job = job.updatingState(.sending, errorMessage: nil)
            replace(job: job)
            try await ble.connectIfNeeded(defaultPeripheralID: settings.settings.defaultPeripheralID)
            try await ble.sendInChunksAwait(output.data, chunkSize: settings.settings.chunkSize)

            job = job.updatingState(.waitingConfirm, errorMessage: nil)
            replace(job: job)
            pendingConfirmationJobID = job.id
            waitingSince = Date()
            ToastHaptics.shared.show(L10n.sentToPrinter, style: .info)

            autoConfirmTask?.cancel()
            let timeout = max(1, settings.settings.tCompleteSeconds)
            autoConfirmTask = Task { @MainActor in
                if #available(iOS 16.0, *) {
                    try? await Task.sleep(for: .seconds(Double(timeout)))
                } else {
                    try? await Task.sleep(nanoseconds: UInt64(timeout) * 1_000_000_000)
                }
                if self.pendingConfirmationJobID == job.id,
                   let head = self.jobs.first, head.id == job.id, head.state == .waitingConfirm {
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
            ToastHaptics.shared.show(L10n.printFailed(error.localizedDescription), style: .error)
        }
    }

    private func replace(job: WaybillPrintJob) {
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

    private static func isNotFound(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.code == 404 { return true }
        if let status = ns.userInfo["statusCode"] as? Int, status == 404 { return true }
        if let responseCode = ns.userInfo["HTTPStatusCode"] as? Int, responseCode == 404 { return true }
        if ns.localizedDescription.contains("404") { return true }
        return false
    }
}
