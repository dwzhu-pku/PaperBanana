import AppKit
import SwiftUI

struct ProviderRunLedgerView: View {
    @ObservedObject var settings: AppSettingsStore
    @StateObject private var store = ProviderRunLedgerStore()
    @State private var filter: ProviderRunLedgerFilter = .all
    @State private var searchText = ""
    @State private var recoveryNotice = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var filteredCalls: [ProviderRunLedgerCall] {
        store.calls.filter { call in
            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .attention:
                matchesFilter = call.needsAttention
            case .failed:
                matchesFilter = call.status == .failed
            case .missingArtifacts:
                matchesFilter = call.status == .missingArtifact
            case .rawRecovered:
                matchesFilter = call.status == .rawRecovered
            case .lastHour:
                let referenceDate = call.updatedAt ?? call.startedAt ?? .distantPast
                matchesFilter = referenceDate >= Date().addingTimeInterval(-3600)
            }

            guard matchesFilter else { return false }
            let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedSearch.isEmpty else { return true }
            return call.callID.localizedCaseInsensitiveContains(trimmedSearch)
                || call.runID.localizedCaseInsensitiveContains(trimmedSearch)
                || call.provider.localizedCaseInsensitiveContains(trimmedSearch)
                || call.model.localizedCaseInsensitiveContains(trimmedSearch)
                || call.context.localizedCaseInsensitiveContains(trimmedSearch)
                || call.usageSummary.localizedCaseInsensitiveContains(trimmedSearch)
                || call.searchablePathText.localizedCaseInsensitiveContains(trimmedSearch)
                || call.searchableReferenceText.localizedCaseInsensitiveContains(trimmedSearch)
                || call.message.localizedCaseInsensitiveContains(trimmedSearch)
                || call.error.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                callList
                    .frame(minWidth: 620)
                ProviderRunInspectorView(
                    call: store.selectedCall,
                    onOpen: store.open,
                    onReveal: store.reveal,
                    onCopyPath: store.copyPath,
                    onSurface: surfaceRecoveryArtifact
                )
                .frame(minWidth: 380, idealWidth: 460, maxWidth: 560)
            }
        }
        .background(AppDesignSystem.Surfaces.content)
        .onAppear {
            refresh()
        }
        .onChange(of: settings.repoPath) { _ in
            refresh()
        }
        .onChange(of: filter) { _ in
            reconcileSelection()
        }
        .onChange(of: searchText) { _ in
            reconcileSelection()
        }
        .animation(AppDesignSystem.Motion.standard(reduceMotion), value: filteredCalls)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: AppDesignSystem.Spacing.md) {
                    titleBlock
                    Spacer(minLength: AppDesignSystem.Spacing.lg)
                    headerActions
                }
                VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
                    titleBlock
                    headerActions
                }
            }

            PaperBananaReadinessPanel(snapshot: settings.readinessSnapshot())

            WorkspaceScopeStrip(
                selection: $filter,
                searchText: $searchText,
                searchPrompt: "Search calls",
                accessibilityLabel: "Run ledger scope",
                visibleCount: filteredCalls.count,
                totalCount: store.calls.count,
                prefersStackedLayout: true,
                scopeIdealWidth: 720,
                scopeMaxWidth: .infinity
            )

            if !recoveryNotice.isEmpty {
                Label(recoveryNotice, systemImage: "shippingbox")
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
        .padding(AppDesignSystem.Spacing.lg)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
            Text("Run Ledger")
                .font(AppDesignSystem.Typography.title)
            Text(summaryText)
                .font(AppDesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }

    private var headerActions: some View {
        HStack(spacing: AppDesignSystem.Spacing.sm) {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([providerAuditDirectoryURL])
            } label: {
                Label("Reveal Audit Folder", systemImage: "finder")
            }
            .help("Reveal the provider audit folder")

            Button {
                refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .labelStyle(.iconOnly)
            .help("Refresh the run ledger")
        }
        .controlSize(.small)
    }

    private var summaryText: String {
        let attention = store.calls.filter(\.needsAttention).count
        return "\(store.calls.count) provider calls, \(attention) need attention, scanned from \(providerAuditDirectoryURL.path)"
    }

    private var providerAuditDirectoryURL: URL {
        URL(fileURLWithPath: settings.repoPath, isDirectory: true)
            .appendingPathComponent("results/provider_audit", isDirectory: true)
    }

    private var callList: some View {
        Group {
            if filteredCalls.isEmpty {
                ArtifactEmptyStateView(
                    title: "No Runs Found",
                    systemImage: "list.bullet.rectangle",
                    description: "Provider calls appear here after PaperBanana starts a Gemini, OpenAI, OpenRouter, or Codex image operation."
                )
                .padding(AppDesignSystem.Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ledgerTable
            }
        }
        .onChange(of: filteredCalls) { _ in
            reconcileSelection()
        }
    }

    private var ledgerTable: some View {
        VStack(spacing: 0) {
            Table(filteredCalls, selection: $store.selectedCallID) {
                TableColumn("Status") { call in
                    ProviderRunStatusLabel(status: call.status)
                }
                .width(min: 130, ideal: 150)

                TableColumn("Time") { call in
                    Text(call.displayDate)
                        .lineLimit(1)
                }
                .width(min: 130, ideal: 150)

                TableColumn("Model") { call in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(call.shortModel)
                            .lineLimit(1)
                        Text(call.provider.isEmpty ? "Unknown provider" : call.provider)
                            .font(AppDesignSystem.Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .width(min: 170, ideal: 220)

                TableColumn("Run") { call in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(call.runID.isEmpty ? "No run ID" : call.runID)
                            .lineLimit(1)
                        Text(call.callID)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .width(min: 190, ideal: 260)

                TableColumn("Artifacts") { call in
                    Text("\(call.artifactURLs.count) saved, \(call.nativeArtifactURLs.count) native, \(call.rawArtifactURLs.count) raw")
                        .lineLimit(1)
                }
                .width(min: 160, ideal: 190)

                TableColumn("Usage") { call in
                    Text(call.usageSummary)
                        .lineLimit(1)
                }
                .width(min: 150, ideal: 220)
            }
            .accessibilityLabel("Provider call ledger")
            .accessibilityValue("\(filteredCalls.count) provider calls shown")
            .accessibilityHint("Use the arrow keys to select a provider call and review its details.")
            .accessibilityIdentifier("provider-run-ledger-table")
            .accessibilityChildren {
                ForEach(filteredCalls) { call in
                    Text(accessibilityLabel(for: call))
                        .accessibilityLabel(accessibilityLabel(for: call))
                        .accessibilityValue(accessibilityValue(for: call))
                        .accessibilityAddTraits(call.id == store.selectedCallID ? [.isSelected] : [])
                }
            }

            Divider()

            NativeTableSelectionSummary(
                title: "Selected provider call",
                value: selectedCallSummary,
                systemImage: "arrow.up.and.down.and.arrow.left.and.right",
                identifier: "provider-run-ledger-table-selection-summary"
            )
        }
    }

    private var selectedLedgerCall: ProviderRunLedgerCall? {
        guard let selectedCallID = store.selectedCallID else { return nil }
        return filteredCalls.first { $0.id == selectedCallID }
    }

    private var selectedCallSummary: String {
        guard let selectedLedgerCall else {
            return filteredCalls.isEmpty ? "No provider calls available." : "No provider call selected."
        }
        return accessibilityValue(for: selectedLedgerCall)
    }

    private func accessibilityLabel(for call: ProviderRunLedgerCall) -> String {
        "\(call.shortModel), \(call.status.label)"
    }

    private func accessibilityValue(for call: ProviderRunLedgerCall) -> String {
        [
            "Provider \(call.provider.isEmpty ? "Unknown" : call.provider)",
            "Run \(call.runID.isEmpty ? "None" : call.runID)",
            "Call \(call.callID)",
            "Status \(call.status.label)",
            "Updated \(call.displayDate)",
            "\(call.artifactURLs.count) saved artifacts",
            "\(call.nativeArtifactURLs.count) native artifacts",
            "\(call.rawArtifactURLs.count) raw artifacts",
            "Usage \(call.usageSummary)",
            call.needsAttention ? "Needs attention" : nil
        ]
        .compactMap { $0 }
        .joined(separator: ". ")
    }

    private func refresh() {
        store.refresh(repoPath: settings.repoPath)
        reconcileSelection()
    }

    private func reconcileSelection() {
        if let selected = store.selectedCallID, filteredCalls.contains(where: { $0.id == selected }) {
            return
        }
        store.selectedCallID = filteredCalls.first?.id
    }

    private func surfaceRecoveryArtifact(_ call: ProviderRunLedgerCall) {
        do {
            let result = try store.surfaceRecoveryArtifact(for: call, repoPath: settings.repoPath)
            recoveryNotice = "Recovered \(result.artifactURL.lastPathComponent) into results/recovered."
        } catch {
            recoveryNotice = "Could not surface recovery artifact: \(error.localizedDescription)"
        }
    }
}

private struct ProviderRunStatusLabel: View {
    let status: ProviderRunStatus

    var body: some View {
        Label(status.label, systemImage: status.systemImage)
            .foregroundStyle(statusColor)
            .lineLimit(1)
            .accessibilityLabel(status.label)
    }

    private var statusColor: Color {
        switch status {
        case .running:
            return AppDesignSystem.SemanticColors.statusStarting
        case .succeeded:
            return AppDesignSystem.SemanticColors.statusReady
        case .failed, .cancelled, .timedOut, .missingArtifact, .rawRecovered:
            return AppDesignSystem.SemanticColors.statusFailed
        }
    }
}

private struct ProviderRunInspectorView: View {
    let call: ProviderRunLedgerCall?
    let onOpen: (URL) -> Void
    let onReveal: (URL) -> Void
    let onCopyPath: (URL) -> Void
    let onSurface: (ProviderRunLedgerCall) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let call {
                ScrollView {
                    inspectorContent(for: call)
                        .padding(AppDesignSystem.Spacing.lg)
                }
            } else {
                ArtifactEmptyStateView(
                    title: "No Run Selected",
                    systemImage: "list.bullet.rectangle",
                    description: "Select a provider call to inspect its status, artifacts, raw recovery files, and audit log."
                )
                .padding(AppDesignSystem.Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppDesignSystem.Surfaces.panel)
    }

    private func inspectorContent(for call: ProviderRunLedgerCall) -> some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
            HStack {
                ProviderRunStatusLabel(status: call.status)
                    .font(AppDesignSystem.Typography.headline)
                Spacer()
                if let auditLogURL = call.auditLogURL {
                    Button {
                        onReveal(auditLogURL)
                    } label: {
                        Label("Log", systemImage: "doc.text.magnifyingglass")
                    }
                    .help("Reveal the JSONL audit log")
                }
                if call.recoveryCandidateURLs.isEmpty == false {
                    Button {
                        onSurface(call)
                    } label: {
                        Label("Surface", systemImage: "shippingbox")
                    }
                    .help("Copy the first recoverable provider artifact into results/recovered")
                }
            }

            Text(call.shortModel)
                .font(AppDesignSystem.Typography.title)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                LabeledContent("Provider", value: call.provider.isEmpty ? "Unknown" : call.provider)
                LabeledContent("Run ID", value: call.runID.isEmpty ? "None" : call.runID)
                LabeledContent("Call ID", value: call.callID)
                LabeledContent("Modality", value: call.modality.isEmpty ? "Unknown" : call.modality)
                LabeledContent("Context", value: call.context.isEmpty ? "None" : call.context)
                LabeledContent("Responses", value: "\(call.responseCount)")
                LabeledContent("Usage", value: call.usageSummary)
                LabeledContent("Recovery candidates", value: "\(call.recoveryCandidateURLs.count)")
                if let attempt = call.attempt {
                    LabeledContent("Attempt", value: call.maxAttempts.map { "\(attempt) / \($0)" } ?? "\(attempt)")
                }
                LabeledContent("Updated", value: call.displayDate)
            }
            .font(AppDesignSystem.Typography.body)

            ReferenceExampleProvenanceSection(provenance: call.referenceProvenance)

            if !call.message.isEmpty {
                LedgerMessagePanel(title: "Message", text: call.message, systemImage: "text.bubble")
            }

            if !call.error.isEmpty {
                LedgerMessagePanel(title: "Error", text: call.error, systemImage: "exclamationmark.triangle")
            }

            PaperBananaAssistantPanel(
                title: "Provider Assistant",
                tasks: [.summarizeRun, .explainRecovery, .generateMetadata],
                input: assistantInput(for: call),
                context: assistantContext(for: call)
            )

            LedgerNativeRunSection(
                call: call,
                onOpen: onOpen,
                onReveal: onReveal,
                onCopyPath: onCopyPath
            )

            LedgerArtifactsSection(
                title: "Saved Artifacts",
                urls: call.artifactURLs,
                emptyText: "No saved image artifacts are recorded for this call.",
                onOpen: onOpen,
                onReveal: onReveal,
                onCopyPath: onCopyPath
            )

            LedgerArtifactsSection(
                title: "Raw Recovery Payloads",
                urls: call.rawArtifactURLs,
                emptyText: "No raw recovery payloads were recorded.",
                onOpen: onOpen,
                onReveal: onReveal,
                onCopyPath: onCopyPath
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func assistantInput(for call: ProviderRunLedgerCall) -> String {
        [
            "Provider call: \(call.callID)",
            "Run ID: \(call.runID.isEmpty ? "None" : call.runID)",
            "Provider: \(call.provider.isEmpty ? "Unknown" : call.provider)",
            "Model: \(call.shortModel)",
            "Raw model: \(call.model)",
            "Status: \(call.status.label)",
            "Modality: \(call.modality.isEmpty ? "Unknown" : call.modality)",
            "Context: \(call.context.isEmpty ? "None" : call.context)",
            "Responses: \(call.responseCount)",
            "Usage: \(call.usageSummary)",
            "Attempt: \(call.attempt.map { "\($0)" } ?? "Unknown")",
            "Recovery candidates: \(call.recoveryCandidateURLs.count)",
            "Reference examples: \(call.referenceProvenance.summaryText.isEmpty ? "None" : call.referenceProvenance.summaryText)",
            "Message: \(nonBlank(call.message) ?? "None")",
            "Error: \(nonBlank(call.error) ?? "None")"
        ].joined(separator: "\n")
    }

    private func assistantContext(for call: ProviderRunLedgerCall) -> String {
        var lines = [
            "Started: \(call.startedAt?.formatted(date: .abbreviated, time: .standard) ?? "Unknown")",
            "Updated: \(call.updatedAt?.formatted(date: .abbreviated, time: .standard) ?? "Unknown")",
            "Run folder: \(call.runDirectoryURL?.path ?? "None")",
            "Native prompt path: \(call.nativePromptURL?.path ?? "None")",
            "Native request path: \(call.nativeRequestURL?.path ?? "None")",
            "Native provider request path: \(call.nativeProviderRequestURL?.path ?? "None")",
            "Native event log path: \(call.nativeEventLogURL?.path ?? "None")",
            "Audit log path: \(call.auditLogURL?.path ?? "None")",
            "Usage metadata: \(call.usageSummary)"
        ]
        if call.referenceProvenance.isManual {
            lines.append("Reference provenance: \(call.referenceProvenance.searchableText)")
        }
        lines.append(contentsOf: call.artifactURLs.map { "Saved artifact path: \($0.path)" })
        lines.append(contentsOf: call.nativeArtifactURLs.map { "Native artifact path: \($0.path)" })
        lines.append(contentsOf: call.rawArtifactURLs.map { "Raw artifact path: \($0.path)" })
        return lines.joined(separator: "\n")
    }

    private func nonBlank(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct LedgerNativeRunSection: View {
    let call: ProviderRunLedgerCall
    let onOpen: (URL) -> Void
    let onReveal: (URL) -> Void
    let onCopyPath: (URL) -> Void

    private var hasNativeRun: Bool {
        call.runDirectoryURL != nil
            || call.nativePromptURL != nil
            || call.nativeRequestURL != nil
            || call.nativeProviderRequestURL != nil
            || call.nativeEventLogURL != nil
            || call.nativeArtifactURLs.isEmpty == false
    }

    var body: some View {
        WorkbenchSection("Native Run Folder", systemImage: "folder.badge.gearshape", subtitle: "Swift-created run files associated with this provider call.") {
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                if hasNativeRun {
                    if let runDirectoryURL = call.runDirectoryURL {
                        LedgerURLRow(
                            title: "Folder",
                            url: runDirectoryURL,
                            onOpen: onOpen,
                            onReveal: onReveal,
                            onCopyPath: onCopyPath
                        )
                    }
                    if let promptURL = call.nativePromptURL {
                        LedgerURLRow(
                            title: "Prompt",
                            url: promptURL,
                            onOpen: onOpen,
                            onReveal: onReveal,
                            onCopyPath: onCopyPath
                        )
                    }
                    if let requestURL = call.nativeRequestURL {
                        LedgerURLRow(
                            title: "Request",
                            url: requestURL,
                            onOpen: onOpen,
                            onReveal: onReveal,
                            onCopyPath: onCopyPath
                        )
                    }
                    if let providerRequestURL = call.nativeProviderRequestURL {
                        LedgerURLRow(
                            title: "Provider Request",
                            url: providerRequestURL,
                            onOpen: onOpen,
                            onReveal: onReveal,
                            onCopyPath: onCopyPath
                        )
                    }
                    if let eventLogURL = call.nativeEventLogURL {
                        LedgerURLRow(
                            title: "Events",
                            url: eventLogURL,
                            onOpen: onOpen,
                            onReveal: onReveal,
                            onCopyPath: onCopyPath
                        )
                    }

                    if call.nativeArtifactURLs.isEmpty == false {
                        Divider()
                        ForEach(call.nativeArtifactURLs, id: \.standardizedFileURL) { url in
                            LedgerURLRow(
                                title: "Output",
                                url: url,
                                onOpen: onOpen,
                                onReveal: onReveal,
                                onCopyPath: onCopyPath
                            )
                        }
                    }
                } else {
                    Text("No native run folder was linked for this provider call.")
                        .font(AppDesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct LedgerMessagePanel: View {
    let title: String
    let text: String
    let systemImage: String

    var body: some View {
        WorkbenchSection(title, systemImage: systemImage) {
            Text(text)
                .font(AppDesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}

private struct LedgerURLRow: View {
    let title: String
    let url: URL
    let onOpen: (URL) -> Void
    let onReveal: (URL) -> Void
    let onCopyPath: (URL) -> Void

    var body: some View {
        HStack(spacing: AppDesignSystem.Spacing.sm) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
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
}

private struct LedgerArtifactsSection: View {
    let title: String
    let urls: [URL]
    let emptyText: String
    let onOpen: (URL) -> Void
    let onReveal: (URL) -> Void
    let onCopyPath: (URL) -> Void

    var body: some View {
        WorkbenchSection(title, systemImage: "shippingbox") {
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                if urls.isEmpty {
                    Text(emptyText)
                        .font(AppDesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(urls, id: \.standardizedFileURL) { url in
                        HStack(spacing: AppDesignSystem.Spacing.sm) {
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
                            Button {
                                onOpen(url)
                            } label: {
                                Label("Open", systemImage: "arrow.up.right.square")
                            }
                            .labelStyle(.iconOnly)
                            .help("Open artifact")
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
                        .padding(.vertical, AppDesignSystem.Spacing.xs)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(url.lastPathComponent)
                    }
                }
            }
        }
    }
}
