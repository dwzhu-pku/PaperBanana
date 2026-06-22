import AppKit
import SwiftUI

struct RunDetailsView: View {
    @ObservedObject var settings: AppSettingsStore
    @StateObject private var store = RunDetailsStore()
    @State private var filter: RunDetailsFilter = .attention
    @State private var searchText = ""
    @State private var recoveryNotice: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var filteredRuns: [RunDetailsItem] {
        store.runs.filter { item in
            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .attention:
                matchesFilter = item.needsAttention
            case .running:
                matchesFilter = item.run.status == .running
            case .failed:
                matchesFilter = item.run.status == .failed
                    || item.run.status == .timedOut
                    || item.run.status == .stalled
                    || item.run.status == .cancelled
                    || item.run.status == .unknown
            case .completed:
                matchesFilter = item.run.status == .completed
            }

            guard matchesFilter else { return false }
            let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedSearch.isEmpty else { return true }
            return item.title.localizedCaseInsensitiveContains(trimmedSearch)
                || item.run.directoryURL.path.localizedCaseInsensitiveContains(trimmedSearch)
                || item.modelLabel.localizedCaseInsensitiveContains(trimmedSearch)
                || item.workflow.localizedCaseInsensitiveContains(trimmedSearch)
                || item.currentStage.localizedCaseInsensitiveContains(trimmedSearch)
                || (item.providerRequestURL?.path.localizedCaseInsensitiveContains(trimmedSearch) ?? false)
                || item.outputURLs.contains { $0.path.localizedCaseInsensitiveContains(trimmedSearch) }
                || item.rawResponseURLs.contains { $0.path.localizedCaseInsensitiveContains(trimmedSearch) }
                || item.rawPayloadURLs.contains { $0.path.localizedCaseInsensitiveContains(trimmedSearch) }
                || item.providerCalls.contains { call in
                    call.callID.localizedCaseInsensitiveContains(trimmedSearch)
                        || call.provider.localizedCaseInsensitiveContains(trimmedSearch)
                        || call.model.localizedCaseInsensitiveContains(trimmedSearch)
                        || call.message.localizedCaseInsensitiveContains(trimmedSearch)
                        || call.error.localizedCaseInsensitiveContains(trimmedSearch)
                }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                runList
                    .frame(minWidth: 620)
                RunDetailsInspectorView(
                    item: store.selectedRun,
                    recoveryNotice: recoveryNotice,
                    onOpen: store.open,
                    onReveal: store.reveal,
                    onCopyPath: store.copyPath,
                    onSurfaceRecovery: surfaceRecoveryArtifact
                )
                .frame(minWidth: 420, idealWidth: 520, maxWidth: 640)
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
        .animation(AppDesignSystem.Motion.standard(reduceMotion), value: filteredRuns)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
            HStack(alignment: .center, spacing: AppDesignSystem.Spacing.md) {
                titleBlock
                Spacer(minLength: AppDesignSystem.Spacing.lg)
                headerActions
            }

            PaperBananaReadinessPanel(snapshot: settings.readinessSnapshot())

            WorkspaceScopeStrip(
                selection: $filter,
                searchText: $searchText,
                searchPrompt: "Search runs",
                accessibilityLabel: "Run scope",
                visibleCount: filteredRuns.count,
                totalCount: store.runs.count
            )
        }
        .padding(.horizontal, AppDesignSystem.Spacing.lg)
        .padding(.vertical, AppDesignSystem.Spacing.md)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
            Text("Native Run Cockpit")
                .font(AppDesignSystem.Typography.title)
            Text(summaryText)
                .font(AppDesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }

    private var headerActions: some View {
        HStack(spacing: AppDesignSystem.Spacing.sm) {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([resultsDirectoryURL])
            } label: {
                Label("Reveal Results", systemImage: "finder")
            }
            .help("Reveal PaperBanana results")

            Button {
                refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .labelStyle(.iconOnly)
            .help("Refresh run details")
        }
        .controlSize(.small)
    }

    private var summaryText: String {
        let attention = store.runs.filter(\.needsAttention).count
        return "\(store.runs.count) runs, \(attention) need attention, scanned from native generation, refinement, and provider audit folders."
    }

    private var resultsDirectoryURL: URL {
        URL(fileURLWithPath: settings.repoPath, isDirectory: true)
            .appendingPathComponent("results", isDirectory: true)
    }

    private var runList: some View {
        RunDetailsRunListView(runs: filteredRuns, selectedRunID: $store.selectedRunID)
        .onChange(of: filteredRuns) { _ in
            reconcileSelection()
        }
    }

    private func refresh() {
        store.refresh(repoPath: settings.repoPath)
        reconcileSelection()
    }

    private func surfaceRecoveryArtifact(_ call: ProviderRunLedgerCall) {
        do {
            let result = try store.surfaceRecoveryArtifact(for: call, repoPath: settings.repoPath)
            recoveryNotice = "Recovered \(result.artifactURL.lastPathComponent)"
            reconcileSelection()
        } catch {
            recoveryNotice = "Recovery failed: \(error.localizedDescription)"
        }
    }

    private func reconcileSelection() {
        if let selected = store.selectedRunID, filteredRuns.contains(where: { $0.id == selected }) {
            return
        }
        store.selectedRunID = filteredRuns.first?.id
    }
}
