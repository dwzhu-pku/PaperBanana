import Foundation

struct LegacyPythonProviderRequest {
    let workflow: ProviderWorkflow
    let repoRoot: URL
    let runID: String
    let sourceURL: URL?
    let prompt: String
    let providerPlan: ImageProviderExecutionPlan
    let resolution: String
    let aspectRatio: String
    let task: String
    let outputDirectory: URL
    let dryRun: Bool
    let mockProviderMode: String?
}

struct LegacyPythonProviderClient: ProviderClient {
    let providerKind: ImageProviderKind
    let repoRootOverride: URL?
    let outputDirectoryOverride: URL?
    let dryRun: Bool
    let mockProviderMode: String?

    init(
        providerKind: ImageProviderKind = .codexFallback,
        repoRootOverride: URL? = nil,
        outputDirectoryOverride: URL? = nil,
        dryRun: Bool = false,
        mockProviderMode: String? = nil
    ) {
        self.providerKind = providerKind
        self.repoRootOverride = repoRootOverride
        self.outputDirectoryOverride = outputDirectoryOverride
        self.dryRun = dryRun
        self.mockProviderMode = mockProviderMode
    }

    func execute(
        _ request: ProviderClientRequest,
        eventHandler: @escaping @Sendable (ProviderProgressEvent) -> Void
    ) async throws -> ProviderResponse {
        let repoRoot = repoRootOverride ?? URL(fileURLWithPath: request.settings.repoPath, isDirectory: true)
        let providerPlan = ImageProviderExecutionPlan(requestedModel: request.model, settings: request.settings)
        let outputDirectory = outputDirectoryOverride ?? repoRoot.appendingPathComponent("results/\(request.workflow.rawValue)", isDirectory: true)
        let legacyRequest = LegacyPythonProviderRequest(
            workflow: request.workflow,
            repoRoot: repoRoot,
            runID: request.runID,
            sourceURL: request.sourceImageURL,
            prompt: request.prompt,
            providerPlan: providerPlan,
            resolution: request.resolution,
            aspectRatio: request.aspectRatio,
            task: request.task,
            outputDirectory: outputDirectory,
            dryRun: dryRun,
            mockProviderMode: mockProviderMode
        )
        let process = makeProcess(for: legacyRequest, settings: request.settings)
        if let providerRequestURL = request.providerRequestURL {
            let manifest = try Self.legacyProviderRequestManifest(
                providerRequest: request,
                legacyRequest: legacyRequest,
                process: process,
                settings: request.settings
            )
            try ProviderRequestPersistence.writeJSON(manifest, to: providerRequestURL)
            eventHandler(
                ProviderProgressEvent(
                    stage: "provider_request_saved",
                    progress: 12,
                    message: "Saved legacy provider handoff manifest before process execution.",
                    callID: request.callID
                )
            )
        }
        return try await run(process: process, request: request, eventHandler: eventHandler)
    }

    func makeProcess(for request: LegacyPythonProviderRequest, settings: PaperBananaSettingsSnapshot) -> Process {
        let process = Process()
        process.executableURL = request.repoRoot.appendingPathComponent(".venv/bin/python")
        process.currentDirectoryURL = request.repoRoot

        switch request.workflow {
        case .generation:
            process.arguments = [
                "-m", "paperbanana_gui.native_generate",
                "--prompt", request.prompt,
                "--model", request.providerPlan.backendModelValue,
                "--resolution", request.resolution,
                "--aspect-ratio", request.aspectRatio,
                "--task", request.task,
                "--output-dir", request.outputDirectory.path,
                "--run-id", request.runID
            ]
        case .refinement:
            process.arguments = [
                "-m", "paperbanana_gui.native_refine",
                "--source", request.sourceURL?.path ?? "",
                "--prompt", request.prompt,
                "--model", request.providerPlan.backendModelValue,
                "--resolution", request.resolution,
                "--aspect-ratio", request.aspectRatio,
                "--output-dir", request.outputDirectory.path,
                "--run-id", request.runID
            ]
        }

        if request.dryRun {
            process.arguments?.append("--dry-run")
        }

        var environment = ProcessInfo.processInfo.environment
        request.providerPlan.applyEnvironment(settings: settings, to: &environment)
        if let mockProviderMode = request.mockProviderMode {
            switch request.workflow {
            case .generation:
                environment["PAPERBANANA_NATIVE_GENERATE_MOCK_PROVIDER"] = mockProviderMode
            case .refinement:
                environment["PAPERBANANA_NATIVE_REFINE_MOCK_PROVIDER"] = mockProviderMode
            }
        }
        process.environment = environment
        return process
    }

