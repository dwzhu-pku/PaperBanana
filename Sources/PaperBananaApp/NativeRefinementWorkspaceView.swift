import AppKit
import SwiftUI

struct NativeRefinementWorkspaceView: View {
    let artifact: PaperBananaArtifact?
    @ObservedObject var settings: AppSettingsStore
    @ObservedObject var refinementStore: NativeRefinementStore
    let onOpen: (PaperBananaArtifact) -> Void
    let onReveal: (PaperBananaArtifact) -> Void
    let onFinished: @MainActor @Sendable (URL) -> Void

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
            if let artifact {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.lg) {
                        workspaceHeader(for: artifact)
                        PaperBananaReadinessPanel(
                            snapshot: settings.readinessSnapshot(requestedModel: model)
                        )
                        sourcePanel(for: artifact)
                        instructionPanel(for: artifact)
                        progressPanel
                        outputPanel
                    }
                    .padding(AppDesignSystem.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                Divider()
                footer(for: artifact)
            } else {
                ArtifactEmptyStateView(
                    title: "Select an Image",
                    systemImage: "wand.and.sparkles",
                    description: "Choose an image from the list to run a native PaperBanana refinement with durable run logging."
                )
                .padding(AppDesignSystem.Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppDesignSystem.Surfaces.content)
        .sheet(item: $pendingPreflightPlan) { plan in
            NativeRunPreflightSheet(
                plan: plan,
                onCancel: clearPendingPreflight,
                onConfirm: confirmPendingRefinement
            )
        }
    }

    private func workspaceHeader(for artifact: PaperBananaArtifact) -> some View {
        HStack(alignment: .top, spacing: AppDesignSystem.Spacing.md) {
            Image(systemName: "wand.and.sparkles")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
                Text(artifact.wasNativeRefined ? "Refine Again" : "Refine High Resolution")
                    .font(AppDesignSystem.Typography.title)
                Text(artifact.title)
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            Spacer()
            HStack(spacing: AppDesignSystem.Spacing.sm) {
                Button {
                    onOpen(artifact)
                } label: {
                    Label("Open", systemImage: "arrow.up.right.square")
                }
                .help("Open the source image")

                Button {
                    onReveal(artifact)
                } label: {
                    Label("Reveal", systemImage: "finder")
                }
                .help("Reveal the source image in Finder")
            }
            .controlSize(.small)
        }
        .accessibilityElement(children: .combine)
    }

    private func sourcePanel(for artifact: PaperBananaArtifact) -> some View {
        WorkbenchSection(
            "Source Image",
            systemImage: "photo",
            subtitle: "Inspect the selected artifact before spending provider credits."
        ) {
            ArtifactPreviewView(artifact: artifact)
                .frame(minHeight: 220, idealHeight: 300, maxHeight: 360)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                }

            Text(artifact.relativePath)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }

