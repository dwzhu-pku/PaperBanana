import Foundation

struct ProviderRecoveryResult: Equatable {
    let artifactURL: URL
    let metadataURL: URL
}

enum ProviderRecoverySurfacer {
    static func surfaceFirstRecoverableArtifact(
        for call: ProviderRunLedgerCall,
        repoRootPath: String,
        fileManager: FileManager = .default
    ) throws -> ProviderRecoveryResult {
        guard let sourceURL = call.recoveryCandidateURLs.first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let repoRoot = URL(fileURLWithPath: repoRootPath, isDirectory: true).standardizedFileURL
        let recoveredDirectory = repoRoot
            .appendingPathComponent("results", isDirectory: true)
            .appendingPathComponent("recovered", isDirectory: true)
        try fileManager.createDirectory(at: recoveredDirectory, withIntermediateDirectories: true)

        let ext = sourceURL.pathExtension.nilIfBlank ?? "bin"
        let stem = sanitizeFilename(call.runID.nilIfBlank ?? call.callID)
        let timestamp = Self.timestamp()
        let artifactURL = recoveredDirectory
            .appendingPathComponent("PaperBanana_Recovered_\(stem)_\(timestamp)")
            .appendingPathExtension(ext)
        let metadataURL = artifactURL.deletingPathExtension().appendingPathExtension("json")

        if fileManager.fileExists(atPath: artifactURL.path) {
            try fileManager.removeItem(at: artifactURL)
        }
        try fileManager.copyItem(at: sourceURL, to: artifactURL)

        let metadata: [String: Any] = [
            "workflow": "recovered",
            "provider_call_id": call.callID,
            "run_id": call.runID,
            "provider": call.provider,
            "model": call.model,
            "status": call.status.rawValue,
            "source_path": sourceURL.path,
            "output_path": artifactURL.path,
            "metadata_path": metadataURL.path,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: metadataURL, options: .atomic)
        return ProviderRecoveryResult(artifactURL: artifactURL, metadataURL: metadataURL)
    }

    private static func sanitizeFilename(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let sanitized = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return sanitized.isEmpty ? "provider_call" : sanitized
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
