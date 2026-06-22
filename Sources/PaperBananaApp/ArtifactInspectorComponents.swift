import AppKit
import SwiftUI

struct ArtifactInspectorView: View {
    let artifact: PaperBananaArtifact?
    let isFavorite: Bool
    let onOpen: (PaperBananaArtifact) -> Void
    let onReveal: (PaperBananaArtifact) -> Void
    let onCopyPath: (PaperBananaArtifact) -> Void
    let onExportImage: (PaperBananaArtifact) -> Void
    let onExportWithMetadata: (PaperBananaArtifact) -> Void
    let onRefine: (PaperBananaArtifact) -> Void
    let onToggleFavorite: (PaperBananaArtifact) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let artifact {
                ScrollView {
                    inspectorContent(for: artifact)
                        .padding(AppDesignSystem.Spacing.lg)
                }

                Divider()

                ArtifactInspectorActionBar(
                    artifact: artifact,
                    isFavorite: isFavorite,
                    onOpen: onOpen,
                    onReveal: onReveal,
                    onCopyPath: onCopyPath,
                    onExportImage: onExportImage,
                    onExportWithMetadata: onExportWithMetadata,
                    onRefine: onRefine,
                    onToggleFavorite: onToggleFavorite
                )
                .padding(AppDesignSystem.Spacing.lg)
            } else {
                ArtifactEmptyStateView(
                    title: "No Artifact Selected",
                    systemImage: "photo.stack",
                    description: "Select a PaperBanana artifact to inspect, open, reveal, copy, or favorite it."
                )
                .padding(AppDesignSystem.Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppDesignSystem.Surfaces.panel)
    }

