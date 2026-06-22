import OSLog
import SwiftUI

struct AppRootContainer: View {
    @ObservedObject var settings: AppSettingsStore
    @ObservedObject var backend: BackendSupervisor
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RootView(settings: settings, backend: backend)
            .frame(minWidth: 1120, minHeight: 760)
            .onAppear {
                AppIconController.shared.apply(colorScheme: colorScheme)
                guard !PaperBananaRuntimeEnvironment.isRunningUnitTests else { return }
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                recoverStaleRunsOnLaunch(repoPath: settings.repoPath)
            }
            .onChange(of: colorScheme) { newValue in
                AppIconController.shared.apply(colorScheme: newValue)
            }
    }

    private func recoverStaleRunsOnLaunch(repoPath: String) {
        let repoRoot = URL(fileURLWithPath: repoPath, isDirectory: true).standardizedFileURL
        let logger = Logger(subsystem: "local.paperbanana.gui", category: "RunRecovery")
        Task.detached {
            do {
                let recovered = try PaperBananaRunStore.recoverStaleNonTerminalRunsSynchronously(repoRoot: repoRoot)
                if recovered.isEmpty == false {
                    logger.warning("Recovered \(recovered.count, privacy: .public) stale PaperBanana run(s) on launch.")
                }
            } catch {
                logger.error("Failed to recover stale PaperBanana runs on launch: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
