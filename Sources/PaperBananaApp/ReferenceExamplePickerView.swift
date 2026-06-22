import AppKit
import SwiftUI

enum ReferenceExampleScope: String, AppFilterOption {
    case all
    case selected

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All"
        case .selected: "Selected"
        }
    }
}

struct ReferenceExamplePickerView: View {
    @ObservedObject var store: ReferenceExampleStore
    @Binding var selectedIDs: Set<String>
    let task: String
    let isRunning: Bool

    @State private var scope: ReferenceExampleScope = .all
    @State private var searchText = ""

    private let datasetURL = URL(string: "https://huggingface.co/datasets/dwzhu/PaperBananaBench")!

    var body: some View {
        WorkbenchSection(
            "Reference Examples",
            systemImage: "quote.bubble",
            subtitle: sectionSubtitle
        ) {
            if taskIsPlot {
                unsupportedPlotState
            } else {
                switch store.state {
                case .available:
                    availableState
                case .idle:
                    statusState(
                        title: "Dataset Not Loaded",
                        systemImage: "clock",
                        detail: "PaperBanana will scan the local benchmark before manual references are available.",
                        tint: .secondary,
                        action: nil
                    )
                case .missing:
                    statusState(
                        title: "Download PaperBananaBench",
                        systemImage: "tray.and.arrow.down",
                        detail: store.state.statusDetail,
                        tint: AppDesignSystem.SemanticColors.statusStarting,
                        action: openDatasetPage
                    )
                case .malformed:
                    statusState(
                        title: "Reference File Needs Review",
                        systemImage: "exclamationmark.triangle",
                        detail: store.state.statusDetail,
                        tint: AppDesignSystem.SemanticColors.statusFailed,
                        action: nil
                    )
                case .empty:
                    statusState(
                        title: "No Diagram Examples Found",
                        systemImage: "doc.text.magnifyingglass",
                        detail: store.state.statusDetail,
                        tint: AppDesignSystem.SemanticColors.statusStarting,
                        action: nil
                    )
                }
            }
        }
        .disabled(isRunning)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reference examples")
        .accessibilityValue(accessibilityValue)
    }

    private var sectionSubtitle: String {
        if taskIsPlot {
            return "Manual plot examples are not available yet."
        }
        let count = store.selectedExamples(for: selectedIDs).count
        if count == 0 {
            return "Optional manual PaperBananaBench diagram guidance."
        }
        return "\(count) of \(ReferenceExampleSelection.maximumSelectionCount) selected for prompt enrichment."
    }

    private var taskIsPlot: Bool {
        task.localizedCaseInsensitiveContains("plot")
    }

    private var availableState: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
            selectionSummary
            missingImageWarning

            WorkspaceScopeStrip(
                selection: $scope,
                searchText: $searchText,
                searchPrompt: "Search examples",
                accessibilityLabel: "Reference example scope",
                visibleCount: visibleExamples.count,
                totalCount: store.state.examples.count,
                prefersStackedLayout: true,
                scopeIdealWidth: 220,
                scopeMaxWidth: 260
            )

