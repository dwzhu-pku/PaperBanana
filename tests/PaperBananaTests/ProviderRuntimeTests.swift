import AppKit
import XCTest
@testable import PaperBanana

final class ProviderRuntimeTests: XCTestCase {
    func testProviderClientFactoryRoutesGoogleToNativeClient() {
        let settings = Self.settings(googleAPIKey: "test-google-key")
        let plan = ImageProviderExecutionPlan(requestedModel: .nanoBananaPro, settings: settings)

        let client = ProviderClientFactory().client(for: plan)

        XCTAssertTrue(client is GoogleGeminiProviderClient)
    }

    func testProviderClientFactoryRoutesFallbackToNativeCodexClient() {
        let settings = Self.settings()
        let plan = ImageProviderExecutionPlan(requestedModel: .nanoBananaPro, settings: settings)

        let client = ProviderClientFactory().client(for: plan)

        XCTAssertTrue(client is CodexFallbackProviderClient)
    }

    func testProviderClientFactoryRoutesOpenRouterToNativeClient() {
        let settings = Self.settings(openRouterAPIKey: "test-openrouter-key")
        let plan = ImageProviderExecutionPlan(requestedModel: .nanoBananaPro, settings: settings)

        let client = ProviderClientFactory().client(for: plan)

        XCTAssertTrue(client is OpenRouterProviderClient)
    }

    func testReleaseVisibleImageModelsDoNotRouteToUnsupportedFoundationModelsProvider() {
        let settingsVariants = [
            Self.settings(),
            Self.settings(googleAPIKey: "test-google-key"),
            Self.settings(openRouterAPIKey: "test-openrouter-key")
        ]

        XCTAssertFalse(
            ImageModelChoice.allCases.contains { $0.backendValue == ImageProviderKind.foundationModels.rawValue },
            "Foundation Models must not be exposed as a release-visible image model until the provider is implemented and validated."
        )

        for settings in settingsVariants {
            for model in ImageModelChoice.allCases {
                let plan = ImageProviderExecutionPlan(requestedModel: model, settings: settings)
                let client = ProviderClientFactory().client(for: plan)

                XCTAssertNotEqual(plan.provider, .foundationModels)
                XCTAssertFalse(client is FoundationModelsProviderClient)
                XCTAssertNotEqual(plan.durableRequestFields["provider_kind"] as? String, ImageProviderKind.foundationModels.rawValue)
            }
        }
    }

    func testOpenRouterProviderClientWritesNativeImageRequestPayload() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        let sourceURL = repoRoot.appendingPathComponent("source.png")
        try Self.tinyPNGData.write(to: sourceURL)
        let settings = Self.settings(repoRoot: repoRoot, openRouterAPIKey: "test-openrouter-key")
        let request = ProviderClientRequest(
            runID: "openrouter-payload-test",
            callID: "swift-openrouter-test-call",
            workflow: .refinement,
            prompt: "Sharpen labels.",
            sourceImageURL: sourceURL,
            model: .nanoBananaPro,
            effectiveModel: ImageModelChoice.nanoBananaPro.backendValue,
            resolution: "4K",
            aspectRatio: "16:9",
            task: "scientific diagram",
            settings: settings
        )

