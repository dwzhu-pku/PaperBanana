import AppKit
import Foundation
import XCTest
@testable import PaperBanana

final class NativeRefinementStoreTests: XCTestCase {
    func testEventParsingMapsJsonLineIntoProgressEvent() throws {
        let line = #"{"stage":"saving","progress":82,"message":"Saving refined image.","run_id":"native_refine_001","run_dir":"/tmp/run","output_path":"/tmp/run/out.png","metadata_path":"/tmp/run/out.json","log_path":"/tmp/run/out.jsonl","prompt_path":"/tmp/run/prompt.txt","call_id":"abc123","raw_response_path":"/tmp/run/provider_response.bin","raw_path":"/tmp/run/provider_raw.bin"}"#

        let event = try XCTUnwrap(NativeRefinementEvent(jsonLine: line))

        XCTAssertEqual(event.stage, "saving")
        XCTAssertEqual(event.progress, 82)
        XCTAssertEqual(event.message, "Saving refined image.")
        XCTAssertEqual(event.runID, "native_refine_001")
        XCTAssertEqual(event.runDirectoryURL?.path, "/tmp/run")
        XCTAssertEqual(event.outputURL?.path, "/tmp/run/out.png")
        XCTAssertEqual(event.metadataURL?.path, "/tmp/run/out.json")
        XCTAssertEqual(event.logURL?.path, "/tmp/run/out.jsonl")
        XCTAssertEqual(event.promptURL?.path, "/tmp/run/prompt.txt")
        XCTAssertEqual(event.callID, "abc123")
        XCTAssertEqual(event.rawResponseURL?.path, "/tmp/run/provider_response.bin")
        XCTAssertEqual(event.rawPayloadURL?.path, "/tmp/run/provider_raw.bin")
    }

    func testMilestonesMarkCompletedStagesBeforeCurrentStage() {
        let milestones = NativeRefinementMilestone.timeline(currentStage: "saving")

        XCTAssertEqual(milestones.first?.title, "Queued")
        XCTAssertEqual(milestones.first?.state, .completed)
        XCTAssertEqual(milestones.first(where: { $0.stage == "saving" })?.state, .active)
        XCTAssertEqual(milestones.first(where: { $0.stage == "complete" })?.state, .pending)
    }

