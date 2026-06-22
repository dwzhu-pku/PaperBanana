import SwiftUI

struct WorkspaceScopeStrip<Option: AppFilterOption>: View where Option.AllCases: RandomAccessCollection {
    @Binding var selection: Option
    @Binding var searchText: String
    let searchPrompt: String
    let accessibilityLabel: String
    let visibleCount: Int
    let totalCount: Int
    let prefersStackedLayout: Bool
    let scopeIdealWidth: CGFloat
    let scopeMaxWidth: CGFloat

    init(
        selection: Binding<Option>,
        searchText: Binding<String>,
        searchPrompt: String,
        accessibilityLabel: String,
        visibleCount: Int,
        totalCount: Int,
        prefersStackedLayout: Bool = false,
        scopeIdealWidth: CGFloat = 440,
        scopeMaxWidth: CGFloat = 560
    ) {
        self._selection = selection
        self._searchText = searchText
        self.searchPrompt = searchPrompt
        self.accessibilityLabel = accessibilityLabel
        self.visibleCount = visibleCount
        self.totalCount = totalCount
        self.prefersStackedLayout = prefersStackedLayout
        self.scopeIdealWidth = scopeIdealWidth
        self.scopeMaxWidth = scopeMaxWidth
    }

    var body: some View {
        if prefersStackedLayout {
            verticalLayout
        } else {
            ViewThatFits(in: .horizontal) {
                horizontalLayout
                verticalLayout
            }
        }
    }

    private var horizontalLayout: some View {
        HStack(spacing: AppDesignSystem.Spacing.md) {
            scopePicker
            WorkspaceSearchField(prompt: searchPrompt, text: $searchText)
                .frame(minWidth: 220, idealWidth: 320, maxWidth: 380)
            Spacer(minLength: AppDesignSystem.Spacing.sm)
            resultCount
        }
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
            scopePicker
            HStack(spacing: AppDesignSystem.Spacing.md) {
                WorkspaceSearchField(prompt: searchPrompt, text: $searchText)
                    .frame(minWidth: 220)
                Spacer(minLength: AppDesignSystem.Spacing.sm)
                resultCount
            }
        }
    }

    private var scopePicker: some View {
        Picker(accessibilityLabel, selection: $selection) {
            ForEach(Array(Option.allCases), id: \.id) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(minWidth: 320, idealWidth: scopeIdealWidth, maxWidth: scopeMaxWidth, alignment: .leading)
        .accessibilityLabel(accessibilityLabel)
        .help("Showing \(selection.label)")
    }

    private var resultCount: some View {
        Text("\(visibleCount) of \(totalCount)")
            .font(AppDesignSystem.Typography.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .lineLimit(1)
            .accessibilityLabel("\(visibleCount) of \(totalCount) shown")
    }
}

private struct WorkspaceSearchField: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: AppDesignSystem.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .lineLimit(1)
                .accessibilityLabel(prompt)
                .accessibilityValue(searchAccessibilityValue)
                .accessibilityIdentifier(searchAccessibilityIdentifier)
                .help(prompt)
        }
        .padding(.horizontal, AppDesignSystem.Spacing.sm)
        .frame(height: 28)
        .appAdaptiveMaterialBackground(
            .regularMaterial,
            fallback: AppDesignSystem.Surfaces.panel,
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(prompt)
    }

    private var searchAccessibilityValue: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No search text" : text
    }

    private var searchAccessibilityIdentifier: String {
        let normalized = prompt
            .lowercased()
            .map { character -> Character in
                character.isLetter || character.isNumber ? character : "-"
            }
        let collapsed = String(normalized)
            .split(separator: "-")
            .joined(separator: "-")
        return "workspace-search-\(collapsed)"
    }
}
