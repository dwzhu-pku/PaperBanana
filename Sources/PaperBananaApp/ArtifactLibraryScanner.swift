import Foundation

enum ArtifactLibraryScanner {
    private static let supportedExtensions: [String: ArtifactKind] = [
        "png": .image,
        "jpg": .image,
        "jpeg": .image,
        "webp": .image,
        "heic": .image,
        "pdf": .document,
        "zip": .archive,
        "json": .data
    ]

    static func scan(repoRootPath: String, fileManager: FileManager = .default) -> [PaperBananaArtifact] {
        let repoRoot = URL(fileURLWithPath: repoRootPath, isDirectory: true).standardizedFileURL
        let resultsRoot = repoRoot.appendingPathComponent("results", isDirectory: true)
        return scanResults(at: resultsRoot, repoRoot: repoRoot, fileManager: fileManager)
    }

    static func scanResults(at resultsRoot: URL, repoRoot: URL, fileManager: FileManager = .default) -> [PaperBananaArtifact] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
        let nativeRunIndex = NativeRunFolderIndex.scan(resultsRoot: resultsRoot, fileManager: fileManager)
        guard let enumerator = fileManager.enumerator(
            at: resultsRoot,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        return enumerator.compactMap { element -> PaperBananaArtifact? in
            guard let url = element as? URL else { return nil }
            let fileExtension = url.pathExtension.lowercased()
            guard let kind = supportedExtensions[fileExtension] else { return nil }
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { return nil }

            let relativePath = relativePath(from: resultsRoot, to: url)
            let workflow = relativePath.split(separator: "/").first.map(String.init) ?? "results"
            let modifiedAt = values.contentModificationDate ?? .distantPast
            let byteCount = Int64(values.fileSize ?? 0)
            let companions = companionFiles(for: url, resultsRoot: resultsRoot, repoRoot: repoRoot, workflow: workflow, fileManager: fileManager)
            let nativeRun = nativeRunIndex.record(containing: url, metadataURL: companions.metadata)

            return PaperBananaArtifact(
                id: url.standardizedFileURL.path,
                url: url.standardizedFileURL,
                kind: kind,
                title: url.deletingPathExtension().lastPathComponent,
                workflow: workflow,
                relativePath: relativePath,
                modifiedAt: modifiedAt,
                byteCount: byteCount,
                promptURL: companions.prompt,
                logURL: companions.log,
                metadataURL: companions.metadata,
                runID: nativeRun?.runID ?? "",
                runDirectoryURL: nativeRun?.directoryURL,
                runStatus: nativeRun?.status,
                referenceProvenance: nativeRun?.referenceProvenance ?? .empty
            )
        }
        .sorted { lhs, rhs in
            if lhs.modifiedAt == rhs.modifiedAt {
                return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
            }
            return lhs.modifiedAt > rhs.modifiedAt
        }
    }

    private static func companionFiles(
        for url: URL,
        resultsRoot: URL,
        repoRoot: URL,
        workflow: String,
        fileManager: FileManager
    ) -> (prompt: URL?, log: URL?, metadata: URL?) {
        let stem = url.deletingPathExtension().lastPathComponent
        let localDirectory = url.deletingLastPathComponent()
        let handoffDirectory = repoRoot.appendingPathComponent(".paperbanana_codex_handoff", isDirectory: true)
        let workflowDirectory = resultsRoot.appendingPathComponent(workflow, isDirectory: true)

        let promptCandidates = [
            localDirectory.appendingPathComponent("prompt.txt"),
            localDirectory.appendingPathComponent("\(stem).prompt.md"),
            handoffDirectory.appendingPathComponent("\(stem).prompt.md")
        ]
        let logCandidates = [
            localDirectory.appendingPathComponent("events.jsonl"),
            localDirectory.appendingPathComponent("\(stem).codex.log"),
            localDirectory.appendingPathComponent("\(stem).log"),
            handoffDirectory.appendingPathComponent("\(stem).codex.log")
        ]
        var metadataCandidates = [
            localDirectory.appendingPathComponent("\(stem).json"),
            handoffDirectory.appendingPathComponent("\(stem).message.txt")
        ]
        if let workflowMetadata = firstFile(in: workflowDirectory, extension: "json", fileManager: fileManager) {
            metadataCandidates.append(workflowMetadata)
        }

        return (
            firstExisting(promptCandidates, fileManager: fileManager),
            firstExisting(logCandidates, fileManager: fileManager),
            firstExisting(metadataCandidates, fileManager: fileManager)
        )
    }

    private static func firstExisting(_ urls: [URL], fileManager: FileManager) -> URL? {
        urls.first { fileManager.fileExists(atPath: $0.path) }
    }

    private static func firstFile(in directory: URL, extension fileExtension: String, fileManager: FileManager) -> URL? {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return contents
            .filter { $0.pathExtension.lowercased() == fileExtension }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate > rhsDate
            }
            .first
    }

    private static func relativePath(from root: URL, to url: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else { return url.lastPathComponent }
        return String(filePath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