    private static func legacyProviderRequestManifest(
        providerRequest: ProviderClientRequest,
        legacyRequest: LegacyPythonProviderRequest,
        process: Process,
        settings: PaperBananaSettingsSnapshot
    ) throws -> Data {
        let environment = process.environment ?? [:]
        let safeEnvironmentKeys = [
            "PAPERBANANA_IMAGE_PROVIDER_KIND",
            "PAPERBANANA_EFFECTIVE_IMAGE_MODEL",
            "PAPERBANANA_CAN_SPEND_PROVIDER_CREDITS",
            "PAPERBANANA_NATIVE_GENERATE_MOCK_PROVIDER",
            "PAPERBANANA_NATIVE_REFINE_MOCK_PROVIDER"
        ]
        var safeEnvironment: [String: String] = [:]
        for key in safeEnvironmentKeys {
            if let value = environment[key] {
                safeEnvironment[key] = value
            }
        }
        let payload: [String: Any] = [
            "adapter": "legacy_python",
            "run_id": providerRequest.runID,
            "call_id": providerRequest.callID,
            "workflow": providerRequest.workflow.rawValue,
            "requested_model": providerRequest.model.backendValue,
            "effective_model": providerRequest.effectiveModel,
            "provider": legacyRequest.providerPlan.provider.rawValue,
            "resolution": providerRequest.resolution,
            "aspect_ratio": providerRequest.aspectRatio,
            "task": providerRequest.task,
            "source_image_path": legacyRequest.sourceURL?.path ?? "",
            "output_directory": legacyRequest.outputDirectory.path,
            "prompt": providerRequest.prompt,
            "dry_run": legacyRequest.dryRun,
            "mock_provider_mode": legacyRequest.mockProviderMode ?? "",
            "python_executable_path": process.executableURL?.path ?? "",
            "working_directory": process.currentDirectoryURL?.path ?? "",
            "command_arguments": process.arguments ?? [],
            "provider_key_status": [
                "google_api_key_present": settings.googleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                "openrouter_api_key_present": settings.openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ],
            "safe_environment": safeEnvironment
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    private func run(
        process: Process,
        request: ProviderClientRequest,
        eventHandler: @escaping @Sendable (ProviderProgressEvent) -> Void
    ) async throws -> ProviderResponse {
        let processBox = LegacyPythonProcessBox(process)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let output = LegacyPythonProcessOutput(
                    request: request,
                    providerKind: providerKind,
                    eventHandler: eventHandler
                )
                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr

                stdout.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard data.isEmpty == false else { return }
                    output.appendStdout(data)
                }
                stderr.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard data.isEmpty == false else { return }
                    output.appendStderr(data)
                }
                process.terminationHandler = { proc in
                    stdout.fileHandleForReading.readabilityHandler = nil
                    stderr.fileHandleForReading.readabilityHandler = nil
                    output.finishBufferedStdout()
                    let status = proc.terminationStatus
                    do {
                        continuation.resume(returning: try output.response(terminationStatus: status))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }

                do {
                    try process.run()
                } catch {
                    stdout.fileHandleForReading.readabilityHandler = nil
                    stderr.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            processBox.terminate()
        }
    }
}

private final class LegacyPythonProcessBox: @unchecked Sendable {
    private let process: Process

    init(_ process: Process) {
        self.process = process
    }

    func terminate() {
        if process.isRunning {
            process.terminate()
        }
    }
}

private final class LegacyPythonProcessOutput: @unchecked Sendable {
    private let lock = NSLock()
    private let request: ProviderClientRequest
    private let providerKind: ImageProviderKind
    private let eventHandler: @Sendable (ProviderProgressEvent) -> Void
    private var stdoutData = Data()
    private var stderrData = Data()
    private var stdoutBuffer = ""
    private var latestEvent: NativeRefinementEvent?
    private var terminalEvent: NativeRefinementEvent?

