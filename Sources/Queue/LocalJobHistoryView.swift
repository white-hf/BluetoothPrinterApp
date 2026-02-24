import SwiftUI

struct LocalJobHistoryView: View {
    @ObservedObject var history: LocalJobHistoryStore

    @State private var query: String = ""
    @State private var showClearConfirm = false

    private var filtered: [LocalPrintJob] {
        guard !query.isEmpty else { return history.jobs }
        return history.jobs.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            if history.jobs.isEmpty {
                Section {
                    Text("No history yet")
                        .foregroundColor(.secondary)
                }
            } else {
                Section(header: Text("Total \(history.jobs.count)")) {
                    ForEach(filtered) { job in
                        HistoryRow(job: job)
                    }
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic))
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !history.jobs.isEmpty {
                    Button("Clear") {
                        showClearConfirm = true
                    }
                    .tint(.red)
                }
            }
        }
        .confirmationDialog("Clear all history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear", role: .destructive) {
                history.removeAll()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct HistoryRow: View {
    let job: LocalPrintJob

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(job.displayName)
                    .font(.system(.body, design: .monospaced))
                    .bold()
                Spacer()
                Text(job.state.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(stateColor.opacity(0.2))
                    .foregroundColor(stateColor)
                    .cornerRadius(6)
            }
            Text(job.createdAt, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
            if let message = job.errorMessage, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
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
