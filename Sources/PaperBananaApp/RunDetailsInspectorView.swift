import Foundation
import SwiftUI

struct RunDetailsInspectorView: View {
    let item: RunDetailsItem?
    let recoveryNotice: String?
    let onOpen: (URL) -> Void
    let onReveal: (URL) -> Void
    let onCopyPath: (URL) -> Void
    let onSurfaceRecovery: (ProviderRunLedgerCall) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let item {
                ScrollView {
                    inspectorContent(for: item)
                        .padding(AppDesignSystem.Spacing.lg)
                }
            } else {
                ArtifactEmptyStateView(
                    title: "No Run Selected",
                    systemImage: "waveform.path.ecg.rectangle",
                    description: "Select a native run to inspect its files, timeline, and linked provider calls."
                )
                .padding(AppDesignSystem.Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppDesignSystem.Surfaces.panel)
    }

    private func inspectorContent(for item: RunDetailsItem) -> some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
            HStack {
                RunDetailsStatusLabel(status: item.run.status, needsAttention: item.needsAttention)
                    .font(AppDesignSystem.Typography.headline)
                Spacer()
                Button {
                    onReveal(item.run.directoryURL)
                } label: {
                    Label("Folder", systemImage: "finder")
                }
                .help("Reveal native run folder")
            }

            Text(item.title)
                .font(AppDesignSystem.Typography.title)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if let recoveryNotice {
                Label(recoveryNotice, systemImage: "arrow.down.doc")
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(AppDesignSystem.SemanticColors.statusReady)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(AppDesignSystem.Spacing.sm)
                    .background(AppDesignSystem.SemanticColors.statusReady.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(recoveryNotice)
            }

            metadataGrid(for: item)

            ReferenceExampleProvenanceSection(provenance: item.referenceProvenance)

            PaperBananaAssistantPanel(
                title: "Run Assistant",
                tasks: [.summarizeRun, .explainRecovery, .generateMetadata],
                input: assistantInput(for: item),
                context: assistantContext(for: item)
            )

            RunDetailsFilesSection(
                item: item,
                onOpen: onOpen,
                onReveal: onReveal,
                onCopyPath: onCopyPath
            )

            RunDetailsTimelineSection(events: item.run.events)

            RunDetailsProviderCallsSection(
                calls: item.providerCalls,
                onOpen: onOpen,
                onReveal: onReveal,
                onCopyPath: onCopyPath,
                onSurfaceRecovery: onSurfaceRecovery
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func metadataGrid(for item: RunDetailsItem) -> some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
            LabeledContent("Status", value: item.run.status.label)
            LabeledContent("Workflow", value: item.workflow)
            LabeledContent("Stage", value: item.currentStage)
            LabeledContent("Elapsed", value: item.elapsedTimeText)
            LabeledContent("Model", value: item.modelLabel)
            LabeledContent("Resolution", value: item.resolution)
            LabeledContent("Aspect ratio", value: item.aspectRatio)
            LabeledContent("Outputs", value: "\(item.outputURLs.count)")
            LabeledContent("Raw responses", value: "\(item.rawResponseURLs.count)")
            LabeledContent("Raw payloads", value: "\(item.rawPayloadURLs.count)")
            LabeledContent("Recoverable", value: "\(item.recoverableURLs.count)")
            LabeledContent("Provider calls", value: "\(item.providerCalls.count)")
            LabeledContent("Provider request", value: item.providerRequestURL == nil ? "Missing" : "Present")
            LabeledContent("Provider call IDs", value: item.providerCallSummary)
            LabeledContent("Durable spend trace", value: item.hasDurableSpendTrace ? "Present" : "Missing")
            LabeledContent("Modified", value: item.run.modifiedAt.formatted(date: .abbreviated, time: .shortened))
        }
        .font(AppDesignSystem.Typography.body)
    }

    private func assistantInput(for item: RunDetailsItem) -> String {
        var lines = [
            "Run: \(item.title)",
            "Workflow: \(item.workflow)",
            "Status: \(item.run.status.label)",
            "Stage: \(item.currentStage)",
            "Elapsed: \(item.elapsedTimeText)",
            "Model: \(item.modelLabel)",
            "Resolution: \(item.resolution)",
            "Aspect ratio: \(item.aspectRatio)",
            "Outputs: \(item.outputURLs.count)",
            "Raw responses: \(item.rawResponseURLs.count)",
            "Raw payloads: \(item.rawPayloadURLs.count)",
            "Recoverable artifacts: \(item.recoverableURLs.count)",
            "Provider calls: \(item.providerCallSummary)",
            "Durable spend trace: \(item.hasDurableSpendTrace ? "present" : "missing")",
            "Reference examples: \(item.referenceProvenance.summaryText.isEmpty ? "None" : item.referenceProvenance.summaryText)"
        ]
        if let promptPreview = previewText(from: item.promptURL, limit: 700) {
            lines.append("Prompt preview: \(promptPreview)")
        }
        return lines.joined(separator: "\n")
    }

    private func assistantContext(for item: RunDetailsItem) -> String {
        var lines = [
            "Run folder: \(item.run.directoryURL.path)",
            "Prompt path: \(item.promptURL?.path ?? "None")",
            "Request path: \(item.requestURL?.path ?? "None")",
            "Provider request path: \(item.providerRequestURL?.path ?? "None")",
            "Event log path: \(item.eventLogURL?.path ?? "None")",
            "Metadata path: \(item.metadataURL?.path ?? "None")"
        ]
        if item.referenceProvenance.isManual {
            lines.append("Reference provenance: \(item.referenceProvenance.searchableText)")
        }
        lines.append(contentsOf: item.outputURLs.map { "Output path: \($0.path)" })
        lines.append(contentsOf: item.rawResponseURLs.map { "Raw response path: \($0.path)" })
        lines.append(contentsOf: item.rawPayloadURLs.map { "Raw payload path: \($0.path)" })
        lines.append(contentsOf: item.providerCalls.map { call in
            "Provider call \(call.callID): \(call.status.label), \(call.provider), \(call.shortModel), responses \(call.responseCount), usage \(call.usageSummary), provider request \(call.nativeProviderRequestURL?.path ?? "None"), message \(nonBlank(call.message) ?? nonBlank(call.error) ?? "None")"
        })
        let events = item.run.events.suffix(8).map { event in
            "Timeline \(event.stage): \(nonBlank(event.message) ?? "No message")"
        }
        lines.append(contentsOf: events)
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

    private func nonBlank(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
