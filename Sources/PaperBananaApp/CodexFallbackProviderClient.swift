import Foundation
import ImageIO

struct CodexFallbackProviderClient: ProviderClient {
    let providerKind: ImageProviderKind = .codexFallback
    var codexExecutableURL: URL?
    var codexExecutableName: String
    var timeoutSeconds: TimeInterval
    var pollInterval: TimeInterval
    var extraEnvironment: [String: String]

    init(
        codexExecutableURL: URL? = nil,
        codexExecutableName: String = "codex",
        timeoutSeconds: TimeInterval = 900,
        pollInterval: TimeInterval = 2,
        extraEnvironment: [String: String] = [:]
    ) {
        self.codexExecutableURL = codexExecutableURL
        self.codexExecutableName = codexExecutableName
        self.timeoutSeconds = max(timeoutSeconds, 1)
        self.pollInterval = max(pollInterval, 0.05)
        self.extraEnvironment = extraEnvironment
    }

    func execute(
        _ request: ProviderClientRequest,
        eventHandler: @escaping @Sendable (ProviderProgressEvent) -> Void
    ) async throws -> ProviderResponse {
        guard let outputURL = request.outputURL else {
            throw ProviderRuntimeError.missingCodexOutputPath
        }
        if request.workflow == .refinement, request.sourceImageURL == nil {
            throw ProviderRuntimeError.missingSourceImage
        }

        let repoRoot = URL(fileURLWithPath: request.settings.repoPath, isDirectory: true)
        let handoff = try Self.prepareHandoff(
            request: request,
            repoRoot: repoRoot,
            outputURL: outputURL,
            codexModel: codexModel(from: request.settings),
            reasoningEffort: reasoningEffort(from: request.settings)
        )
        if let providerRequestURL = request.providerRequestURL {
            let manifest = try Self.codexProviderRequestManifest(request: request, handoff: handoff)
            try ProviderRequestPersistence.writeJSON(manifest, to: providerRequestURL)
            eventHandler(
                ProviderProgressEvent(
                    stage: "provider_request_saved",
                    progress: 12,
                    message: "Saved Codex handoff request manifest before execution.",
                    callID: request.callID
                )
            )
        }
        eventHandler(
            ProviderProgressEvent(
                stage: "prepared",
                progress: 10,
                message: "Prepared Codex handoff prompt and output target.",
                callID: request.callID
            )
        )

        let process = makeProcess(repoRoot: repoRoot, request: request, handoff: handoff)
        let processBox = CodexProcessBox(process)
        return try await withTaskCancellationHandler {
            try await run(process: process, processBox: processBox, request: request, handoff: handoff, eventHandler: eventHandler)
        } onCancel: {
            processBox.terminate()
        }
    }

    private func makeProcess(
        repoRoot: URL,
        request: ProviderClientRequest,
        handoff: CodexHandoffArtifacts
    ) -> Process {
        let process = Process()
        if let codexExecutableURL {
            process.executableURL = codexExecutableURL
            process.arguments = handoff.commandArguments
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [codexExecutableName] + handoff.commandArguments
        }
        process.currentDirectoryURL = repoRoot
        process.environment = Self.handoffEnvironment(
            baseEnvironment: ProcessInfo.processInfo.environment,
            request: request,
            codexModel: codexModel(from: request.settings),
            reasoningEffort: reasoningEffort(from: request.settings),
            extraEnvironment: extraEnvironment
        )
        return process
    }

    static func handoffEnvironment(
        baseEnvironment: [String: String],
        request: ProviderClientRequest,
        codexModel: String,
        reasoningEffort: String,
        extraEnvironment: [String: String]
    ) -> [String: String] {
        var environment: [String: String] = [:]
        for key in inheritedEnvironmentKeys {
            if let value = baseEnvironment[key], !isSecretLikeEnvironmentKey(key) {
                environment[key] = value
            }
        }
        for (key, value) in baseEnvironment where key.hasPrefix("CODEX_") && !isSecretLikeEnvironmentKey(key) {
            environment[key] = value
        }
        for (key, value) in extraEnvironment where !isSecretLikeEnvironmentKey(key) {
            environment[key] = value
        }
        environment["PAPERBANANA_CODEX_MODEL"] = codexModel
        environment["PAPERBANANA_CODEX_REASONING_EFFORT"] = reasoningEffort
        environment["PAPERBANANA_CODEX_IMAGE_HANDOFF"] = "1"
        environment["PAPERBANANA_RUN_ID"] = request.runID
        environment["PAPERBANANA_PROVIDER_CALL_ID"] = request.callID
        return environment
    }

