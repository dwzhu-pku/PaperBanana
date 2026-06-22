import AppKit
import SwiftUI

struct RootView: View {
    @ObservedObject var settings: AppSettingsStore
    @ObservedObject var backend: BackendSupervisor
    @StateObject private var generationStore = NativeImageGenerationStore()
    @State private var selection: RootSidebarDestination? = .recoveredImages
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            RootSidebarView(settings: settings, selection: $selection)
                .frame(width: AppDesignSystem.Layout.sidebarWidth)
                .background(AppDesignSystem.Surfaces.sidebar)
                .clipped()

            Divider()

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppDesignSystem.Surfaces.content)
        .onAppear {
            applyPendingIntentDestination()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            applyPendingIntentDestination()
        }
        .animation(AppDesignSystem.Motion.standard(reduceMotion), value: selection)
    }

    private func applyPendingIntentDestination() {
        guard let destination = PaperBananaIntentBridge.consume() else { return }
        switch destination {
        case .promptStudio:
            selection = .promptStudio
        case .refineImage:
            selection = .refineImage
        case .recoveredImages:
            selection = .recoveredImages
        case .runDetails:
            selection = .runDetails
        case .runLedger:
            selection = .runLedger
        }
    }

    @ViewBuilder
    private var detail: some View {
        if selection == .recoveredImages {
            ArtifactLibraryView(
                settings: settings,
                title: "Recovered Images",
                initialFilter: .recovered
            )
        } else if selection == .promptStudio {
            NativePromptStudioView(
                settings: settings,
                generationStore: generationStore
            )
        } else if selection == .artifactLibrary {
            ArtifactLibraryView(settings: settings)
        } else if selection == .runDetails {
            RunDetailsView(settings: settings)
        } else if selection == .runLedger {
            ProviderRunLedgerView(settings: settings)
        } else if selection == .backendDiagnostics {
            BackendDiagnosticsView(settings: settings, backend: backend)
        } else if selection == .generateCandidates {
            NativePromptStudioView(
                settings: settings,
                generationStore: generationStore,
                title: "Generate Candidates"
            )
        } else if selection == .refineImage {
            ArtifactLibraryView(
                settings: settings,
                title: "Refine Image",
                initialFilter: .images,
                refinementPresentation: .workspace
            )
        } else {
            ArtifactLibraryView(settings: settings)
        }
    }
}