    private func inspectorContent(for artifact: PaperBananaArtifact) -> some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
            WorkbenchSection("Preview", systemImage: artifact.kind.systemImage) {
                ArtifactPreviewView(artifact: artifact, allowsInteraction: true)
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                            .stroke(.quaternary, lineWidth: 1)
                    }
            }

            WorkbenchSection("Artifact", systemImage: "doc.richtext") {
                VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
                    Text(artifact.title)
                        .font(AppDesignSystem.Typography.title)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)

                    VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
                        if artifact.isRecovered {
                            Label("Recovered Image", systemImage: "checkmark.seal.fill")
                                .font(AppDesignSystem.Typography.headline)
                                .foregroundStyle(Color.accentColor)
                        }

                        if let runStatus = artifact.runStatus {
                            Label(runStatus.label, systemImage: runStatus.systemImage)
                                .font(AppDesignSystem.Typography.headline)
                                .foregroundStyle(runStatusColor(runStatus))
                        }
                    }

                    VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                        LabeledContent("Type", value: artifact.kind.label)
                        LabeledContent("Workflow", value: artifact.workflow)
                        if !artifact.runID.isEmpty {
                            LabeledContent("Run ID", value: artifact.runID)
                        }
                        LabeledContent("Size", value: artifact.formattedSize)
                        LabeledContent("Modified", value: artifact.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                        if let quality = PaperBananaImageQualityInspector.inspect(artifact.url) {
                            LabeledContent("Pixels", value: quality.resolutionText)
                            LabeledContent("Megapixels", value: quality.megapixelsText)
                            LabeledContent("Metal Preview", value: quality.usesMetalDevice ? "Available" : "Unavailable")
                            if quality.warnings.isEmpty == false {
                                LabeledContent("QA", value: quality.warnings.joined(separator: " "))
                            }
                        }
                    }
                    .font(AppDesignSystem.Typography.body)

                    Text(artifact.relativePath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            WorkbenchSection("Linked Files", systemImage: "folder") {
                CompanionRow(title: "Run Folder", url: artifact.runDirectoryURL)
                CompanionRow(title: "Prompt", url: artifact.promptURL)
                CompanionRow(title: "Log", url: artifact.logURL)
                CompanionRow(title: "Metadata", url: artifact.metadataURL)
            }

            ReferenceExampleProvenanceSection(provenance: artifact.referenceProvenance)

            PaperBananaAssistantPanel(
                title: "Local Assistant",
                tasks: assistantTasks(for: artifact),
                input: assistantInput(for: artifact),
                context: assistantContext(for: artifact),
                imageURL: artifact.kind == .image ? artifact.url : nil
            )

            if let lineage = artifact.refinementLineage {
                ArtifactLineagePanel(
                    lineage: lineage,
                    onOpenSource: { NSWorkspace.shared.open(lineage.sourceURL) },
                    onRevealSource: { NSWorkspace.shared.activateFileViewerSelecting([lineage.sourceURL]) },
                    onUseAsSource: { onRefine(artifact) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func assistantTasks(for artifact: PaperBananaArtifact) -> [PaperBananaAssistantTask] {
        artifact.kind == .image
            ? [.critiqueFigure, .extractText, .nameArtifact, .generateMetadata]
            : [.nameArtifact, .generateMetadata]
    }

    private func assistantInput(for artifact: PaperBananaArtifact) -> String {
        var lines = [
            "Artifact: \(artifact.title)",
            "Type: \(artifact.kind.label)",
            "Workflow: \(artifact.workflow)",
            "Run ID: \(artifact.runID.isEmpty ? "None" : artifact.runID)",
            "Relative path: \(artifact.relativePath)",
            "Size: \(artifact.formattedSize)",
            "Modified: \(artifact.modifiedAt.formatted(date: .abbreviated, time: .shortened))"
        ]
        if let status = artifact.runStatus {
            lines.append("Run status: \(status.label)")
        }
        lines.append("Reference examples: \(artifact.referenceProvenance.summaryText.isEmpty ? "None" : artifact.referenceProvenance.summaryText)")
        if let quality = PaperBananaImageQualityInspector.inspect(artifact.url) {
            lines.append("Resolution: \(quality.resolutionText)")
            lines.append("Megapixels: \(quality.megapixelsText)")
            if quality.warnings.isEmpty == false {
                lines.append("Visual QA warnings: \(quality.warnings.joined(separator: " "))")
            }
        }
        if let promptPreview = previewText(from: artifact.promptURL, limit: 700) {
            lines.append("Prompt preview: \(promptPreview)")
        }
        return lines.joined(separator: "\n")
    }

    private func assistantContext(for artifact: PaperBananaArtifact) -> String {
        var lines = [
            "Output path: \(artifact.url.path)",
            "Run folder: \(artifact.runDirectoryURL?.path ?? "None")",
            "Prompt path: \(artifact.promptURL?.path ?? "None")",
            "Log path: \(artifact.logURL?.path ?? "None")",
            "Metadata path: \(artifact.metadataURL?.path ?? "None")",
            "Recovered: \(artifact.isRecovered ? "yes" : "no")",
            "Favorite: \(isFavorite ? "yes" : "no")"
        ]
        if artifact.referenceProvenance.isManual {
            lines.append("Reference provenance: \(artifact.referenceProvenance.searchableText)")
        }
        if let metadataPreview = previewText(from: artifact.metadataURL, limit: 700) {
            lines.append("Metadata preview: \(metadataPreview)")
        }
        return lines.joined(separator: "\n")
    }

    private func previewText(from url: URL?, limit: Int) -> String? {
        guard let url,
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        let normalized = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
        guard normalized.isEmpty == false else { return nil }
        return String(normalized.prefix(limit))
    }

    private func runStatusColor(_ status: ArtifactRunStatus) -> Color {
        switch status {
        case .completed:
            return AppDesignSystem.SemanticColors.statusReady
        case .running:
            return AppDesignSystem.SemanticColors.statusStarting
        case .timedOut, .stalled, .cancelled, .failed:
            return AppDesignSystem.SemanticColors.statusFailed
        case .unknown:
            return .secondary
        }
    }
}

private struct ArtifactInspectorActionBar: View {
    let artifact: PaperBananaArtifact
    let isFavorite: Bool
    let onOpen: (PaperBananaArtifact) -> Void
    let onReveal: (PaperBananaArtifact) -> Void
    let onCopyPath: (PaperBananaArtifact) -> Void
    let onExportImage: (PaperBananaArtifact) -> Void
    let onExportWithMetadata: (PaperBananaArtifact) -> Void
    let onRefine: (PaperBananaArtifact) -> Void
    let onToggleFavorite: (PaperBananaArtifact) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppDesignSystem.Spacing.sm) {
                    primaryActions
                    Spacer(minLength: AppDesignSystem.Spacing.md)
                    secondaryActions
                }

                VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                    primaryActions
                    secondaryActions
                }
            }
        }
    }

    private var primaryActions: some View {
        HStack(spacing: AppDesignSystem.Spacing.sm) {
            Button {
                onToggleFavorite(artifact)
            } label: {
                Label(isFavorite ? "Favorited" : "Favorite", systemImage: isFavorite ? "star.fill" : "star")
            }
            .help(isFavorite ? "Remove from favorites" : "Add to favorites")

            Button {
                onOpen(artifact)
            } label: {
                Label("Open", systemImage: "arrow.up.right.square")
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)
            .help("Open the selected artifact")

            Button {
                onReveal(artifact)
            } label: {
                Label("Reveal", systemImage: "finder")
            }
            .help("Reveal the selected artifact in Finder")
        }
    }

    private var secondaryActions: some View {
        HStack(spacing: AppDesignSystem.Spacing.sm) {
            Button {
                onExportImage(artifact)
            } label: {
                Label("Image", systemImage: "square.and.arrow.down")
            }
            .disabled(artifact.kind != .image)
            .help("Export image")

            Button {
                onExportWithMetadata(artifact)
            } label: {
                Label("Bundle", systemImage: "shippingbox")
            }
            .help("Export with metadata")

            Button {
                onCopyPath(artifact)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .help("Copy file path")

            Button {
                onRefine(artifact)
            } label: {
                Label("Refine", systemImage: "wand.and.sparkles")
            }
            .disabled(artifact.kind != .image)
            .help(artifact.wasNativeRefined ? "Refine again" : "Refine image")
        }
    }
}

