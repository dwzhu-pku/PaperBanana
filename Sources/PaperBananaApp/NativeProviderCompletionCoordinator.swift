import Foundation

struct NativeProviderCompletionResult {
    let statusMessage: String
    let artifacts: NativeProviderPersistedArtifacts
}

@MainActor
enum NativeProviderCompletionCoordinator {
    static func completeImageResponse(
        response: ProviderResponse,
        repoRoot: URL,
        runID: String,
        workflow: ProviderWorkflow,
        outputURL: URL,
        rawResponseURL: URL,
        rawPayloadURL: URL,
        savingMessage: String,
        successFallbackMessage: String,
        failureMessagePrefix: String,
        didSaveRawResponse: (URL) -> Void,
        didSaveRawPayload: (URL) -> Void,
        appendEvent: (String, Int, String) -> Void,
        writeMetadata: () throws -> Void
    ) throws -> NativeProviderCompletionResult {
        do {
            let artifacts = try NativeProviderResponsePersister.persist(
                response: response,
                repoRoot: repoRoot,
                runID: runID,
                workflow: workflow,
                outputURL: outputURL,
                rawResponseURL: rawResponseURL,
                rawPayloadURL: rawPayloadURL,
                savingMessage: savingMessage,
                didSaveRawResponse: didSaveRawResponse,
                didSaveRawPayload: didSaveRawPayload,
                appendEvent: appendEvent
            )

            try writeMetadata()
            let statusMessage = response.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? successFallbackMessage
                : response.text
            try NativeProviderResponsePersister.finishSuccess(
                response: response,
                repoRoot: repoRoot,
                runID: runID,
                workflow: workflow,
                message: statusMessage,
                artifacts: artifacts
            )
            appendEvent("complete", 100, statusMessage)
            return NativeProviderCompletionResult(
                statusMessage: statusMessage,
                artifacts: artifacts
            )
        } catch {
            do {
                try NativeProviderResponsePersister.finishFailure(
                    response: response,
                    repoRoot: repoRoot,
                    runID: runID,
                    workflow: workflow,
                    rawResponseURL: rawResponseURL,
                    rawPayloadURL: rawPayloadURL,
                    failureMessagePrefix: failureMessagePrefix,
                    error: error
                )
            } catch {
                throw error
            }
            throw error
        }
    }
}