    init(
        request: ProviderClientRequest,
        providerKind: ImageProviderKind,
        eventHandler: @escaping @Sendable (ProviderProgressEvent) -> Void
    ) {
        self.request = request
        self.providerKind = providerKind
        self.eventHandler = eventHandler
    }

    func appendStdout(_ data: Data) {
        let events: [NativeRefinementEvent]
        lock.lock()
        stdoutData.append(data)
        events = parseEventsLocked(data: data)
        lock.unlock()
        publish(events)
    }

    func appendStderr(_ data: Data) {
        lock.lock()
        stderrData.append(data)
        lock.unlock()
    }

    func finishBufferedStdout() {
        let events: [NativeRefinementEvent]
        lock.lock()
        if stdoutBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            events = []
        } else {
            events = NativeRefinementEvent(jsonLine: stdoutBuffer).map { [$0] } ?? []
            stdoutBuffer = ""
            for event in events {
                latestEvent = event
                if event.stage == "complete" || event.stage == "failed" {
                    terminalEvent = event
                }
            }
        }
        lock.unlock()
        publish(events)
    }

    func response(terminationStatus: Int32) throws -> ProviderResponse {
        lock.lock()
        let stdout = stdoutData
        let stderr = stderrData
        let event = terminalEvent ?? latestEvent
        lock.unlock()

        let stderrText = String(data: stderr, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if terminationStatus != 0 {
            throw ProviderRuntimeError.legacyPythonProcessFailed(terminationStatus, stderrText.isEmpty ? "No stderr output." : stderrText)
        }
        if event?.stage == "failed" {
            throw ProviderRuntimeError.legacyPythonProcessFailed(terminationStatus, event?.message ?? "Provider emitted a failed terminal event.")
        }

        let outputURL = event?.outputURL
        let imageData = outputURL.flatMap { try? Data(contentsOf: $0) }
        guard let imageData else {
            throw ProviderRuntimeError.providerReturnedNoImage
        }

        let rawResponse = Self.rawResponseData(
            stdout: stdout,
            stderr: stderr,
            event: event,
            outputURL: outputURL
        )
        return ProviderResponse(
            provider: providerKind,
            model: request.effectiveModel,
            callID: event?.callID.isEmpty == false ? event?.callID ?? request.callID : request.callID,
            rawResponseData: rawResponse,
            imageData: imageData,
            text: event?.message ?? "",
            usageMetadata: [
                "legacy_process_status": "\(terminationStatus)",
                "legacy_stdout_bytes": "\(stdout.count)",
                "legacy_stderr_bytes": "\(stderr.count)"
            ]
        )
    }

    private func parseEventsLocked(data: Data) -> [NativeRefinementEvent] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        stdoutBuffer += text
        let lines = stdoutBuffer.components(separatedBy: .newlines)
        stdoutBuffer = lines.last ?? ""
        let events = lines.dropLast().compactMap { NativeRefinementEvent(jsonLine: $0) }
        for event in events {
            latestEvent = event
            if event.stage == "complete" || event.stage == "failed" {
                terminalEvent = event
            }
        }
        return events
    }

    private func publish(_ events: [NativeRefinementEvent]) {
        for event in events {
            eventHandler(
                ProviderProgressEvent(
                    stage: event.stage,
                    progress: event.progress,
                    message: event.message,
                    callID: event.callID.isEmpty ? request.callID : event.callID,
                    nativeRunEvent: event
                )
            )
        }
    }

    private static func rawResponseData(
        stdout: Data,
        stderr: Data,
        event: NativeRefinementEvent?,
        outputURL: URL?
    ) -> Data {
        var payload: [String: Any] = [
            "adapter": "legacy_python",
            "stdout": String(data: stdout, encoding: .utf8) ?? "",
            "stderr": String(data: stderr, encoding: .utf8) ?? "",
            "output_path": outputURL?.path ?? ""
        ]
        if let event {
            payload["stage"] = event.stage
            payload["message"] = event.message
            payload["call_id"] = event.callID
            payload["run_id"] = event.runID
        }
        return (try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])) ?? stdout
    }
}
