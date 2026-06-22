import AppKit
import OSLog
import SwiftUI

enum ArtifactLibraryFilter: String, AppFilterOption {
    case recovered
    case images
    case favorites
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recovered: "Recovered"
        case .images: "Images"
        case .favorites: "Favorites"
        case .all: "All"
        }
    }
}

enum ArtifactRefinementPresentation {
    case sheet
    case workspace
}

struct ArtifactLibraryView: View {
    private static let logger = Logger(subsystem: "local.paperbanana.gui", category: "ArtifactLibrary")

    @ObservedObject var settings: AppSettingsStore
    let title: String
    @StateObject private var store = ArtifactLibraryStore()
    @StateObject private var refinementStore = NativeRefinementStore()
    @State private var filter: ArtifactLibraryFilter
    @State private var searchText = ""
    @State private var refinementArtifact: PaperBananaArtifact?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let refinementPresentation: ArtifactRefinementPresentation

    init(
        settings: AppSettingsStore,
        title: String = "Artifact Library",
        initialFilter: ArtifactLibraryFilter = .images,
        refinementPresentation: ArtifactRefinementPresentation = .sheet
    ) {
        self.settings = settings
        self.title = title
        self.refinementPresentation = refinementPresentation
        _filter = State(initialValue: initialFilter)
    }

