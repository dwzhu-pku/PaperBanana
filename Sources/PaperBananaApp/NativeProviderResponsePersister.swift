import Foundation

struct NativeProviderPersistedArtifacts {
    let auditArtifactURL: URL
    let rawResponseURL: URL
    let rawPayloadURL: URL
    let outputURL: URL
}

@MainActor
enum NativeProviderResponsePersister {
    static func persistFailureRawResponseIfAvailable(
        error: Error,
        rawResponseURL: URL?,
        didSaveRawResponse: (URL) -> Void,
        appendEvent: (String, Int, String) -> Void
    ) throws -> URL? {
        guard let rawResponseData = (error as? ProviderRuntimeError)?.rawProviderResponseData,
              let rawResponseURL else {
            return nil
        }

        try FileManager.default.createDirectory(at: rawResponseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try rawResponseData.write(to: rawResponseURL, options: .atomic)
        didSaveRawResponse(rawResponseURL)
        appendEvent(
            "provider_response_saved",
            78,
            "Saved raw provider error response bytes."
        )
        return rawResponseURL
    }

    static func persist(
        response: ProviderResponse,
        repoRoot: URL,
        runID: String,
        workflow: ProviderWorkflow,
        outputURL: URL,
        rawResponseURL: URL,
        rawPayloadURL: URL,
        savingMessage: String,
        didSaveRawResponse: (URL) -> Void,
        didSaveRawPayload: (URL) -> Void,
        appendEvent: (String, Int, String) -> Void
    ) throws -> NativeProviderPersistedArtifacts {
        try ensureLedgerCanSurfaceProviderResponse(
            response: response,
            repoRoot: repoRoot,
            runID: runID,
            workflow: workflow,
            outputURL: outputURL,
            rawResponseURL: rawResponseURL,
            rawPayloadURL: rawPayloadURL
        )

        try response.rawResponseData.write(to: rawResponseURL, options: .atomic)
        didSaveRawResponse(rawResponseURL)
        appendEvent(
            "provider_response_saved",
            78,
            "Saved raw provider response bytes before decoding."
        )

        guard let imageData = response.imageData else {
            throw ProviderRuntimeError.providerReturnedNoImage
        }

        try imageData.write(to: rawPayloadURL, options: .atomic)
        didSaveRawPayload(rawPayloadURL)
        appendEvent("saving", 82, savingMessage)

        let auditArtifactURL = ProviderAuditWriter.auditImageURL(
            repoRoot: repoRoot,
            callID: response.callID,
            suffix: "png"
        )
        try ProviderImagePersistence.writePNG(imageData: imageData, to: outputURL)
        if (try? FileManager.default.createDirectory(at: auditArtifactURL.deletingLastPathComponent(), withIntermediateDirectories: true)) != nil,
           (try? imageData.write(to: auditArtifactURL, options: .atomic)) != nil {
            ProviderAuditWriter.imageSaved(
                repoRoot: repoRoot,
                runID: runID,
                callID: response.callID,
                provider: auditProviderName(response.provider),
                model: response.model,
                path: auditArtifactURL,
                raw: false,
                context: workflow.rawValue
            )
            try PaperBananaRunStore.writeProviderImageSavedSynchronously(
                runID: runID,
                callID: response.callID,
                provider: auditProviderName(response.provider),
                model: response.model,
                path: auditArtifactURL,
                raw: false,
                context: workflow.rawValue,
                repoRoot: repoRoot
            )
        }

        return NativeProviderPersistedArtifacts(
            auditArtifactURL: auditArtifactURL,
            rawResponseURL: rawResponseURL,
            rawPayloadURL: rawPayloadURL,
            outputURL: outputURL
        )
    }

    static func finishSuccess(
        response: ProviderResponse,
        repoRoot: URL,
        runID: String,
        workflow: ProviderWorkflow,
        message: String,
        artifacts: NativeProviderPersistedArtifacts
    ) throws {
        ProviderAuditWriter.finishCall(
            repoRoot: repoRoot,
            runID: runID,
            callID: response.callID,
            provider: auditProviderName(response.provider),
            model: response.model,
            modality: "image",
            context: workflow.rawValue,
            success: true,
            responseCount: 1,
            message: message,
            artifacts: [
                artifacts.auditArtifactURL,
                artifacts.outputURL,
                artifacts.rawResponseURL
            ].filter {
                FileManager.default.fileExists(atPath: $0.path)
            }
        )
        try PaperBananaRunStore.writeProviderCallFinishedSynchronously(
            runID: runID,
            callID: response.callID,
            provider: auditProviderName(response.provider),
            model: response.model,
            modality: "image",
            context: workflow.rawValue,
            success: true,
            responseCount: 1,
            message: message,
            artifacts: [
                artifacts.auditArtifactURL,
                artifacts.outputURL,
                artifacts.rawResponseURL
            ].filter {
                FileManager.default.fileExists(atPath: $0.path)
            },
            usageMetadata: response.usageMetadata,
            repoRoot: repoRoot
        )
    }

    static func finishFailure(
        response: ProviderResponse,
        repoRoot: URL,
        runID: String,
        workflow: ProviderWorkflow,
        rawResponseURL: URL,
        rawPayloadURL: URL,
        failureMessagePrefix: String,
        error: Error
    ) throws {
        var recoveryArtifacts = [rawResponseURL]
        if FileManager.default.fileExists(atPath: rawPayloadURL.path) {
            recoveryArtifacts.append(rawPayloadURL)
            ProviderAuditWriter.imageSaved(
                repoRoot: repoRoot,
                runID: runID,
                callID: response.callID,
                provider: auditProviderName(response.provider),
                model: response.model,
                path: rawPayloadURL,
                raw: true,
                context: workflow.rawValue
            )
            try PaperBananaRunStore.writeProviderImageSavedSynchronously(
                runID: runID,
                callID: response.callID,
                provider: auditProviderName(response.provider),
                model: response.model,
                path: rawPayloadURL,
                raw: true,
                context: workflow.rawValue,
                repoRoot: repoRoot
            )
        }

        ProviderAuditWriter.finishCall(
            repoRoot: repoRoot,
            runID: runID,
            callID: response.callID,
            provider: auditProviderName(response.provider),
            model: response.model,
            modality: "image",
            context: workflow.rawValue,
            success: false,
            responseCount: 1,
            message: "\(failureMessagePrefix): \(error.localizedDescription)",
            artifacts: recoveryArtifacts
        )
        try PaperBananaRunStore.writeProviderCallFinishedSynchronously(
            runID: runID,
            callID: response.callID,
            provider: auditProviderName(response.provider),
            model: response.model,
            modality: "image",
            context: workflow.rawValue,
            success: false,
            responseCount: 1,
            message: "\(failureMessagePrefix): \(error.localizedDescription)",
            artifacts: recoveryArtifacts,
            usageMetadata: response.usageMetadata,
            repoRoot: repoRoot
        )
    }

    private static func auditProviderName(_ provider: ImageProviderKind) -> String {
        switch provider {
        case .googleGemini:
            "gemini"
        default:
            provider.rawValue
        }
    }

    private static func ensureLedgerCanSurfaceProviderResponse(
        response: ProviderResponse,
        repoRoot: URL,
        runID: String,
        workflow: ProviderWorkflow,
        outputURL: URL,
        rawResponseURL: URL,
        rawPayloadURL: URL
    ) throws {
        if try PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot) == nil {
            try bootstrapRecoveredRun(
                response: response,
                repoRoot: repoRoot,
                runID: runID,
                workflow: workflow,
                outputURL: outputURL,
                rawResponseURL: rawResponseURL,
                rawPayloadURL: rawPayloadURL
            )
        }

        if try PaperBananaRunStore.fetchProviderCallSynchronously(callID: response.callID, repoRoot: repoRoot) == nil {
            try PaperBananaRunStore.writeProviderCallStartedSynchronously(
                runID: runID,
                callID: response.callID,
                provider: auditProviderName(response.provider),
                model: response.model,
                modality: "image",
                context: workflow.rawValue,
                repoRoot: repoRoot
            )
        }
    }

