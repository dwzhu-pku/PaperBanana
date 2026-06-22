import Foundation

enum ProviderAuditWriter {
    static func startCall(
        repoRoot: URL,
        runID: String,
        callID: String,
        provider: String,
        model: String,
        modality: String,
        context: String,
        attempt: Int = 1,
        maxAttempts: Int = 1
    ) {
        appendEvent(
            repoRoot: repoRoot,
            [
                "timestamp": timestamp(),
                "run_id": runID,
                "event": "provider_call_started",
                "call_id": callID,
                "provider": provider,
                "model": model,
                "modality": modality,
                "context": context,
                "attempt": attempt,
                "max_attempts": maxAttempts
            ]
        )
    }

    static func finishCall(
        repoRoot: URL,
        runID: String,
        callID: String,
        provider: String,
        model: String,
        modality: String,
        context: String,
        success: Bool,
        responseCount: Int,
        message: String,
        artifacts: [URL],
        attempt: Int = 1
    ) {
        appendEvent(
            repoRoot: repoRoot,
            [
                "timestamp": timestamp(),
                "run_id": runID,
                "event": "provider_call_finished",
                "call_id": callID,
                "provider": provider,
                "model": model,
                "modality": modality,
                "context": context,
                "attempt": attempt,
                "success": success,
                "response_count": responseCount,
                "message": message,
                "artifacts": artifacts.map { $0.standardizedFileURL.path }
            ]
        )
    }

    static func failCall(
        repoRoot: URL,
        runID: String,
        callID: String,
        provider: String,
        model: String,
        modality: String,
        context: String,
        error: String,
        attempt: Int = 1
    ) {
        appendEvent(
            repoRoot: repoRoot,
            [
                "timestamp": timestamp(),
                "run_id": runID,
                "event": "provider_call_failed",
                "call_id": callID,
                "provider": provider,
                "model": model,
                "modality": modality,
                "context": context,
                "attempt": attempt,
                "error": error
            ]
        )
    }

    static func imageSaved(
        repoRoot: URL,
        runID: String,
        callID: String,
        provider: String,
        model: String,
        path: URL,
        raw: Bool,
        context: String = "native_generate"
    ) {
        appendEvent(
            repoRoot: repoRoot,
            [
                "timestamp": timestamp(),
                "run_id": runID,
                "event": raw ? "provider_image_raw_saved" : "provider_image_saved",
                "call_id": callID,
                "provider": provider,
                "model": model,
                "modality": "image",
                "context": context,
                "path": path.standardizedFileURL.path
            ]
        )
    }

    static func auditImageURL(repoRoot: URL, callID: String, suffix: String = "png") -> URL {
        let safeCallID = sanitize(callID)
        return repoRoot
            .appendingPathComponent("results/provider_audit/images", isDirectory: true)
            .appendingPathComponent("\(safeCallID)_\(fileTimestamp())")
            .appendingPathExtension(suffix)
    }

    private static func appendEvent(repoRoot: URL, _ event: [String: Any]) {
        let url = auditLogURL(repoRoot: repoRoot)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: event, options: [.sortedKeys])
            guard let line = String(data: data, encoding: .utf8) else { return }
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                try handle.seekToEnd()
                try handle.write(contentsOf: Data((line + "\n").utf8))
                try handle.close()
            } else {
                try (line + "\n").write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            return
        }
    }

    private static func auditLogURL(repoRoot: URL) -> URL {
        repoRoot
            .appendingPathComponent("results/provider_audit", isDirectory: true)
            .appendingPathComponent("provider_calls_\(logDate()).jsonl")
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func logDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
    }

    private static func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    private static func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let safe = String(value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return safe.isEmpty ? "provider_call" : safe
    }
}
