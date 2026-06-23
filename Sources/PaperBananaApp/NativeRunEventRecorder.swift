import Foundation

struct NativeRunEventContext {
    let repoRootURL: URL?
    let runID: String
    let runDirectoryURL: URL?
    let outputURL: URL?
    let metadataURL: URL?
    let promptURL: URL?
    let requestURL: URL?
    let sourceCopyURL: URL?
    let providerCallID: String
    let rawResponseURL: URL?
    let rawPayloadURL: URL?
    let logURL: URL?
}

enum NativeRunEventRecorder {
    static func appendLocalEvent(
        stage: String,
        progress: Int,
        message: String,
        context: NativeRunEventContext
    ) {
        guard let logURL = context.logURL else { return }
        let payload: [String: Any] = [
            "stage": stage,
            "progress": progress,
            "message": message,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "run_id": context.runID,
            "run_dir": context.runDirectoryURL?.path ?? "",
            "output_path": context.outputURL?.path ?? "",
            "metadata_path": context.metadataURL?.path ?? "",
            "prompt_path": context.promptURL?.path ?? "",
            "request_path": context.requestURL?.path ?? "",
            "source_copy_path": context.sourceCopyURL?.path ?? "",
            "call_id": context.providerCallID,
            "raw_response_path": context.rawResponseURL?.path ?? "",
            "raw_path": context.rawPayloadURL?.path ?? "",
            "log_path": logURL.path
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: data, encoding: .utf8) else { return }
        try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: logURL.path),
           let handle = try? FileHandle(forWritingTo: logURL) {
            do {
                try handle.seekToEnd()
            } catch {
                return
            }
            try? handle.write(contentsOf: Data((line + "\n").utf8))
            try? handle.close()
        } else {
            try? (line + "\n").write(to: logURL, atomically: true, encoding: .utf8)
        }
        persistLocalEvent(
            stage: stage,
            progress: progress,
            message: message,
            rawResponsePath: context.rawResponseURL?.path ?? "",
            rawPayloadPath: context.rawPayloadURL?.path ?? "",
            artifactPath: context.outputURL?.path ?? "",
            metadataPath: context.metadataURL?.path ?? "",
            providerCallID: context.providerCallID,
            context: context
        )
    }

    static func persistProviderEvent(_ event: NativeRefinementEvent, context: NativeRunEventContext) {
        persistLocalEvent(
            stage: event.stage,
            progress: event.progress,
            message: event.message,
            rawResponsePath: event.rawResponseURL?.path ?? "",
            rawPayloadPath: event.rawPayloadURL?.path ?? "",
            artifactPath: event.outputURL?.path ?? "",
            metadataPath: event.metadataURL?.path ?? "",
            providerCallID: event.callID,
            context: context
        )
    }

    private static func persistLocalEvent(
        stage: String,
        progress: Int,
        message: String,
        rawResponsePath: String,
        rawPayloadPath: String,
        artifactPath: String,
        metadataPath: String,
        providerCallID: String,
        context: NativeRunEventContext
    ) {
        guard let repoRoot = context.repoRootURL, !context.runID.isEmpty else { return }
        let event = PaperBananaRunStore.event(
            runID: context.runID,
            stage: stage,
            progress: progress,
            message: message,
            rawResponsePath: rawResponsePath,
            rawPayloadPath: rawPayloadPath,
            artifactPath: artifactPath,
            metadataPath: metadataPath,
            providerCallID: providerCallID
        )
        try? PaperBananaRunStore.writeEventSynchronously(event, repoRoot: repoRoot)
    }
}
