import Foundation

@MainActor
enum NativeProviderCallRecorder {
    static func start(
        repoRoot: URL,
        runID: String,
        workflow: ProviderWorkflow,
        providerPlan: ImageProviderExecutionPlan,
        setProviderCallID: (String) -> Void,
        appendEvent: (String, Int, String) -> Void
    ) throws -> String {
        let callID = "\(callIDPrefix(for: providerPlan.provider))-\(UUID().uuidString)"
        try PaperBananaRunStore.writeProviderCallStartedSynchronously(
            runID: runID,
            callID: callID,
            provider: auditProviderName(providerPlan.provider),
            model: providerPlan.backendModelValue,
            modality: "image",
            context: workflow.rawValue,
            repoRoot: repoRoot
        )
        setProviderCallID(callID)
        appendEvent(
            "model_call",
            45,
            startMessage(for: providerPlan)
        )
        ProviderAuditWriter.startCall(
            repoRoot: repoRoot,
            runID: runID,
            callID: callID,
            provider: auditProviderName(providerPlan.provider),
            model: providerPlan.backendModelValue,
            modality: "image",
            context: workflow.rawValue
        )
        return callID
    }

    static func fail(
        error: Error,
        repoRoot: URL,
        runID: String,
        callID: String,
        workflow: ProviderWorkflow,
        providerPlan: ImageProviderExecutionPlan,
        responseCount: Int = 0,
        artifacts: [URL] = []
    ) throws {
        if responseCount > 0 || artifacts.isEmpty == false {
            try PaperBananaRunStore.writeProviderCallFinishedSynchronously(
                runID: runID,
                callID: callID,
                provider: auditProviderName(providerPlan.provider),
                model: providerPlan.backendModelValue,
                modality: "image",
                context: workflow.rawValue,
                success: false,
                responseCount: responseCount,
                message: error.localizedDescription,
                artifacts: artifacts,
                repoRoot: repoRoot
            )
            ProviderAuditWriter.finishCall(
                repoRoot: repoRoot,
                runID: runID,
                callID: callID,
                provider: auditProviderName(providerPlan.provider),
                model: providerPlan.backendModelValue,
                modality: "image",
                context: workflow.rawValue,
                success: false,
                responseCount: responseCount,
                message: error.localizedDescription,
                artifacts: artifacts
            )
        } else {
            try PaperBananaRunStore.writeProviderCallFailedSynchronously(
                runID: runID,
                callID: callID,
                provider: auditProviderName(providerPlan.provider),
                model: providerPlan.backendModelValue,
                modality: "image",
                context: workflow.rawValue,
                error: error.localizedDescription,
                repoRoot: repoRoot
            )
            ProviderAuditWriter.failCall(
                repoRoot: repoRoot,
                runID: runID,
                callID: callID,
                provider: auditProviderName(providerPlan.provider),
                model: providerPlan.backendModelValue,
                modality: "image",
                context: workflow.rawValue,
                error: error.localizedDescription
            )
        }
    }

    static func terminal(
        status: ProviderRunStatus,
        message: String,
        repoRoot: URL,
        runID: String,
        callID: String,
        workflow: ProviderWorkflow,
        providerPlan: ImageProviderExecutionPlan
    ) throws {
        guard !callID.isEmpty else { return }
        try PaperBananaRunStore.writeProviderCallTerminalSynchronously(
            runID: runID,
            callID: callID,
            provider: auditProviderName(providerPlan.provider),
            model: providerPlan.backendModelValue,
            modality: "image",
            context: workflow.rawValue,
            status: status,
            message: message,
            repoRoot: repoRoot
        )
        ProviderAuditWriter.failCall(
            repoRoot: repoRoot,
            runID: runID,
            callID: callID,
            provider: auditProviderName(providerPlan.provider),
            model: providerPlan.backendModelValue,
            modality: "image",
            context: workflow.rawValue,
            error: message
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

    private static func callIDPrefix(for provider: ImageProviderKind) -> String {
        switch provider {
        case .googleGemini:
            "swift-gemini"
        case .codexFallback:
            "swift-codex"
        case .openRouter:
            "swift-openrouter"
        case .foundationModels:
            "swift-foundation"
        }
    }

    private static func startMessage(for providerPlan: ImageProviderExecutionPlan) -> String {
        switch providerPlan.provider {
        case .codexFallback:
            "Handing image request to Codex fallback."
        default:
            "Calling image model \(providerPlan.backendModelValue)."
        }
    }
}