    private func instructionPanel(for artifact: PaperBananaArtifact) -> some View {
        WorkbenchSection(
            "Refinement Request",
            systemImage: "text.bubble",
            subtitle: "Describe the high-resolution rebuild and preserve constraints."
        ) {
            TextEditor(text: $prompt)
                .font(AppDesignSystem.Typography.body)
                .frame(minHeight: 130)
                .scrollContentBackground(.hidden)
                .padding(AppDesignSystem.Spacing.sm)
                .background(
                    AppDesignSystem.Surfaces.content,
                    in: RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                }
                .disabled(refinementStore.isRunning)
                .accessibilityLabel("Refinement instructions")

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
    }

    private var progressPanel: some View {
        WorkbenchSection(
            "Run Timeline",
            systemImage: "waveform.path.ecg.rectangle",
            subtitle: "Track preflight, provider execution, output persistence, and recovery artifacts."
        ) {
            HStack {
                Text(refinementStore.statusMessage)
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(refinementStore.isStalled ? AppDesignSystem.SemanticColors.statusStarting : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Spacer()
                Text("\(refinementStore.progress)%")
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(refinementStore.progress), total: 100)
                .progressViewStyle(.linear)

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
                    .accessibilityLabel("\(milestone.title): \(milestoneAccessibilityState(milestone.state))")
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
            if let requestURL = refinementStore.requestURL {
                GridRow {
                    Text("Request")
                        .foregroundStyle(.secondary)
                    Text(requestURL.lastPathComponent)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
            if let providerRequestURL = refinementStore.providerRequestURL {
                GridRow {
                    Text("Provider request")
                        .foregroundStyle(.secondary)
                    Text(providerRequestURL.lastPathComponent)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
            if let sourceCopyURL = refinementStore.sourceCopyURL {
                GridRow {
                    Text("Source copy")
                        .foregroundStyle(.secondary)
                    Text(sourceCopyURL.lastPathComponent)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
            if !refinementStore.providerCallID.isEmpty {
                GridRow {
                    Text("Provider call")
                        .foregroundStyle(.secondary)
                    Text(refinementStore.providerCallID)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
            if let rawResponseURL = refinementStore.rawResponseURL {
                GridRow {
                    Text("Raw response")
                        .foregroundStyle(.secondary)
                    Text(rawResponseURL.lastPathComponent)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
            if let rawPayloadURL = refinementStore.rawPayloadURL {
                GridRow {
                    Text("Raw payload")
                        .foregroundStyle(.secondary)
                    Text(rawPayloadURL.lastPathComponent)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
        }
        .font(AppDesignSystem.Typography.caption)
    }

    @ViewBuilder
    private var outputPanel: some View {
        if let outputURL = refinementStore.outputURL {
            WorkbenchSection(
                "Refined Output",
                systemImage: "checkmark.seal",
                subtitle: "Saved output from the completed provider run."
            ) {
                if let image = NSImage(contentsOf: outputURL) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(minHeight: 180, idealHeight: 260, maxHeight: 340)
                        .frame(maxWidth: .infinity)
                        .background(
                            AppDesignSystem.Surfaces.content,
                            in: RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                                .stroke(.quaternary, lineWidth: 1)
                        }
                }

                Text(outputURL.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
    }

    private func footer(for artifact: PaperBananaArtifact) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppDesignSystem.Spacing.sm) {
                runLinkButtons
                Spacer(minLength: AppDesignSystem.Spacing.md)
                runButtons(for: artifact)
            }

            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                runLinkButtons
                runButtons(for: artifact)
            }
        }
        .padding(AppDesignSystem.Spacing.lg)
        .controlSize(.small)
    }

    private var runLinkButtons: some View {
        HStack(spacing: AppDesignSystem.Spacing.sm) {
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
            }
            if let requestURL = refinementStore.requestURL {
                Button {
                    NSWorkspace.shared.open(requestURL)
                } label: {
                    Label("Request", systemImage: "doc.badge.gearshape")
                }
            }
            if let providerRequestURL = refinementStore.providerRequestURL {
                Button {
                    NSWorkspace.shared.open(providerRequestURL)
                } label: {
                    Label("Provider Request", systemImage: "doc.plaintext")
                }
            }
            if let rawResponseURL = refinementStore.rawResponseURL {
                Button {
                    NSWorkspace.shared.open(rawResponseURL)
                } label: {
                    Label("Raw Response", systemImage: "doc.zipper")
                }
            }
            if let rawPayloadURL = refinementStore.rawPayloadURL {
                Button {
                    NSWorkspace.shared.open(rawPayloadURL)
                } label: {
                    Label("Raw Payload", systemImage: "shippingbox")
                }
            }
            if let logURL = refinementStore.logURL {
                Button {
                    NSWorkspace.shared.open(logURL)
                } label: {
                    Label("Log", systemImage: "doc.text")
                }
            }
        }
    }

    private func runButtons(for artifact: PaperBananaArtifact) -> some View {
        HStack(spacing: AppDesignSystem.Spacing.sm) {
            if refinementStore.isRunning {
                Button(role: .destructive) {
                    refinementStore.cancel()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
            }

            Button {
                prepareRefinementPreflight(for: artifact)
            } label: {
                Label(refinementStore.isRunning ? "Running" : "Start Refinement", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(refinementStore.isRunning || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }

    private func prepareRefinementPreflight(for artifact: PaperBananaArtifact) {
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

    private func milestoneAccessibilityState(_ state: NativeRefinementMilestoneState) -> String {
        switch state {
        case .pending: "pending"
        case .active: "active"
        case .completed: "completed"
        case .recovered: "recovered"
        case .failed: "failed"
        case .cancelled: "cancelled"
        case .timedOut: "timed out"
        }
    }
}
