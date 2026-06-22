import AppKit
import SwiftUI

enum RootSidebarDestination: String, Hashable {
    case promptStudio
    case generateCandidates
    case refineImage
    case recoveredImages
    case artifactLibrary
    case runDetails
    case runLedger
    case backendDiagnostics

    var title: String {
        switch self {
        case .promptStudio: "Prompt Studio"
        case .generateCandidates: "Generate Candidates"
        case .refineImage: "Refine Image"
        case .recoveredImages: "Recovered Images"
        case .artifactLibrary: "Artifact Library"
        case .runDetails: "Run Details"
        case .runLedger: "Run Ledger"
        case .backendDiagnostics: "Diagnostics"
        }
    }

    var systemImage: String {
        switch self {
        case .promptStudio: "text.bubble"
        case .generateCandidates: "square.grid.2x2"
        case .refineImage: "photo.on.rectangle"
        case .recoveredImages: "checkmark.seal"
        case .artifactLibrary: "photo.stack"
        case .runDetails: "waveform.path.ecg.rectangle"
        case .runLedger: "list.bullet.rectangle"
        case .backendDiagnostics: "stethoscope"
        }
    }
}

struct RootSidebarView: View {
    @ObservedObject var settings: AppSettingsStore
    @Binding var selection: RootSidebarDestination?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            RootActivityRail(selection: $selection)

            Divider()

            RootSidebarNavigationPane(settings: settings, selection: $selection)
        }
        .frame(width: AppDesignSystem.Layout.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(AppDesignSystem.Surfaces.sidebar)
        .clipped()
        .animation(AppDesignSystem.Motion.standard(reduceMotion), value: selection)
    }
}

private struct RootSidebarNavigationPane: View {
    @ObservedObject var settings: AppSettingsStore
    @Binding var selection: RootSidebarDestination?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RootSidebarHeader()

