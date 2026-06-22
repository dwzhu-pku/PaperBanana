import Foundation

enum NativeRefinementDurableRunWriter {
    static func prepare(
        request: NativeRefinementRequest,
        providerPlan: ImageProviderExecutionPlan,
        prompt: String,
        runID: String,
        repoRoot: URL,
        runDirectoryURL: URL,
        outputURL: URL,
        metadataURL: URL,
        logURL: URL,
        promptURL: URL,
        requestURL: URL,
        providerRequestURL: URL,
        sourceCopyURL: URL
    ) throws {
        try FileManager.default.createDirectory(at: runDirectoryURL, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: sourceCopyURL.path) {
            try FileManager.default.removeItem(at: sourceCopyURL)
        }
        try FileManager.default.copyItem(at: request.sourceURL, to: sourceCopyURL)
        try prompt.write(to: promptURL, atomically: true, encoding: .utf8)

        var payload: [String: Any] = [
            "run_id": runID,
            "run_dir": runDirectoryURL.path,
            "source_path": request.sourceURL.path,
            "source_copy_path": sourceCopyURL.path,
            "prompt_path": promptURL.path,
            "log_path": logURL.path,
            "request_path": requestURL.path,
            "provider_request_path": providerRequestURL.path,
            "output_path": outputURL.path,
            "metadata_path": metadataURL.path,
            "prompt": prompt,
            "resolution": request.resolution,
            "aspect_ratio": request.aspectRatio,
            "workflow": "native_refine",
            "status": "queued",
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        for (key, value) in providerPlan.durableRequestFields {
            payload[key] = value
        }
        let requestData = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try requestData.write(to: requestURL, options: .atomic)

        let record = PaperBananaRunStore.makeRecord(
            runID: runID,
            workflow: "native_refine",
            providerPlan: providerPlan,
            settings: request.settings,
            resolution: request.resolution,
            aspectRatio: request.aspectRatio,
            runDirectoryURL: runDirectoryURL,
            promptURL: promptURL,
            requestURL: requestURL,
            providerRequestURL: providerRequestURL,
            outputURL: outputURL,
            metadataURL: metadataURL,
            eventLogURL: logURL,
            message: "Queued native refinement."
        )
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)
    }
}

enum NativeRefinementMetadataWriter {
    static func write(
        metadataURL: URL,
        outputURL: URL,
        prompt: String,
        response: ProviderResponse,
        request: NativeRefinementRequest,
        runID: String,
        runDirectoryURL: URL?,
        sourceCopyURL: URL?,
        promptURL: URL?,
        logURL: URL?,
        providerRequestURL: URL?
    ) throws {
        var metadata: [String: Any] = [
            "output_path": outputURL.path,
            "run_id": runID,
            "run_dir": runDirectoryURL?.path ?? "",
            "source_path": request.sourceURL.path,
            "source_copy_path": sourceCopyURL?.path ?? "",
            "prompt_path": promptURL?.path ?? "",
            "log_path": logURL?.path ?? "",
            "provider_request_path": providerRequestURL?.path ?? "",
            "prompt": prompt,
            "model": response.model,
            "provider": response.provider.rawValue,
            "provider_call_id": response.callID,
            "resolution": request.resolution,
            "aspect_ratio": request.aspectRatio,
            "provider_message": response.text,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "workflow": "native_refine"
        ]
        if let values = try? outputURL.resourceValues(forKeys: [.fileSizeKey]) {
            metadata["output_bytes"] = values.fileSize ?? 0
        }
        if response.usageMetadata.isEmpty == false {
            metadata["usage_metadata"] = response.usageMetadata
        }
        let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: metadataURL, options: .atomic)
    }
}

extension NativeRefinementStore {
    static func makeRunID(sourceURL: URL, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: date)
        let safeStem = safeFileStem(sourceURL.deletingPathExtension().lastPathComponent)
        return "native_refine_\(safeStem)_\(timestamp)"
    }

    static func safeFileStem(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let safeStem = String(value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return safeStem.isEmpty ? "artifact" : safeStem
    }

    static func safeSourceFilename(_ sourceURL: URL) -> String {
        let stem = safeFileStem(sourceURL.deletingPathExtension().lastPathComponent)
        let ext = sourceURL.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        return ext.isEmpty ? stem : "\(stem).\(ext)"
    }

    static func formatDuration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        let minutes = seconds / 60
        let remainder = seconds % 60
        if minutes == 0 {
            return "\(remainder)s"
        }
        return "\(minutes)m \(remainder)s"
    }
}
