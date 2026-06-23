import AppKit
import Foundation

@MainActor
final class ArtifactLibraryStore: ObservableObject {
    private enum DefaultsKey {
        static let favoriteArtifactPaths = "artifactLibrary.favoriteArtifactPaths"
    }

    @Published private(set) var artifacts: [PaperBananaArtifact] = []
    @Published private(set) var favoritePaths: Set<String>
    @Published var selectedArtifactID: PaperBananaArtifact.ID?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        favoritePaths = Set(defaults.stringArray(forKey: DefaultsKey.favoriteArtifactPaths) ?? [])
    }

    var selectedArtifact: PaperBananaArtifact? {
        guard let selectedArtifactID else { return nil }
        return artifacts.first { $0.id == selectedArtifactID }
    }

    func refresh(repoPath: String) {
        artifacts = ArtifactLibraryScanner.scan(repoRootPath: repoPath)
        PaperBananaSpotlightIndexer.index(
            artifacts: artifacts,
            runs: NativeRunCockpitScanner.scan(repoRootPath: repoPath),
            providerCalls: ProviderRunLedgerScanner.scan(repoRootPath: repoPath)
        )
        if let selectedArtifactID, artifacts.contains(where: { $0.id == selectedArtifactID }) == false {
            self.selectedArtifactID = artifacts.first?.id
        } else if selectedArtifactID == nil {
            selectedArtifactID = artifacts.first?.id
        }
    }

    func isFavorite(_ artifact: PaperBananaArtifact) -> Bool {
        favoritePaths.contains(artifact.id)
    }

    func toggleFavorite(_ artifact: PaperBananaArtifact) {
        if favoritePaths.contains(artifact.id) {
            favoritePaths.remove(artifact.id)
        } else {
            favoritePaths.insert(artifact.id)
        }
        defaults.set(Array(favoritePaths).sorted(), forKey: DefaultsKey.favoriteArtifactPaths)
    }

    func open(_ artifact: PaperBananaArtifact) {
        NSWorkspace.shared.open(artifact.url)
    }

    func reveal(_ artifact: PaperBananaArtifact) {
        NSWorkspace.shared.activateFileViewerSelecting([artifact.url])
    }

    func copyPath(_ artifact: PaperBananaArtifact) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(artifact.url.path, forType: .string)
    }

    func exportImage(_ artifact: PaperBananaArtifact) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Image"
        savePanel.prompt = "Export"
        savePanel.nameFieldStringValue = artifact.url.lastPathComponent
        savePanel.canCreateDirectories = true

        guard savePanel.runModal() == .OK, let destination = savePanel.url else { return }
        do {
            try copyReplacingItem(from: artifact.url, to: destination)
            showAlert(title: "Export Complete", message: "The image was exported to \(destination.path).")
        } catch {
            showAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }

    func exportWithMetadata(_ artifact: PaperBananaArtifact) {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose Export Folder"
        openPanel.prompt = "Export"
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false

        guard openPanel.runModal() == .OK, let destinationDirectory = openPanel.url else { return }
        do {
            let exportDirectory = try uniqueExportDirectory(for: artifact, in: destinationDirectory)
            try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
            for companion in exportCompanions(for: artifact) {
                try copyUniquely(from: companion, toDirectory: exportDirectory)
            }
            showAlert(title: "Export Complete", message: "The artifact bundle was exported to \(exportDirectory.path).")
        } catch {
            showAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }

    private func exportCompanions(for artifact: PaperBananaArtifact) -> [URL] {
        var urls = [artifact.url]
        if let metadataURL = artifact.metadataURL {
            urls.append(metadataURL)
        }
        if let promptURL = artifact.promptURL {
            urls.append(promptURL)
        }
        if let logURL = artifact.logURL {
            urls.append(logURL)
        }
        if let sourceURL = artifact.refinementLineage?.sourceURL,
           FileManager.default.fileExists(atPath: sourceURL.path) {
            urls.append(sourceURL)
        }
        return Array(NSOrderedSet(array: urls.map(\.standardizedFileURL)).array as? [URL] ?? urls)
    }

    private func uniqueExportDirectory(for artifact: PaperBananaArtifact, in directory: URL) throws -> URL {
        let baseName = artifact.title.replacingOccurrences(of: "/", with: "-") + " PaperBanana Export"
        var candidate = directory.appendingPathComponent(baseName, isDirectory: true)
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName) \(index)", isDirectory: true)
            index += 1
        }
        return candidate
    }

    private func copyReplacingItem(from source: URL, to destination: URL) throws {
        let standardizedSource = source.standardizedFileURL
        let standardizedDestination = destination.standardizedFileURL
        guard standardizedSource != standardizedDestination else { return }
        if FileManager.default.fileExists(atPath: standardizedDestination.path) {
            try FileManager.default.removeItem(at: standardizedDestination)
        }
        try FileManager.default.copyItem(at: standardizedSource, to: standardizedDestination)
    }

    private func copyUniquely(from source: URL, toDirectory directory: URL) throws {
        let destination = uniqueFileURL(for: source.lastPathComponent, in: directory)
        try FileManager.default.copyItem(at: source, to: destination)
    }

    private func uniqueFileURL(for filename: String, in directory: URL) -> URL {
        let baseURL = directory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: baseURL.path) else { return baseURL }

        let stem = baseURL.deletingPathExtension().lastPathComponent
        let fileExtension = baseURL.pathExtension
        var index = 2
        var candidate: URL
        repeat {
            let name = fileExtension.isEmpty ? "\(stem) \(index)" : "\(stem) \(index).\(fileExtension)"
            candidate = directory.appendingPathComponent(name)
            index += 1
        } while FileManager.default.fileExists(atPath: candidate.path)
        return candidate
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = title.localizedCaseInsensitiveContains("failed") ? .warning : .informational
        alert.runModal()
    }
}
