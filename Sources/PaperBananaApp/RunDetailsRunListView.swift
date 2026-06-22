import SwiftUI

struct RunDetailsRunListView: View {
    let runs: [RunDetailsItem]
    @Binding var selectedRunID: RunDetailsItem.ID?

    var body: some View {
        Group {
            if runs.isEmpty {
                ArtifactEmptyStateView(
                    title: "No Runs Found",
                    systemImage: "waveform.path.ecg.rectangle",
                    description: "Native PaperBanana runs appear here after image refinement starts."
                )
                .padding(AppDesignSystem.Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                runTable
            }
        }
    }

    private var runTable: some View {
        VStack(spacing: 0) {
            Table(runs, selection: $selectedRunID) {
                TableColumn("Status") { item in
                    RunDetailsStatusLabel(status: item.run.status, needsAttention: item.needsAttention)
                }
                .width(min: 140, ideal: 170)

                TableColumn("Modified") { item in
                    Text(item.run.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                        .lineLimit(1)
                }
                .width(min: 140, ideal: 160)

                TableColumn("Run") { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .lineLimit(1)
                        Text(item.workflow)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .width(min: 220, ideal: 320)

                TableColumn("Model") { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.modelLabel)
                            .lineLimit(1)
                        Text("\(item.resolution) · \(item.aspectRatio)")
                            .font(AppDesignSystem.Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .width(min: 150, ideal: 190)

                TableColumn("Stage") { item in
                    Text(item.currentStage)
                        .lineLimit(1)
                }
                .width(min: 110, ideal: 140)

                TableColumn("Elapsed") { item in
                    Text(item.elapsedTimeText)
                        .lineLimit(1)
                }
                .width(min: 90, ideal: 110)

                TableColumn("Artifacts") { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(item.outputURLs.count) output")
                            .lineLimit(1)
                        Text("\(item.recoverableURLs.count) recoverable")
                            .font(AppDesignSystem.Typography.caption)
                            .foregroundStyle(item.recoverableURLs.isEmpty ? .secondary : AppDesignSystem.SemanticColors.statusFailed)
                            .lineLimit(1)
                    }
                }
                .width(min: 130, ideal: 150)

                TableColumn("Provider") { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.providerSummary)
                            .lineLimit(1)
                        Text(item.providerCallSummary)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .width(min: 180, ideal: 260)
            }
            .accessibilityLabel("Run list")
            .accessibilityValue("\(runs.count) runs shown")
            .accessibilityHint("Use the arrow keys to select a run and review its details.")
            .accessibilityIdentifier("run-details-table")
            .accessibilityChildren {
                ForEach(runs) { item in
                    Text(accessibilityLabel(for: item))
                        .accessibilityLabel(accessibilityLabel(for: item))
                        .accessibilityValue(accessibilityValue(for: item))
                        .accessibilityAddTraits(item.id == selectedRunID ? [.isSelected] : [])
                }
            }

            Divider()

            NativeTableSelectionSummary(
                title: "Selected run",
                value: selectedRunSummary,
                systemImage: "arrow.up.and.down.and.arrow.left.and.right",
                identifier: "run-details-table-selection-summary"
            )
        }
    }

    private var selectedRun: RunDetailsItem? {
        guard let selectedRunID else { return nil }
        return runs.first { $0.id == selectedRunID }
    }

    private var selectedRunSummary: String {
        guard let selectedRun else {
            return runs.isEmpty ? "No runs available." : "No run selected."
        }
        return accessibilityValue(for: selectedRun)
    }

    private func accessibilityLabel(for item: RunDetailsItem) -> String {
        "\(item.title), \(item.run.status.label)"
    }

    private func accessibilityValue(for item: RunDetailsItem) -> String {
        [
            "Workflow \(item.workflow)",
            "Stage \(item.currentStage)",
            "Model \(item.modelLabel)",
            "Resolution \(item.resolution)",
            "Aspect ratio \(item.aspectRatio)",
            "Elapsed \(item.elapsedTimeText)",
            "\(item.outputURLs.count) output files",
            "\(item.recoverableURLs.count) recoverable files",
            "Provider \(item.providerSummary)",
            item.needsAttention ? "Needs attention" : nil
        ]
        .compactMap { $0 }
        .joined(separator: ". ")
    }
}

struct RunDetailsStatusLabel: View {
    let status: ArtifactRunStatus
    let needsAttention: Bool

    var body: some View {
        Label(label, systemImage: image)
            .foregroundStyle(color)
            .lineLimit(1)
            .accessibilityLabel(label)
    }

    private var label: String {
        needsAttention ? "Needs Attention" : status.label
    }

    private var image: String {
        needsAttention ? "exclamationmark.triangle" : status.systemImage
    }

    private var color: Color {
        if needsAttention { return AppDesignSystem.SemanticColors.statusFailed }
        switch status {
        case .completed:
            return AppDesignSystem.SemanticColors.statusReady
        case .running:
            return AppDesignSystem.SemanticColors.statusStarting
        case .timedOut, .stalled, .cancelled, .failed, .unknown:
            return AppDesignSystem.SemanticColors.statusFailed
        }
    }
}
