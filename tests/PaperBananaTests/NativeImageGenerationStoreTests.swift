import AppKit
import Foundation
import XCTest
@testable import PaperBanana

final class NativeImageGenerationStoreTests: XCTestCase {
    func testProviderExecutionPlanUsesGoogleForPaidModelWhenGoogleCredentialExists() {
        let settings = PaperBananaSettingsSnapshot(
            repoPath: "/tmp/PaperBanana",
            serverPort: 7860,
            defaultImageModel: .nanoBananaPro,
            codexModel: "gpt-5.5",
            codexReasoning: "xhigh",
            googleAPIKey: "test-google-key",
            openRouterAPIKey: ""
        )

        let plan = ImageProviderExecutionPlan(requestedModel: .nanoBananaPro, settings: settings)

        XCTAssertEqual(plan.requestedModel, .nanoBananaPro)
        XCTAssertEqual(plan.effectiveModel, .nanoBananaPro)
        XCTAssertEqual(plan.provider, .googleGemini)
        XCTAssertEqual(plan.credentialSource, .googleAPIKey)
        XCTAssertTrue(plan.canSpendProviderCredits)
        XCTAssertEqual(plan.spendClass, "paid_provider")
        XCTAssertEqual(plan.providerLabel, "Google Gemini")

        var environment: [String: String] = [:]
        plan.applyEnvironment(settings: settings, to: &environment)
        XCTAssertEqual(environment["PAPERBANANA_IMAGE_PROVIDER_KIND"], "google_gemini")
        XCTAssertEqual(environment["PAPERBANANA_CAN_SPEND_PROVIDER_CREDITS"], "1")
        XCTAssertEqual(environment["PAPERBANANA_EFFECTIVE_IMAGE_MODEL"], ImageModelChoice.nanoBananaPro.backendValue)
        XCTAssertEqual(environment["GOOGLE_API_KEY"], "test-google-key")
        XCTAssertNil(environment["OPENROUTER_API_KEY"])
    }

    func testProviderExecutionPlanFallsBackToCodexWithoutProviderCredential() {
        let settings = PaperBananaSettingsSnapshot(
            repoPath: "/tmp/PaperBanana",
            serverPort: 7860,
            defaultImageModel: .nanoBananaPro,
            codexModel: "gpt-5.5",
            codexReasoning: "xhigh",
            googleAPIKey: "",
            openRouterAPIKey: ""
        )

        let plan = ImageProviderExecutionPlan(requestedModel: .nanoBananaPro, settings: settings)

        XCTAssertEqual(plan.requestedModel, .nanoBananaPro)
        XCTAssertEqual(plan.effectiveModel, .codexFallback)
        XCTAssertEqual(plan.provider, .codexFallback)
        XCTAssertEqual(plan.credentialSource, .codexApp)
        XCTAssertFalse(plan.canSpendProviderCredits)
        XCTAssertEqual(plan.spendClass, "codex_fallback")

        var environment: [String: String] = [:]
        plan.applyEnvironment(settings: settings, to: &environment)
        XCTAssertEqual(environment["PAPERBANANA_IMAGE_PROVIDER_KIND"], "codex_fallback")
        XCTAssertEqual(environment["PAPERBANANA_CAN_SPEND_PROVIDER_CREDITS"], "0")
        XCTAssertEqual(environment["PAPERBANANA_REQUESTED_IMAGE_MODEL"], ImageModelChoice.nanoBananaPro.backendValue)
        XCTAssertEqual(environment["PAPERBANANA_EFFECTIVE_IMAGE_MODEL"], ImageModelChoice.codexFallback.backendValue)
        XCTAssertEqual(environment["PAPERBANANA_CODEX_MODEL"], "gpt-5.5")
        XCTAssertEqual(environment["PAPERBANANA_CODEX_REASONING_EFFORT"], "xhigh")
        XCTAssertNil(environment["GOOGLE_API_KEY"])
        XCTAssertNil(environment["OPENROUTER_API_KEY"])
    }

    func testFoundationAssistantFallbackImprovesPromptWithoutProviderSpend() async {
        let result = await PaperBananaFoundationAssistant.run(
            task: .improvePrompt,
            input: "Create a CIED MR-linac workflow figure.",
            context: "Resolution: 4K. Aspect ratio: 16:9.",
            preferFoundationModels: false
        )

        XCTAssertEqual(result.task, .improvePrompt)
        XCTAssertFalse(result.usedFoundationModels)
        XCTAssertEqual(result.fallbackReason, "Foundation Models disabled for this request.")
        XCTAssertTrue(result.text.contains("Create a CIED MR-linac workflow figure."))
        XCTAssertTrue(result.text.contains("Requirements:"))
        XCTAssertTrue(result.text.contains("legible typography"))
    }

    func testFoundationAssistantFallbackImprovesStatisticalPlotPromptFromContext() async {
        let result = await PaperBananaFoundationAssistant.run(
            task: .improvePrompt,
            input: "Compare AUC across cohorts.",
            context: "Task: statistical plot. Resolution: 4K. Aspect ratio: 16:9.",
            preferFoundationModels: false
        )

        XCTAssertEqual(result.task, .improvePrompt)
        XCTAssertFalse(result.usedFoundationModels)
        XCTAssertEqual(result.fallbackReason, "Foundation Models disabled for this request.")
        XCTAssertTrue(result.text.contains("Compare AUC across cohorts."))
        let lowercasedText = result.text.lowercased()
        XCTAssertTrue(lowercasedText.contains("statistical plot"))
        XCTAssertTrue(lowercasedText.contains("data series"))
        XCTAssertTrue(lowercasedText.contains("x-axis"))
        XCTAssertTrue(lowercasedText.contains("y-axis"))
        XCTAssertTrue(lowercasedText.contains("visual encoding"))
        XCTAssertFalse(lowercasedText.contains("scientific diagram"))
        XCTAssertFalse(lowercasedText.contains("workflow logic"))
        XCTAssertFalse(lowercasedText.contains("clear panel structure"))
        XCTAssertFalse(lowercasedText.contains("aligned connectors"))
    }

    func testFoundationAssistantExtractTextAcceptsImageInputWithoutProviderSpend() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaAssistantImageTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let imageURL = root.appendingPathComponent("candidate.png")
        try Self.writeTinyPNG(to: imageURL)

        let result = await PaperBananaFoundationAssistant.run(
            task: .extractText,
            input: "Panel A\n\nPanel B",
            imageURL: imageURL,
            preferFoundationModels: false
        )

