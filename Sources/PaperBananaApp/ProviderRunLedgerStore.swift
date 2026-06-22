import AppKit
import Foundation

@MainActor
final class ProviderRunLedgerStore: ObservableObject {
    @Published private(set) var calls: [ProviderRunLedgerCall] = []
    @Published var selectedCallID: ProviderRunLedgerCall.ID?

    var selectedCall: ProviderRunLedgerCall? {
        guard let selectedCallID else { return nil }
        return calls.first { $0.id == selectedCallID }
    }

    func refresh(repoPath: String) {
        calls = ProviderRunLedgerScanner.scan(repoRootPath: repoPath)
        if let selectedCallID, calls.contains(where: { $0.id == selectedCallID }) == false {
            self.selectedCallID = calls.first?.id
        } else if selectedCallID == nil {
            selectedCallID = calls.first?.id
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
