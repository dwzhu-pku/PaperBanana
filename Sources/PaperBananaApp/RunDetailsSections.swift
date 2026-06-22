import Foundation
import SwiftUI

struct RunDetailsFilesSection: View {
    let item: RunDetailsItem
    let onOpen: (URL) -> Void
    let onReveal: (URL) -> Void
    let onCopyPath: (URL) -> Void

    var body: some View {
        WorkbenchSection("Files", systemImage: "folder", subtitle: "Durable run folder, request, event log, outputs, and raw recovery payloads.") {
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                RunDetailsURLRow(title: "Folder", url: item.run.directoryURL, onOpen: onOpen, onReveal: onReveal, onCopyPath: onCopyPath)
                if let promptURL = item.promptURL {
                    RunDetailsURLRow(title: "Prompt", url: promptURL, onOpen: onOpen, onReveal: onReveal, onCopyPath: onCopyPath)
                }
                if let requestURL = item.requestURL {
                    RunDetailsURLRow(title: "Request", url: requestURL, onOpen: onOpen, onReveal: onReveal, onCopyPath: onCopyPath)
                }
                if let providerRequestURL = item.providerRequestURL {
                    RunDetailsURLRow(title: "Provider", url: providerRequestURL, onOpen: onOpen, onReveal: onReveal, onCopyPath: onCopyPath)
                }
                if let eventLogURL = item.eventLogURL {
                    RunDetailsURLRow(title: "Events", url: eventLogURL, onOpen: onOpen, onReveal: onReveal, onCopyPath: onCopyPath)
                }
                if let metadataURL = item.metadataURL {
                    RunDetailsURLRow(title: "Metadata", url: metadataURL, onOpen: onOpen, onReveal: onReveal, onCopyPath: onCopyPath)
                }

                ForEach(item.outputURLs, id: \.standardizedFileURL) { url in
                    RunDetailsURLRow(title: "Output", url: url, onOpen: onOpen, onReveal: onReveal, onCopyPath: onCopyPath)
                }
                ForEach(item.rawResponseURLs, id: \.standardizedFileURL) { url in
                    RunDetailsURLRow(title: "Raw Response", url: url, onOpen: onOpen, onReveal: onReveal, onCopyPath: onCopyPath)
                }
                ForEach(item.rawPayloadURLs, id: \.standardizedFileURL) { url in
                    RunDetailsURLRow(title: "Raw Payload", url: url, onOpen: onOpen, onReveal: onReveal, onCopyPath: onCopyPath)
                }
            }
        }
    }
}

struct RunDetailsURLRow: View {
    let title: String
    let url: URL
    let onOpen: (URL) -> Void
    let onReveal: (URL) -> Void
    let onCopyPath: (URL) -> Void

    var body: some View {
        HStack(spacing: AppDesignSystem.Spacing.sm) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .lineLimit(1)
                Text(url.deletingLastPathComponent().path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: AppDesignSystem.Spacing.md)
            if !exists {
                Text("Missing")
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(AppDesignSystem.SemanticColors.statusFailed)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppDesignSystem.SemanticColors.statusFailed.opacity(0.12), in: Capsule())
            }
            Button {
                onOpen(url)
            } label: {
                Label("Open", systemImage: "arrow.up.right.square")
            }
            .labelStyle(.iconOnly)
            .help("Open")
            Button {
                onReveal(url)
            } label: {
                Label("Reveal", systemImage: "finder")
            }
            .labelStyle(.iconOnly)
            .help("Reveal in Finder")
            Button {
                onCopyPath(url)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
            .labelStyle(.iconOnly)
            .help("Copy path")
        }
        .font(AppDesignSystem.Typography.caption)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(url.lastPathComponent)")
    }

    private var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}

struct RunDetailsTimelineSection: View {
    let events: [NativeRunTimelineEvent]

