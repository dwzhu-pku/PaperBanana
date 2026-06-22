import AppKit
import SwiftUI

struct RefinementSheetView: View {
    let artifact: PaperBananaArtifact
    @ObservedObject var settings: AppSettingsStore
    @ObservedObject var refinementStore: NativeRefinementStore
    let onFinished: @MainActor @Sendable (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var prompt = "Keep the same scientific content, rebuild at higher resolution, improve typography and label clarity, and preserve the original layout unless a correction is needed."
    @State private var model: ImageModelChoice = .nanoBananaPro
    @State private var resolution = "4K"
    @State private var aspectRatio = "16:9"
    @State private var pendingPreflightPlan: NativeRunPreflightPlan?
    @State private var pendingRefinementRequest: NativeRefinementRequest?

    private let resolutions = ["2K", "4K"]
    private let aspectRatios = ["21:9", "16:9", "3:2", "4:3", "1:1"]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(alignment: .top, spacing: AppDesignSystem.Spacing.lg) {
                sourcePreview
                controls
            }
            .padding(AppDesignSystem.Spacing.lg)
            Divider()
            footer
        }
        .frame(minWidth: 920, minHeight: 620)
        .background(AppDesignSystem.Surfaces.content)
        .sheet(item: $pendingPreflightPlan) { plan in
            NativeRunPreflightSheet(
                plan: plan,
                onCancel: clearPendingPreflight,
                onConfirm: confirmPendingRefinement
            )
        }
    }

    private var header: some View {
        HStack(spacing: AppDesignSystem.Spacing.md) {
            Image(systemName: "wand.and.sparkles")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(artifact.wasNativeRefined ? "Refine Again" : "Refine High Resolution")
                    .font(AppDesignSystem.Typography.title)
                Text(artifact.title)
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                if refinementStore.isRunning {
                    refinementStore.cancel()
                }
                dismiss()
            } label: {
                Label("Close", systemImage: "xmark")
            }
        }
        .padding(AppDesignSystem.Spacing.lg)
    }

    private var sourcePreview: some View {
        WorkbenchSection("Source", systemImage: "photo") {
            ArtifactPreviewView(artifact: artifact)
                .frame(width: 360, height: 240)
                .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                }
            Text(artifact.relativePath)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(width: 360, alignment: .leading)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
            WorkbenchSection("Modification Instructions", systemImage: "text.bubble") {
                TextEditor(text: $prompt)
                    .font(AppDesignSystem.Typography.body)
                    .frame(minHeight: 118)
                    .scrollContentBackground(.hidden)
                    .padding(AppDesignSystem.Spacing.sm)
                    .background(AppDesignSystem.Surfaces.panel, in: RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                            .stroke(.quaternary, lineWidth: 1)
                    }
                    .disabled(refinementStore.isRunning)

                RefinementOptionBar(
                    model: $model,
                    resolution: $resolution,
                    aspectRatio: $aspectRatio,
                    resolutions: resolutions,
                    aspectRatios: aspectRatios
                )
                .disabled(refinementStore.isRunning)

                if model != .codexFallback && settings.snapshot.googleAPIKey.isEmpty && settings.snapshot.openRouterAPIKey.isEmpty {
                    Label("Save a Google or OpenRouter key in Settings before using Nano Banana models.", systemImage: "key")
                        .font(AppDesignSystem.Typography.caption)
                        .foregroundStyle(AppDesignSystem.SemanticColors.statusStarting)
                }
            }

            progressPanel
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var progressPanel: some View {
        WorkbenchSection("Progress", systemImage: "waveform.path.ecg.rectangle") {
            HStack {
                Spacer()
                Text("\(refinementStore.progress)%")
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(refinementStore.progress), total: 100)
                .progressViewStyle(.linear)
            Text(refinementStore.statusMessage)
                .font(AppDesignSystem.Typography.caption)
                .foregroundStyle(refinementStore.isStalled ? AppDesignSystem.SemanticColors.statusStarting : .secondary)
                .textSelection(.enabled)

            activeRunPanel

            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                ForEach(refinementStore.milestones) { milestone in
                    HStack(spacing: AppDesignSystem.Spacing.sm) {
                        Image(systemName: milestoneSymbol(milestone.state))
                            .foregroundStyle(milestoneColor(milestone.state))
                            .frame(width: 16)
                        Text(milestone.title)
                            .foregroundStyle(milestone.state == .pending ? .secondary : .primary)
                        Spacer()
                    }
                }
            }
        }
    }

    private var activeRunPanel: some View {
        Grid(alignment: .leading, horizontalSpacing: AppDesignSystem.Spacing.md, verticalSpacing: AppDesignSystem.Spacing.xs) {
            if !refinementStore.runID.isEmpty {
                GridRow {
                    Text("Run")
                        .foregroundStyle(.secondary)
                    Text(refinementStore.runID)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
            GridRow {
                Text("Elapsed")
                    .foregroundStyle(.secondary)
                Text(NativeRefinementStore.formatDuration(refinementStore.elapsedSeconds))
                    .font(.system(.caption, design: .monospaced))
            }
            GridRow {
                Text("Last event")
                    .foregroundStyle(.secondary)
                Text(NativeRefinementStore.formatDuration(refinementStore.secondsSinceLastEvent))
                    .font(.system(.caption, design: .monospaced))
            }
            if let runDirectoryURL = refinementStore.runDirectoryURL {
                GridRow {
                    Text("Folder")
                        .foregroundStyle(.secondary)
                    Text(runDirectoryURL.path)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
        }
        .font(AppDesignSystem.Typography.caption)
    }

    private var footer: some View {
        HStack {
            if let outputURL = refinementStore.outputURL {
                Text(outputURL.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            Spacer()
            if let outputURL = refinementStore.outputURL {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                } label: {
                    Label("Reveal Output", systemImage: "finder")
                }
            }
            if let runDirectoryURL = refinementStore.runDirectoryURL {
                Button {
                    NSWorkspace.shared.open(runDirectoryURL)
                } label: {
                    Label("Run Folder", systemImage: "folder")
                }
                .help("Open the dedicated folder for this refinement run")
            }
            if let logURL = refinementStore.logURL {
                Button {
                    NSWorkspace.shared.open(logURL)
                } label: {
                    Label("Log", systemImage: "doc.text")
                }
                .help("Open the JSONL event log")
            }
            if refinementStore.isRunning {
                Button(role: .destructive) {
                    refinementStore.cancel()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
            }
            Button {
                prepareRefinementPreflight()
            } label: {
                Label(refinementStore.isRunning ? "Running" : "Start Refinement", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(refinementStore.isRunning || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(AppDesignSystem.Spacing.lg)
    }

    private func prepareRefinementPreflight() {
        settings.persistNonSecretSettings()
        let request = NativeRefinementRequest(
            sourceURL: artifact.url,
            prompt: prompt,
            model: model,
            resolution: resolution,
            aspectRatio: aspectRatio,
            settings: settings.snapshot
        )
        let plan = NativeRunPreflightPlan.refinement(request: request)
        pendingRefinementRequest = request
        pendingPreflightPlan = plan
    }

    private func confirmPendingRefinement() {
        guard let request = pendingRefinementRequest,
              let plan = pendingPreflightPlan else {
            clearPendingPreflight()
            return
        }
        clearPendingPreflight()
        let finished = onFinished
        refinementStore.start(request: request.withPreflightRunID(plan.runID), onCompletion: { outputURL in
            Task { @MainActor in
                finished(outputURL)
            }
        })
    }

    private func clearPendingPreflight() {
        pendingRefinementRequest = nil
        pendingPreflightPlan = nil
    }

    private func milestoneSymbol(_ state: NativeRefinementMilestoneState) -> String {
        switch state {
        case .pending: "circle"
        case .active: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle.fill"
        case .recovered: "shippingbox.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .cancelled: "stop.circle.fill"
        case .timedOut: "clock.badge.exclamationmark.fill"
        }
    }

    private func milestoneColor(_ state: NativeRefinementMilestoneState) -> Color {
        switch state {
        case .pending: .secondary
        case .active: AppDesignSystem.SemanticColors.statusStarting
        case .completed: AppDesignSystem.SemanticColors.statusReady
        case .recovered: AppDesignSystem.SemanticColors.statusRecovered
        case .failed: AppDesignSystem.SemanticColors.statusFailed
        case .cancelled: AppDesignSystem.SemanticColors.statusCancelled
        case .timedOut: AppDesignSystem.SemanticColors.statusTimedOut
        }
    }
}
