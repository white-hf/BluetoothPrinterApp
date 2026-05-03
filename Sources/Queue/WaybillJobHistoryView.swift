import SwiftUI

struct WaybillJobHistoryView: View {
    @ObservedObject var history: WaybillJobHistoryStore
    @Environment(\.dismiss) var dismiss

    @State private var query: String = ""
    @State private var showClearConfirm = false

    private var filtered: [WaybillPrintJob] {
        guard !query.isEmpty else { return history.jobs }
        return history.jobs.filter { $0.tno.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            if history.jobs.isEmpty {
                Section {
                    Text(L10n.noHistoryYet)
                        .foregroundColor(.secondary)
                }
            } else {
                Section(header: Text(L10n.totalItems(history.jobs.count))) {
                    ForEach(filtered) { job in
                        WaybillHistoryRow(job: job)
                    }
                }
            }
        }
        .searchable(text: $query, prompt: L10n.searchWaybillPrompt)
        .navigationTitle(L10n.tabHistory)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !history.jobs.isEmpty {
                    Button(L10n.btnClear) {
                        showClearConfirm = true
                    }
                    .tint(.red)
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(L10n.btnClose) { dismiss() }
            }
        }
        .confirmationDialog(L10n.clearHistoryConfirm, isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button(L10n.btnClear, role: .destructive) {
                history.removeAll()
            }
            Button(L10n.cancel, role: .cancel) {}
        }
    }
}

private struct WaybillHistoryRow: View {
    let job: WaybillPrintJob

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(job.tno)
                    .font(.system(.body, design: .monospaced))
                    .bold()
                Spacer()
                Text(job.state.stateDescription)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(stateColor.opacity(0.15))
                    .foregroundColor(stateColor)
                    .cornerRadius(6)
            }
            HStack {
                Text(job.createdAt, style: .date)
                Text(job.createdAt, style: .time)
                if job.attempts > 1 {
                    Text("· " + L10n.retryCount(job.attempts - 1))
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            if let message = job.errorMessage, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var stateColor: Color {
        switch job.state {
        case .success: return .green
        case .failed: return .red
        case .skipped: return .gray
        default: return .blue
        }
    }
}