    private static let inheritedEnvironmentKeys: Set<String> = [
        "PATH",
        "HOME",
        "TMPDIR",
        "TEMP",
        "TMP",
        "USER",
        "LOGNAME",
        "SHELL",
        "LANG",
        "LC_ALL",
        "LC_CTYPE",
        "TERM",
        "__CF_USER_TEXT_ENCODING",
        "XDG_CONFIG_HOME",
        "XDG_CACHE_HOME",
        "XDG_DATA_HOME",
        "XDG_STATE_HOME",
        "CODEX_HOME"
    ]

    private static func isSecretLikeEnvironmentKey(_ key: String) -> Bool {
        let normalized = key.uppercased()
        let markers = [
            "API_KEY",
            "AUTHORIZATION",
            "BEARER",
            "CREDENTIAL",
            "PASSWORD",
            "PRIVATE_KEY",
            "SECRET",
            "TOKEN"
        ]
        return markers.contains { normalized.contains($0) }
    }

    private func run(
        process: Process,
        processBox: CodexProcessBox,
        request: ProviderClientRequest,
        handoff: CodexHandoffArtifacts,
        eventHandler: @escaping @Sendable (ProviderProgressEvent) -> Void
    ) async throws -> ProviderResponse {
        try FileManager.default.createDirectory(at: handoff.logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: handoff.logURL.path) {
            FileManager.default.createFile(atPath: handoff.logURL.path, contents: nil)
        }
        let logHandle = try FileHandle(forWritingTo: handoff.logURL)
        try logHandle.seekToEnd()
        try logHandle.write(contentsOf: Data("$ \(handoff.displayCommand)\n".utf8))
        process.standardOutput = logHandle
        process.standardError = logHandle

        eventHandler(
            ProviderProgressEvent(
                stage: "started",
                progress: 20,
                message: "Started Codex handoff with \(handoff.codexModel) / \(handoff.reasoningEffort).",
                callID: request.callID
            )
        )

        do {
            try process.run()
        } catch {
            try? logHandle.close()
            throw ProviderRuntimeError.codexHandoffFailed("Failed to start Codex: \(error.localizedDescription)")
        }

        let startedAt = Date()
        var lastSize: UInt64?
        var lastRunningProgress = 20
        defer {
            try? logHandle.close()
        }

        while true {
            try Task.checkCancellation()
            let elapsed = Date().timeIntervalSince(startedAt)

            if let imageData = Self.stableValidatedPNGData(at: handoff.outputURL, lastSize: &lastSize) {
                processBox.terminate()
                return try Self.response(
                    request: request,
                    handoff: handoff,
                    imageData: imageData,
                    message: "PNG validation passed. Returned after output validation."
                )
            }

            if !process.isRunning {
                if process.terminationStatus != 0 {
                    throw ProviderRuntimeError.codexHandoffFailed(
                        "Codex exited with code \(process.terminationStatus). Log: \(handoff.logURL.path)"
                    )
                }
                guard let imageData = Self.validatedPNGData(at: handoff.outputURL) else {
                    throw ProviderRuntimeError.codexHandoffFailed(
                        "Codex exited successfully but did not create a valid PNG at \(handoff.outputURL.path). Log: \(handoff.logURL.path)"
                    )
                }
                return try Self.response(
                    request: request,
                    handoff: handoff,
                    imageData: imageData,
                    message: "PNG validation passed."
                )
            }

            if elapsed >= timeoutSeconds {
                processBox.terminate()
                if let imageData = Self.validatedPNGData(at: handoff.outputURL) {
                    return try Self.response(
                        request: request,
                        handoff: handoff,
                        imageData: imageData,
                        message: "PNG validation passed. Returned after timeout watchdog."
                    )
                }
                throw ProviderRuntimeError.codexHandoffTimedOut(
                    "No valid PNG was created within \(Int(timeoutSeconds))s. Log: \(handoff.logURL.path)"
                )
            }

            let runningProgress = min(90, 30 + Int(elapsed / 12) * 5)
            if runningProgress != lastRunningProgress || Int(elapsed) % max(Int(pollInterval), 1) == 0 {
                lastRunningProgress = runningProgress
                eventHandler(
                    ProviderProgressEvent(
                        stage: "running",
                        progress: runningProgress,
                        message: "Codex is running. Elapsed: \(Int(elapsed))s. Log: \(handoff.logURL.path)",
                        callID: request.callID
                    )
                )
            }

            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
    }

    private func codexModel(from settings: PaperBananaSettingsSnapshot) -> String {
        let value = settings.codexModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "gpt-5.5" : value
    }

    private func reasoningEffort(from settings: PaperBananaSettingsSnapshot) -> String {
        let value = settings.codexReasoning.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "xhigh" : value
    }

    private static func prepareHandoff(
        request: ProviderClientRequest,
        repoRoot: URL,
        outputURL: URL,
        codexModel: String,
        reasoningEffort: String
    ) throws -> CodexHandoffArtifacts {
        let resolvedOutputURL = outputURL.standardizedFileURL
        try FileManager.default.createDirectory(at: resolvedOutputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let artifactDirectory = resolvedOutputURL
            .deletingLastPathComponent()
            .appendingPathComponent(".paperbanana_codex_handoff", isDirectory: true)
        try FileManager.default.createDirectory(at: artifactDirectory, withIntermediateDirectories: true)
        let promptURL = artifactDirectory.appendingPathComponent("\(resolvedOutputURL.deletingPathExtension().lastPathComponent).prompt.md")
        let logURL = artifactDirectory.appendingPathComponent("\(resolvedOutputURL.deletingPathExtension().lastPathComponent).codex.log")
        let messageURL = logURL.deletingPathExtension().appendingPathExtension("message.txt")
        let prompt = codexPrompt(
            request: request,
            outputURL: resolvedOutputURL,
            codexModel: codexModel,
            reasoningEffort: reasoningEffort
        )
        try prompt.write(to: promptURL, atomically: true, encoding: .utf8)

        var arguments = [
            "exec",
            "-m",
            codexModel,
            "-c",
            #"model_reasoning_effort="\#(reasoningEffort)""#,
            "--sandbox",
            "workspace-write",
            "-C",
            repoRoot.path,
            "--add-dir",
            resolvedOutputURL.deletingLastPathComponent().path,
            "-o",
            messageURL.path
        ]
        if let sourceImageURL = request.sourceImageURL {
            let resolvedSourceURL = sourceImageURL.standardizedFileURL
            arguments.append(contentsOf: ["--image", resolvedSourceURL.path])
            arguments.append(contentsOf: ["--add-dir", resolvedSourceURL.deletingLastPathComponent().path])
        }
        arguments.append(prompt)

        return CodexHandoffArtifacts(
            outputURL: resolvedOutputURL,
            promptURL: promptURL,
            logURL: logURL,
            messageURL: messageURL,
            codexModel: codexModel,
            reasoningEffort: reasoningEffort,
            commandArguments: arguments
        )
    }

    private static func codexPrompt(
        request: ProviderClientRequest,
        outputURL: URL,
        codexModel: String,
        reasoningEffort: String
    ) -> String {
        switch request.workflow {
        case .generation:
            """
            Create one publication-quality academic \(request.task) as a PNG.

            Use local code generation to create the final image file directly at:
            \(outputURL.path)

            Requirements:
            - Model request: \(codexModel) with \(reasoningEffort) reasoning.
            - Prompt: \(request.prompt)
            - Aspect ratio: \(request.aspectRatio)
            - Resolution target: \(request.resolution)
            - Preserve academic figure conventions from PaperBanana: faithful content, concise labels, readable typography, clean layout, and publication-ready aesthetics.
            - Use a restrained color palette and avoid overlapping text.
            - Create exactly the requested PNG file and verify it exists before finishing.
            """
        case .refinement:
            """
            Modify the attached academic figure and save the edited result as a PNG.

            Use the attached image as the source. Apply these requested changes:
            \(request.prompt)

            Output path:
            \(outputURL.path)

            Requirements:
            - Model request: \(codexModel) with \(reasoningEffort) reasoning.
            - Aspect ratio: \(request.aspectRatio)
            - Resolution target: \(request.resolution)
            - Preserve the original scientific meaning unless the requested edit explicitly changes it.
            - Preserve or improve readability, label alignment, academic styling, and visual hierarchy.
            - Create exactly the requested PNG file and verify it exists before finishing.
            """
        }
    }

    private static func stableValidatedPNGData(at url: URL, lastSize: inout UInt64?) -> Data? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? UInt64,
              size > 0 else {
            return nil
        }
        defer { lastSize = size }
        guard lastSize == size else { return nil }
        return validatedPNGData(at: url)
    }

    private static func validatedPNGData(at url: URL) -> Data? {
        guard let data = try? Data(contentsOf: url),
              data.starts(with: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0,
              height > 0 else {
            return nil
        }
        return data
    }

    private static func response(
        request: ProviderClientRequest,
        handoff: CodexHandoffArtifacts,
        imageData: Data,
        message: String
    ) throws -> ProviderResponse {
        ProviderResponse(
            provider: .codexFallback,
            model: request.effectiveModel,
            callID: request.callID,
            rawResponseData: try rawResponseData(request: request, handoff: handoff, message: message),
            imageData: imageData,
            text: message,
            usageMetadata: [
                "provider_spend": "none",
                "handoff_adapter": "swift_codex",
                "prompt_path": handoff.promptURL.path,
                "log_path": handoff.logURL.path,
                "message_path": handoff.messageURL.path
            ]
        )
    }

    private static func rawResponseData(
        request: ProviderClientRequest,
        handoff: CodexHandoffArtifacts,
        message: String
    ) throws -> Data {
        let payload: [String: Any] = [
            "adapter": "swift_codex",
            "run_id": request.runID,
            "call_id": request.callID,
            "workflow": request.workflow.rawValue,
            "model": request.effectiveModel,
            "codex_model": handoff.codexModel,
            "reasoning_effort": handoff.reasoningEffort,
            "message": message,
            "output_path": handoff.outputURL.path,
            "prompt_path": handoff.promptURL.path,
            "log_path": handoff.logURL.path,
            "message_path": handoff.messageURL.path,
            "log": (try? String(contentsOf: handoff.logURL, encoding: .utf8)) ?? "",
            "prompt": (try? String(contentsOf: handoff.promptURL, encoding: .utf8)) ?? ""
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    private static func codexProviderRequestManifest(
        request: ProviderClientRequest,
        handoff: CodexHandoffArtifacts
    ) throws -> Data {
        let payload: [String: Any] = [
            "adapter": "swift_codex",
            "run_id": request.runID,
            "call_id": request.callID,
            "workflow": request.workflow.rawValue,
            "requested_model": request.model.backendValue,
            "effective_model": request.effectiveModel,
            "codex_model": handoff.codexModel,
            "reasoning_effort": handoff.reasoningEffort,
            "resolution": request.resolution,
            "aspect_ratio": request.aspectRatio,
            "task": request.task,
            "source_image_path": request.sourceImageURL?.path ?? "",
            "prompt_path": handoff.promptURL.path,
            "output_path": handoff.outputURL.path,
            "log_path": handoff.logURL.path,
            "command_arguments": handoff.commandArguments
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }
}

private struct CodexHandoffArtifacts: Sendable {
    let outputURL: URL
    let promptURL: URL
    let logURL: URL
    let messageURL: URL
    let codexModel: String
    let reasoningEffort: String
    let commandArguments: [String]

    var displayCommand: String {
        commandArguments.map(Self.shellQuoted).joined(separator: " ")
    }

    private static func shellQuoted(_ value: String) -> String {
        guard value.rangeOfCharacter(from: .whitespacesAndNewlines) != nil || value.contains("'") || value.contains("\"") else {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

private final class CodexProcessBox: @unchecked Sendable {
    private let process: Process

    init(_ process: Process) {
        self.process = process
    }

    func terminate() {
        guard process.isRunning else { return }
        process.terminate()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3) {
            if self.process.isRunning {
                self.process.interrupt()
            }
        }
    }
}
