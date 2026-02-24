import Foundation

enum LocalPrintJobState: String, Codable, CaseIterable {
    case queued
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
}

struct LocalPrintJob: Identifiable, Codable, Equatable {
    let id: UUID
    var displayName: String
    var createdAt: Date
    var updatedAt: Date
    var state: LocalPrintJobState
    var errorMessage: String?
    var attempts: Int

    init(
        id: UUID = UUID(),
        displayName: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        state: LocalPrintJobState = .queued,
        errorMessage: String? = nil,
        attempts: Int = 0
    ) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.state = state
        self.errorMessage = errorMessage
        self.attempts = attempts
    }

    func updatingState(_ newState: LocalPrintJobState, errorMessage: String? = nil) -> LocalPrintJob {
        LocalPrintJob(
            id: id,
            displayName: displayName,
            createdAt: createdAt,
            updatedAt: Date(),
            state: newState,
            errorMessage: errorMessage,
            attempts: attempts
        )
    }

    func incrementingAttempts(state newState: LocalPrintJobState, errorMessage: String? = nil) -> LocalPrintJob {
        LocalPrintJob(
            id: id,
            displayName: displayName,
            createdAt: createdAt,
            updatedAt: Date(),
            state: newState,
            errorMessage: errorMessage,
            attempts: attempts + 1
        )
    }
}

extension Array where Element == LocalPrintJob {
    func index(of jobID: UUID) -> Int? {
        firstIndex { $0.id == jobID }
    }
}