        XCTAssertEqual(result.task, .extractText)
        XCTAssertFalse(result.usedFoundationModels)
        XCTAssertEqual(result.text, "Panel A\nPanel B")
        XCTAssertEqual(result.fallbackReason, "Foundation Models disabled for this request.")
    }

    func testFoundationAssistantGeneratesStructuredMetadataWithoutProviderSpend() async throws {
        let result = await PaperBananaFoundationAssistant.run(
            task: .generateMetadata,
            input: "Run: native_generate_4k\nModel: Nano Banana Pro\nOutput path: /tmp/output.png",
            context: "Recovered: no\nPrompt preview: CIED MR-linac workflow figure",
            preferFoundationModels: false
        )

        XCTAssertEqual(result.task, .generateMetadata)
        XCTAssertFalse(result.usedFoundationModels)
        XCTAssertEqual(result.fallbackReason, "Foundation Models disabled for this request.")
        let data = try XCTUnwrap(result.text.data(using: .utf8))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(payload["workflow"] as? String, "paperbanana")
        XCTAssertEqual(payload["provider_spend"] as? String, "none")
        XCTAssertEqual(payload["contains_output_signal"] as? Bool, true)
        XCTAssertEqual(payload["contains_recovery_signal"] as? Bool, true)
        XCTAssertNotNil(payload["artifact_name"] as? String)
    }

    func testIntentBridgeConsumesRequestedDestinationOnce() {
        PaperBananaIntentBridge.request(.artifactLibrary)

        XCTAssertEqual(PaperBananaIntentBridge.consume(), .artifactLibrary)
        XCTAssertNil(PaperBananaIntentBridge.consume())
    }

    func testPreflightPlanPredictsGenerationTraceBeforeLaunch() throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaGenerationPreflight-\(UUID().uuidString)", isDirectory: true)
        let request = NativeImageGenerationRequest(
            prompt: "Create a preflighted paid image request.",
            model: .nanoBananaPro,
            resolution: "4K",
            aspectRatio: "16:9",
            task: "scientific diagram",
            settings: PaperBananaSettingsSnapshot(
                repoPath: repoRoot.path,
                serverPort: 7860,
                defaultImageModel: .nanoBananaPro,
                codexModel: "gpt-5.5",
                codexReasoning: "xhigh",
                googleAPIKey: "test-google-key",
                openRouterAPIKey: ""
            )
        )

        let plan = NativeRunPreflightPlan.generation(request: request, runID: "native_generate_20260430_120000")

        XCTAssertEqual(plan.workflow, "Generation")
        XCTAssertEqual(plan.providerLabel, "Google Gemini")
        XCTAssertEqual(plan.modelLabel, "Nano Banana Pro")
        XCTAssertEqual(plan.credentialSource, "Google API key")
        XCTAssertEqual(plan.spendSafetyLabel, "Can spend provider credits")
        XCTAssertEqual(plan.resolution, "4K")
        XCTAssertEqual(plan.aspectRatio, "16:9")
        XCTAssertEqual(plan.runID, "native_generate_20260430_120000")
        XCTAssertEqual(plan.runDirectoryURL.path, repoRoot.appendingPathComponent("results/native_generate/native_generate_20260430_120000").path)
        XCTAssertEqual(plan.outputURL.lastPathComponent, "generated_4K.png")
        XCTAssertEqual(plan.requestURL.lastPathComponent, "request.json")
        XCTAssertTrue(plan.usesPaidProvider)
    }

    func testPreflightPlanTreatsDryRunAsNoProviderSpend() throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaGenerationDryRunPreflight-\(UUID().uuidString)", isDirectory: true)
        let request = NativeImageGenerationRequest(
            prompt: "Create a dry run request.",
            model: .nanoBananaPro,
            resolution: "2K",
            aspectRatio: "16:9",
            task: "scientific diagram",
            settings: PaperBananaSettingsSnapshot(
                repoPath: repoRoot.path,
                serverPort: 7860,
                defaultImageModel: .nanoBananaPro,
                codexModel: "gpt-5.5",
                codexReasoning: "xhigh",
                googleAPIKey: "test-google-key",
                openRouterAPIKey: ""
            ),
            executionMode: .dryRun
        )

        let plan = NativeRunPreflightPlan.generation(request: request, runID: "native_generate_20260430_121500")

        XCTAssertEqual(plan.providerLabel, "Google Gemini")
        XCTAssertEqual(plan.modelLabel, "Nano Banana Pro")
        XCTAssertEqual(plan.credentialSource, "Google API key")
        XCTAssertEqual(plan.spendSafetyLabel, "No provider API spend (local dry run)")
        XCTAssertFalse(plan.usesPaidProvider)
        XCTAssertEqual(plan.runDirectoryURL.path, repoRoot.appendingPathComponent("results/native_generate/native_generate_20260430_121500").path)
    }

    @MainActor
    func testStartCreatesDurableGenerationRunRecordBeforeProcessLaunchFailure() throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaGenerationTrace-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let store = NativeImageGenerationStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            providerClientFactory: ProviderClientFactory(
                codexClient: BlockingNativeProviderClient(providerKind: .codexFallback)
            )
        )
        store.start(
            request: NativeImageGenerationRequest(
                prompt: "Create a durable generation record before provider launch.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
                task: "scientific diagram",
                settings: PaperBananaSettingsSnapshot(
                    repoPath: repoRoot.path,
                    serverPort: 7860,
                    defaultImageModel: .nanoBananaPro,
                    codexModel: "gpt-5.5",
                    codexReasoning: "xhigh",
                    googleAPIKey: "",
                    openRouterAPIKey: ""
                )
            ),
            onCompletion: { _ in }
        )

        let runDirectory = try XCTUnwrap(store.runDirectoryURL)
        let requestURL = runDirectory.appendingPathComponent("request.json")
        let eventLogURL = runDirectory.appendingPathComponent("events.jsonl")
        let promptURL = runDirectory.appendingPathComponent("prompt.txt")

        XCTAssertTrue(FileManager.default.fileExists(atPath: runDirectory.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: requestURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: eventLogURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: promptURL.path))

        let requestData = try Data(contentsOf: requestURL)
        let requestPayload = try XCTUnwrap(JSONSerialization.jsonObject(with: requestData) as? [String: Any])
        XCTAssertEqual(requestPayload["prompt"] as? String, "Create a durable generation record before provider launch.")
        XCTAssertEqual(requestPayload["model"] as? String, ImageModelChoice.codexFallback.backendValue)
        XCTAssertEqual(requestPayload["requested_model"] as? String, ImageModelChoice.nanoBananaPro.backendValue)
        XCTAssertEqual(requestPayload["provider"] as? String, "Codex")
        XCTAssertEqual(requestPayload["provider_kind"] as? String, "codex_fallback")
        XCTAssertEqual(requestPayload["credential_source"] as? String, "codex_app")
        XCTAssertEqual(requestPayload["spend_class"] as? String, "codex_fallback")
        XCTAssertEqual(requestPayload["can_spend_provider_credits"] as? Bool, false)
        XCTAssertNil(requestPayload["google_api_key"])
        XCTAssertNil(requestPayload["GOOGLE_API_KEY"])
        XCTAssertEqual(requestPayload["workflow"] as? String, "native_generate")
        XCTAssertEqual(requestPayload["output_path"] as? String, store.outputURL?.path)
        XCTAssertEqual(requestPayload["provider_request_path"] as? String, store.providerRequestURL?.path)

        let initialEvents = try String(contentsOf: eventLogURL, encoding: .utf8)
        XCTAssertTrue(initialEvents.contains(#""stage":"queued""#), initialEvents)

        store.cancel()
    }

    @MainActor
    func testGenerationRunRecordsManualReferenceExamplesInArtifactsAndProviderPrompt() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaManualReferenceGeneration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let reference = ReferenceExampleSelection(
            id: "diagram_042",
            visualIntent: "Show a planner, visualizer, and critic loop.",
            contentSummary: "Agent loop with retrieval-guided planning and iterative critique.",
            imagePath: "images/diagram_042.png"
        )
        let store = NativeImageGenerationStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            providerClientFactory: ProviderClientFactory(
                googleClient: MockNativeProviderClient(
                    imageData: Self.tinyPNGData,
                    text: "Mock native image generated with references.",
                    usageMetadata: ["totalTokenCount": "55"]
                )
            )
        )

        store.start(
            request: NativeImageGenerationRequest(
                prompt: "Create a native PaperBanana diagram with manual references.",
                model: .nanoBananaPro,
                resolution: "2K",
                aspectRatio: "16:9",
                task: "scientific diagram",
                settings: PaperBananaSettingsSnapshot(
                    repoPath: repoRoot.path,
                    serverPort: 7860,
                    defaultImageModel: .nanoBananaPro,
                    codexModel: "gpt-5.5",
                    codexReasoning: "xhigh",
                    googleAPIKey: "test-google-key",
                    openRouterAPIKey: ""
                ),
                referenceExamples: [reference]
            ),
            onCompletion: { _ in }
        )

        try await Self.waitForGenerationStore(store) {
            if case .complete = $0.runState { return true }
            return false
        }

        let requestURL = try XCTUnwrap(store.requestURL)
        let providerRequestURL = try XCTUnwrap(store.providerRequestURL)
        let metadataURL = try XCTUnwrap(store.metadataURL)

        let requestPayload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: requestURL)) as? [String: Any])
        XCTAssertEqual(requestPayload["source_prompt"] as? String, "Create a native PaperBanana diagram with manual references.")
        XCTAssertEqual(requestPayload["reference_mode"] as? String, "manual_native_prompt_enrichment")
        XCTAssertEqual(requestPayload["reference_example_count"] as? Int, 1)
        let requestPrompt = try XCTUnwrap(requestPayload["prompt"] as? String)
        XCTAssertTrue(requestPrompt.contains("Selected Reference Examples"))
        let requestReferences = try XCTUnwrap(requestPayload["reference_examples"] as? [[String: Any]])
        let requestReference = try XCTUnwrap(requestReferences.first)
        XCTAssertEqual(requestReference["id"] as? String, "diagram_042")
        XCTAssertEqual(requestReference["image_path"] as? String, "images/diagram_042.png")
        XCTAssertNil(requestReference["image_available"])
        XCTAssertNil(requestReference["imageAvailable"])

        let providerPayload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: providerRequestURL)) as? [String: Any])
        let providerPrompt = try XCTUnwrap(providerPayload["prompt"] as? String)
        XCTAssertEqual(providerPrompt, requestPrompt)
        XCTAssertTrue(providerPrompt.contains("Selected Reference Examples"))
        XCTAssertTrue(providerPrompt.contains("ID: diagram_042"))
        XCTAssertTrue(providerPrompt.contains("Image path: images/diagram_042.png"))
        XCTAssertFalse(providerPrompt.contains("image_available"))
        XCTAssertFalse(providerPrompt.contains("imageAvailable"))
        XCTAssertFalse(providerPrompt.contains("Image missing."))
        XCTAssertFalse(providerPrompt.contains("Image available."))

        let metadata = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL)) as? [String: Any])
        XCTAssertEqual(metadata["source_prompt"] as? String, "Create a native PaperBanana diagram with manual references.")
        XCTAssertEqual(metadata["reference_mode"] as? String, "manual_native_prompt_enrichment")
        XCTAssertEqual(metadata["reference_example_count"] as? Int, 1)
        let metadataPrompt = try XCTUnwrap(metadata["prompt"] as? String)
        XCTAssertEqual(metadataPrompt, providerPrompt)
        let metadataReferences = try XCTUnwrap(metadata["reference_examples"] as? [[String: Any]])
        let metadataReference = try XCTUnwrap(metadataReferences.first)
        XCTAssertEqual(metadataReference["id"] as? String, "diagram_042")
        XCTAssertNil(metadataReference["image_available"])
        XCTAssertNil(metadataReference["imageAvailable"])
    }

    @MainActor
    func testNativeGoogleGenerationWritesOutputLedgerAndProviderAuditWithoutPython() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeGoogleSuccess-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let store = NativeImageGenerationStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            providerClientFactory: ProviderClientFactory(
                googleClient: MockNativeProviderClient(
                    imageData: Self.tinyPNGData,
                    text: "Mock native image generated.",
                    usageMetadata: ["totalTokenCount": "42"]
                )
            )
        )

        store.start(
            request: NativeImageGenerationRequest(
                prompt: "Create a Swift-native provider figure.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
                task: "scientific diagram",
                settings: PaperBananaSettingsSnapshot(
                    repoPath: repoRoot.path,
                    serverPort: 7860,
                    defaultImageModel: .nanoBananaPro,
                    codexModel: "gpt-5.5",
                    codexReasoning: "xhigh",
                    googleAPIKey: "test-google-key",
                    openRouterAPIKey: ""
                )
            ),
            onCompletion: { _ in }
        )

        try await Self.waitForGenerationStore(store) {
            if case .complete = $0.runState { return true }
            return false
        }

        let outputURL = try XCTUnwrap(store.outputURL)
        let rawResponseURL = try XCTUnwrap(store.rawResponseURL)
        let rawPayloadURL = try XCTUnwrap(store.rawPayloadURL)
        let providerRequestURL = try XCTUnwrap(store.providerRequestURL)
        let metadataURL = try XCTUnwrap(store.metadataURL)
        let runID = store.runID
        let callID = store.providerCallID

        XCTAssertTrue(callID.hasPrefix("swift-gemini-"))
        XCTAssertEqual(outputURL.standardizedFileURL, store.outputURL?.standardizedFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawResponseURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawPayloadURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: providerRequestURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataURL.path))
        XCTAssertEqual(store.runState, .complete(outputURL))

        let record = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot))
        XCTAssertEqual(record.status, .completed)
        XCTAssertEqual(record.providerKind, "google_gemini")
        XCTAssertEqual(record.model, ImageModelChoice.nanoBananaPro.backendValue)
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.providerRequestPath, providerRequestURL.path)
        XCTAssertEqual(record.rawResponsePath, rawResponseURL.path)
        XCTAssertEqual(record.rawPayloadPath, rawPayloadURL.path)
        XCTAssertEqual(record.artifactPath, outputURL.path)

        let metadata = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL)) as? [String: Any])
        XCTAssertEqual(metadata["provider_call_id"] as? String, callID)
        XCTAssertEqual(metadata["provider_request_path"] as? String, providerRequestURL.path)
        XCTAssertEqual((metadata["usage_metadata"] as? [String: String])?["totalTokenCount"], "42")

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let call = try XCTUnwrap(calls.first { $0.callID == callID })
        XCTAssertEqual(call.status, .succeeded)
        XCTAssertEqual(call.runID, runID)
        XCTAssertEqual(call.usageMetadata["totalTokenCount"], "42")
        XCTAssertEqual(call.nativeArtifactURLs.map(\.standardizedFileURL), [outputURL.standardizedFileURL])
        XCTAssertTrue(call.artifactURLs.contains { $0.path.contains("/results/provider_audit/images/") })
    }

    @MainActor
    func testNativeOpenRouterGenerationWritesOutputLedgerWithoutPython() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeOpenRouterGeneration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let store = NativeImageGenerationStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            providerClientFactory: ProviderClientFactory(
                openRouterClient: MockNativeProviderClient(
                    providerKind: .openRouter,
                    imageData: Self.tinyPNGData,
                    text: "Mock OpenRouter image generated.",
                    usageMetadata: ["total_tokens": "64"]
                )
            )
        )

        store.start(
            request: NativeImageGenerationRequest(
                prompt: "Create a Swift-native OpenRouter figure.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
                task: "scientific diagram",
                settings: PaperBananaSettingsSnapshot(
                    repoPath: repoRoot.path,
                    serverPort: 7860,
                    defaultImageModel: .nanoBananaPro,
                    codexModel: "gpt-5.5",
                    codexReasoning: "xhigh",
                    googleAPIKey: "",
                    openRouterAPIKey: "test-openrouter-key"
                )
            ),
            onCompletion: { _ in }
        )

        try await Self.waitForGenerationStore(store) {
            if case .complete = $0.runState { return true }
            return false
        }

        let outputURL = try XCTUnwrap(store.outputURL)
        let rawResponseURL = try XCTUnwrap(store.rawResponseURL)
        let rawPayloadURL = try XCTUnwrap(store.rawPayloadURL)
        let providerRequestURL = try XCTUnwrap(store.providerRequestURL)
        let metadataURL = try XCTUnwrap(store.metadataURL)
        let runID = store.runID
        let callID = store.providerCallID

        XCTAssertTrue(callID.hasPrefix("swift-openrouter-"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawResponseURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawPayloadURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: providerRequestURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataURL.path))

        let providerRequest = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: providerRequestURL)) as? [String: Any])
        XCTAssertEqual(providerRequest["provider"] as? String, "openrouter")
        XCTAssertNil(providerRequest["adapter"])

        let record = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot))
        XCTAssertEqual(record.status, .completed)
        XCTAssertEqual(record.providerKind, "openrouter")
        XCTAssertEqual(record.model, ImageModelChoice.nanoBananaPro.backendValue)
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.providerRequestPath, providerRequestURL.path)
        XCTAssertEqual(record.rawResponsePath, rawResponseURL.path)
        XCTAssertEqual(record.rawPayloadPath, rawPayloadURL.path)
        XCTAssertEqual(record.artifactPath, outputURL.path)
        XCTAssertEqual(record.spendClass, "paid_provider")

        let metadata = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL)) as? [String: Any])
        XCTAssertEqual(metadata["provider_call_id"] as? String, callID)
        XCTAssertEqual(metadata["provider_request_path"] as? String, providerRequestURL.path)
        XCTAssertEqual((metadata["usage_metadata"] as? [String: String])?["total_tokens"], "64")

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let call = try XCTUnwrap(calls.first { $0.callID == callID })
        XCTAssertEqual(call.status, .succeeded)
        XCTAssertEqual(call.provider, "openrouter")
        XCTAssertEqual(call.runID, runID)
        XCTAssertEqual(call.usageMetadata["total_tokens"], "64")
        XCTAssertEqual(call.nativeArtifactURLs.map(\.standardizedFileURL), [outputURL.standardizedFileURL])
    }

    @MainActor
    func testNativeCodexGenerationFallbackWritesOutputLedgerWithoutPython() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeCodexGeneration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let store = NativeImageGenerationStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            providerClientFactory: ProviderClientFactory(
                codexClient: MockNativeProviderClient(
                    providerKind: .codexFallback,
                    imageData: Self.tinyPNGData,
                    text: "Mock Codex fallback image generated.",
                    usageMetadata: ["provider_spend": "none"]
                )
            )
        )

        store.start(
            request: NativeImageGenerationRequest(
                prompt: "Create a no-key native Codex fallback figure.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
                task: "scientific diagram",
                settings: PaperBananaSettingsSnapshot(
                    repoPath: repoRoot.path,
                    serverPort: 7860,
                    defaultImageModel: .nanoBananaPro,
                    codexModel: "gpt-5.5",
                    codexReasoning: "xhigh",
                    googleAPIKey: "",
                    openRouterAPIKey: ""
                )
            ),
            onCompletion: { _ in }
        )

        try await Self.waitForGenerationStore(store) {
            if case .complete = $0.runState { return true }
            return false
        }

        let outputURL = try XCTUnwrap(store.outputURL)
        let rawResponseURL = try XCTUnwrap(store.rawResponseURL)
        let rawPayloadURL = try XCTUnwrap(store.rawPayloadURL)
        let providerRequestURL = try XCTUnwrap(store.providerRequestURL)
        let runID = store.runID
        let callID = store.providerCallID

        XCTAssertTrue(callID.hasPrefix("swift-codex-"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawResponseURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawPayloadURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: providerRequestURL.path))

        let record = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot))
        XCTAssertEqual(record.status, .completed)
        XCTAssertEqual(record.providerKind, "codex_fallback")
        XCTAssertEqual(record.model, ImageModelChoice.codexFallback.backendValue)
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.spendClass, "codex_fallback")

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let call = try XCTUnwrap(calls.first { $0.callID == callID })
        XCTAssertEqual(call.status, .succeeded)
        XCTAssertEqual(call.provider, "codex_fallback")
        XCTAssertEqual(call.nativeArtifactURLs.map(\.standardizedFileURL), [outputURL.standardizedFileURL])
    }

    @MainActor
    func testNativeCodexGenerationFallbackRunsFakeCodexHandoffEndToEndWithoutLiveProvider() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeCodexGenerationHandoff-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let fakeCodexURL = try Self.installFakeCodexExecutable(repoRoot: repoRoot)
        let store = NativeImageGenerationStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            providerClientFactory: ProviderClientFactory(
                codexClient: CodexFallbackProviderClient(
                    codexExecutableURL: fakeCodexURL,
                    timeoutSeconds: 5,
                    pollInterval: 0.05,
                    extraEnvironment: [
                        "PAPERBANANA_FAKE_CODEX_IMAGE_BASE64": Self.tinyPNGData.base64EncodedString()
                    ]
                )
            )
        )

        store.start(
            request: NativeImageGenerationRequest(
                prompt: "Create a no-key native Codex fallback figure through the real handoff adapter.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
                task: "scientific diagram",
                settings: PaperBananaSettingsSnapshot(
                    repoPath: repoRoot.path,
                    serverPort: 7860,
                    defaultImageModel: .nanoBananaPro,
                    codexModel: "gpt-5.5",
                    codexReasoning: "xhigh",
                    googleAPIKey: "",
                    openRouterAPIKey: ""
                )
            ),
            onCompletion: { _ in }
        )

        try await Self.waitForGenerationStore(store, timeoutNanoseconds: 6_000_000_000) {
            if case .complete = $0.runState { return true }
            return false
        }

        let outputURL = try XCTUnwrap(store.outputURL)
        let rawResponseURL = try XCTUnwrap(store.rawResponseURL)
        let rawPayloadURL = try XCTUnwrap(store.rawPayloadURL)
        let providerRequestURL = try XCTUnwrap(store.providerRequestURL)
        let metadataURL = try XCTUnwrap(store.metadataURL)
        let runID = store.runID
        let callID = store.providerCallID

        XCTAssertTrue(callID.hasPrefix("swift-codex-"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawResponseURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawPayloadURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: providerRequestURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataURL.path))

        let providerRequest = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: providerRequestURL)) as? [String: Any])
        XCTAssertEqual(providerRequest["adapter"] as? String, "swift_codex")
        XCTAssertEqual(providerRequest["workflow"] as? String, "native_generate")
        XCTAssertEqual(providerRequest["call_id"] as? String, callID)
        XCTAssertEqual(providerRequest["output_path"] as? String, outputURL.path)

        let rawResponseText = try String(contentsOf: rawResponseURL, encoding: .utf8)
        XCTAssertTrue(rawResponseText.contains(#""adapter" : "swift_codex""#))
        XCTAssertTrue(rawResponseText.contains(callID))

        let metadata = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL)) as? [String: Any])
        XCTAssertEqual(metadata["provider_call_id"] as? String, callID)
        XCTAssertEqual(metadata["provider_request_path"] as? String, providerRequestURL.path)
        let usageMetadata = try XCTUnwrap(metadata["usage_metadata"] as? [String: String])
        XCTAssertEqual(usageMetadata["provider_spend"], "none")
        XCTAssertEqual(usageMetadata["handoff_adapter"], "swift_codex")

        let durableText = [
            try String(contentsOf: providerRequestURL, encoding: .utf8),
            rawResponseText,
            try String(contentsOf: metadataURL, encoding: .utf8)
        ].joined(separator: "\n")
        XCTAssertFalse(durableText.contains("GOOGLE_API_KEY"))
        XCTAssertFalse(durableText.contains("OPENROUTER_API_KEY"))
        XCTAssertFalse(durableText.contains("test-google-key"))
        XCTAssertFalse(durableText.contains("test-openrouter-key"))

        let record = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot))
        XCTAssertEqual(record.status, .completed)
        XCTAssertEqual(record.providerKind, "codex_fallback")
        XCTAssertEqual(record.model, ImageModelChoice.codexFallback.backendValue)
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.providerRequestPath, providerRequestURL.path)
        XCTAssertEqual(record.rawResponsePath, rawResponseURL.path)
        XCTAssertEqual(record.spendClass, "codex_fallback")

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let call = try XCTUnwrap(calls.first { $0.callID == callID })
        XCTAssertEqual(call.status, .succeeded)
        XCTAssertEqual(call.provider, "codex_fallback")
        XCTAssertEqual(call.runID, runID)
        XCTAssertEqual(call.usageMetadata["provider_spend"], "none")
        XCTAssertEqual(call.usageMetadata["handoff_adapter"], "swift_codex")
        XCTAssertEqual(call.nativeArtifactURLs.map(\.standardizedFileURL), [outputURL.standardizedFileURL])
    }

    @MainActor
    func testNativeGoogleGenerationProviderFailureKeepsCallVisibleWithoutResponseBytes() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeGoogleProviderFailure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let store = NativeImageGenerationStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            googleProviderClient: ThrowingNativeProviderClient(error: ProviderRuntimeError.providerHTTPStatus(429, "quota exceeded", nil))
        )

        store.start(
            request: NativeImageGenerationRequest(
                prompt: "Create a Swift-native provider figure that fails before response bytes.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
                task: "scientific diagram",
                settings: PaperBananaSettingsSnapshot(
                    repoPath: repoRoot.path,
                    serverPort: 7860,
                    defaultImageModel: .nanoBananaPro,
                    codexModel: "gpt-5.5",
                    codexReasoning: "xhigh",
                    googleAPIKey: "test-google-key",
                    openRouterAPIKey: ""
                )
            ),
            onCompletion: { _ in
                XCTFail("Provider failure before response bytes must not complete as an artifact.")
            }
        )

        try await Self.waitForGenerationStore(store) {
            if case .failed = $0.runState { return true }
            return false
        }

        let runID = store.runID
        let callID = store.providerCallID
        XCTAssertTrue(callID.hasPrefix("swift-gemini-"))
        XCTAssertNil(store.rawResponseURL)
        XCTAssertNil(store.rawPayloadURL)

        let record = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot))
        XCTAssertEqual(record.status, .failed)
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.rawResponsePath, "")
        XCTAssertEqual(record.rawPayloadPath, "")
        XCTAssertTrue(record.message.contains("Provider request failed with HTTP 429"), record.message)

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let call = try XCTUnwrap(calls.first { $0.callID == callID })
        XCTAssertEqual(call.status, .failed)
        XCTAssertEqual(call.context, "native_generate")
        XCTAssertEqual(call.runID, runID)
        XCTAssertTrue(call.needsAttention)
    }

    @MainActor
    func testNativeGoogleGenerationPersistsRawHTTPErrorResponse() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeGoogleHTTPErrorBody-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let rawBody = Data(#"{"error":"quota exceeded","status":"RESOURCE_EXHAUSTED"}"#.utf8)
        let store = NativeImageGenerationStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            googleProviderClient: ThrowingNativeProviderClient(
                error: ProviderRuntimeError.providerHTTPStatus(429, "quota exceeded", rawBody)
            )
        )

        store.start(
            request: NativeImageGenerationRequest(
                prompt: "Create a Swift-native provider figure that receives an HTTP error body.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
                task: "scientific diagram",
                settings: PaperBananaSettingsSnapshot(
                    repoPath: repoRoot.path,
                    serverPort: 7860,
                    defaultImageModel: .nanoBananaPro,
                    codexModel: "gpt-5.5",
                    codexReasoning: "xhigh",
                    googleAPIKey: "test-google-key",
                    openRouterAPIKey: ""
                )
            ),
            onCompletion: { _ in
                XCTFail("Provider HTTP error response must not complete as an artifact.")
            }
        )

        try await Self.waitForGenerationStore(store) {
            if case .failed = $0.runState { return true }
            return false
        }

        let rawResponseURL = try XCTUnwrap(store.rawResponseURL)
        let runID = store.runID
        let callID = store.providerCallID

        XCTAssertEqual(try Data(contentsOf: rawResponseURL), rawBody)
        XCTAssertNil(store.rawPayloadURL)

        let record = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot))
        XCTAssertEqual(record.status, .failed)
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.rawResponsePath, rawResponseURL.path)
        XCTAssertEqual(record.rawPayloadPath, "")
        XCTAssertEqual(record.recoveryStatus, "raw_response")

        let call = try XCTUnwrap(ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path).first { $0.callID == callID })
        XCTAssertEqual(call.status, .failed)
        XCTAssertEqual(call.responseCount, 1)
        XCTAssertTrue(call.artifactURLs.map(\.standardizedFileURL).contains(rawResponseURL.standardizedFileURL))
        XCTAssertTrue(call.recoveryCandidateURLs.map(\.standardizedFileURL).contains(rawResponseURL.standardizedFileURL))
        XCTAssertTrue(call.needsAttention)
    }

    @MainActor
    func testNativeGoogleGenerationPersistsMalformedSuccessRawResponse() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeGoogleMalformedBody-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let rawBody = Data("not-json-after-paid-provider-call".utf8)
        let store = NativeImageGenerationStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            googleProviderClient: ThrowingNativeProviderClient(
                error: ProviderRuntimeError.malformedProviderResponseBody("Invalid JSON body.", rawBody)
            )
        )

        store.start(
            request: NativeImageGenerationRequest(
                prompt: "Create a Swift-native provider figure that receives malformed JSON.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
                task: "scientific diagram",
                settings: PaperBananaSettingsSnapshot(
                    repoPath: repoRoot.path,
                    serverPort: 7860,
                    defaultImageModel: .nanoBananaPro,
                    codexModel: "gpt-5.5",
                    codexReasoning: "xhigh",
                    googleAPIKey: "test-google-key",
                    openRouterAPIKey: ""
                )
            ),
            onCompletion: { _ in
                XCTFail("Malformed provider response must not complete as an artifact.")
            }
        )

        try await Self.waitForGenerationStore(store) {
            if case .failed = $0.runState { return true }
            return false
        }

        let rawResponseURL = try XCTUnwrap(store.rawResponseURL)
        let runID = store.runID
        let callID = store.providerCallID

        XCTAssertEqual(try Data(contentsOf: rawResponseURL), rawBody)
        XCTAssertNil(store.rawPayloadURL)

        let record = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot))
        XCTAssertEqual(record.status, .failed)
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.rawResponsePath, rawResponseURL.path)
        XCTAssertEqual(record.rawPayloadPath, "")
        XCTAssertEqual(record.recoveryStatus, "raw_response")
        XCTAssertTrue(record.message.contains("Provider response could not be decoded"), record.message)

        let call = try XCTUnwrap(ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path).first { $0.callID == callID })
        XCTAssertEqual(call.status, .failed)
        XCTAssertEqual(call.responseCount, 1)
        XCTAssertTrue(call.artifactURLs.map(\.standardizedFileURL).contains(rawResponseURL.standardizedFileURL))
        XCTAssertTrue(call.recoveryCandidateURLs.map(\.standardizedFileURL).contains(rawResponseURL.standardizedFileURL))
        XCTAssertTrue(call.needsAttention)
    }

    @MainActor
    func testNativeGoogleGenerationCancelMarksProviderCallCancelled() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeGoogleCancel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let store = NativeImageGenerationStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            googleProviderClient: BlockingNativeProviderClient()
        )

        store.start(
            request: NativeImageGenerationRequest(
                prompt: "Create a Swift-native provider figure that will be cancelled.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
                task: "scientific diagram",
                settings: PaperBananaSettingsSnapshot(
                    repoPath: repoRoot.path,
                    serverPort: 7860,
                    defaultImageModel: .nanoBananaPro,
                    codexModel: "gpt-5.5",
                    codexReasoning: "xhigh",
                    googleAPIKey: "test-google-key",
                    openRouterAPIKey: ""
                )
            ),
            onCompletion: { _ in
                XCTFail("Cancelled generation must not complete as an artifact.")
            }
        )

        let runID = store.runID
        let callID = store.providerCallID
        XCTAssertTrue(callID.hasPrefix("swift-gemini-"))

        store.cancel()

        XCTAssertEqual(store.runState, .cancelled("Generation cancelled by user."))
        XCTAssertTrue(store.milestones.contains { $0.state == .cancelled })

        let record = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot))
        XCTAssertEqual(record.status, .cancelled)
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.message, "Generation cancelled by user.")

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let call = try XCTUnwrap(calls.first { $0.callID == callID })
        XCTAssertEqual(call.status, .cancelled)
        XCTAssertTrue(call.needsAttention)
        XCTAssertEqual(call.message, "Generation cancelled by user.")
    }

    @MainActor
    func testNativeGoogleGenerationTimeoutMarksProviderCallTimedOut() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeGoogleTimeout-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let store = NativeImageGenerationStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 0.01,
            googleProviderClient: BlockingNativeProviderClient()
        )

        store.start(
            request: NativeImageGenerationRequest(
                prompt: "Create a Swift-native provider figure that will time out.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
                task: "scientific diagram",
                settings: PaperBananaSettingsSnapshot(
                    repoPath: repoRoot.path,
                    serverPort: 7860,
                    defaultImageModel: .nanoBananaPro,
                    codexModel: "gpt-5.5",
                    codexReasoning: "xhigh",
                    googleAPIKey: "test-google-key",
                    openRouterAPIKey: ""
                )
            ),
            onCompletion: { _ in
                XCTFail("Timed-out generation must not complete as an artifact.")
            }
        )

        try await Self.waitForGenerationStore(store, timeoutNanoseconds: 3_000_000_000) {
            if case .timedOut = $0.runState { return true }
            return false
        }

        let runID = store.runID
        let callID = store.providerCallID
        XCTAssertTrue(callID.hasPrefix("swift-gemini-"))
        guard case .timedOut(let timedOutMessage) = store.runState else {
            return XCTFail("Expected timed-out generation state, got \(store.runState).")
        }
        XCTAssertTrue(timedOutMessage.contains("terminating local generation process"), timedOutMessage)
        XCTAssertTrue(store.milestones.contains { $0.state == .timedOut })

        let record = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot))
        XCTAssertEqual(record.status, .timedOut)
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertTrue(record.message.contains("terminating local generation process"), record.message)

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let call = try XCTUnwrap(calls.first { $0.callID == callID })
        XCTAssertEqual(call.status, .timedOut)
        XCTAssertTrue(call.needsAttention)
        XCTAssertTrue(call.message.contains("terminating local generation process"), call.message)
    }

    @MainActor
    func testNativeGoogleGenerationPreservesRawPayloadWhenImageDecodeFails() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeGoogleRawRecovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let invalidImageData = Data("not a decodable image".utf8)
        let store = NativeImageGenerationStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            googleProviderClient: MockNativeProviderClient(
                imageData: invalidImageData,
                text: "Provider returned bytes.",
                usageMetadata: ["totalTokenCount": "99"]
            )
        )

        store.start(
            request: NativeImageGenerationRequest(
                prompt: "Create a Swift-native provider figure with invalid bytes.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
                task: "scientific diagram",
                settings: PaperBananaSettingsSnapshot(
                    repoPath: repoRoot.path,
                    serverPort: 7860,
                    defaultImageModel: .nanoBananaPro,
                    codexModel: "gpt-5.5",
                    codexReasoning: "xhigh",
                    googleAPIKey: "test-google-key",
                    openRouterAPIKey: ""
                )
            ),
            onCompletion: { _ in
                XCTFail("Invalid image bytes must not complete as a decoded artifact.")
            }
        )

        try await Self.waitForGenerationStore(store) {
            if case .recovered = $0.runState { return true }
            return false
        }

        let rawResponseURL = try XCTUnwrap(store.rawResponseURL)
        let rawPayloadURL = try XCTUnwrap(store.rawPayloadURL)
        let outputURL = try XCTUnwrap(store.outputURL)
        let runID = store.runID
        let callID = store.providerCallID

        XCTAssertTrue(FileManager.default.fileExists(atPath: rawResponseURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawPayloadURL.path))
        XCTAssertEqual(try Data(contentsOf: rawPayloadURL), invalidImageData)
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(store.runState, .recovered(rawPayloadURL, store.statusMessage))
        XCTAssertTrue(store.statusMessage.contains("raw recoverable payload"), store.statusMessage)
        XCTAssertTrue(store.milestones.contains { $0.state == .recovered })

        let record = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot))
        XCTAssertEqual(record.status, .recovered)
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.rawResponsePath, rawResponseURL.path)
        XCTAssertEqual(record.rawPayloadPath, rawPayloadURL.path)
        XCTAssertEqual(record.recoveryStatus, "raw_payload")

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let call = try XCTUnwrap(calls.first { $0.callID == callID })
        XCTAssertEqual(call.status, .rawRecovered)
        XCTAssertEqual(call.rawArtifactURLs.map(\.standardizedFileURL), [rawPayloadURL.standardizedFileURL])
        XCTAssertTrue(call.recoveryCandidateURLs.map(\.standardizedFileURL).contains(rawPayloadURL.standardizedFileURL))
        XCTAssertTrue(call.needsAttention)
    }

    @MainActor
    func testNativeGoogleGenerationPreservesRawResponseWhenProviderReturnsNoImage() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeGoogleNoImage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let store = NativeImageGenerationStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            googleProviderClient: MockNativeProviderClient(
                imageData: nil,
                text: "Provider returned text but no image.",
                usageMetadata: ["totalTokenCount": "117"]
            )
        )

        store.start(
            request: NativeImageGenerationRequest(
                prompt: "Create a Swift-native provider figure but return no image.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
                task: "scientific diagram",
                settings: PaperBananaSettingsSnapshot(
                    repoPath: repoRoot.path,
                    serverPort: 7860,
                    defaultImageModel: .nanoBananaPro,
                    codexModel: "gpt-5.5",
                    codexReasoning: "xhigh",
                    googleAPIKey: "test-google-key",
                    openRouterAPIKey: ""
                )
            ),
            onCompletion: { _ in
                XCTFail("No-image provider response must not complete as an artifact.")
            }
        )

        try await Self.waitForGenerationStore(store) {
            if case .failed = $0.runState { return true }
            return false
        }

        let rawResponseURL = try XCTUnwrap(store.rawResponseURL)
        let outputURL = try XCTUnwrap(store.outputURL)
        let runID = store.runID
        let callID = store.providerCallID

        XCTAssertTrue(FileManager.default.fileExists(atPath: rawResponseURL.path))
        XCTAssertNil(store.rawPayloadURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))

        let record = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot))
        XCTAssertEqual(record.status, .failed)
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.rawResponsePath, rawResponseURL.path)
        XCTAssertEqual(record.rawPayloadPath, "")
        XCTAssertTrue(record.message.contains("Provider response did not contain image bytes."), record.message)

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let call = try XCTUnwrap(calls.first { $0.callID == callID })
        XCTAssertEqual(call.status, .failed)
        XCTAssertEqual(call.responseCount, 1)
        XCTAssertEqual(call.usageMetadata["totalTokenCount"], "117")
        XCTAssertTrue(call.artifactURLs.map(\.standardizedFileURL).contains(rawResponseURL.standardizedFileURL))
        XCTAssertTrue(call.recoveryCandidateURLs.map(\.standardizedFileURL).contains(rawResponseURL.standardizedFileURL))
        XCTAssertTrue(call.needsAttention)
    }

    @MainActor
    func testDryRunStartedFromStoreCreatesIndexedGenerationFolder() async throws {
        let repoRoot = Self.repoRoot()
        let store = NativeImageGenerationStore(stallWarningInterval: 60, hardTimeoutInterval: 120)
        let outputURL = await withCheckedContinuation { continuation in
            store.start(
                request: NativeImageGenerationRequest(
                    prompt: "Create a native PaperBanana generation test figure.",
                    model: .codexFallback,
                    resolution: "2K",
                    aspectRatio: "16:9",
                    task: "diagram",
                    settings: PaperBananaSettingsSnapshot(
                        repoPath: repoRoot.path,
                        serverPort: 7860,
                        defaultImageModel: .codexFallback,
                        codexModel: "gpt-5.5",
                        codexReasoning: "xhigh",
                        googleAPIKey: "",
                        openRouterAPIKey: ""
                    ),
                    executionMode: .dryRun
                ),
                onCompletion: { url in
                    continuation.resume(returning: url)
                }
            )
        }

        let runDirectory = outputURL.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: runDirectory) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: runDirectory.appendingPathComponent("prompt.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: runDirectory.appendingPathComponent("request.json").path))
        let providerRequestURL = runDirectory.appendingPathComponent("provider_request.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: providerRequestURL.path))
        let providerRequest = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: providerRequestURL)) as? [String: Any])
        XCTAssertEqual(providerRequest["adapter"] as? String, "swift_local")
        XCTAssertEqual(providerRequest["mode"] as? String, "dry_run")
        XCTAssertEqual(providerRequest["provider_spend"] as? String, "none")
        XCTAssertTrue(FileManager.default.fileExists(atPath: runDirectory.appendingPathComponent("events.jsonl").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.deletingPathExtension().appendingPathExtension("json").path))
        XCTAssertEqual(store.requestURL?.standardizedFileURL, runDirectory.appendingPathComponent("request.json").standardizedFileURL)
        XCTAssertEqual(store.runState, .complete(outputURL))

        let artifact = try XCTUnwrap(ArtifactLibraryScanner.scan(repoRootPath: repoRoot.path).first { $0.url == outputURL.standardizedFileURL })
        XCTAssertEqual(artifact.workflow, "native_generate")
        XCTAssertEqual(artifact.runDirectoryURL?.standardizedFileURL, runDirectory.standardizedFileURL)
        XCTAssertEqual(artifact.runStatus, .completed)
    }

    @MainActor
    func testStatisticalPlotDryRunPersistsOnlyPlotReferenceArtifacts() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativePlotDryRun-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let prompt = "Create a statistical plot comparing two accuracy values."
        let staleDiagramReference = ReferenceExampleSelection(
            id: "diagram_999",
            visualIntent: "Show a diagram reference that should not affect plot runs.",
            contentSummary: "Diagram-only example that must be discarded for statistical plots.",
            imagePath: "images/diagram_999.png"
        )
        let plotReference = ReferenceExampleSelection(
            id: "plot_042",
            visualIntent: "Use grouped bars to compare model accuracy.",
            contentSummary: "Accuracy values by model and dataset.",
            imagePath: "images/plot_042.jpg",
            referenceSource: ReferenceExampleBenchmarkTask.plot.referenceSource
        )
        let request = NativeImageGenerationRequest(
            prompt: prompt,
            model: .codexFallback,
            resolution: "2K",
            aspectRatio: "16:9",
            task: "statistical plot",
            settings: PaperBananaSettingsSnapshot(
                repoPath: repoRoot.path,
                serverPort: 7860,
                defaultImageModel: .codexFallback,
                codexModel: "gpt-5.5",
                codexReasoning: "xhigh",
                googleAPIKey: "",
                openRouterAPIKey: ""
            ),
            referenceExamples: [staleDiagramReference, plotReference],
            executionMode: .dryRun
        )
        XCTAssertEqual(request.referenceExamples.map(\.id), ["plot_042"])
        XCTAssertTrue(request.providerPrompt.contains("Selected Reference Examples"))
        XCTAssertTrue(request.providerPrompt.contains("ID: plot_042"))
        XCTAssertFalse(request.providerPrompt.contains("diagram_999"))

        let store = NativeImageGenerationStore(stallWarningInterval: 60, hardTimeoutInterval: 120)
        let outputURL = await withCheckedContinuation { continuation in
            store.start(
                request: request,
                onCompletion: { url in
                    continuation.resume(returning: url)
                }
            )
        }

        let runDirectory = outputURL.deletingLastPathComponent()
        let requestURL = runDirectory.appendingPathComponent("request.json")
        let providerRequestURL = runDirectory.appendingPathComponent("provider_request.json")
        let metadataURL = outputURL.deletingPathExtension().appendingPathExtension("json")

        let requestPayload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: requestURL)) as? [String: Any])
        XCTAssertEqual(requestPayload["task"] as? String, "statistical plot")
        XCTAssertEqual(requestPayload["source_prompt"] as? String, prompt)
        XCTAssertEqual(requestPayload["reference_mode"] as? String, "manual_native_prompt_enrichment")
        XCTAssertEqual(requestPayload["reference_example_count"] as? Int, 1)
        let requestReferences = try XCTUnwrap(requestPayload["reference_examples"] as? [[String: Any]])
        XCTAssertEqual(requestReferences.first?["id"] as? String, "plot_042")
        XCTAssertEqual(requestReferences.first?["reference_source"] as? String, "PaperBananaBench/plot")
        let requestPrompt = try XCTUnwrap(requestPayload["prompt"] as? String)
        XCTAssertTrue(requestPrompt.contains("Selected Reference Examples"))
        XCTAssertTrue(requestPrompt.contains("ID: plot_042"))
        XCTAssertFalse(requestPrompt.contains("diagram_999"))

        let providerPayload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: providerRequestURL)) as? [String: Any])
        XCTAssertEqual(providerPayload["task"] as? String, "statistical plot")
        XCTAssertEqual(providerPayload["prompt"] as? String, requestPrompt)

        let metadata = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL)) as? [String: Any])
        XCTAssertEqual(metadata["task"] as? String, "statistical plot")
        XCTAssertEqual(metadata["source_prompt"] as? String, prompt)
        XCTAssertEqual(metadata["prompt"] as? String, requestPrompt)
        XCTAssertEqual(metadata["reference_mode"] as? String, "manual_native_prompt_enrichment")
        XCTAssertEqual(metadata["reference_example_count"] as? Int, 1)
        let metadataReferences = try XCTUnwrap(metadata["reference_examples"] as? [[String: Any]])
        XCTAssertEqual(metadataReferences.first?["id"] as? String, "plot_042")
        XCTAssertEqual(metadataReferences.first?["reference_source"] as? String, "PaperBananaBench/plot")
    }

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func writeTinyPNG(to url: URL) throws {
        try tinyPNGData.write(to: url)
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
        bitmap.setColor(NSColor(calibratedRed: 1, green: 0.5, blue: 0, alpha: 1), atX: 0, y: 0)
        return bitmap.representation(using: .png, properties: [:])!
    }

    @MainActor
    private static func waitForGenerationStore(
        _ store: NativeImageGenerationStore,
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        predicate: (NativeImageGenerationStore) -> Bool
    ) async throws {
        let step: UInt64 = 20_000_000
        var waited: UInt64 = 0
        while waited < timeoutNanoseconds {
            if predicate(store) { return }
            try await Task.sleep(nanoseconds: step)
            waited += step
        }
        XCTFail("Timed out waiting for generation store state. Current state: \(store.runState)")
        throw GenerationStoreWaitError.timedOut
    }
}

