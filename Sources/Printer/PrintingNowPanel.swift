import SwiftUI
import UIKit

struct PrintingNowPanel: View {
    @ObservedObject var coordinator: WaybillPrintCoordinator
    @ObservedObject var ble: PrinterBLEManager
    var onShowPreview: (UIImage) -> Void

    @State private var now: Date = .init()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if coordinator.jobs.isEmpty {
                Text(L10n.queueEmptyMsg)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(coordinator.jobs) { job in
                                let active = (job.state == .downloading || job.state == .rendering || job.state == .sending || job.state == .waitingConfirm) || (coordinator.currentJob?.id == job.id)
                                taskRow(job: job, isActive: active)
                                    .id(job.id)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(maxHeight: 300)
                    .onChange(of: coordinator.currentJob?.id) { id in
                        guard let id = id else { return }
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                    .onAppear {
                        if let id = coordinator.currentJob?.id {
                            DispatchQueue.main.async {
                                withAnimation(.easeInOut) {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                            }
                        }
                    }
                }

                if let job = coordinator.currentJob {
                    actionButtons(for: job)
                    if let banner = coordinator.bannerMessage {
                        Text(banner)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onReceive(timer) { value in
            now = value
        }
    }

    private var header: some View {
        HStack {
            Text(L10n.currentJobSection)
                .font(.headline)
            Spacer()
            if !coordinator.jobs.isEmpty {
                Text(L10n.totalItemsBrief(coordinator.jobs.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func actionButtons(for job: WaybillPrintJob) -> some View {
        HStack(spacing: 12) {
            if let preview = coordinator.currentPreview {
                Button {
                    onShowPreview(preview)
                } label: {
                    Label(L10n.btnPreview, systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.bordered)
            }

            if job.state == .waitingConfirm {
                Button {
                    coordinator.confirmCurrentJobCompleted()
                } label: {
                    Label(L10n.btnConfirm, systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }

            if job.state == .failed || job.state == .waitingConfirm {
                Button {
                    coordinator.retryCurrentJob()
                } label: {
                    Label(L10n.btnRetry, systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
            }

            if job.state == .failed || job.state == .waitingConfirm {
                Button(role: .destructive) {
                    coordinator.skipCurrentJob()
                } label: {
                    Label(L10n.btnSkip, systemImage: "forward.end")
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.small)
    }

    private func taskRow(job: WaybillPrintJob, isActive: Bool) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(isActive ? Color.accentColor : Color.clear)
                .frame(width: 4)
                .cornerRadius(2)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.tno)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                    Text(job.state.stateDescription)
                        .font(.caption)
                        .foregroundColor(isActive ? .accentColor : .secondary)
                }
                Spacer()
                
                if isActive && (job.state == .downloading || job.state == .rendering || job.state == .sending) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                } else if job.state == .waitingConfirm {
                    let elapsed = coordinator.waitingSince.map { Int(now.timeIntervalSince($0)) } ?? 0
                    let remain = max(coordinator.currentJobTimeoutSeconds() - elapsed, 0)
                    Text("\(remain)s")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.orange)
                } else if let error = job.errorMessage, !error.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            }
            .padding(10)
        }
        .background(isActive ? Color.accentColor.opacity(0.12) : Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isActive ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .cornerRadius(10)
    }
}
