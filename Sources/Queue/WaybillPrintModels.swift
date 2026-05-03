import Foundation

enum WaybillPrintJobState: String, Codable, CaseIterable {
    case queued
    case downloading
    case rendering
    case sending
    case waitingConfirm
    case success
    case failed
    case skipped

    var isTerminal: Bool {
        switch self {
        case .success, .failed, .skipped:
            return true
        default:
            return false
        }
    }

    var stateDescription: String {
        switch self {
        case .queued: return L10n.jobQueued
        case .downloading: return L10n.jobDownloading
        case .rendering: return L10n.jobRendering
        case .sending: return L10n.jobSending
        case .waitingConfirm: return L10n.jobWaitingConfirm
        case .failed: return L10n.jobFailed
        case .success: return L10n.jobSuccess
        case .skipped: return L10n.jobSkipped
        }
    }
}

struct WaybillPrintJob: Identifiable, Codable, Equatable {
    let id: UUID
    var tno: String
    var createdAt: Date
    var updatedAt: Date
    var state: WaybillPrintJobState
    var errorMessage: String?
    var attempts: Int

    init(
        id: UUID = UUID(),
        tno: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        state: WaybillPrintJobState = .queued,
        errorMessage: String? = nil,
        attempts: Int = 0
    ) {
        self.id = id
        self.tno = tno
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.state = state
        self.errorMessage = errorMessage
        self.attempts = attempts
    }

    func updatingState(_ newState: WaybillPrintJobState, errorMessage: String? = nil) -> WaybillPrintJob {
        WaybillPrintJob(
            id: id,
            tno: tno,
            createdAt: createdAt,
            updatedAt: Date(),
            state: newState,
            errorMessage: errorMessage ?? self.errorMessage,
            attempts: attempts
        )
    }

    func incrementingAttempts(state newState: WaybillPrintJobState, errorMessage: String? = nil) -> WaybillPrintJob {
        WaybillPrintJob(
            id: id,
            tno: tno,
            createdAt: createdAt,
            updatedAt: Date(),
            state: newState,
            errorMessage: errorMessage ?? self.errorMessage,
            attempts: attempts + 1
        )
    }
}

extension Array where Element == WaybillPrintJob {
    func index(of jobID: UUID) -> Int? {
        firstIndex { $0.id == jobID }
    }
}
