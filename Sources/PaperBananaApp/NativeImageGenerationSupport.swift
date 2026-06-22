import Foundation

enum NativeImageGenerationDurableRunWriter {
    static func prepare(
        request: NativeImageGenerationRequest,
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
        providerRequestURL: URL
    ) throws {
        try FileManager.default.createDirectory(at: runDirectoryURL, withIntermediateDirectories: true)
        try prompt.write(to: promptURL, atomically: true, encoding: .utf8)

        var payload: [String: Any] = [
            "run_id": runID,
            "run_dir": runDirectoryURL.path,
            "prompt_path": promptURL.path,
            "log_path": logURL.path,
            "request_path": requestURL.path,
            "provider_request_path": providerRequestURL.path,
            "output_path": outputURL.path,
            "metadata_path": metadataURL.path,
            "prompt": prompt,
            "resolution": request.resolution,
            "aspect_ratio": request.aspectRatio,
            "task": request.task,
            "workflow": "native_generate",
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
            workflow: "native_generate",
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
            message: "Queued native generation."
        )
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)
    }
}

enum NativeImageGenerationMetadataWriter {
    static func write(
        metadataURL: URL,
        outputURL: URL,
        prompt: String,
        response: ProviderResponse,
        request: NativeImageGenerationRequest,
        runID: String,
        runDirectoryURL: URL?,
        promptURL: URL?,
        logURL: URL?,
        providerRequestURL: URL?
    ) throws {
        var metadata: [String: Any] = [
            "output_path": outputURL.path,
            "run_id": runID,
            "run_dir": runDirectoryURL?.path ?? "",
            "prompt_path": promptURL?.path ?? "",
            "log_path": logURL?.path ?? "",
            "provider_request_path": providerRequestURL?.path ?? "",
            "prompt": prompt,
            "model": response.model,
            "provider": response.provider.rawValue,
            "provider_call_id": response.callID,
            "resolution": request.resolution,
            "aspect_ratio": request.aspectRatio,
            "task": request.task,
            "provider_message": response.text,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "workflow": "native_generate"
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

extension NativeImageGenerationStore {
    static func makeRunID(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "native_generate_\(formatter.string(from: date))"
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