    @MainActor
    func testDryRunStartedFromStoreCreatesIndexedRunFolder() async throws {
        let repoRoot = Self.repoRoot()
        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaStoreDryRun-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sourceDirectory) }

        let sourceURL = sourceDirectory.appendingPathComponent("store_dry_run_source.png")
        try Self.writeTinyPNG(to: sourceURL)

        let store = NativeRefinementStore(stallWarningInterval: 60, hardTimeoutInterval: 120)
        let outputURL = await withCheckedContinuation { continuation in
            store.start(
                request: NativeRefinementRequest(
                    sourceURL: sourceURL,
                    prompt: "Dry-run GUI refinement should create a durable run folder.",
                    model: .nanoBananaPro,
                    resolution: "4K",
                    aspectRatio: "16:9",
                    settings: PaperBananaSettingsSnapshot(
                        repoPath: repoRoot.path,
                        serverPort: 7860,
                        defaultImageModel: .nanoBananaPro,
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
        let providerRequestURL = runDirectory.appendingPathComponent("provider_request.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: providerRequestURL.path))
        let providerRequest = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: providerRequestURL)) as? [String: Any])
        XCTAssertEqual(providerRequest["adapter"] as? String, "swift_local")
        XCTAssertEqual(providerRequest["mode"] as? String, "dry_run")
        XCTAssertEqual(providerRequest["provider_spend"] as? String, "none")
        XCTAssertEqual(providerRequest["source_image_path"] as? String, runDirectory.appendingPathComponent("store_dry_run_source.png").path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: runDirectory.appendingPathComponent("events.jsonl").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.deletingPathExtension().appendingPathExtension("json").path))

        let artifact = try XCTUnwrap(ArtifactLibraryScanner.scan(repoRootPath: repoRoot.path).first { $0.url == outputURL.standardizedFileURL })
        XCTAssertEqual(artifact.runDirectoryURL?.standardizedFileURL, runDirectory.standardizedFileURL)
        XCTAssertEqual(artifact.runStatus, .completed)
        XCTAssertEqual(artifact.promptURL?.lastPathComponent, "prompt.txt")
        XCTAssertEqual(artifact.logURL?.lastPathComponent, "events.jsonl")
    }

    @MainActor
    func testStartCreatesDurableRunRecordBeforeProviderCompletion() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaPreflightRun-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let sourceURL = repoRoot.appendingPathComponent("source figure.png")
        try Self.writeTinyPNG(to: sourceURL)

        let store = NativeRefinementStore(stallWarningInterval: 60, hardTimeoutInterval: 120)
        store.start(
            request: NativeRefinementRequest(
                sourceURL: sourceURL,
                prompt: "Create the durable record before any provider work starts.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
                settings: PaperBananaSettingsSnapshot(
                    repoPath: repoRoot.path,
                    serverPort: 7860,
                    defaultImageModel: .nanoBananaPro,
                    codexModel: "gpt-5.5",
                    codexReasoning: "xhigh",
                    googleAPIKey: "",
                    openRouterAPIKey: ""
                ),
                executionMode: .mockProviderInvalidPayload
            ),
            onCompletion: { _ in }
        )

        let runDirectory = try XCTUnwrap(store.runDirectoryURL)
        let requestURL = runDirectory.appendingPathComponent("request.json")
        let eventLogURL = runDirectory.appendingPathComponent("events.jsonl")
        let sourceCopyURL = runDirectory.appendingPathComponent("source_figure.png")

        XCTAssertTrue(FileManager.default.fileExists(atPath: runDirectory.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: requestURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceCopyURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: eventLogURL.path))

        let requestData = try Data(contentsOf: requestURL)
        let requestPayload = try XCTUnwrap(JSONSerialization.jsonObject(with: requestData) as? [String: Any])
        XCTAssertEqual(requestPayload["prompt"] as? String, "Create the durable record before any provider work starts.")
        XCTAssertEqual(requestPayload["model"] as? String, ImageModelChoice.codexFallback.backendValue)
        XCTAssertEqual(requestPayload["requested_model"] as? String, ImageModelChoice.nanoBananaPro.backendValue)
        XCTAssertEqual(requestPayload["provider"] as? String, "Codex")
        XCTAssertEqual(requestPayload["provider_kind"] as? String, "codex_fallback")
        XCTAssertEqual(requestPayload["credential_source"] as? String, "codex_app")
        XCTAssertEqual(requestPayload["spend_class"] as? String, "codex_fallback")
        XCTAssertEqual(requestPayload["can_spend_provider_credits"] as? Bool, false)
        XCTAssertEqual(requestPayload["source_copy_path"] as? String, sourceCopyURL.path)
        XCTAssertEqual(requestPayload["provider_request_path"] as? String, store.providerRequestURL?.path)

        let initialEvents = try String(contentsOf: eventLogURL, encoding: .utf8)
        XCTAssertTrue(initialEvents.contains(#""stage":"queued""#), initialEvents)

        try await Self.waitForRefinementStore(store) {
            if case .recovered = $0.runState { return true }
            return false
        }

        let providerRequestURL = try XCTUnwrap(store.providerRequestURL)
        let providerRequestData = try Data(contentsOf: providerRequestURL)
        let providerRequestPayload = try XCTUnwrap(JSONSerialization.jsonObject(with: providerRequestData) as? [String: Any])
        XCTAssertEqual(providerRequestPayload["adapter"] as? String, "swift_local")
        XCTAssertEqual(providerRequestPayload["mode"] as? String, "mock_invalid_payload")
        XCTAssertEqual(providerRequestPayload["provider_spend"] as? String, "none")

        let rawResponseURL = try XCTUnwrap(store.rawResponseURL)
        let rawPayloadURL = try XCTUnwrap(store.rawPayloadURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawResponseURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawPayloadURL.path))
        XCTAssertTrue(String(data: try Data(contentsOf: rawPayloadURL), encoding: .utf8)?.contains("swift-local-invalid-image-payload") == true)

        let recoveredRecord = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: store.runID, repoRoot: repoRoot))
        XCTAssertEqual(recoveredRecord.status, .recovered)
        XCTAssertEqual(recoveredRecord.rawResponsePath, rawResponseURL.path)
        XCTAssertEqual(recoveredRecord.rawPayloadPath, rawPayloadURL.path)
        XCTAssertEqual(recoveredRecord.recoveryStatus, "raw_payload")
    }

    @MainActor
    func testNativeGoogleRefinementWritesOutputLedgerAndProviderAuditWithoutPython() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeRefineSuccess-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let sourceURL = repoRoot.appendingPathComponent("source figure.png")
        try Self.writeTinyPNG(to: sourceURL)

        let store = NativeRefinementStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            providerClientFactory: ProviderClientFactory(
                googleClient: MockRefinementProviderClient(
                    imageData: Self.tinyPNGData,
                    text: "Mock native refinement generated.",
                    usageMetadata: ["totalTokenCount": "57"]
                )
            )
        )

        store.start(
            request: NativeRefinementRequest(
                sourceURL: sourceURL,
                prompt: "Refine labels and preserve scientific meaning.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
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

        try await Self.waitForRefinementStore(store) {
            if case .complete = $0.runState { return true }
            return false
        }

        let outputURL = try XCTUnwrap(store.outputURL)
        let rawResponseURL = try XCTUnwrap(store.rawResponseURL)
        let rawPayloadURL = try XCTUnwrap(store.rawPayloadURL)
        let providerRequestURL = try XCTUnwrap(store.providerRequestURL)
        let metadataURL = try XCTUnwrap(store.metadataURL)
        let sourceCopyURL = try XCTUnwrap(store.sourceCopyURL)
        let runID = store.runID
        let callID = store.providerCallID

        XCTAssertTrue(callID.hasPrefix("swift-gemini-"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawResponseURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawPayloadURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: providerRequestURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceCopyURL.path))
        XCTAssertEqual(store.runState, .complete(outputURL))

        let record = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot))
        XCTAssertEqual(record.status, .completed)
        XCTAssertEqual(record.workflow, "native_refine")
        XCTAssertEqual(record.providerKind, "google_gemini")
        XCTAssertEqual(record.model, ImageModelChoice.nanoBananaPro.backendValue)
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.providerRequestPath, providerRequestURL.path)
        XCTAssertEqual(record.rawResponsePath, rawResponseURL.path)
        XCTAssertEqual(record.rawPayloadPath, rawPayloadURL.path)
        XCTAssertEqual(record.artifactPath, outputURL.path)

        let metadata = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL)) as? [String: Any])
        XCTAssertEqual(metadata["workflow"] as? String, "native_refine")
        XCTAssertEqual(metadata["provider_call_id"] as? String, callID)
        XCTAssertEqual(metadata["provider_request_path"] as? String, providerRequestURL.path)
        XCTAssertEqual(metadata["source_path"] as? String, sourceURL.path)
        XCTAssertEqual(metadata["source_copy_path"] as? String, sourceCopyURL.path)
        XCTAssertEqual((metadata["usage_metadata"] as? [String: String])?["totalTokenCount"], "57")

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let call = try XCTUnwrap(calls.first { $0.callID == callID })
        XCTAssertEqual(call.status, .succeeded)
        XCTAssertEqual(call.context, "native_refine")
        XCTAssertEqual(call.runID, runID)
        XCTAssertEqual(call.usageMetadata["totalTokenCount"], "57")
        XCTAssertEqual(call.nativeArtifactURLs.map(\.standardizedFileURL), [outputURL.standardizedFileURL])
        XCTAssertTrue(call.artifactURLs.contains { $0.path.contains("/results/provider_audit/images/") })
    }

    @MainActor
    func testNativeOpenRouterRefinementWritesOutputLedgerWithoutPython() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeOpenRouterRefine-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let sourceURL = repoRoot.appendingPathComponent("source figure.png")
        try Self.writeTinyPNG(to: sourceURL)

        let store = NativeRefinementStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            providerClientFactory: ProviderClientFactory(
                openRouterClient: MockRefinementProviderClient(
                    providerKind: .openRouter,
                    imageData: Self.tinyPNGData,
                    text: "Mock OpenRouter refinement generated.",
                    usageMetadata: ["total_tokens": "73"]
                )
            )
        )

        store.start(
            request: NativeRefinementRequest(
                sourceURL: sourceURL,
                prompt: "Refine labels through Swift-native OpenRouter.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
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

        try await Self.waitForRefinementStore(store) {
            if case .complete = $0.runState { return true }
            return false
        }

        let outputURL = try XCTUnwrap(store.outputURL)
        let rawResponseURL = try XCTUnwrap(store.rawResponseURL)
        let rawPayloadURL = try XCTUnwrap(store.rawPayloadURL)
        let providerRequestURL = try XCTUnwrap(store.providerRequestURL)
        let metadataURL = try XCTUnwrap(store.metadataURL)
        let sourceCopyURL = try XCTUnwrap(store.sourceCopyURL)
        let runID = store.runID
        let callID = store.providerCallID

        XCTAssertTrue(callID.hasPrefix("swift-openrouter-"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawResponseURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawPayloadURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: providerRequestURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceCopyURL.path))

        let providerRequest = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: providerRequestURL)) as? [String: Any])
        XCTAssertEqual(providerRequest["provider"] as? String, "openrouter")
        XCTAssertEqual(providerRequest["source_image_path"] as? String, sourceCopyURL.path)
        XCTAssertNil(providerRequest["adapter"])

        let record = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot))
        XCTAssertEqual(record.status, .completed)
        XCTAssertEqual(record.workflow, "native_refine")
        XCTAssertEqual(record.providerKind, "openrouter")
        XCTAssertEqual(record.model, ImageModelChoice.nanoBananaPro.backendValue)
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.providerRequestPath, providerRequestURL.path)
        XCTAssertEqual(record.rawResponsePath, rawResponseURL.path)
        XCTAssertEqual(record.rawPayloadPath, rawPayloadURL.path)
        XCTAssertEqual(record.artifactPath, outputURL.path)
        XCTAssertEqual(record.spendClass, "paid_provider")

        let metadata = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL)) as? [String: Any])
        XCTAssertEqual(metadata["workflow"] as? String, "native_refine")
        XCTAssertEqual(metadata["provider_call_id"] as? String, callID)
        XCTAssertEqual(metadata["provider_request_path"] as? String, providerRequestURL.path)
        XCTAssertEqual(metadata["source_copy_path"] as? String, sourceCopyURL.path)
        XCTAssertEqual((metadata["usage_metadata"] as? [String: String])?["total_tokens"], "73")

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let call = try XCTUnwrap(calls.first { $0.callID == callID })
        XCTAssertEqual(call.status, .succeeded)
        XCTAssertEqual(call.context, "native_refine")
        XCTAssertEqual(call.provider, "openrouter")
        XCTAssertEqual(call.runID, runID)
        XCTAssertEqual(call.usageMetadata["total_tokens"], "73")
        XCTAssertEqual(call.nativeArtifactURLs.map(\.standardizedFileURL), [outputURL.standardizedFileURL])
    }

    @MainActor
    func testNativeCodexRefinementFallbackWritesOutputLedgerWithoutPython() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeCodexRefine-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let sourceURL = repoRoot.appendingPathComponent("source figure.png")
        try Self.writeTinyPNG(to: sourceURL)

        let store = NativeRefinementStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            providerClientFactory: ProviderClientFactory(
                codexClient: MockRefinementProviderClient(
                    providerKind: .codexFallback,
                    imageData: Self.tinyPNGData,
                    text: "Mock Codex fallback refinement generated.",
                    usageMetadata: ["provider_spend": "none"]
                )
            )
        )

        store.start(
            request: NativeRefinementRequest(
                sourceURL: sourceURL,
                prompt: "Refine labels through no-key native Codex fallback.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
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

        try await Self.waitForRefinementStore(store) {
            if case .complete = $0.runState { return true }
            return false
        }

        let outputURL = try XCTUnwrap(store.outputURL)
        let rawResponseURL = try XCTUnwrap(store.rawResponseURL)
        let rawPayloadURL = try XCTUnwrap(store.rawPayloadURL)
        let providerRequestURL = try XCTUnwrap(store.providerRequestURL)
        let sourceCopyURL = try XCTUnwrap(store.sourceCopyURL)
        let runID = store.runID
        let callID = store.providerCallID

        XCTAssertTrue(callID.hasPrefix("swift-codex-"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawResponseURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawPayloadURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: providerRequestURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceCopyURL.path))

        let record = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot))
        XCTAssertEqual(record.status, .completed)
        XCTAssertEqual(record.workflow, "native_refine")
        XCTAssertEqual(record.providerKind, "codex_fallback")
        XCTAssertEqual(record.model, ImageModelChoice.codexFallback.backendValue)
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.spendClass, "codex_fallback")

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let call = try XCTUnwrap(calls.first { $0.callID == callID })
        XCTAssertEqual(call.status, .succeeded)
        XCTAssertEqual(call.context, "native_refine")
        XCTAssertEqual(call.provider, "codex_fallback")
        XCTAssertEqual(call.nativeArtifactURLs.map(\.standardizedFileURL), [outputURL.standardizedFileURL])
    }

    @MainActor
    func testNativeCodexRefinementFallbackRunsFakeCodexHandoffEndToEndWithoutLiveProvider() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeCodexRefineHandoff-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let sourceURL = repoRoot.appendingPathComponent("source figure.png")
        try Self.writeTinyPNG(to: sourceURL)

        let fakeCodexURL = try Self.installFakeCodexExecutable(repoRoot: repoRoot)
        let store = NativeRefinementStore(
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
            request: NativeRefinementRequest(
                sourceURL: sourceURL,
                prompt: "Refine labels through the no-key native Codex fallback handoff adapter.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
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

        try await Self.waitForRefinementStore(store, timeoutNanoseconds: 6_000_000_000) {
            if case .complete = $0.runState { return true }
            return false
        }

        let outputURL = try XCTUnwrap(store.outputURL)
        let rawResponseURL = try XCTUnwrap(store.rawResponseURL)
        let rawPayloadURL = try XCTUnwrap(store.rawPayloadURL)
        let providerRequestURL = try XCTUnwrap(store.providerRequestURL)
        let metadataURL = try XCTUnwrap(store.metadataURL)
        let sourceCopyURL = try XCTUnwrap(store.sourceCopyURL)
        let runID = store.runID
        let callID = store.providerCallID

        XCTAssertTrue(callID.hasPrefix("swift-codex-"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawResponseURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawPayloadURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: providerRequestURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceCopyURL.path))

        let providerRequest = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: providerRequestURL)) as? [String: Any])
        XCTAssertEqual(providerRequest["adapter"] as? String, "swift_codex")
        XCTAssertEqual(providerRequest["workflow"] as? String, "native_refine")
        XCTAssertEqual(providerRequest["call_id"] as? String, callID)
        XCTAssertEqual(providerRequest["source_image_path"] as? String, sourceCopyURL.path)
        XCTAssertEqual(providerRequest["output_path"] as? String, outputURL.path)

        let rawResponseText = try String(contentsOf: rawResponseURL, encoding: .utf8)
        XCTAssertTrue(rawResponseText.contains(#""adapter" : "swift_codex""#))
        XCTAssertTrue(rawResponseText.contains(callID))

        let metadata = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL)) as? [String: Any])
        XCTAssertEqual(metadata["workflow"] as? String, "native_refine")
        XCTAssertEqual(metadata["provider_call_id"] as? String, callID)
        XCTAssertEqual(metadata["provider_request_path"] as? String, providerRequestURL.path)
        XCTAssertEqual(metadata["source_copy_path"] as? String, sourceCopyURL.path)
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
        XCTAssertEqual(record.workflow, "native_refine")
        XCTAssertEqual(record.providerKind, "codex_fallback")
        XCTAssertEqual(record.model, ImageModelChoice.codexFallback.backendValue)
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.providerRequestPath, providerRequestURL.path)
        XCTAssertEqual(record.rawResponsePath, rawResponseURL.path)
        XCTAssertEqual(record.spendClass, "codex_fallback")

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let call = try XCTUnwrap(calls.first { $0.callID == callID })
        XCTAssertEqual(call.status, .succeeded)
        XCTAssertEqual(call.context, "native_refine")
        XCTAssertEqual(call.provider, "codex_fallback")
        XCTAssertEqual(call.runID, runID)
        XCTAssertEqual(call.usageMetadata["provider_spend"], "none")
        XCTAssertEqual(call.usageMetadata["handoff_adapter"], "swift_codex")
        XCTAssertEqual(call.nativeArtifactURLs.map(\.standardizedFileURL), [outputURL.standardizedFileURL])
    }

    @MainActor
    func testNativeGoogleRefinementProviderFailureKeepsCallVisibleWithoutResponseBytes() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeRefineProviderFailure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let sourceURL = repoRoot.appendingPathComponent("source figure.png")
        try Self.writeTinyPNG(to: sourceURL)

        let store = NativeRefinementStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            googleProviderClient: ThrowingRefinementProviderClient(error: ProviderRuntimeError.providerHTTPStatus(503, "provider unavailable", nil))
        )

        store.start(
            request: NativeRefinementRequest(
                sourceURL: sourceURL,
                prompt: "Refine labels but fail before response bytes.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
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

        try await Self.waitForRefinementStore(store) {
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
        XCTAssertEqual(record.workflow, "native_refine")
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.rawResponsePath, "")
        XCTAssertEqual(record.rawPayloadPath, "")
        XCTAssertTrue(record.message.contains("Provider request failed with HTTP 503"), record.message)

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let call = try XCTUnwrap(calls.first { $0.callID == callID })
        XCTAssertEqual(call.status, .failed)
        XCTAssertEqual(call.context, "native_refine")
        XCTAssertEqual(call.runID, runID)
        XCTAssertTrue(call.needsAttention)
    }

    @MainActor
    func testNativeGoogleRefinementPersistsRawHTTPErrorResponse() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeRefineHTTPErrorBody-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let sourceURL = repoRoot.appendingPathComponent("source figure.png")
        try Self.writeTinyPNG(to: sourceURL)

        let rawBody = Data(#"{"error":"provider unavailable","status":"UNAVAILABLE"}"#.utf8)
        let store = NativeRefinementStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            googleProviderClient: ThrowingRefinementProviderClient(
                error: ProviderRuntimeError.providerHTTPStatus(503, "provider unavailable", rawBody)
            )
        )

        store.start(
            request: NativeRefinementRequest(
                sourceURL: sourceURL,
                prompt: "Refine labels but receive an HTTP error body.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
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

        try await Self.waitForRefinementStore(store) {
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
        XCTAssertEqual(record.workflow, "native_refine")
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.rawResponsePath, rawResponseURL.path)
        XCTAssertEqual(record.rawPayloadPath, "")
        XCTAssertEqual(record.recoveryStatus, "raw_response")

        let call = try XCTUnwrap(ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path).first { $0.callID == callID })
        XCTAssertEqual(call.status, .failed)
        XCTAssertEqual(call.context, "native_refine")
        XCTAssertEqual(call.responseCount, 1)
        XCTAssertTrue(call.artifactURLs.map(\.standardizedFileURL).contains(rawResponseURL.standardizedFileURL))
        XCTAssertTrue(call.recoveryCandidateURLs.map(\.standardizedFileURL).contains(rawResponseURL.standardizedFileURL))
        XCTAssertTrue(call.needsAttention)
    }

    @MainActor
    func testNativeGoogleRefinementPersistsMalformedSuccessRawResponse() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeRefineMalformedBody-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let sourceURL = repoRoot.appendingPathComponent("source figure.png")
        try Self.writeTinyPNG(to: sourceURL)

        let rawBody = Data("not-json-after-paid-refinement-call".utf8)
        let store = NativeRefinementStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            googleProviderClient: ThrowingRefinementProviderClient(
                error: ProviderRuntimeError.malformedProviderResponseBody("Invalid JSON body.", rawBody)
            )
        )

        store.start(
            request: NativeRefinementRequest(
                sourceURL: sourceURL,
                prompt: "Refine labels but receive malformed JSON.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
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

        try await Self.waitForRefinementStore(store) {
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
        XCTAssertEqual(record.workflow, "native_refine")
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.rawResponsePath, rawResponseURL.path)
        XCTAssertEqual(record.rawPayloadPath, "")
        XCTAssertEqual(record.recoveryStatus, "raw_response")
        XCTAssertTrue(record.message.contains("Provider response could not be decoded"), record.message)

        let call = try XCTUnwrap(ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path).first { $0.callID == callID })
        XCTAssertEqual(call.status, .failed)
        XCTAssertEqual(call.context, "native_refine")
        XCTAssertEqual(call.responseCount, 1)
        XCTAssertTrue(call.artifactURLs.map(\.standardizedFileURL).contains(rawResponseURL.standardizedFileURL))
        XCTAssertTrue(call.recoveryCandidateURLs.map(\.standardizedFileURL).contains(rawResponseURL.standardizedFileURL))
        XCTAssertTrue(call.needsAttention)
    }

    @MainActor
    func testNativeGoogleRefinementCancelMarksProviderCallCancelled() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeRefineCancel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let sourceURL = repoRoot.appendingPathComponent("source figure.png")
        try Self.writeTinyPNG(to: sourceURL)

        let store = NativeRefinementStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            googleProviderClient: BlockingRefinementProviderClient()
        )

        store.start(
            request: NativeRefinementRequest(
                sourceURL: sourceURL,
                prompt: "Refine labels then cancel before provider output.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
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
                XCTFail("Cancelled refinement must not complete as an artifact.")
            }
        )

        let runID = store.runID
        let callID = store.providerCallID
        XCTAssertTrue(callID.hasPrefix("swift-gemini-"))

        store.cancel()

        XCTAssertEqual(store.runState, .cancelled("Refinement cancelled by user."))
        XCTAssertTrue(store.milestones.contains { $0.state == .cancelled })

        let record = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot))
        XCTAssertEqual(record.status, .cancelled)
        XCTAssertEqual(record.workflow, "native_refine")
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.message, "Refinement cancelled by user.")

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let call = try XCTUnwrap(calls.first { $0.callID == callID })
        XCTAssertEqual(call.status, .cancelled)
        XCTAssertEqual(call.context, "native_refine")
        XCTAssertTrue(call.needsAttention)
        XCTAssertEqual(call.message, "Refinement cancelled by user.")
    }

    @MainActor
    func testNativeGoogleRefinementTimeoutMarksProviderCallTimedOut() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeRefineTimeout-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let sourceURL = repoRoot.appendingPathComponent("source figure.png")
        try Self.writeTinyPNG(to: sourceURL)

        let store = NativeRefinementStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 0.01,
            googleProviderClient: BlockingRefinementProviderClient()
        )

        store.start(
            request: NativeRefinementRequest(
                sourceURL: sourceURL,
                prompt: "Refine labels then time out before provider output.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
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
                XCTFail("Timed-out refinement must not complete as an artifact.")
            }
        )

        try await Self.waitForRefinementStore(store, timeoutNanoseconds: 3_000_000_000) {
            if case .timedOut = $0.runState { return true }
            return false
        }

        let runID = store.runID
        let callID = store.providerCallID
        XCTAssertTrue(callID.hasPrefix("swift-gemini-"))
        guard case .timedOut(let timedOutMessage) = store.runState else {
            return XCTFail("Expected timed-out refinement state, got \(store.runState).")
        }
        XCTAssertTrue(timedOutMessage.contains("terminating local refinement process"), timedOutMessage)
        XCTAssertTrue(store.milestones.contains { $0.state == .timedOut })

        let record = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot))
        XCTAssertEqual(record.status, .timedOut)
        XCTAssertEqual(record.workflow, "native_refine")
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertTrue(record.message.contains("terminating local refinement process"), record.message)

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let call = try XCTUnwrap(calls.first { $0.callID == callID })
        XCTAssertEqual(call.status, .timedOut)
        XCTAssertEqual(call.context, "native_refine")
        XCTAssertTrue(call.needsAttention)
        XCTAssertTrue(call.message.contains("terminating local refinement process"), call.message)
    }

    @MainActor
    func testNativeGoogleRefinementPreservesRawPayloadWhenImageDecodeFails() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeRefineRawRecovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let sourceURL = repoRoot.appendingPathComponent("source figure.png")
        try Self.writeTinyPNG(to: sourceURL)

        let invalidImageData = Data("not a decodable refinement image".utf8)
        let store = NativeRefinementStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            googleProviderClient: MockRefinementProviderClient(
                imageData: invalidImageData,
                text: "Provider returned refinement bytes.",
                usageMetadata: ["totalTokenCount": "101"]
            )
        )

        store.start(
            request: NativeRefinementRequest(
                sourceURL: sourceURL,
                prompt: "Refine labels with invalid returned bytes.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
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
                XCTFail("Invalid refinement bytes must not complete as a decoded artifact.")
            }
        )

        try await Self.waitForRefinementStore(store) {
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
        XCTAssertEqual(record.workflow, "native_refine")
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.rawResponsePath, rawResponseURL.path)
        XCTAssertEqual(record.rawPayloadPath, rawPayloadURL.path)
        XCTAssertEqual(record.recoveryStatus, "raw_payload")

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let call = try XCTUnwrap(calls.first { $0.callID == callID })
        XCTAssertEqual(call.status, .rawRecovered)
        XCTAssertEqual(call.context, "native_refine")
        XCTAssertEqual(call.rawArtifactURLs.map(\.standardizedFileURL), [rawPayloadURL.standardizedFileURL])
        XCTAssertTrue(call.recoveryCandidateURLs.map(\.standardizedFileURL).contains(rawPayloadURL.standardizedFileURL))
        XCTAssertTrue(call.needsAttention)
    }

    @MainActor
    func testNativeGoogleRefinementPreservesRawResponseWhenProviderReturnsNoImage() async throws {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeRefineNoImage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let sourceURL = repoRoot.appendingPathComponent("source figure.png")
        try Self.writeTinyPNG(to: sourceURL)

        let store = NativeRefinementStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            googleProviderClient: MockRefinementProviderClient(
                imageData: nil,
                text: "Provider returned refinement text but no image.",
                usageMetadata: ["totalTokenCount": "119"]
            )
        )

        store.start(
            request: NativeRefinementRequest(
                sourceURL: sourceURL,
                prompt: "Refine labels but return no image.",
                model: .nanoBananaPro,
                resolution: "4K",
                aspectRatio: "16:9",
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
                XCTFail("No-image refinement response must not complete as an artifact.")
            }
        )

        try await Self.waitForRefinementStore(store) {
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
        XCTAssertEqual(record.workflow, "native_refine")
        XCTAssertEqual(record.providerCallID, callID)
        XCTAssertEqual(record.rawResponsePath, rawResponseURL.path)
        XCTAssertEqual(record.rawPayloadPath, "")
        XCTAssertTrue(record.message.contains("Provider response did not contain image bytes."), record.message)

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let call = try XCTUnwrap(calls.first { $0.callID == callID })
        XCTAssertEqual(call.status, .failed)
        XCTAssertEqual(call.context, "native_refine")
        XCTAssertEqual(call.responseCount, 1)
        XCTAssertEqual(call.usageMetadata["totalTokenCount"], "119")
        XCTAssertTrue(call.artifactURLs.map(\.standardizedFileURL).contains(rawResponseURL.standardizedFileURL))
        XCTAssertTrue(call.recoveryCandidateURLs.map(\.standardizedFileURL).contains(rawResponseURL.standardizedFileURL))
        XCTAssertTrue(call.needsAttention)
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
        bitmap.setColor(NSColor(calibratedRed: 0, green: 0.45, blue: 1, alpha: 1), atX: 0, y: 0)
        return bitmap.representation(using: .png, properties: [:])!
    }

    @MainActor
    private static func waitForRefinementStore(
        _ store: NativeRefinementStore,
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        predicate: (NativeRefinementStore) -> Bool
    ) async throws {
        let step: UInt64 = 20_000_000
        var waited: UInt64 = 0
        while waited < timeoutNanoseconds {
            if predicate(store) { return }
            try await Task.sleep(nanoseconds: step)
            waited += step
        }
        XCTFail("Timed out waiting for refinement store state. Current state: \(store.runState)")
        throw RefinementStoreWaitError.timedOut
    }
}

