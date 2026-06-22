import Foundation

@MainActor
final class NativeImageGenerationStore: ObservableObject {
    enum RunState: Equatable {
        case idle
        case running
        case complete(URL)
        case recovered(URL, String)
        case failed(String)
        case cancelled(String)
        case timedOut(String)
    }

    @Published private(set) var runState: RunState = .idle
    @Published private(set) var progress: Int = 0
    @Published private(set) var statusMessage: String = "Waiting."
    @Published private(set) var milestones: [NativeRefinementMilestone] = NativeRefinementMilestone.timeline(currentStage: "queued")
    @Published private(set) var outputURL: URL?
    @Published private(set) var metadataURL: URL?
    @Published private(set) var logURL: URL?
    @Published private(set) var promptURL: URL?
    @Published private(set) var requestURL: URL?
    @Published private(set) var providerRequestURL: URL?
    @Published private(set) var providerCallID: String = ""
    @Published private(set) var rawResponseURL: URL?
    @Published private(set) var rawPayloadURL: URL?
    @Published private(set) var runDirectoryURL: URL?
    @Published private(set) var runID: String = ""
    @Published private(set) var startedAt: Date?
    @Published private(set) var lastEventAt: Date?
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var secondsSinceLastEvent: TimeInterval = 0
    @Published private(set) var isStalled = false

    private var providerTask: Task<Void, Never>?
    private var sawTerminalEvent = false
    private var progressTimer: Timer?
    private var activeRepoRootURL: URL?
    private var activeProviderPlan: ImageProviderExecutionPlan?
    private let stallWarningInterval: TimeInterval
    private let hardTimeoutInterval: TimeInterval
    private let providerClientFactory: ProviderClientFactory

    init(
        stallWarningInterval: TimeInterval = 120,
        hardTimeoutInterval: TimeInterval = 900,
        googleProviderClient: any ProviderClient = GoogleGeminiProviderClient(),
        providerClientFactory: ProviderClientFactory? = nil
    ) {
        self.stallWarningInterval = stallWarningInterval
        self.hardTimeoutInterval = hardTimeoutInterval
        self.providerClientFactory = providerClientFactory ?? ProviderClientFactory(googleClient: googleProviderClient)
    }

    var isRunning: Bool {
        if case .running = runState { return true }
        return false
    }

    func start(request: NativeImageGenerationRequest, onCompletion: @escaping @Sendable (URL) -> Void) {
        guard !isRunning else { return }
        let trimmedPrompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            fail("Generation prompt is required.")
            return
        }

        let repoRoot = URL(fileURLWithPath: request.settings.repoPath, isDirectory: true)
        let outputDirectory = repoRoot.appendingPathComponent("results/native_generate", isDirectory: true)
        let runID = request.preflightRunID ?? Self.makeRunID(date: Date())
        let runDirectory = outputDirectory.appendingPathComponent(runID, isDirectory: true)
        let providerPlan = ImageProviderExecutionPlan(requestedModel: request.model, settings: request.settings)
        let predictedOutputURL = runDirectory
            .appendingPathComponent("generated_\(request.resolution)")
            .appendingPathExtension("png")

        sawTerminalEvent = false
        resetForRun(
            repoRoot: repoRoot,
            runID: runID,
            runDirectory: runDirectory,
            predictedOutputURL: predictedOutputURL,
            providerPlan: providerPlan
        )

        do {
            try prepareDurableRunRecord(request: request, providerPlan: providerPlan, prompt: trimmedPrompt)
        } catch {
            fail("Could not create durable generation run record: \(error.localizedDescription)")
            return
        }

        if let localProviderClient = localProviderClient(for: request.executionMode, providerPlan: providerPlan) {
            startNativeProviderExecution(
                request: request,
                providerPlan: providerPlan,
                prompt: trimmedPrompt,
                providerClientOverride: localProviderClient,
                onCompletion: onCompletion
            )
            return
        }

