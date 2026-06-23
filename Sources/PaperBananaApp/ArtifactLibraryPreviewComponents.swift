import AppKit
import SwiftUI

struct ArtifactCardView: View {
    let artifact: PaperBananaArtifact
    let isSelected: Bool
    let isFavorite: Bool

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
            ZStack(alignment: .topTrailing) {
                ArtifactPreviewView(artifact: artifact)
                    .frame(height: 142)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Radius.control, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppDesignSystem.Radius.control, style: .continuous)
                            .stroke(.quaternary, lineWidth: 1)
                    }

                cardBadges
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(artifact.title)
                    .font(AppDesignSystem.Typography.headline)
                    .lineLimit(1)
                Text(artifact.workflow)
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(AppDesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                .fill(
                    isSelected
                        ? AppDesignSystem.Adaptive.selectionFill(Color.accentColor, contrast: colorSchemeContrast)
                        : AppDesignSystem.Surfaces.panel
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                .stroke(
                    isSelected
                        ? AppDesignSystem.Adaptive.selectionStroke(Color.accentColor, contrast: colorSchemeContrast)
                        : Color.secondary.opacity(colorSchemeContrast == .increased ? 0.48 : 0.22),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(artifact.title), \(artifact.kind.label), \(artifact.workflow)")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Selects this artifact for preview and actions.")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var accessibilityValue: String {
        var values: [String] = []
        if isSelected { values.append("Selected") }
        if isFavorite { values.append("Favorite") }
        if artifact.isRecovered { values.append("Recovered") }
        if let status = artifact.runStatus {
            values.append("Run status \(status.label)")
        }
        values.append(artifact.relativePath)
        return values.joined(separator: ", ")
    }

    private var cardBadges: some View {
        VStack(alignment: .trailing, spacing: 5) {
            if isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .padding(7)
                    .appAdaptiveMaterialBackground(
                        .regularMaterial,
                        fallback: AppDesignSystem.Surfaces.panel,
                        in: Circle()
                    )
                    .accessibilityLabel("Favorite")
            }

            if artifact.isRecovered {
                Label("Recovered", systemImage: "checkmark.seal.fill")
                    .font(AppDesignSystem.Typography.caption)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .appAdaptiveMaterialBackground(
                        .regularMaterial,
                        fallback: AppDesignSystem.Surfaces.panel,
                        in: Capsule()
                    )
                    .accessibilityLabel("Recovered image")
            }

            if let runStatus = artifact.runStatus {
                ArtifactRunStatusBadge(status: runStatus)
                    .accessibilityLabel("Run status \(runStatus.label)")
            }
        }
        .padding(6)
    }
}

struct ArtifactPreviewView: View {
    let artifact: PaperBananaArtifact
    var allowsInteraction = false

    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        if artifact.kind == .image, let image = NSImage(contentsOf: artifact.url) {
            if allowsInteraction {
                interactiveImage(image)
            } else {
                staticImage(image)
            }
        } else {
            VStack(spacing: AppDesignSystem.Spacing.sm) {
                Image(systemName: artifact.kind.systemImage)
                    .font(.system(size: 34, weight: .regular))
                Text(artifact.url.pathExtension.uppercased())
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appAdaptiveMaterialBackground(
                .regularMaterial,
                fallback: AppDesignSystem.Surfaces.content,
                in: Rectangle()
            )
        }
    }

    private func staticImage(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
    }

    private func interactiveImage(_ image: NSImage) -> some View {
        ZStack(alignment: .bottomTrailing) {
            interactiveImageContent(fallbackImage: image)
                .scaleEffect(zoom)
                .offset(offset)
                .contentShape(Rectangle())
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            zoom = min(max(lastZoom * value, 1), 6)
                        }
                        .onEnded { _ in
                            lastZoom = zoom
                            if zoom <= 1 {
                                resetView()
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            guard zoom > 1 else { return }
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )

            HStack(spacing: AppDesignSystem.Spacing.xs) {
                Button {
                    withAnimation(AppDesignSystem.Motion.quick) {
                        zoom = min(zoom + 0.5, 6)
                        lastZoom = zoom
                    }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .help("Zoom in")
                .accessibilityLabel("Zoom in")

                Button {
                    withAnimation(AppDesignSystem.Motion.quick) {
                        zoom = max(zoom - 0.5, 1)
                        lastZoom = zoom
                        if zoom <= 1 {
                            resetView()
                        }
                    }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .help("Zoom out")
                .accessibilityLabel("Zoom out")

                Button {
                    withAnimation(AppDesignSystem.Motion.quick) {
                        resetView()
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help("Reset preview")
                .accessibilityLabel("Reset preview")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(8)
            .appAdaptiveMaterialBackground(
                .regularMaterial,
                fallback: AppDesignSystem.Surfaces.panel,
                in: Capsule()
            )
            .padding(8)
        }
    }

    @ViewBuilder
    private func interactiveImageContent(fallbackImage image: NSImage) -> some View {
        if MetalImagePreviewView.isAvailable {
            MetalImagePreviewView(imageURL: artifact.url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
                .accessibilityLabel("Metal image preview for \(artifact.title)")
        } else {
            staticImage(image)
        }
    }

    private func resetView() {
        zoom = 1
        lastZoom = 1
        offset = .zero
        lastOffset = .zero
    }
}

struct ArtifactRunStatusBadge: View {
    let status: ArtifactRunStatus

    var body: some View {
        Label(status.label, systemImage: status.systemImage)
            .font(AppDesignSystem.Typography.caption)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .appAdaptiveMaterialBackground(
                .regularMaterial,
                fallback: AppDesignSystem.Surfaces.panel,
                in: Capsule()
            )
            .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
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