private struct ArtifactLineagePanel: View {
    let lineage: ArtifactLineage
    let onOpenSource: () -> Void
    let onRevealSource: () -> Void
    let onUseAsSource: () -> Void

    var body: some View {
        WorkbenchSection("Lineage", systemImage: "point.3.connected.trianglepath.dotted") {
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                HStack {
                    Spacer()
                    Button {
                        onUseAsSource()
                    } label: {
                        Label("Use as Source", systemImage: "arrow.triangle.branch")
                    }
                    .controlSize(.small)
                }

                HStack(spacing: AppDesignSystem.Spacing.sm) {
                    Text(lineage.sourceURL.lastPathComponent)
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    Text(lineage.outputURL.lastPathComponent)
                        .lineLimit(1)
                }
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)

                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent("Model", value: lineage.modelLabel)
                    if !lineage.resolution.isEmpty {
                        LabeledContent("Resolution", value: lineage.resolution)
                    }
                    if !lineage.aspectRatio.isEmpty {
                        LabeledContent("Aspect", value: lineage.aspectRatio)
                    }
                    if !lineage.providerMessage.isEmpty {
                        LabeledContent("Provider", value: lineage.providerMessage)
                    }
                }
                .font(AppDesignSystem.Typography.caption)

                if !lineage.prompt.isEmpty {
                    Text(lineage.prompt)
                        .font(AppDesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }

                HStack {
                    Button {
                        onOpenSource()
                    } label: {
                        Label("Open Source", systemImage: "photo")
                    }
                    Button {
                        onRevealSource()
                    } label: {
                        Label("Reveal Source", systemImage: "finder")
                    }
                }
                .controlSize(.small)
            }
        }
    }
}

private struct CompanionRow: View {
    let title: String
    let url: URL?

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            if let url {
                Button(url.lastPathComponent) {
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.link)
                .lineLimit(1)
            } else {
                Text("None")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(AppDesignSystem.Typography.caption)
    }
}
