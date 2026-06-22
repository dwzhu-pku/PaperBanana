import AppKit
import Foundation

@MainActor
final class RunDetailsStore: ObservableObject {
    @Published private(set) var runs: [RunDetailsItem] = []
    @Published var selectedRunID: RunDetailsItem.ID?

    var selectedRun: RunDetailsItem? {
        guard let selectedRunID else { return nil }
        return runs.first { $0.id == selectedRunID }
    }

    func refresh(repoPath: String) {
        runs = RunDetailsScanner.scan(repoRootPath: repoPath)
        if let selectedRunID, runs.contains(where: { $0.id == selectedRunID }) == false {
            self.selectedRunID = runs.first?.id
        } else if selectedRunID == nil {
            selectedRunID = runs.first?.id
        }
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    func surfaceRecoveryArtifact(for call: ProviderRunLedgerCall, repoPath: String) throws -> ProviderRecoveryResult {
        let result = try ProviderRecoverySurfacer.surfaceFirstRecoverableArtifact(
            for: call,
            repoRootPath: repoPath,
            fileManager: .default
        )
        refresh(repoPath: repoPath)
        return result
    }
}
