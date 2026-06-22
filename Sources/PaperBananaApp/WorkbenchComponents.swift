import SwiftUI

struct WorkbenchSection<Content: View>: View {
    let title: String
    let systemImage: String
    let subtitle: String?
    let content: Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        _ title: String,
        systemImage: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
                Label(title, systemImage: systemImage)
                    .font(AppDesignSystem.Typography.headline)
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(AppDesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(AppDesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(sectionBackground)
        .overlay {
            RoundedRectangle(cornerRadius: AppDesignSystem.Radius.workbench, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var sectionBackground: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: AppDesignSystem.Radius.workbench, style: .continuous)
                .fill(AppDesignSystem.Surfaces.panel)
        } else {
            RoundedRectangle(cornerRadius: AppDesignSystem.Radius.workbench, style: .continuous)
                .fill(.regularMaterial)
        }
    }
}

struct WorkbenchOptionField<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
            Text(title)
                .font(AppDesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
            content
        }
    }
}

struct WorkbenchCommandBar<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(alignment: .center, spacing: AppDesignSystem.Spacing.sm) {
            content
        }
        .padding(.horizontal, AppDesignSystem.Spacing.sm)
        .padding(.vertical, AppDesignSystem.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(commandBarBackground)
        .overlay {
            RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var commandBarBackground: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                .fill(AppDesignSystem.Surfaces.panel)
        } else {
            RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                .fill(.thinMaterial)
        }
    }
}

struct WorkbenchEditorSurface<Content: View>: View {
    let minHeight: CGFloat
    let content: Content

    init(minHeight: CGFloat = 280, @ViewBuilder content: () -> Content) {
        self.minHeight = minHeight
        self.content = content()
    }

    var body: some View {
        content
            .frame(minHeight: minHeight, alignment: .topLeading)
            .padding(AppDesignSystem.Spacing.sm)
            .background(
                AppDesignSystem.Surfaces.content,
                in: RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            }
    }
}

struct WorkbenchStatusPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(AppDesignSystem.Typography.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, AppDesignSystem.Spacing.sm)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: Capsule())
            .accessibilityLabel(title)
    }
}

struct PaperBananaReadinessPanel: View {
    let snapshot: PaperBananaReadinessSnapshot
    let title: String

    init(
        snapshot: PaperBananaReadinessSnapshot,
        title: String = "PaperBanana Readiness"
    ) {
        self.snapshot = snapshot
        self.title = title
    }

    var body: some View {
        WorkbenchSection(
            title,
            systemImage: "checklist.checked",
            subtitle: snapshot.statusMessage
        ) {
            HStack(alignment: .firstTextBaseline, spacing: AppDesignSystem.Spacing.md) {
                WorkbenchStatusPill(
                    title: snapshot.statusTitle,
                    systemImage: statusSystemImage(for: snapshot.severity),
                    tint: color(for: snapshot.severity)
                )

                Text(snapshot.configuredPath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(snapshot.configuredPath)
                    .accessibilityValue(snapshot.configuredPath)
            }

            Grid(alignment: .leading, horizontalSpacing: AppDesignSystem.Spacing.md, verticalSpacing: AppDesignSystem.Spacing.sm) {
                ForEach(snapshot.rows) { row in
                    readinessRow(row)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("PaperBanana readiness: \(snapshot.statusTitle)")
    }

    private func readinessRow(_ row: PaperBananaReadinessRow) -> some View {
        GridRow {
            Label(row.title, systemImage: row.systemImage)
                .font(AppDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(color(for: row.severity))
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.value)
                    .font(row.id == .configuredPath ? .system(.caption, design: .monospaced) : AppDesignSystem.Typography.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(row.id == .configuredPath ? 2 : 1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                Text(row.detail)
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }

    private func statusSystemImage(for severity: PaperBananaReadinessSeverity) -> String {
        switch severity {
        case .ready: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .blocked: "xmark.octagon.fill"
        }
    }

    private func color(for severity: PaperBananaReadinessSeverity) -> Color {
        switch severity {
        case .ready: AppDesignSystem.SemanticColors.statusReady
        case .warning: AppDesignSystem.SemanticColors.statusStarting
        case .blocked: AppDesignSystem.SemanticColors.statusFailed
        }
    }
}