    var body: some View {
        WorkbenchSection("Timeline", systemImage: "waveform.path.ecg.rectangle", subtitle: "Native event log milestones for this run.") {
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                if events.isEmpty {
                    Text("No event log entries were found.")
                        .font(AppDesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(events) { event in
                        timelineRow(for: event)
                    }
                }
            }
        }
    }

    private func timelineRow(for event: NativeRunTimelineEvent) -> some View {
        HStack(alignment: .top, spacing: AppDesignSystem.Spacing.sm) {
            Image(systemName: event.status.systemImage)
                .foregroundStyle(color(for: event.status))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.stage.isEmpty ? "Unknown" : event.stage)
                    .font(AppDesignSystem.Typography.body)
                if !event.message.isEmpty {
                    Text(event.message)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                if !event.timestamp.isEmpty {
                    Text(event.timestamp)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if let rawResponseURL = event.rawResponseURL {
                    Text("Raw response: \(rawResponseURL.lastPathComponent)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(AppDesignSystem.SemanticColors.statusFailed)
                        .lineLimit(1)
                }
                if let rawURL = event.rawURL {
                    Text("Raw payload: \(rawURL.lastPathComponent)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(AppDesignSystem.SemanticColors.statusFailed)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let progress = event.progress {
                Text("\(progress)%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .font(AppDesignSystem.Typography.caption)
    }

    private func color(for status: ArtifactRunStatus) -> Color {
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

struct RunDetailsProviderCallsSection: View {
    let calls: [ProviderRunLedgerCall]
    let onOpen: (URL) -> Void
    let onReveal: (URL) -> Void
    let onCopyPath: (URL) -> Void
    let onSurfaceRecovery: (ProviderRunLedgerCall) -> Void

    var body: some View {
        WorkbenchSection("Provider Calls", systemImage: "bolt.horizontal", subtitle: "Paid and fallback provider requests linked to this native run.") {
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                if calls.isEmpty {
                    Text("No provider audit entries were linked to this native run.")
                        .font(AppDesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(calls) { call in
                        providerCallRow(for: call)
                    }
                }
            }
        }
    }

    private func providerCallRow(for call: ProviderRunLedgerCall) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                ProviderRunStatusText(call: call)
                Spacer()
                Text(call.responseCount == 1 ? "1 response" : "\(call.responseCount) responses")
                    .foregroundStyle(.secondary)
            }
            Text(call.shortModel)
                .lineLimit(1)
            Text(call.callID)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if call.usageMetadata.isEmpty == false {
                Text(call.usageSummary)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let providerRequestURL = call.nativeProviderRequestURL {
                RunDetailsURLRow(
                    title: "Provider Request",
                    url: providerRequestURL,
                    onOpen: onOpen,
                    onReveal: onReveal,
                    onCopyPath: onCopyPath
                )
            }
            if !call.recoveryCandidateURLs.isEmpty {
                Button {
                    onSurfaceRecovery(call)
                } label: {
                    Label("Recover Artifact", systemImage: "arrow.down.doc")
                }
                .help("Copy the first recoverable provider artifact into results/recovered")

                ForEach(call.recoveryCandidateURLs, id: \.standardizedFileURL) { url in
                    RunDetailsURLRow(
                        title: "Candidate",
                        url: url,
                        onOpen: onOpen,
                        onReveal: onReveal,
                        onCopyPath: onCopyPath
                    )
                }
            }
        }
        .font(AppDesignSystem.Typography.caption)
        .padding(.vertical, AppDesignSystem.Spacing.xs)
    }
}

struct ProviderRunStatusText: View {
    let call: ProviderRunLedgerCall

    var body: some View {
        Label(call.status.label, systemImage: call.status.systemImage)
            .foregroundStyle(color)
    }

    private var color: Color {
        switch call.status {
        case .running:
            return AppDesignSystem.SemanticColors.statusStarting
        case .succeeded:
            return AppDesignSystem.SemanticColors.statusReady
        case .failed, .cancelled, .timedOut, .missingArtifact, .rawRecovered:
            return AppDesignSystem.SemanticColors.statusFailed
        }
    }
}