            if visibleExamples.isEmpty {
                ArtifactEmptyStateView(
                    title: scope == .selected ? "No Selected Examples" : "No Matches",
                    systemImage: "doc.text.magnifyingglass",
                    description: scope == .selected ? "Select up to 10 diagram examples to guide the next run." : "Try a different id, caption, or methodology keyword."
                )
                .frame(maxWidth: .infinity, minHeight: 130)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
                        ForEach(visibleExamples) { example in
                            ReferenceExampleRow(
                                example: example,
                                isSelected: selectedIDs.contains(example.id),
                                canSelect: canSelect(example),
                                isRunning: isRunning
                            ) {
                                selectedIDs = ReferenceExampleSelection.toggledIDs(
                                    selectedIDs,
                                    id: example.id,
                                    orderedExamples: store.state.examples
                                )
                            }
                        }
                    }
                }
                .frame(maxHeight: 280)
                .accessibilityLabel("Reference example list")
            }
        }
    }

    private var selectionSummary: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppDesignSystem.Spacing.sm) {
            WorkbenchStatusPill(
                title: "\(store.selectedExamples(for: selectedIDs).count)/\(ReferenceExampleSelection.maximumSelectionCount)",
                systemImage: "checklist",
                tint: store.selectedExamples(for: selectedIDs).isEmpty ? .secondary : AppDesignSystem.SemanticColors.statusReady
            )

            Text(store.selectedExamples(for: selectedIDs).isEmpty ? "No manual examples selected." : "Selected examples will be appended to the provider prompt and run metadata.")
                .font(AppDesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: AppDesignSystem.Spacing.xs)

            Button {
                selectedIDs.removeAll()
            } label: {
                Label("Clear", systemImage: "xmark.circle")
            }
            .controlSize(.small)
            .disabled(selectedIDs.isEmpty || isRunning)
            .help("Clear selected reference examples")
        }
    }

    @ViewBuilder
    private var missingImageWarning: some View {
        let count = store.state.missingImageCount
        if count > 0 {
            Label(missingImageWarningText(count), systemImage: "exclamationmark.triangle.fill")
                .font(AppDesignSystem.Typography.caption)
                .foregroundStyle(AppDesignSystem.SemanticColors.statusStarting)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(missingImageWarningText(count))
        }
    }

    private var unsupportedPlotState: some View {
        statusState(
            title: "Manual Plot Examples Unavailable",
            systemImage: "chart.xyaxis.line",
            detail: "Native manual selection currently supports PaperBananaBench diagrams only. Plot generation can still run without manual examples.",
            tint: AppDesignSystem.SemanticColors.statusStarting,
            action: nil
        )
    }

    private func statusState(
        title: String,
        systemImage: String,
        detail: String,
        tint: Color,
        action: (() -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
            Label(title, systemImage: systemImage)
                .font(AppDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(detail)
                .font(AppDesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            if let action {
                Button(action: action) {
                    Label("Open Dataset Page", systemImage: "arrow.up.forward.app")
                }
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var visibleExamples: [ReferenceExample] {
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.state.examples.filter { example in
            if scope == .selected, !selectedIDs.contains(example.id) {
                return false
            }
            guard !search.isEmpty else { return true }
            return example.id.localizedCaseInsensitiveContains(search)
                || example.visualIntent.localizedCaseInsensitiveContains(search)
                || example.contentSummary.localizedCaseInsensitiveContains(search)
                || example.imageRelativePath.localizedCaseInsensitiveContains(search)
                || (!example.imageAvailable && "missing image".localizedCaseInsensitiveContains(search))
        }
    }

    private func canSelect(_ example: ReferenceExample) -> Bool {
        selectedIDs.contains(example.id) || store.selectedExamples(for: selectedIDs).count < ReferenceExampleSelection.maximumSelectionCount
    }

    private func missingImageWarningText(_ count: Int) -> String {
        if count == 1 {
            return "1 example is missing its local image. It can still be selected, but prompt guidance will use metadata only."
        }
        return "\(count) examples are missing local images. They can still be selected, but prompt guidance will use metadata only."
    }

    private func openDatasetPage() {
        NSWorkspace.shared.open(datasetURL)
    }

    private var accessibilityValue: String {
        if taskIsPlot {
            return "Manual plot examples are unavailable."
        }
        switch store.state {
        case .available:
            let selectedCount = store.selectedExamples(for: selectedIDs).count
            let missingCount = store.state.missingImageCount
            guard missingCount > 0 else { return "\(selectedCount) selected." }
            return "\(selectedCount) selected. \(missingCount) examples missing local images."
        case .idle, .missing, .malformed, .empty:
            return store.state.statusTitle
        }
    }
}

private struct ReferenceExampleRow: View {
    let example: ReferenceExample
    let isSelected: Bool
    let canSelect: Bool
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: AppDesignSystem.Spacing.sm) {
                ReferenceExampleThumbnail(url: example.imageURL, imageAvailable: example.imageAvailable)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: AppDesignSystem.Spacing.xs) {
                        Text(example.id)
                            .font(.system(.caption, design: .monospaced, weight: .semibold))
                            .lineLimit(1)

                        Spacer(minLength: AppDesignSystem.Spacing.xs)

                        if !example.imageAvailable {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppDesignSystem.SemanticColors.statusStarting)
                                .help("Local reference image is missing")
                                .accessibilityHidden(true)
                        }

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? AppDesignSystem.SemanticColors.statusReady : .secondary)
                            .accessibilityHidden(true)
                    }

                    Text(example.visualIntent)
                        .font(AppDesignSystem.Typography.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(example.contentSummary)
                        .font(AppDesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(AppDesignSystem.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                    .stroke(isSelected ? AppDesignSystem.SemanticColors.statusReady.opacity(0.55) : Color.primary.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isRunning || (!isSelected && !canSelect))
        .accessibilityLabel("Reference example \(example.id)")
        .accessibilityValue(accessibilityValue)
        .help(isSelected ? "Remove this reference example" : "Select this reference example")
    }

    @ViewBuilder
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
            .fill(isSelected ? AppDesignSystem.SemanticColors.statusReady.opacity(0.12) : AppDesignSystem.Surfaces.content)
    }

    private var accessibilityValue: String {
        let imageState = example.imageAvailable ? "Image available." : "Image missing."
        if isSelected {
            return "Selected. \(imageState) \(example.visualIntent)"
        }
        if canSelect {
            return "Not selected. \(imageState) \(example.visualIntent)"
        }
        return "Selection limit reached. \(imageState) \(example.visualIntent)"
    }
}

private struct ReferenceExampleThumbnail: View {
    let url: URL
    let imageAvailable: Bool

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else if !imageAvailable {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppDesignSystem.SemanticColors.statusStarting)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 46, height: 34)
        .background(AppDesignSystem.Surfaces.panel, in: RoundedRectangle(cornerRadius: AppDesignSystem.Radius.control, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppDesignSystem.Radius.control, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .accessibilityHidden(true)
        .onAppear {
            guard image == nil, imageAvailable else { return }
            image = NSImage(contentsOf: url)
        }
    }
}