        let payloadData = try OpenRouterProviderClient().makeOpenRouterPayload(for: request)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: payloadData) as? [String: Any])
        let messages = try XCTUnwrap(payload["messages"] as? [[String: Any]])
        let message = try XCTUnwrap(messages.first)
        let content = try XCTUnwrap(message["content"] as? [[String: Any]])

        XCTAssertEqual(payload["model"] as? String, "google/gemini-3-pro-image-preview")
        XCTAssertEqual(payload["modalities"] as? [String], ["image", "text"])
        XCTAssertEqual((payload["image_config"] as? [String: String])?["aspect_ratio"], "16:9")
        XCTAssertEqual((payload["image_config"] as? [String: String])?["image_size"], "4K")
        XCTAssertEqual(content.first?["type"] as? String, "text")
        XCTAssertTrue((content.first?["text"] as? String)?.contains("Modify the attached image") == true)
        XCTAssertEqual(content.last?["type"] as? String, "image_url")
        let imageURL = try XCTUnwrap((content.last?["image_url"] as? [String: String])?["url"])
        XCTAssertTrue(imageURL.hasPrefix("data:image/png;base64,"))
    }

    func testOpenRouterProviderClientExtractsImageBytesFromImageURLResponse() throws {
        let responseData = Data(
            """
            {
              "choices": [
                {
                  "message": {
                    "role": "assistant",
                    "content": "Generated image.",
                    "images": [
                      {
                        "type": "image_url",
                        "image_url": {
                          "url": "data:image/png;base64,\(Self.tinyPNGBase64)"
                        }
                      }
                    ]
                  }
                }
              ],
              "usage": {
                "prompt_tokens": 3,
                "completion_tokens": 5,
                "total_tokens": 8
              }
            }
            """.utf8
        )

        let parsed = try OpenRouterProviderClient().extractImageAndText(from: responseData)

        XCTAssertEqual(parsed.imageData, Data(base64Encoded: Self.tinyPNGBase64))
        XCTAssertEqual(parsed.text, "Generated image.")
        XCTAssertEqual(parsed.usageMetadata["total_tokens"], "8")
    }

    func testOpenRouterProviderClientPreservesHTTPErrorRawResponse() async throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        let errorData = Data(#"{"error":{"message":"quota exceeded"}}"#.utf8)
        let session = Self.mockProviderSession(
            statusCode: 429,
            responseData: errorData
        )
        let client = OpenRouterProviderClient(session: session)

        do {
            _ = try await client.execute(
                ProviderClientRequest(
                    runID: "openrouter-http-error-test",
                    callID: "swift-openrouter-error-call",
                    workflow: .generation,
                    prompt: "Create a test figure.",
                    sourceImageURL: nil,
                    model: .nanoBanana2,
                    effectiveModel: ImageModelChoice.nanoBanana2.backendValue,
                    resolution: "2K",
                    aspectRatio: "16:9",
                    task: "scientific diagram",
                    settings: Self.settings(repoRoot: repoRoot, openRouterAPIKey: "test-openrouter-key")
                ),
                eventHandler: { _ in }
            )
            XCTFail("Expected OpenRouter HTTP error.")
        } catch ProviderRuntimeError.providerHTTPStatus(let status, let preview, let rawData) {
            XCTAssertEqual(status, 429)
            XCTAssertTrue(preview.contains("quota exceeded"))
            XCTAssertEqual(rawData, errorData)
        } catch {
            XCTFail("Expected providerHTTPStatus, got \(error).")
        }
    }

    func testGoogleProviderClientPreservesMalformedSuccessRawResponse() async throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        let malformedData = Data("not-json-from-google".utf8)
        let client = GoogleGeminiProviderClient(
            session: Self.mockProviderSession(responseData: malformedData)
        )

        do {
            _ = try await client.execute(
                ProviderClientRequest(
                    runID: "google-malformed-body-test",
                    callID: "swift-gemini-malformed-call",
                    workflow: .generation,
                    prompt: "Create a test figure.",
                    sourceImageURL: nil,
                    model: .nanoBananaPro,
                    effectiveModel: ImageModelChoice.nanoBananaPro.backendValue,
                    resolution: "4K",
                    aspectRatio: "16:9",
                    task: "scientific diagram",
                    settings: Self.settings(repoRoot: repoRoot, googleAPIKey: "test-google-key")
                ),
                eventHandler: { _ in }
            )
            XCTFail("Expected malformed provider response.")
        } catch ProviderRuntimeError.malformedProviderResponseBody(let reason, let rawData) {
            XCTAssertFalse(reason.isEmpty)
            XCTAssertEqual(rawData, malformedData)
        } catch {
            XCTFail("Expected malformedProviderResponseBody, got \(error).")
        }
    }

    func testOpenRouterProviderClientPreservesMalformedSuccessRawResponse() async throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        let malformedData = Data("not-json-from-openrouter".utf8)
        let client = OpenRouterProviderClient(
            session: Self.mockProviderSession(responseData: malformedData)
        )

        do {
            _ = try await client.execute(
                ProviderClientRequest(
                    runID: "openrouter-malformed-body-test",
                    callID: "swift-openrouter-malformed-call",
                    workflow: .generation,
                    prompt: "Create a test figure.",
                    sourceImageURL: nil,
                    model: .nanoBananaPro,
                    effectiveModel: ImageModelChoice.nanoBananaPro.backendValue,
                    resolution: "4K",
                    aspectRatio: "16:9",
                    task: "scientific diagram",
                    settings: Self.settings(repoRoot: repoRoot, openRouterAPIKey: "test-openrouter-key")
                ),
                eventHandler: { _ in }
            )
            XCTFail("Expected malformed provider response.")
        } catch ProviderRuntimeError.malformedProviderResponseBody(let reason, let rawData) {
            XCTAssertFalse(reason.isEmpty)
            XCTAssertEqual(rawData, malformedData)
        } catch {
            XCTFail("Expected malformedProviderResponseBody, got \(error).")
        }
    }

    @MainActor
    func testProviderCallRecorderFailsBeforeAuditWhenDurableRunIsMissing() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        let settings = Self.settings(repoRoot: repoRoot, googleAPIKey: "test-google-key")
        let providerPlan = ImageProviderExecutionPlan(requestedModel: .nanoBananaPro, settings: settings)
        var capturedCallID = ""
        var capturedEvents: [(String, Int, String)] = []

        XCTAssertThrowsError(
            try NativeProviderCallRecorder.start(
                repoRoot: repoRoot,
                runID: "missing_native_run",
                workflow: .generation,
                providerPlan: providerPlan,
                setProviderCallID: { capturedCallID = $0 },
                appendEvent: { stage, progress, message in
                    capturedEvents.append((stage, progress, message))
                }
            )
        ) { error in
            guard case PaperBananaRunStoreError.missingRunRecord(let runID) = error else {
                XCTFail("Expected missing durable run record error, got \(error).")
                return
            }
            XCTAssertEqual(runID, "missing_native_run")
        }

        XCTAssertEqual(capturedCallID, "")
        XCTAssertTrue(capturedEvents.isEmpty)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: repoRoot.appendingPathComponent("results/provider_audit").path
            )
        )
        XCTAssertTrue(try PaperBananaRunStore.fetchProviderCallsSynchronously(repoRoot: repoRoot).isEmpty)
    }

    @MainActor
    func testProviderCallRecorderFailureThrowsBeforeAuditWhenDurableRunIsMissing() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        let settings = Self.settings(repoRoot: repoRoot, googleAPIKey: "test-google-key")
        let providerPlan = ImageProviderExecutionPlan(requestedModel: .nanoBananaPro, settings: settings)
        let providerError = NSError(
            domain: "PaperBananaProviderRuntimeTests",
            code: 71,
            userInfo: [NSLocalizedDescriptionKey: "Provider failed after returning no usable image."]
        )

        XCTAssertThrowsError(
            try NativeProviderCallRecorder.fail(
                error: providerError,
                repoRoot: repoRoot,
                runID: "missing_native_run",
                callID: "orphan-failure-call",
                workflow: .generation,
                providerPlan: providerPlan
            )
        ) { error in
            guard case PaperBananaRunStoreError.missingRunRecord(let runID) = error else {
                XCTFail("Expected missing durable run record error, got \(error).")
                return
            }
            XCTAssertEqual(runID, "missing_native_run")
        }

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: repoRoot.appendingPathComponent("results/provider_audit").path
            )
        )
        XCTAssertNil(try PaperBananaRunStore.fetchProviderCallSynchronously(callID: "orphan-failure-call", repoRoot: repoRoot))
    }

    @MainActor
    func testProviderCallRecorderTerminalThrowsBeforeAuditWhenDurableRunIsMissing() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        let settings = Self.settings(repoRoot: repoRoot, googleAPIKey: "test-google-key")
        let providerPlan = ImageProviderExecutionPlan(requestedModel: .nanoBananaPro, settings: settings)

        XCTAssertThrowsError(
            try NativeProviderCallRecorder.terminal(
                status: .timedOut,
                message: "Provider call timed out.",
                repoRoot: repoRoot,
                runID: "missing_native_run",
                callID: "orphan-timeout-call",
                workflow: .refinement,
                providerPlan: providerPlan
            )
        ) { error in
            guard case PaperBananaRunStoreError.missingRunRecord(let runID) = error else {
                XCTFail("Expected missing durable run record error, got \(error).")
                return
            }
            XCTAssertEqual(runID, "missing_native_run")
        }

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: repoRoot.appendingPathComponent("results/provider_audit").path
            )
        )
        XCTAssertNil(try PaperBananaRunStore.fetchProviderCallSynchronously(callID: "orphan-timeout-call", repoRoot: repoRoot))
    }

    @MainActor
    func testProviderCompletionBootstrapsRecoveredRunWhenLedgerIsMissing() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        let runDirectory = repoRoot.appendingPathComponent("results/native_generate/missing_native_run", isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        let outputURL = runDirectory.appendingPathComponent("generated_4K.png")
        let rawResponseURL = runDirectory.appendingPathComponent("generated_4K.provider_response.json")
        let rawPayloadURL = runDirectory.appendingPathComponent("generated_4K.provider_raw.bin")
        let response = ProviderResponse(
            provider: .googleGemini,
            model: ImageModelChoice.nanoBananaPro.backendValue,
            callID: "swift-gemini-orphan-completion",
            rawResponseData: Data(#"{"mock":true}"#.utf8),
            imageData: Self.tinyPNGData,
            text: "Provider returned an image.",
            usageMetadata: ["totalTokenCount": "11"]
        )
        var savedRawResponseURL: URL?
        var savedRawPayloadURL: URL?
        var capturedEvents: [(String, Int, String)] = []
        var metadataWriteCalled = false

        let completion = try NativeProviderCompletionCoordinator.completeImageResponse(
            response: response,
            repoRoot: repoRoot,
            runID: "missing_native_run",
            workflow: .generation,
            outputURL: outputURL,
            rawResponseURL: rawResponseURL,
            rawPayloadURL: rawPayloadURL,
            savingMessage: "Saving generated image.",
            successFallbackMessage: "Image generated successfully.",
            failureMessagePrefix: "Failed to save generated image",
            didSaveRawResponse: { savedRawResponseURL = $0 },
            didSaveRawPayload: { savedRawPayloadURL = $0 },
            appendEvent: { stage, progress, message in
                capturedEvents.append((stage, progress, message))
                let event = PaperBananaRunEvent(
                    runID: "missing_native_run",
                    stage: stage,
                    progress: progress,
                    message: message,
                    timestamp: PaperBananaRunStore.timestamp(),
                    rawResponsePath: rawResponseURL.path,
                    rawPayloadPath: stage == "provider_response_saved" ? "" : rawPayloadURL.path,
                    artifactPath: stage == "complete" ? outputURL.path : "",
                    metadataPath: outputURL.deletingPathExtension().appendingPathExtension("json").path,
                    providerCallID: response.callID
                )
                try? PaperBananaRunStore.writeEventSynchronously(event, repoRoot: repoRoot)
            },
            writeMetadata: {
                metadataWriteCalled = true
            }
        )

        XCTAssertEqual(completion.statusMessage, "Provider returned an image.")
        XCTAssertEqual(savedRawResponseURL, rawResponseURL)
        XCTAssertEqual(savedRawPayloadURL, rawPayloadURL)
        XCTAssertTrue(metadataWriteCalled)
        XCTAssertTrue(capturedEvents.contains { $0.0 == "complete" })
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawResponseURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawPayloadURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: completion.artifacts.auditArtifactURL.path))

        let recoveredRun = try XCTUnwrap(
            PaperBananaRunStore.fetchRunSynchronously(id: "missing_native_run", repoRoot: repoRoot)
        )
        XCTAssertEqual(recoveredRun.status, .recovered)
        XCTAssertEqual(recoveredRun.providerCallID, "swift-gemini-orphan-completion")
        XCTAssertEqual(recoveredRun.rawResponsePath, rawResponseURL.path)
        XCTAssertEqual(recoveredRun.rawPayloadPath, rawPayloadURL.path)
        XCTAssertEqual(recoveredRun.artifactPath, outputURL.path)
        XCTAssertEqual(recoveredRun.spendClass, "paid_provider")
        XCTAssertEqual(recoveredRun.recoveryStatus, "raw_payload")

        let providerCall = try XCTUnwrap(
            PaperBananaRunStore.fetchProviderCallSynchronously(
                callID: "swift-gemini-orphan-completion",
                repoRoot: repoRoot
            )
        )
        XCTAssertEqual(providerCall.status, ProviderRunStatus.succeeded.rawValue)
        XCTAssertEqual(providerCall.artifactPaths.map(URL.init(fileURLWithPath:)).map(\.lastPathComponent).sorted(), [
            completion.artifacts.auditArtifactURL.lastPathComponent,
            outputURL.lastPathComponent,
            rawResponseURL.lastPathComponent
        ].sorted())
        XCTAssertEqual(providerCall.usageMetadata["totalTokenCount"], "11")

        let providerEvents = try PaperBananaRunStore.fetchProviderCallEventsSynchronously(
            callID: "swift-gemini-orphan-completion",
            repoRoot: repoRoot
        )
        XCTAssertEqual(providerEvents.map(\.status), [
            ProviderRunStatus.running.rawValue,
            ProviderRunStatus.running.rawValue,
            ProviderRunStatus.succeeded.rawValue
        ])
        XCTAssertEqual(providerEvents.last?.usageMetadata["totalTokenCount"], "11")
    }

    func testLegacyPythonProviderClientBuildsGenerationProcessWithProviderEnvironment() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        let settings = Self.settings(repoRoot: repoRoot, googleAPIKey: "test-google-key")
        let providerPlan = ImageProviderExecutionPlan(requestedModel: .nanoBanana2, settings: settings)
        let outputDirectory = repoRoot.appendingPathComponent("results/native_generate", isDirectory: true)

        let process = LegacyPythonProviderClient(providerKind: providerPlan.provider).makeProcess(
            for: LegacyPythonProviderRequest(
                workflow: .generation,
                repoRoot: repoRoot,
                runID: "native_generate_provider_runtime_test",
                sourceURL: nil,
                prompt: "Create a test figure.",
                providerPlan: providerPlan,
                resolution: "2K",
                aspectRatio: "16:9",
                task: "scientific diagram",
                outputDirectory: outputDirectory,
                dryRun: true,
                mockProviderMode: nil
            ),
            settings: settings
        )

        XCTAssertEqual(process.executableURL, repoRoot.appendingPathComponent(".venv/bin/python"))
        XCTAssertEqual(process.currentDirectoryURL, repoRoot)
        XCTAssertEqual(process.arguments?.prefix(2), ["-m", "paperbanana_gui.native_generate"])
        XCTAssertTrue(process.arguments?.contains("--dry-run") == true)
        XCTAssertEqual(process.environment?["PAPERBANANA_IMAGE_PROVIDER_KIND"], "google_gemini")
        XCTAssertEqual(process.environment?["PAPERBANANA_EFFECTIVE_IMAGE_MODEL"], ImageModelChoice.nanoBanana2.backendValue)
        XCTAssertEqual(process.environment?["PAPERBANANA_CAN_SPEND_PROVIDER_CREDITS"], "1")
        XCTAssertEqual(process.environment?["GOOGLE_API_KEY"], "test-google-key")
    }

    func testLegacyPythonProviderClientExecutesThroughProviderProtocolAndReturnsImageBytes() async throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        try Self.installFakePythonExecutable(repoRoot: repoRoot)
        let settings = Self.settings(repoRoot: repoRoot, googleAPIKey: "secret-google-key")
        let providerRequestURL = repoRoot
            .appendingPathComponent("results/native_generate/native_generate_provider_runtime_test/provider_request.json")
        let client: any ProviderClient = LegacyPythonProviderClient(
            providerKind: .codexFallback,
            dryRun: true
        )
        let progressEvents = ProviderProgressEventCollector()

        let response = try await client.execute(
            ProviderClientRequest(
                runID: "native_generate_provider_runtime_test",
                callID: "legacy-call-from-request",
                workflow: .generation,
                prompt: "Create a test figure.",
                sourceImageURL: nil,
                model: .codexFallback,
                effectiveModel: ImageModelChoice.codexFallback.backendValue,
                resolution: "2K",
                aspectRatio: "16:9",
                task: "scientific diagram",
                settings: settings,
                providerRequestURL: providerRequestURL
            ),
            eventHandler: { event in
                progressEvents.append(event)
            }
        )

        let capturedEvents = progressEvents.events()
        XCTAssertEqual(response.provider, .codexFallback)
        XCTAssertEqual(response.model, ImageModelChoice.codexFallback.backendValue)
        XCTAssertEqual(response.callID, "fake-legacy-call")
        XCTAssertEqual(response.imageData, Data(base64Encoded: Self.tinyPNGBase64))
        XCTAssertTrue(response.text.contains("Fake legacy complete"))
        XCTAssertEqual(response.usageMetadata["legacy_process_status"], "0")
        XCTAssertTrue(String(data: response.rawResponseData, encoding: .utf8)?.contains("legacy_python") == true)
        XCTAssertEqual(capturedEvents.map(\.stage), ["provider_request_saved", "complete"])
        XCTAssertEqual(capturedEvents.first?.callID, "legacy-call-from-request")
        XCTAssertEqual(capturedEvents.last?.callID, "fake-legacy-call")
        XCTAssertEqual(capturedEvents.last?.nativeRunEvent?.runID, "native_generate_provider_runtime_test")
        XCTAssertEqual(capturedEvents.last?.nativeRunEvent?.outputURL?.lastPathComponent, "generated_2K.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: providerRequestURL.path))
        let manifestData = try Data(contentsOf: providerRequestURL)
        let manifestText = try XCTUnwrap(String(data: manifestData, encoding: .utf8))
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: manifestData) as? [String: Any])
        XCTAssertEqual(manifest["adapter"] as? String, "legacy_python")
        XCTAssertEqual(manifest["run_id"] as? String, "native_generate_provider_runtime_test")
        XCTAssertEqual(manifest["call_id"] as? String, "legacy-call-from-request")
        XCTAssertEqual(manifest["workflow"] as? String, "native_generate")
        XCTAssertEqual(manifest["python_executable_path"] as? String, repoRoot.appendingPathComponent(".venv/bin/python").path)
        XCTAssertTrue((manifest["command_arguments"] as? [String])?.contains("paperbanana_gui.native_generate") == true)
        XCTAssertFalse(manifestText.contains("secret-google-key"))
    }

    func testCodexFallbackProviderClientExecutesNativeHandoffAndReturnsImageBytes() async throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        let codexExecutableURL = try Self.installFakeCodexExecutable(repoRoot: repoRoot)
        let outputURL = repoRoot
            .appendingPathComponent("results/native_generate/native_generate_provider_runtime_test/generated_2K.png")
        let providerRequestURL = outputURL
            .deletingLastPathComponent()
            .appendingPathComponent("provider_request.json")
        let settings = Self.settings(repoRoot: repoRoot)
        let client: any ProviderClient = CodexFallbackProviderClient(
            codexExecutableURL: codexExecutableURL,
            timeoutSeconds: 5,
            pollInterval: 0.05,
            extraEnvironment: [
                "PAPERBANANA_FAKE_CODEX_IMAGE_BASE64": Self.tinyPNGBase64
            ]
        )
        let progressEvents = ProviderProgressEventCollector()

        let response = try await client.execute(
            ProviderClientRequest(
                runID: "native_generate_provider_runtime_test",
                callID: "swift-codex-test-call",
                workflow: .generation,
                prompt: "Create a test figure.",
                sourceImageURL: nil,
                model: .codexFallback,
                effectiveModel: ImageModelChoice.codexFallback.backendValue,
                resolution: "2K",
                aspectRatio: "16:9",
                task: "scientific diagram",
                settings: settings,
                outputURL: outputURL,
                providerRequestURL: providerRequestURL
            ),
            eventHandler: { event in
                progressEvents.append(event)
            }
        )

        let capturedEvents = progressEvents.events()
        XCTAssertEqual(response.provider, .codexFallback)
        XCTAssertEqual(response.model, ImageModelChoice.codexFallback.backendValue)
        XCTAssertEqual(response.callID, "swift-codex-test-call")
        XCTAssertEqual(response.imageData, Data(base64Encoded: Self.tinyPNGBase64))
        XCTAssertEqual(response.usageMetadata["provider_spend"], "none")
        XCTAssertEqual(response.usageMetadata["handoff_adapter"], "swift_codex")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: providerRequestURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: response.usageMetadata["prompt_path"] ?? ""))
        XCTAssertTrue(FileManager.default.fileExists(atPath: response.usageMetadata["log_path"] ?? ""))
        XCTAssertTrue(String(data: response.rawResponseData, encoding: .utf8)?.contains("swift_codex") == true)
        let providerRequestPayload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: providerRequestURL)) as? [String: Any])
        XCTAssertEqual(providerRequestPayload["adapter"] as? String, "swift_codex")
        XCTAssertEqual(providerRequestPayload["output_path"] as? String, outputURL.path)
        XCTAssertEqual(providerRequestPayload["call_id"] as? String, "swift-codex-test-call")
        XCTAssertEqual(capturedEvents.first?.stage, "provider_request_saved")
        XCTAssertTrue(capturedEvents.map(\.stage).contains("prepared"))
        XCTAssertTrue(capturedEvents.map(\.stage).contains("started"))
    }

    func testReadinessSnapshotSurfacesPathKeysBackendAndCodexFallback() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        try Self.installFakePythonExecutable(repoRoot: repoRoot)
        try Data("print('backend')\n".utf8).write(to: repoRoot.appendingPathComponent("app.py"))

        let snapshot = PaperBananaReadinessSnapshot.make(
            settings: Self.settings(repoRoot: repoRoot),
            requestedModel: .nanoBananaPro
        )

        XCTAssertEqual(snapshot.statusTitle, "Ready with Codex Fallback")
        XCTAssertEqual(snapshot.severity, .warning)
        XCTAssertEqual(snapshot.configuredPathRow.value, repoRoot.path)
        XCTAssertEqual(snapshot.configuredPathRow.severity, .ready)
        XCTAssertEqual(snapshot.generationKeyRow.value, "No generation key saved")
        XCTAssertEqual(snapshot.generationKeyRow.severity, .warning)
        XCTAssertEqual(snapshot.backendValidityRow.value, "Compatibility backend valid")
        XCTAssertEqual(snapshot.backendValidityRow.severity, .ready)
        XCTAssertTrue(snapshot.deterministicFallbackRow.value.contains("Nano Banana Pro resolves to Codex fallback"))
        XCTAssertTrue(snapshot.deterministicFallbackRow.detail.contains("no provider API spend"))
        XCTAssertEqual(snapshot.deterministicFallbackRow.severity, .ready)
    }

    func testReadinessSnapshotSurfacesPaidProviderWhenGenerationKeyExists() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        try Self.installFakePythonExecutable(repoRoot: repoRoot)
        try Data("print('backend')\n".utf8).write(to: repoRoot.appendingPathComponent("app.py"))

        let snapshot = PaperBananaReadinessSnapshot.make(
            settings: Self.settings(repoRoot: repoRoot, googleAPIKey: "test-google-key"),
            requestedModel: .nanoBananaPro
        )

        XCTAssertEqual(snapshot.statusTitle, "Ready")
        XCTAssertEqual(snapshot.severity, .ready)
        XCTAssertEqual(snapshot.generationKeyRow.value, "Google key saved")
        XCTAssertEqual(snapshot.deterministicFallbackRow.value, "Google Gemini via Google API key")
        XCTAssertTrue(snapshot.deterministicFallbackRow.detail.contains("can spend provider credits"))
    }

    private static func makeTemporaryRepoRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaProviderRuntimeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func settings(
        repoRoot: URL = URL(fileURLWithPath: "/tmp/PaperBanana", isDirectory: true),
        googleAPIKey: String = "",
        openRouterAPIKey: String = ""
    ) -> PaperBananaSettingsSnapshot {
        PaperBananaSettingsSnapshot(
            repoPath: repoRoot.path,
            serverPort: 7860,
            defaultImageModel: .nanoBananaPro,
            codexModel: "gpt-5.5",
            codexReasoning: "xhigh",
            googleAPIKey: googleAPIKey,
            openRouterAPIKey: openRouterAPIKey
        )
    }

    private static func mockProviderSession(
        statusCode: Int = 200,
        responseData: Data
    ) -> URLSession {
        MockProviderURLProtocol.statusCode = statusCode
        MockProviderURLProtocol.responseData = responseData
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockProviderURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func installFakePythonExecutable(repoRoot: URL) throws {
        let binDirectory = repoRoot.appendingPathComponent(".venv/bin", isDirectory: true)
        try FileManager.default.createDirectory(at: binDirectory, withIntermediateDirectories: true)
        let executableURL = binDirectory.appendingPathComponent("python")
        let script = """
        #!/usr/bin/env python3
        import base64
        import json
        import pathlib
        import sys

        def value_after(flag, default=""):
            if flag not in sys.argv:
                return default
            index = sys.argv.index(flag)
            if index + 1 >= len(sys.argv):
                return default
            return sys.argv[index + 1]

        output_dir = pathlib.Path(value_after("--output-dir"))
        run_id = value_after("--run-id")
        resolution = value_after("--resolution", "2K")
        run_dir = output_dir / run_id
        run_dir.mkdir(parents=True, exist_ok=True)
        output = run_dir / f"generated_{resolution}.png"
        output.write_bytes(base64.b64decode("\(tinyPNGBase64)"))
        print(json.dumps({
            "stage": "complete",
            "progress": 100,
            "message": "Fake legacy complete.",
            "run_id": run_id,
            "run_dir": str(run_dir),
            "output_path": str(output),
            "metadata_path": str(output.with_suffix(".json")),
            "prompt_path": str(run_dir / "prompt.txt"),
            "request_path": str(run_dir / "request.json"),
            "call_id": "fake-legacy-call",
            "raw_response_path": "",
            "raw_path": "",
            "log_path": str(run_dir / "events.jsonl")
        }), flush=True)
        """
        try script.write(to: executableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)
    }

    private static func installFakeCodexExecutable(repoRoot: URL) throws -> URL {
        let binDirectory = repoRoot.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: binDirectory, withIntermediateDirectories: true)
        let executableURL = binDirectory.appendingPathComponent("codex-fake")
        let script = """
        #!/usr/bin/env python3
        import base64
        import os
        import pathlib
        import re
        import sys

        prompt = sys.argv[-1]
        match = re.search(r"(?:directly at:|Output path:)\\s*\\n([^\\n]+)", prompt)
        if match is None:
            print("No output path in prompt", file=sys.stderr)
            sys.exit(12)
        output = pathlib.Path(match.group(1).strip())
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(base64.b64decode(os.environ["PAPERBANANA_FAKE_CODEX_IMAGE_BASE64"]))
        print(f"fake codex wrote {output}")
        """
        try script.write(to: executableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)
        return executableURL
    }

    private static let tinyPNGBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC"

    private static var tinyPNGData: Data {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 4,
            bitsPerPixel: 32
        )!
        bitmap.setColor(NSColor(calibratedRed: 0, green: 0.45, blue: 1, alpha: 1), atX: 0, y: 0)
        return bitmap.representation(using: .png, properties: [:])!
    }
}

private final class ProviderProgressEventCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var capturedEvents: [ProviderProgressEvent] = []

    func append(_ event: ProviderProgressEvent) {
        lock.lock()
        capturedEvents.append(event)
        lock.unlock()
    }

    func events() -> [ProviderProgressEvent] {
        lock.lock()
        defer { lock.unlock() }
        return capturedEvents
    }
}

private final class MockProviderURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var responseData = Data()

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