    private var filteredArtifacts: [PaperBananaArtifact] {
        store.artifacts.filter { artifact in
            let matchesFilter: Bool
            switch filter {
            case .recovered:
                matchesFilter = artifact.kind == .image && artifact.isRecovered
            case .images:
                matchesFilter = artifact.kind == .image
            case .favorites:
                matchesFilter = store.isFavorite(artifact)
            case .all:
                matchesFilter = true
            }

            guard matchesFilter else { return false }
            let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedSearch.isEmpty else { return true }
            return artifact.title.localizedCaseInsensitiveContains(trimmedSearch)
                || artifact.workflow.localizedCaseInsensitiveContains(trimmedSearch)
                || artifact.relativePath.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                artifactGrid
                    .frame(minWidth: 520)
                inspectorOrRefinementWorkspace
                    .frame(minWidth: 420, idealWidth: refinementPresentation == .workspace ? 540 : 430, maxWidth: 680)
            }
        }
        .background(AppDesignSystem.Surfaces.content)
        .onAppear {
            store.refresh(repoPath: settings.repoPath)
            reconcileSelectionWithFilter()
            logRecoveredVisibilityIfNeeded()
        }
        .onChange(of: settings.repoPath) { repoPath in
            store.refresh(repoPath: repoPath)
            reconcileSelectionWithFilter()
            logRecoveredVisibilityIfNeeded()
        }
        .onChange(of: store.artifacts) { _ in
            reconcileSelectionWithFilter()
            logRecoveredVisibilityIfNeeded()
        }
        .onChange(of: filter) { _ in
            reconcileSelectionWithFilter()
            logRecoveredVisibilityIfNeeded()
        }
        .onChange(of: searchText) { _ in
            reconcileSelectionWithFilter()
            logRecoveredVisibilityIfNeeded()
        }
        .sheet(item: $refinementArtifact) { artifact in
            if refinementPresentation == .sheet {
                RefinementSheetView(
                    artifact: artifact,
                    settings: settings,
                    refinementStore: refinementStore,
                    onFinished: selectFinishedRefinement
                )
            }
        }
        .animation(AppDesignSystem.Motion.standard(reduceMotion), value: filteredArtifacts)
    }

    @ViewBuilder
    private var inspectorOrRefinementWorkspace: some View {
        if refinementPresentation == .workspace {
            NativeRefinementWorkspaceView(
                artifact: store.selectedArtifact,
                settings: settings,
                refinementStore: refinementStore,
                onOpen: { artifact in store.open(artifact) },
                onReveal: { artifact in store.reveal(artifact) },
                onFinished: selectFinishedRefinement
            )
        } else {
            ArtifactInspectorView(
                artifact: store.selectedArtifact,
                isFavorite: store.selectedArtifact.map(store.isFavorite) ?? false,
                onOpen: { artifact in store.open(artifact) },
                onReveal: { artifact in store.reveal(artifact) },
                onCopyPath: { artifact in store.copyPath(artifact) },
                onExportImage: { artifact in store.exportImage(artifact) },
                onExportWithMetadata: { artifact in store.exportWithMetadata(artifact) },
                onRefine: { artifact in refinementArtifact = artifact },
                onToggleFavorite: { artifact in store.toggleFavorite(artifact) }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
            HStack(alignment: .center, spacing: AppDesignSystem.Spacing.md) {
                headerTitle
                Spacer(minLength: AppDesignSystem.Spacing.lg)
                headerActions
            }

            WorkspaceScopeStrip(
                selection: $filter,
                searchText: $searchText,
                searchPrompt: "Search artifacts",
                accessibilityLabel: "Artifact scope",
                visibleCount: filteredArtifacts.count,
                totalCount: store.artifacts.count
            )
        }
        .padding(.horizontal, AppDesignSystem.Spacing.lg)
        .padding(.vertical, AppDesignSystem.Spacing.md)
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
            Text(title)
                .font(AppDesignSystem.Typography.title)
                .lineLimit(1)
            Text(summaryText)
                .font(AppDesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }

    private var headerActions: some View {
        HStack(spacing: AppDesignSystem.Spacing.sm) {
            if filter == .recovered {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([recoveryDirectoryURL])
                } label: {
                    Label("Reveal Recovery Folder", systemImage: "finder")
                }
                .help("Reveal the recovered image folder in Finder")
            }
            Button {
                store.refresh(repoPath: settings.repoPath)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .labelStyle(.iconOnly)
            .help("Refresh the artifact library")
        }
        .controlSize(.small)
    }

    private var summaryText: String {
        let imageCount = store.artifacts.filter { $0.kind == .image }.count
        let recoveredCount = store.artifacts.filter { $0.kind == .image && $0.isRecovered }.count
        let favoriteCount = store.favoritePaths.count
        if filter == .recovered {
            return "\(recoveredCount) recovered images surfaced from \(recoveryDirectoryURL.path)"
        }
        return "\(imageCount) images, \(store.artifacts.count) total artifacts, \(favoriteCount) favorites"
    }

    private var recoveryDirectoryURL: URL {
        URL(fileURLWithPath: settings.repoPath, isDirectory: true)
            .appendingPathComponent("results/recovered", isDirectory: true)
    }

    private func reconcileSelectionWithFilter() {
        if let selectedArtifactID = store.selectedArtifactID,
           filteredArtifacts.contains(where: { $0.id == selectedArtifactID }) {
            return
        }
        store.selectedArtifactID = filteredArtifacts.first?.id
    }

    private func logRecoveredVisibilityIfNeeded() {
        guard filter == .recovered else { return }
        let recoveredImages = store.artifacts.filter { $0.kind == .image && $0.isRecovered }
        let selectedPath = store.selectedArtifact?.url.path ?? "none"
        Self.logger.notice("Recovered Images surfaced \(recoveredImages.count, privacy: .public) image(s); selected \(selectedPath, privacy: .public)")
    }

    private func selectFinishedRefinement(_ outputURL: URL) {
        store.refresh(repoPath: settings.repoPath)
        store.selectedArtifactID = outputURL.standardizedFileURL.path
    }

    @ViewBuilder
    private var artifactGrid: some View {
        if filteredArtifacts.isEmpty {
            EmptyArtifactLibraryView(repoPath: settings.repoPath)
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: AppDesignSystem.Spacing.md)],
                    spacing: AppDesignSystem.Spacing.md
                ) {
                    ForEach(filteredArtifacts) { artifact in
                        ArtifactCardView(
                            artifact: artifact,
                            isSelected: artifact.id == store.selectedArtifactID,
                            isFavorite: store.isFavorite(artifact)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.selectedArtifactID = artifact.id
                        }
                        .contextMenu {
                            Button("Open") { store.open(artifact) }
                            Button("Reveal in Finder") { store.reveal(artifact) }
                            Button("Copy Path") { store.copyPath(artifact) }
                            Button("Export Image...") { store.exportImage(artifact) }
                                .disabled(artifact.kind != .image)
                            Button("Export with Metadata...") { store.exportWithMetadata(artifact) }
                            if artifact.kind == .image {
                                Divider()
                                Button(artifact.wasNativeRefined ? "Refine Again..." : "Refine...") {
                                    refinementArtifact = artifact
                                }
                            }
                            Divider()
                            Button(store.isFavorite(artifact) ? "Remove Favorite" : "Favorite") {
                                store.toggleFavorite(artifact)
                            }
                        }
                    }
                }
                .padding(AppDesignSystem.Spacing.lg)
            }
        }
    }
}

private struct EmptyArtifactLibraryView: View {
    let repoPath: String

    var body: some View {
        ArtifactEmptyStateView(
            title: "No Artifacts",
            systemImage: "photo.stack",
            description: "PaperBanana results are scanned from \(repoPath)/results."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppDesignSystem.Surfaces.content)
    }
}

struct ArtifactEmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: AppDesignSystem.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(.secondary)
            Text(title)
                .font(AppDesignSystem.Typography.title)
            Text(description)
                .font(AppDesignSystem.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(AppDesignSystem.Spacing.xl)
    }
}