            Divider()

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.lg) {
                    RootRuntimeBlock(settings: settings)
                    commandSection(
                        "Create",
                        destinations: [.promptStudio, .generateCandidates, .refineImage]
                    )
                    commandSection(
                        "Library",
                        destinations: [.recoveredImages, .artifactLibrary]
                    )
                    commandSection(
                        "Operations",
                        destinations: [.runDetails, .runLedger]
                    )
                    commandSection(
                        "Diagnostics",
                        destinations: [.backendDiagnostics]
                    )
                }
                .padding(.horizontal, AppDesignSystem.Layout.sidebarHorizontalPadding)
                .padding(.vertical, AppDesignSystem.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.automatic)

            Divider()

            Button {
                openSettingsWindow()
            } label: {
                HStack(spacing: AppDesignSystem.Spacing.sm) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppDesignSystem.SemanticColors.sidebarLabel)
                        .frame(width: 18, alignment: .center)
                        .accessibilityHidden(true)

                    Text("Settings")
                        .font(.system(.body, design: .default))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, AppDesignSystem.Spacing.sm)
                .frame(height: AppDesignSystem.Layout.sidebarRowHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppDesignSystem.SemanticColors.sidebarLabel)
            .padding(.horizontal, AppDesignSystem.Layout.sidebarHorizontalPadding)
            .padding(.vertical, AppDesignSystem.Spacing.md)
            .accessibilityLabel("Settings")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppDesignSystem.Surfaces.sidebar)
    }

    private func commandSection(_ title: String, destinations: [RootSidebarDestination]) -> some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, AppDesignSystem.Spacing.sm)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(destinations, id: \.self) { destination in
                    RootSidebarCommandRow(
                        destination: destination,
                        isSelected: selection == destination
                    ) {
                        selection = destination
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openSettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

private struct RootActivityRail: View {
    @Binding var selection: RootSidebarDestination?

    private let primaryDestinations: [RootSidebarDestination] = [
        .promptStudio,
        .recoveredImages,
        .runDetails,
        .runLedger,
        .backendDiagnostics
    ]

    var body: some View {
        VStack(spacing: AppDesignSystem.Spacing.xs) {
            Spacer()
                .frame(height: AppDesignSystem.Spacing.md)

            ForEach(primaryDestinations, id: \.self) { destination in
                RootActivityRailButton(
                    destination: destination,
                    isSelected: selection == destination
                ) {
                    selection = destination
                }
            }

            Spacer()

            Button {
                openSettingsWindow()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: AppDesignSystem.Layout.activityButtonSize, height: AppDesignSystem.Layout.activityButtonSize)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppDesignSystem.SemanticColors.sidebarLabel)
            .help("Settings")
            .accessibilityLabel("Settings")

            Spacer()
                .frame(height: AppDesignSystem.Spacing.md)
        }
        .frame(width: AppDesignSystem.Layout.activityRailWidth)
        .frame(maxHeight: .infinity)
        .background(AppDesignSystem.Surfaces.activityRail)
    }

    private func openSettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

private struct RootActivityRailButton: View {
    let destination: RootSidebarDestination
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: destination.systemImage)
                .font(.system(size: 15, weight: .medium))
                .frame(width: AppDesignSystem.Layout.activityButtonSize, height: AppDesignSystem.Layout.activityButtonSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.primary : AppDesignSystem.SemanticColors.sidebarLabel)
        .background {
            if isSelected {
                Circle()
                    .fill(AppDesignSystem.SemanticColors.accent.opacity(0.24))
                    .overlay {
                        Circle()
                            .stroke(AppDesignSystem.SemanticColors.accent.opacity(0.55), lineWidth: 1)
                    }
            }
        }
        .help(destination.title)
        .accessibilityLabel(destination.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct RootSidebarHeader: View {
    var body: some View {
        HStack(spacing: AppDesignSystem.Spacing.sm) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("PaperBanana")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                Text("Native figure cockpit")
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.leading, AppDesignSystem.Layout.sidebarHorizontalPadding)
        .padding(.trailing, AppDesignSystem.Spacing.md)
        .frame(height: 60)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RootRuntimeBlock: View {
    @ObservedObject var settings: AppSettingsStore

    var body: some View {
        let readiness = settings.readinessSnapshot()

        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
            HStack(spacing: AppDesignSystem.Spacing.sm) {
                Circle()
                    .fill(statusColor(readiness.severity))
                    .frame(width: 8, height: 8)
                Text("Native Ready")
                    .font(.system(.subheadline, design: .default, weight: .medium))
                    .lineLimit(1)
            }

            SidebarMetadataRow(title: "Path", value: readiness.configuredPathRow.value)
            SidebarMetadataRow(title: "Key", value: readiness.generationKeyRow.value)
            SidebarMetadataRow(title: "Model", value: settings.defaultImageModel.label)
            SidebarMetadataRow(title: "Backend", value: readiness.backendValidityRow.value)
            SidebarMetadataRow(title: "Fallback", value: readiness.deterministicFallbackRow.value)
        }
        .padding(AppDesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Native PaperBanana app is ready")
        .help(readiness.statusMessage)
    }

    private func statusColor(_ severity: PaperBananaReadinessSeverity) -> Color {
        switch severity {
        case .ready: AppDesignSystem.SemanticColors.statusReady
        case .warning: AppDesignSystem.SemanticColors.statusStarting
        case .blocked: AppDesignSystem.SemanticColors.statusFailed
        }
    }
}

private struct RootSidebarCommandRow: View {
    let destination: RootSidebarDestination
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppDesignSystem.Spacing.sm) {
                Image(systemName: destination.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? Color.primary : AppDesignSystem.SemanticColors.sidebarLabel)
                    .frame(width: 18, alignment: .center)
                    .accessibilityHidden(true)

                Text(destination.title)
                    .font(.system(.body, design: .default, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, AppDesignSystem.Spacing.sm)
            .frame(height: AppDesignSystem.Layout.sidebarRowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.primary : AppDesignSystem.SemanticColors.sidebarLabel)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(AppDesignSystem.SemanticColors.accent.opacity(0.22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(AppDesignSystem.SemanticColors.accent.opacity(0.45), lineWidth: 1)
                    }
            }
        }
        .accessibilityLabel(destination.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct SidebarMetadataRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppDesignSystem.Spacing.sm) {
            Text(title)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 58, alignment: .leading)
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(AppDesignSystem.Typography.caption)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(title): \(value)")
        .help(value)
    }
}