private enum GenerationStoreWaitError: Error {
    case timedOut
}

private struct MockNativeProviderClient: ProviderClient {
    let providerKind: ImageProviderKind
    let imageData: Data?
    let text: String
    let usageMetadata: [String: String]

    init(
        providerKind: ImageProviderKind = .googleGemini,
        imageData: Data?,
        text: String,
        usageMetadata: [String: String]
    ) {
        self.providerKind = providerKind
        self.imageData = imageData
        self.text = text
        self.usageMetadata = usageMetadata
    }

    func execute(
        _ request: ProviderClientRequest,
        eventHandler: @escaping @Sendable (ProviderProgressEvent) -> Void
    ) async throws -> ProviderResponse {
        if let providerRequestURL = request.providerRequestURL {
            try FileManager.default.createDirectory(at: providerRequestURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let payload: [String: Any] = [
                "mock": true,
                "run_id": request.runID,
                "call_id": request.callID,
                "provider": providerKind.rawValue,
                "workflow": request.workflow.rawValue,
                "prompt": request.prompt,
                "output_path": request.outputURL?.path ?? ""
            ]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: providerRequestURL, options: .atomic)
            eventHandler(
                ProviderProgressEvent(
                    stage: "provider_request_saved",
                    progress: 43,
                    message: "Mock native provider request persisted.",
                    callID: request.callID
                )
            )
        }
        eventHandler(
            ProviderProgressEvent(
                stage: "provider_response_saved",
                progress: 78,
                message: "Mock native provider returned response bytes.",
                callID: request.callID
            )
        )
        return ProviderResponse(
            provider: providerKind,
            model: request.effectiveModel,
            callID: request.callID,
            rawResponseData: Data(#"{"mock":true,"call_id":"\#(request.callID)"}"#.utf8),
            imageData: imageData,
            text: text,
            usageMetadata: usageMetadata
        )
    }
}

private struct ThrowingNativeProviderClient: ProviderClient {
    let providerKind: ImageProviderKind
    let error: Error

    init(providerKind: ImageProviderKind = .googleGemini, error: Error) {
        self.providerKind = providerKind
        self.error = error
    }

    func execute(
        _ request: ProviderClientRequest,
        eventHandler: @escaping @Sendable (ProviderProgressEvent) -> Void
    ) async throws -> ProviderResponse {
        throw error
    }
}

private struct BlockingNativeProviderClient: ProviderClient {
    let providerKind: ImageProviderKind

    init(providerKind: ImageProviderKind = .googleGemini) {
        self.providerKind = providerKind
    }

    func execute(
        _ request: ProviderClientRequest,
        eventHandler: @escaping @Sendable (ProviderProgressEvent) -> Void
    ) async throws -> ProviderResponse {
        while true {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