        if shouldUseNativeProvider(providerPlan: providerPlan, request: request) {
            startNativeProviderExecution(
                request: request,
                providerPlan: providerPlan,
                prompt: trimmedPrompt,
                onCompletion: onCompletion
            )
            return
        }

        failUnsupportedNativeProvider(providerPlan)
    }

    func cancel() {
        let message = "Generation cancelled by user."
        if let ledgerError = markActiveProviderCallTerminal(status: .cancelled, message: message) {
            let failureMessage = "Generation cancelled locally, but PaperBanana could not record the provider call as cancelled: \(ledgerError.localizedDescription)"
            appendLocalEvent(stage: "failed", progress: progress, message: failureMessage)
            sawTerminalEvent = true
            providerTask?.cancel()
            providerTask = nil
            fail(failureMessage)
            return
        }
        appendLocalEvent(stage: "cancelled", progress: progress, message: message)
        sawTerminalEvent = true
        providerTask?.cancel()
        providerTask = nil
        finishCancelled(message)
    }

    private func resetForRun(
        repoRoot: URL,
        runID: String,
        runDirectory: URL,
        predictedOutputURL: URL,
        providerPlan: ImageProviderExecutionPlan
    ) {
        runState = .running
        progress = 0
        statusMessage = "Queued native generation."
        activeRepoRootURL = repoRoot
        activeProviderPlan = providerPlan
        self.runID = runID
        runDirectoryURL = runDirectory
        outputURL = predictedOutputURL
        metadataURL = predictedOutputURL.deletingPathExtension().appendingPathExtension("json")
        logURL = runDirectory.appendingPathComponent("events.jsonl")
        promptURL = runDirectory.appendingPathComponent("prompt.txt")
        requestURL = runDirectory.appendingPathComponent("request.json")
        providerRequestURL = runDirectory.appendingPathComponent("provider_request.json")
        providerCallID = ""
        rawResponseURL = nil
        rawPayloadURL = nil
        let now = Date()
        startedAt = now
        lastEventAt = now
        elapsedSeconds = 0
        secondsSinceLastEvent = 0
        isStalled = false
        milestones = NativeRefinementMilestone.timeline(currentStage: "queued")
        startProgressTimer()
    }

    private func shouldUseNativeProvider(
        providerPlan: ImageProviderExecutionPlan,
        request: NativeImageGenerationRequest
    ) -> Bool {
        request.executionMode == .live && (
            providerPlan.provider == .googleGemini
                || providerPlan.provider == .openRouter
                || providerPlan.provider == .codexFallback
        )
    }

    private func localProviderClient(
        for executionMode: NativeImageGenerationExecutionMode,
        providerPlan: ImageProviderExecutionPlan
    ) -> (any ProviderClient)? {
        switch executionMode {
        case .live:
            nil
        case .dryRun:
            NativeLocalProviderClient(providerKind: providerPlan.provider, mode: .dryRun)
        }
    }

    private func startNativeProviderExecution(
        request: NativeImageGenerationRequest,
        providerPlan: ImageProviderExecutionPlan,
        prompt: String,
        providerClientOverride: (any ProviderClient)? = nil,
        onCompletion: @escaping @Sendable (URL) -> Void
    ) {
        guard let repoRoot = activeRepoRootURL else {
            fail("No active repository root is available for native provider execution.")
            return
        }

        let callID: String
        do {
            callID = try NativeProviderCallRecorder.start(
                repoRoot: repoRoot,
                runID: runID,
                workflow: .generation,
                providerPlan: providerPlan,
                setProviderCallID: { self.providerCallID = $0 },
                appendEvent: { stage, progress, message in
                    self.appendLocalEvent(stage: stage, progress: progress, message: message)
                }
            )
        } catch {
            fail("Could not create durable provider call record: \(error.localizedDescription)")
            return
        }

        let client = providerClientOverride ?? providerClientFactory.client(for: providerPlan)
        let providerRequest = ProviderClientRequest(
            runID: runID,
            callID: callID,
            workflow: .generation,
            prompt: prompt,
            sourceImageURL: nil,
            model: providerPlan.effectiveModel,
            effectiveModel: providerPlan.backendModelValue,
            resolution: request.resolution,
            aspectRatio: request.aspectRatio,
            task: request.task,
            settings: request.settings,
            outputURL: outputURL,
            providerRequestURL: providerRequestURL
        )

        let progressRelay = NativeProviderProgressRelay(store: self) { store, event in
            store.applyNativeProviderProgressEvent(event)
        }
        providerTask = Task { [weak self, client, providerRequest, repoRoot, providerPlan, progressRelay] in
            do {
                let response = try await client.execute(providerRequest, eventHandler: progressRelay.handle)
                try Task.checkCancellation()
                await MainActor.run {
                    self?.completeNativeProviderResponse(
                        response,
                        repoRoot: repoRoot,
                        providerPlan: providerPlan,
                        prompt: prompt,
                        request: request,
                        onCompletion: onCompletion
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    self?.failNativeProviderResponse(
                        error,
                        repoRoot: repoRoot,
                        providerPlan: providerPlan
                    )
                }
            }
        }
    }

    fileprivate func applyNativeProviderProgressEvent(_ event: ProviderProgressEvent) {
        guard !sawTerminalEvent else { return }
        let now = Date()
        lastEventAt = now
        secondsSinceLastEvent = 0
        isStalled = false
        progress = max(progress, event.progress)
        statusMessage = event.message
        if !event.callID.isEmpty {
            providerCallID = event.callID
        }
        milestones = NativeRefinementMilestone.timeline(currentStage: event.stage)
        appendLocalEvent(stage: event.stage, progress: progress, message: event.message)
    }

    private func completeNativeProviderResponse(
        _ response: ProviderResponse,
        repoRoot: URL,
        providerPlan: ImageProviderExecutionPlan,
        prompt: String,
        request: NativeImageGenerationRequest,
        onCompletion: @escaping @Sendable (URL) -> Void
    ) {
        guard !sawTerminalEvent else { return }
        providerTask = nil
        providerCallID = response.callID

        guard let outputURL,
              let metadataURL,
              let rawResponseURL = nativeProviderResponseURL(),
              let rawPayloadURL = nativeProviderRawPayloadURL() else {
            fail("Native provider returned a response, but run output paths were unavailable.")
            return
        }

        do {
            let completion = try NativeProviderCompletionCoordinator.completeImageResponse(
                response: response,
                repoRoot: repoRoot,
                runID: runID,
                workflow: .generation,
                outputURL: outputURL,
                rawResponseURL: rawResponseURL,
                rawPayloadURL: rawPayloadURL,
                savingMessage: "Saving generated image.",
                successFallbackMessage: "Image generated successfully.",
                failureMessagePrefix: "Failed to save generated image",
                didSaveRawResponse: { self.rawResponseURL = $0 },
                didSaveRawPayload: { self.rawPayloadURL = $0 },
                appendEvent: { stage, progress, message in
                    self.appendLocalEvent(stage: stage, progress: progress, message: message)
                },
                writeMetadata: {
                    try NativeImageGenerationMetadataWriter.write(
                        metadataURL: metadataURL,
                        outputURL: outputURL,
                        prompt: prompt,
                        response: response,
                        request: request,
                        runID: runID,
                        runDirectoryURL: runDirectoryURL,
                        promptURL: promptURL,
                        logURL: logURL,
                        providerRequestURL: providerRequestURL
                    )
                }
            )
            sawTerminalEvent = true
            progress = 100
            statusMessage = completion.statusMessage
            milestones = NativeRefinementMilestone.timeline(currentStage: "complete")
            stopProgressTimer()
            runState = .complete(outputURL)
            onCompletion(outputURL)
        } catch {
            rawPayloadURLDidFail(error)
        }
    }

    private func failNativeProviderResponse(
        _ error: Error,
        repoRoot: URL,
        providerPlan: ImageProviderExecutionPlan
    ) {
        guard !sawTerminalEvent else { return }
        providerTask = nil
        do {
            let rawFailureResponseURL: URL? = {
                do {
                    return try NativeProviderResponsePersister.persistFailureRawResponseIfAvailable(
                        error: error,
                        rawResponseURL: nativeProviderResponseURL(),
                        didSaveRawResponse: { self.rawResponseURL = $0 },
                        appendEvent: { stage, progress, message in
                            self.appendLocalEvent(stage: stage, progress: progress, message: message)
                        }
                    )
                } catch {
                    appendLocalEvent(
                        stage: "provider_response_save_failed",
                        progress: 78,
                        message: "Provider returned error response bytes, but PaperBanana could not save them: \(error.localizedDescription)"
                    )
                    return nil
                }
            }()
            try NativeProviderCallRecorder.fail(
                error: error,
                repoRoot: repoRoot,
                runID: runID,
                callID: providerCallID,
                workflow: .generation,
                providerPlan: providerPlan,
                responseCount: rawFailureResponseURL == nil ? 0 : 1,
                artifacts: [rawFailureResponseURL].compactMap { $0 }
            )
            fail(error.localizedDescription)
        } catch {
            fail("Provider failed, but PaperBanana could not record the provider failure in the durable ledger: \(error.localizedDescription)")
        }
    }

    private func rawPayloadURLDidFail(_ error: Error) {
        if let rawPayloadURL,
           FileManager.default.fileExists(atPath: rawPayloadURL.path) {
            let message = "Generated provider bytes were preserved as a raw recoverable payload, but PaperBanana could not normalize them into a PNG: \(error.localizedDescription)"
            sawTerminalEvent = true
            appendLocalEvent(stage: "recovered", progress: 100, message: message)
            finishRecovered(rawPayloadURL, message: message)
            return
        }

        let message = "Failed to save generated image: \(error.localizedDescription)"
        appendLocalEvent(stage: "failed", progress: 100, message: message)
        sawTerminalEvent = true
        fail(message)
    }

    private func nativeProviderResponseURL() -> URL? {
        outputURL?.deletingPathExtension().appendingPathExtension("provider_response.json")
    }

    private func nativeProviderRawPayloadURL() -> URL? {
        guard let outputURL else { return nil }
        return outputURL
            .deletingPathExtension()
            .appendingPathExtension("provider_raw.bin")
    }

    private func prepareDurableRunRecord(request: NativeImageGenerationRequest, providerPlan: ImageProviderExecutionPlan, prompt: String) throws {
        guard let runDirectoryURL,
              let outputURL,
              let metadataURL,
              let logURL,
              let promptURL,
              let requestURL,
              let providerRequestURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        let repoRoot = URL(fileURLWithPath: request.settings.repoPath, isDirectory: true)
        try NativeImageGenerationDurableRunWriter.prepare(
            request: request,
            providerPlan: providerPlan,
            prompt: prompt,
            runID: runID,
            repoRoot: repoRoot,
            runDirectoryURL: runDirectoryURL,
            outputURL: outputURL,
            metadataURL: metadataURL,
            logURL: logURL,
            promptURL: promptURL,
            requestURL: requestURL,
            providerRequestURL: providerRequestURL
        )

        appendLocalEvent(
            stage: "queued",
            progress: 0,
            message: "Created durable native generation run record."
        )
    }

    private func failUnsupportedNativeProvider(_ providerPlan: ImageProviderExecutionPlan) {
        fail(
            "Native generation does not support \(providerPlan.providerLabel) for \(providerPlan.backendModelValue). " +
            "No provider call was started. Use Legacy Diagnostics only for explicit Python compatibility."
        )
    }

    private func fail(_ message: String) {
        stopProgressTimer()
        if !sawTerminalEvent {
            appendLocalEvent(stage: "failed", progress: 100, message: message)
        }
        progress = 100
        statusMessage = message
        milestones = NativeRefinementMilestone.timeline(currentStage: "failed")
        runState = .failed(message)
    }

    private func finishCancelled(_ message: String) {
        stopProgressTimer()
        progress = 100
        statusMessage = message
        milestones = NativeRefinementMilestone.timeline(currentStage: "cancelled")
        runState = .cancelled(message)
    }

    private func finishRecovered(_ url: URL, message: String) {
        stopProgressTimer()
        progress = 100
        statusMessage = message
        milestones = NativeRefinementMilestone.timeline(currentStage: "recovered")
        runState = .recovered(url, message)
    }

    private func finishTimedOut(_ message: String) {
        stopProgressTimer()
        progress = 100
        statusMessage = message
        milestones = NativeRefinementMilestone.timeline(currentStage: "timeout")
        runState = .timedOut(message)
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickProgressClock()
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func tickProgressClock() {
        guard isRunning else {
            stopProgressTimer()
            return
        }
        let now = Date()
        if let startedAt {
            elapsedSeconds = now.timeIntervalSince(startedAt)
        }
        if let lastEventAt {
            secondsSinceLastEvent = now.timeIntervalSince(lastEventAt)
        }

        if secondsSinceLastEvent >= hardTimeoutInterval {
            let message = "No provider progress for \(Self.formatDuration(secondsSinceLastEvent)); terminating local generation process."
            if let ledgerError = markActiveProviderCallTerminal(status: .timedOut, message: message) {
                let failureMessage = "Generation timed out locally, but PaperBanana could not record the provider timeout in the durable ledger: \(ledgerError.localizedDescription)"
                appendLocalEvent(stage: "failed", progress: progress, message: failureMessage)
                sawTerminalEvent = true
                providerTask?.cancel()
                providerTask = nil
                fail(failureMessage)
                return
            }
            appendLocalEvent(stage: "timeout", progress: progress, message: message)
            sawTerminalEvent = true
            providerTask?.cancel()
            providerTask = nil
            finishTimedOut(message)
        } else if secondsSinceLastEvent >= stallWarningInterval, !isStalled {
            isStalled = true
            statusMessage = "Waiting on provider response. No progress for \(Self.formatDuration(secondsSinceLastEvent))."
            appendLocalEvent(stage: "stalled", progress: progress, message: statusMessage)
        }
    }

    private func appendLocalEvent(stage: String, progress: Int, message: String) {
        NativeRunEventRecorder.appendLocalEvent(
            stage: stage,
            progress: progress,
            message: message,
            context: eventContext
        )
    }

    private func markActiveProviderCallTerminal(status: ProviderRunStatus, message: String) -> Error? {
        guard let activeRepoRootURL,
              let activeProviderPlan else {
            return nil
        }
        do {
            try NativeProviderCallRecorder.terminal(
                status: status,
                message: message,
                repoRoot: activeRepoRootURL,
                runID: runID,
                callID: providerCallID,
                workflow: .generation,
                providerPlan: activeProviderPlan
            )
            return nil
        } catch {
            return error
        }
    }

    private var eventContext: NativeRunEventContext {
        NativeRunEventContext(
            repoRootURL: activeRepoRootURL,
            runID: runID,
            runDirectoryURL: runDirectoryURL,
            outputURL: outputURL,
            metadataURL: metadataURL,
            promptURL: promptURL,
            requestURL: requestURL,
            sourceCopyURL: nil,
            providerCallID: providerCallID,
            rawResponseURL: rawResponseURL,
            rawPayloadURL: rawPayloadURL,
            logURL: logURL
        )
    }
}