    private static func bootstrapRecoveredRun(
        response: ProviderResponse,
        repoRoot: URL,
        runID: String,
        workflow: ProviderWorkflow,
        outputURL: URL,
        rawResponseURL: URL,
        rawPayloadURL: URL
    ) throws {
        let runDirectory = outputURL.deletingLastPathComponent()
        let metadataURL = outputURL.deletingPathExtension().appendingPathExtension("json")
        let rawPayloadPath = response.imageData == nil ? "" : rawPayloadURL.path
        let recoveryStatus = rawPayloadPath.isEmpty ? "provider_response" : "raw_payload"
        let now = PaperBananaRunStore.timestamp()
        let record = RunRecord(
            id: runID,
            workflow: workflow.rawValue,
            status: .queued,
            provider: auditProviderName(response.provider),
            providerKind: response.provider.rawValue,
            model: response.model,
            requestedModel: response.model,
            resolution: inferredResolution(from: outputURL),
            aspectRatio: "",
            projectPath: repoRoot.path,
            runDirectoryPath: runDirectory.path,
            promptPath: runDirectory.appendingPathComponent("prompt.txt").path,
            requestPath: runDirectory.appendingPathComponent("request.json").path,
            providerRequestPath: runDirectory.appendingPathComponent("provider_request.json").path,
            rawResponsePath: rawResponseURL.path,
            rawPayloadPath: rawPayloadPath,
            artifactPath: outputURL.path,
            metadataPath: metadataURL.path,
            eventLogPath: runDirectory.appendingPathComponent("events.jsonl").path,
            providerCallID: response.callID,
            spendClass: response.provider == .codexFallback ? "no_provider_spend" : "paid_provider",
            recoveryStatus: recoveryStatus,
            createdAt: now,
            updatedAt: now,
            elapsedSeconds: 0,
            message: "Recovered provider response without a preexisting durable run record."
        )
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)
        try PaperBananaRunStore.writeEventSynchronously(
            PaperBananaRunEvent(
                runID: runID,
                stage: "recovered",
                progress: 1,
                message: record.message,
                timestamp: record.updatedAt,
                rawResponsePath: rawResponseURL.path,
                rawPayloadPath: rawPayloadPath,
                artifactPath: outputURL.path,
                metadataPath: metadataURL.path,
                providerCallID: response.callID
            ),
            repoRoot: repoRoot
        )
    }

    private static func inferredResolution(from outputURL: URL) -> String {
        let stem = outputURL.deletingPathExtension().lastPathComponent
        if let match = stem.range(of: #"(?:^|_)([0-9]+K|[0-9]+p)(?:_|$)"#, options: .regularExpression) {
            return String(stem[match]).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        }
        return ""
    }
}