private enum RefinementStoreWaitError: Error {
    case timedOut
}

private struct MockRefinementProviderClient: ProviderClient {
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
        guard request.sourceImageURL != nil else {
            throw ProviderRuntimeError.missingSourceImage
        }
        if let providerRequestURL = request.providerRequestURL {
            try FileManager.default.createDirectory(at: providerRequestURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let payload: [String: Any] = [
                "mock": true,
                "run_id": request.runID,
                "call_id": request.callID,
                "provider": providerKind.rawValue,
                "workflow": request.workflow.rawValue,
                "prompt": request.prompt,
                "source_image_path": request.sourceImageURL?.path ?? "",
                "output_path": request.outputURL?.path ?? ""
            ]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: providerRequestURL, options: .atomic)
            eventHandler(
                ProviderProgressEvent(
                    stage: "provider_request_saved",
                    progress: 43,
                    message: "Mock native refinement provider request persisted.",
                    callID: request.callID
                )
            )
        }
        eventHandler(
            ProviderProgressEvent(
                stage: "provider_response_saved",
                progress: 78,
                message: "Mock native refinement provider returned response bytes.",
                callID: request.callID
            )
        )
        return ProviderResponse(
            provider: providerKind,
            model: request.effectiveModel,
            callID: request.callID,
            rawResponseData: Data(#"{"mock":true,"workflow":"native_refine","call_id":"\#(request.callID)"}"#.utf8),
            imageData: imageData,
            text: text,
            usageMetadata: usageMetadata
        )
    }
}

private struct ThrowingRefinementProviderClient: ProviderClient {
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

private struct BlockingRefinementProviderClient: ProviderClient {
    let providerKind: ImageProviderKind

    init(providerKind: ImageProviderKind = .googleGemini) {
        self.providerKind = providerKind
    }

    func execute(
        _ request: ProviderClientRequest,
        eventHandler: @escaping @Sendable (ProviderProgressEvent) -> Void
    ) async throws -> ProviderResponse {
        guard request.sourceImageURL != nil else {
            throw ProviderRuntimeError.missingSourceImage
        }
        while true {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
