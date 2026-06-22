import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import PaperBanana

final class ProviderRunLedgerTests: XCTestCase {
    func testPaidModelResolvesToCodexFallbackWhenNoProviderCredentialExists() {
        let settings = PaperBananaSettingsSnapshot(
            repoPath: "/tmp/PaperBanana",
            serverPort: 7860,
            defaultImageModel: .nanoBananaPro,
            codexModel: "gpt-5.5",
            codexReasoning: "xhigh",
            googleAPIKey: "",
            openRouterAPIKey: ""
        )

        let resolved = ImageModelChoice.nanoBananaPro.resolvedForAvailableCredentials(settings: settings)

        XCTAssertEqual(resolved, .codexFallback)
        XCTAssertFalse(resolved.usesPaidProvider(settings: settings))
    }

    func testRunCockpitSurfacesQueuedNativeRunBeforeProviderCall() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaCockpitQueuedTests-\(UUID().uuidString)", isDirectory: true)
        let runDirectory = root.appendingPathComponent("results/native_generate/native_generate_queued", isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let output = runDirectory.appendingPathComponent("generated_4K.png")
        let prompt = runDirectory.appendingPathComponent("prompt.txt")
        let request = runDirectory.appendingPathComponent("request.json")
        let providerRequest = runDirectory.appendingPathComponent("provider_request.json")
        let events = runDirectory.appendingPathComponent("events.jsonl")
        try Data("Generate a queued figure.".utf8).write(to: prompt)
        try Data(#"{"contents":[{"role":"user","parts":[{"text":"Generate a queued figure."}]}]}"#.utf8).write(to: providerRequest)
        try Data(
            """
            {
              "run_id": "native_generate_queued",
              "run_dir": "\(runDirectory.path)",
              "prompt_path": "\(prompt.path)",
              "request_path": "\(request.path)",
              "provider_request_path": "\(providerRequest.path)",
              "log_path": "\(events.path)",
              "output_path": "\(output.path)",
              "model": "gemini-3-pro-image-preview",
              "resolution": "4K",
              "aspect_ratio": "16:9",
              "workflow": "native_generate",
              "status": "queued"
            }
            """.utf8
        ).write(to: request)
        try Data(#"{"stage":"queued","progress":0,"message":"Created durable native generation run record.","run_id":"native_generate_queued","run_dir":"\#(runDirectory.path)","output_path":"\#(output.path)","prompt_path":"\#(prompt.path)","request_path":"\#(request.path)","provider_request_path":"\#(providerRequest.path)","log_path":"\#(events.path)"}"#.utf8).write(to: events)

        let items = NativeRunCockpitScanner.scan(repoRootPath: root.path)

        XCTAssertEqual(items.count, 1)
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.title, "native_generate_queued")
        XCTAssertEqual(item.workflow, "native_generate")
        XCTAssertEqual(item.modelLabel, "Nano Banana Pro")
        XCTAssertEqual(item.resolution, "4K")
        XCTAssertEqual(item.aspectRatio, "16:9")
        XCTAssertEqual(item.currentStage, "queued")
        XCTAssertEqual(item.status, .running)
        XCTAssertTrue(item.hasDurableSpendTrace)
        XCTAssertEqual(item.outputURLs.map(\.path), [output.path])
        XCTAssertEqual(item.promptURL?.path, prompt.path)
        XCTAssertEqual(item.requestURL?.path, request.path)
        XCTAssertEqual(item.providerRequestURL?.path, providerRequest.path)
        XCTAssertEqual(item.eventLogURL?.path, events.path)
        XCTAssertTrue(item.providerCalls.isEmpty)
    }

    func testRunCockpitComputesElapsedTimeFromNativeTimeline() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaCockpitElapsedTests-\(UUID().uuidString)", isDirectory: true)
        let runDirectory = root.appendingPathComponent("results/native_generate/native_generate_elapsed", isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let output = runDirectory.appendingPathComponent("generated_4K.png")
        let events = runDirectory.appendingPathComponent("events.jsonl")
        let tinyPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")!
        try tinyPNG.write(to: output)
        try [
            #"{"stage":"queued","timestamp":"2026-06-14T05:00:00.000Z","run_id":"native_generate_elapsed","output_path":"\#(output.path)"}"#,
            #"{"stage":"model_call","timestamp":"2026-06-14T05:01:10.000Z","run_id":"native_generate_elapsed","output_path":"\#(output.path)"}"#,
            #"{"stage":"complete","timestamp":"2026-06-14T05:02:03.000Z","run_id":"native_generate_elapsed","output_path":"\#(output.path)"}"#
        ].joined(separator: "\n").write(to: events, atomically: true, encoding: .utf8)

        let item = try XCTUnwrap(NativeRunCockpitScanner.scan(repoRootPath: root.path).first)

        XCTAssertEqual(item.status, .completed)
        XCTAssertEqual(item.elapsedTimeText, "2m 3s")
        XCTAssertEqual(try XCTUnwrap(item.elapsedSeconds), 123, accuracy: 0.01)
    }

    func testRunCockpitSurfacesCancelledNativeRunAsAttention() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaCockpitCancelledTests-\(UUID().uuidString)", isDirectory: true)
        let runDirectory = root.appendingPathComponent("results/native_refine/native_refine_cancelled", isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let events = runDirectory.appendingPathComponent("events.jsonl")
        try [
            #"{"stage":"queued","timestamp":"2026-06-14T05:00:00.000Z","run_id":"native_refine_cancelled"}"#,
            #"{"stage":"cancelled","timestamp":"2026-06-14T05:00:12.000Z","run_id":"native_refine_cancelled","message":"User cancelled the native refinement run."}"#
        ].joined(separator: "\n").write(to: events, atomically: true, encoding: .utf8)

        let item = try XCTUnwrap(NativeRunCockpitScanner.scan(repoRootPath: root.path).first)

        XCTAssertEqual(item.status, .cancelled)
        XCTAssertEqual(item.currentStage, "cancelled")
        XCTAssertTrue(item.needsAttention)
        XCTAssertEqual(item.elapsedTimeText, "12s")
    }

    func testRunCockpitSurfacesTimedOutNativeRunAsAttention() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaCockpitTimeoutTests-\(UUID().uuidString)", isDirectory: true)
        let runDirectory = root.appendingPathComponent("results/native_refine/native_refine_timeout", isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let events = runDirectory.appendingPathComponent("events.jsonl")
        try [
            #"{"stage":"queued","timestamp":"2026-06-14T05:00:00.000Z","run_id":"native_refine_timeout"}"#,
            #"{"stage":"timeout","timestamp":"2026-06-14T05:05:00.000Z","run_id":"native_refine_timeout","message":"Provider call exceeded the configured timeout."}"#
        ].joined(separator: "\n").write(to: events, atomically: true, encoding: .utf8)

        let item = try XCTUnwrap(NativeRunCockpitScanner.scan(repoRootPath: root.path).first)

        XCTAssertEqual(item.status, .timedOut)
        XCTAssertEqual(item.currentStage, "timeout")
        XCTAssertTrue(item.needsAttention)
        XCTAssertEqual(item.elapsedTimeText, "5m 0s")
    }

    func testRunCockpitAndEvaluatorSurfaceStaleRunningNativeRunAsAttention() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaCockpitStaleRunningTests-\(UUID().uuidString)", isDirectory: true)
        let runDirectory = root.appendingPathComponent("results/native_generate/native_generate_stale", isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let now = Date()
        let queuedAt = now.addingTimeInterval(-1_200)
        let modelCallAt = now.addingTimeInterval(-1_100)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let events = runDirectory.appendingPathComponent("events.jsonl")
        try [
            #"{"stage":"queued","timestamp":"\#(formatter.string(from: queuedAt))","run_id":"native_generate_stale","message":"Created durable native generation run record."}"#,
            #"{"stage":"model_call","timestamp":"\#(formatter.string(from: modelCallAt))","run_id":"native_generate_stale","message":"Calling image model gemini-3-pro-image-preview."}"#
        ].joined(separator: "\n").write(to: events, atomically: true, encoding: .utf8)

        let item = try XCTUnwrap(NativeRunCockpitScanner.scan(repoRootPath: root.path, now: now).first)

        XCTAssertEqual(item.status, .stalled)
        XCTAssertEqual(item.currentStage, "model_call")
        XCTAssertTrue(item.needsAttention)
        XCTAssertEqual(item.elapsedTimeText, "1m 40s")

        let findings = PaperBananaWorkflowEvaluator.evaluate(repoRootPath: root.path)
        XCTAssertTrue(findings.contains {
            $0.check == .staleRunningRun &&
            $0.severity == .failure &&
            $0.subject == "native_generate_stale"
        })
    }

    func testRunCockpitSurfacesCompletedProviderCallWithoutNativeOutputAsAttention() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaCockpitOrphanTests-\(UUID().uuidString)", isDirectory: true)
        let audit = root.appendingPathComponent("results/provider_audit", isDirectory: true)
        try FileManager.default.createDirectory(at: audit, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let auditArtifact = root.appendingPathComponent("results/provider_audit/images/generated.png")
        try FileManager.default.createDirectory(at: auditArtifact.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: auditArtifact)
        let jsonl = audit.appendingPathComponent("provider_calls_20260614.jsonl")
        try [
            #"{"timestamp":"2026-06-14T05:00:00.000Z","run_id":"missing_native_run","event":"provider_call_started","call_id":"paid-call","provider":"gemini","model":"gemini-3-pro-image-preview","modality":"image","context":"native_generate","attempt":1,"max_attempts":1}"#,
            #"{"timestamp":"2026-06-14T05:00:02.000Z","run_id":"missing_native_run","event":"provider_call_finished","call_id":"paid-call","provider":"gemini","model":"gemini-3-pro-image-preview","modality":"image","context":"native_generate","attempt":1,"success":true,"response_count":1,"artifacts":["\#(auditArtifact.path)"],"message":"Image response received."}"#
        ].joined(separator: "\n").write(to: jsonl, atomically: true, encoding: .utf8)

        let item = try XCTUnwrap(NativeRunCockpitScanner.scan(repoRootPath: root.path).first)

        XCTAssertEqual(item.title, "missing_native_run")
        XCTAssertEqual(item.modelLabel, "Nano Banana Pro")
        XCTAssertEqual(item.status, .unknown)
        XCTAssertTrue(item.needsAttention)
        XCTAssertEqual(item.providerCallIDs, ["paid-call"])
        XCTAssertEqual(item.recoverableURLs.map(\.path), [auditArtifact.path])
        XCTAssertFalse(item.hasDurableSpendTrace)
    }

    func testRunCockpitSurfacesRawResponseAndRawPayloadForFailedDecode() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaCockpitRawTests-\(UUID().uuidString)", isDirectory: true)
        let runDirectory = root.appendingPathComponent("results/native_refine/native_refine_raw", isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = runDirectory.appendingPathComponent("source.png")
        let output = runDirectory.appendingPathComponent("source_refined_4K.png")
        let rawResponse = runDirectory.appendingPathComponent("source_refined_4K_provider_response_20260614.bin")
        let rawPayload = runDirectory.appendingPathComponent("source_refined_4K_provider_raw_20260614.bin")
        let prompt = runDirectory.appendingPathComponent("prompt.txt")
        let request = runDirectory.appendingPathComponent("request.json")
        let events = runDirectory.appendingPathComponent("events.jsonl")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: source)
        try Data("raw response bytes".utf8).write(to: rawResponse)
        try Data("raw payload bytes".utf8).write(to: rawPayload)
        try Data("Refine this figure.".utf8).write(to: prompt)
        try Data(
            """
            {
              "run_id": "native_refine_raw",
              "run_dir": "\(runDirectory.path)",
              "prompt_path": "\(prompt.path)",
              "request_path": "\(request.path)",
              "log_path": "\(events.path)",
              "output_path": "\(output.path)",
              "model": "gemini-3-pro-image-preview",
              "resolution": "4K",
              "aspect_ratio": "16:9",
              "workflow": "native_refine",
              "source_path": "\(source.path)"
            }
            """.utf8
        ).write(to: request)
        try [
            #"{"stage":"provider_response_saved","progress":78,"message":"Saved raw provider response bytes before decoding.","run_id":"native_refine_raw","run_dir":"\#(runDirectory.path)","output_path":"\#(output.path)","prompt_path":"\#(prompt.path)","request_path":"\#(request.path)","log_path":"\#(events.path)","raw_response_path":"\#(rawResponse.path)"}"#,
            #"{"stage":"failed","progress":100,"message":"Failed to decode provider image bytes; raw payload saved.","run_id":"native_refine_raw","run_dir":"\#(runDirectory.path)","output_path":"\#(output.path)","prompt_path":"\#(prompt.path)","request_path":"\#(request.path)","log_path":"\#(events.path)","raw_path":"\#(rawPayload.path)","raw_response_path":"\#(rawResponse.path)"}"#
        ].joined(separator: "\n").write(to: events, atomically: true, encoding: .utf8)

        let item = try XCTUnwrap(NativeRunCockpitScanner.scan(repoRootPath: root.path).first)

        XCTAssertEqual(item.status, .failed)
        XCTAssertTrue(item.needsAttention)
        XCTAssertEqual(item.rawResponseURLs.map(\.path), [rawResponse.path])
        XCTAssertEqual(item.rawPayloadURLs.map(\.path), [rawPayload.path])
        XCTAssertEqual(item.recoverableURLs.map(\.path), [rawPayload.path, rawResponse.path])
        XCTAssertEqual(item.currentStage, "failed")
    }

    func testLedgerGroupsProviderEventsIntoCalls() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaLedgerTests-\(UUID().uuidString)", isDirectory: true)
        let audit = root.appendingPathComponent("results/provider_audit", isDirectory: true)
        try FileManager.default.createDirectory(at: audit, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let imagePath = root.appendingPathComponent("results/provider_audit/images/out.png").path
        let jsonl = audit.appendingPathComponent("provider_calls_20260429.jsonl")
        try [
            #"{"timestamp":"2026-04-29T01:00:00.000Z","run_id":"demo_1","event":"provider_call_started","call_id":"abc123","provider":"gemini","model":"gemini-3-pro-image-preview","modality":"image","context":"refine","attempt":1,"max_attempts":1}"#,
            #"{"timestamp":"2026-04-29T01:00:02.000Z","run_id":"demo_1","event":"provider_image_saved","call_id":"abc123","provider":"gemini","model":"gemini-3-pro-image-preview","path":"\#(imagePath)","bytes":2048}"#,
            #"{"timestamp":"2026-04-29T01:00:03.000Z","run_id":"demo_1","event":"provider_call_finished","call_id":"abc123","provider":"gemini","model":"gemini-3-pro-image-preview","modality":"image","context":"refine","attempt":1,"success":true,"response_count":1,"artifacts":["\#(imagePath)"],"message":"Image response received."}"#
        ].joined(separator: "\n").write(to: jsonl, atomically: true, encoding: .utf8)

        let calls = ProviderRunLedgerScanner.scan(repoRootPath: root.path)

        XCTAssertEqual(calls.count, 1)
        let call = try XCTUnwrap(calls.first)
        XCTAssertEqual(call.callID, "abc123")
        XCTAssertEqual(call.runID, "demo_1")
        XCTAssertEqual(call.provider, "gemini")
        XCTAssertEqual(call.model, "gemini-3-pro-image-preview")
        XCTAssertEqual(call.status, .missingArtifact)
        XCTAssertEqual(call.responseCount, 1)
        XCTAssertEqual(call.artifactURLs.map(\.path), [imagePath])
        XCTAssertEqual(call.recoveryCandidateURLs.map(\.path), [imagePath])
        XCTAssertTrue(call.needsAttention)
    }

    func testLedgerSurfacesSQLiteProviderCallWithoutJSONLAudit() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaSQLiteLedgerTests-\(UUID().uuidString)", isDirectory: true)
        let runDirectory = root.appendingPathComponent("results/native_generate/native_generate_sqlite", isDirectory: true)
        let auditArtifact = root.appendingPathComponent("results/provider_audit/images/sqlite-call.png")
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: auditArtifact.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let output = runDirectory.appendingPathComponent("generated_4K.png")
        let prompt = runDirectory.appendingPathComponent("prompt.txt")
        let request = runDirectory.appendingPathComponent("request.json")
        let providerRequest = runDirectory.appendingPathComponent("provider_request.json")
        let events = runDirectory.appendingPathComponent("events.jsonl")
        let tinyPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")!
        try tinyPNG.write(to: output)
        try tinyPNG.write(to: auditArtifact)
        try Data("Generate a SQLite-ledger figure.".utf8).write(to: prompt)
        try Data(#"{"adapter":"swift_gemini","call_id":"sqlite-only-call"}"#.utf8).write(to: providerRequest)
        try Data(#"{"stage":"complete","timestamp":"2026-06-14T05:00:04.000Z","run_id":"native_generate_sqlite","output_path":"\#(output.path)"}"#.utf8).write(to: events)
        try Data(
            """
            {
              "run_id": "native_generate_sqlite",
              "run_dir": "\(runDirectory.path)",
              "prompt_path": "\(prompt.path)",
              "request_path": "\(request.path)",
              "provider_request_path": "\(providerRequest.path)",
              "log_path": "\(events.path)",
              "output_path": "\(output.path)",
              "model": "gemini-3-pro-image-preview",
              "resolution": "4K",
              "aspect_ratio": "16:9",
              "workflow": "native_generate",
              "status": "complete"
            }
            """.utf8
        ).write(to: request)

        let settings = PaperBananaSettingsSnapshot(
            repoPath: root.path,
            serverPort: 7860,
            defaultImageModel: .nanoBananaPro,
            codexModel: "gpt-5.5",
            codexReasoning: "xhigh",
            googleAPIKey: "test-google-key",
            openRouterAPIKey: ""
        )
        try PaperBananaRunStore.writeQueuedRunSynchronously(
            PaperBananaRunStore.makeRecord(
                runID: "native_generate_sqlite",
                workflow: "native_generate",
                providerPlan: ImageProviderExecutionPlan(requestedModel: .nanoBananaPro, settings: settings),
                settings: settings,
                resolution: "4K",
                aspectRatio: "16:9",
                runDirectoryURL: runDirectory,
                promptURL: prompt,
                requestURL: request,
                providerRequestURL: providerRequest,
                outputURL: output,
                metadataURL: runDirectory.appendingPathComponent("generated_4K.json"),
                eventLogURL: events,
                message: "Queued before provider call."
            ),
            repoRoot: root
        )

        try PaperBananaRunStore.writeProviderCallStartedSynchronously(
            runID: "native_generate_sqlite",
            callID: "sqlite-only-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            repoRoot: root
        )
        try PaperBananaRunStore.writeProviderImageSavedSynchronously(
            runID: "native_generate_sqlite",
            callID: "sqlite-only-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            path: auditArtifact,
            raw: false,
            context: "native_generate",
            repoRoot: root
        )
        try PaperBananaRunStore.writeProviderCallFinishedSynchronously(
            runID: "native_generate_sqlite",
            callID: "sqlite-only-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            success: true,
            responseCount: 1,
            message: "Image response received.",
            artifacts: [auditArtifact],
            usageMetadata: [
                "candidatesTokenCount": "7",
                "totalTokenCount": "42"
            ],
            repoRoot: root
        )

        let call = try XCTUnwrap(ProviderRunLedgerScanner.scan(repoRootPath: root.path).first)

        XCTAssertEqual(call.callID, "sqlite-only-call")
        XCTAssertEqual(call.runID, "native_generate_sqlite")
        XCTAssertEqual(call.status, .succeeded)
        XCTAssertEqual(call.auditLogURL, nil)
        XCTAssertEqual(call.artifactURLs.map(\.standardizedFileURL), [auditArtifact.standardizedFileURL])
        XCTAssertEqual(call.nativeArtifactURLs.map(\.standardizedFileURL), [output.standardizedFileURL])
        XCTAssertEqual(call.nativePromptURL?.standardizedFileURL, prompt.standardizedFileURL)
        XCTAssertEqual(call.nativeRequestURL?.standardizedFileURL, request.standardizedFileURL)
        XCTAssertEqual(call.nativeProviderRequestURL?.standardizedFileURL, providerRequest.standardizedFileURL)
        XCTAssertEqual(call.usageMetadata["totalTokenCount"], "42")
        XCTAssertTrue(call.usageSummary.contains("candidatesTokenCount: 7"))
        XCTAssertFalse(call.needsAttention)
        XCTAssertEqual(call.recoveryCandidateURLs, [])
    }

    func testLedgerKeepsSQLiteSuccessfulCallSucceededWhenRawPayloadAndNativeOutputExist() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaSQLiteSuccessWithRawLedgerTests-\(UUID().uuidString)", isDirectory: true)
        let runDirectory = root.appendingPathComponent("results/native_generate/native_generate_sqlite_success_raw", isDirectory: true)
        let auditArtifact = root.appendingPathComponent("results/provider_audit/images/sqlite-success-call.png")
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: auditArtifact.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let output = runDirectory.appendingPathComponent("generated_4K.png")
        let rawPayload = runDirectory.appendingPathComponent("provider_raw.bin")
        let prompt = runDirectory.appendingPathComponent("prompt.txt")
        let request = runDirectory.appendingPathComponent("request.json")
        let providerRequest = runDirectory.appendingPathComponent("provider_request.json")
        let events = runDirectory.appendingPathComponent("events.jsonl")
        let tinyPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")!
        try tinyPNG.write(to: output)
        try tinyPNG.write(to: auditArtifact)
        try Data("raw bytes retained from provider history".utf8).write(to: rawPayload)
        try Data("Generate a SQLite-ledger figure.".utf8).write(to: prompt)
        try Data(#"{"adapter":"swift_gemini","call_id":"sqlite-success-raw-call"}"#.utf8).write(to: providerRequest)
        try Data(#"{"stage":"complete","timestamp":"2026-06-14T05:00:04.000Z","run_id":"native_generate_sqlite_success_raw","output_path":"\#(output.path)"}"#.utf8).write(to: events)
        try Data(
            """
            {
              "run_id": "native_generate_sqlite_success_raw",
              "run_dir": "\(runDirectory.path)",
              "prompt_path": "\(prompt.path)",
              "request_path": "\(request.path)",
              "provider_request_path": "\(providerRequest.path)",
              "log_path": "\(events.path)",
              "output_path": "\(output.path)",
              "model": "gemini-3-pro-image-preview",
              "resolution": "4K",
              "aspect_ratio": "16:9",
              "workflow": "native_generate",
              "status": "complete"
            }
            """.utf8
        ).write(to: request)

        let settings = PaperBananaSettingsSnapshot(
            repoPath: root.path,
            serverPort: 7860,
            defaultImageModel: .nanoBananaPro,
            codexModel: "gpt-5.5",
            codexReasoning: "xhigh",
            googleAPIKey: "test-google-key",
            openRouterAPIKey: ""
        )
        try PaperBananaRunStore.writeQueuedRunSynchronously(
            PaperBananaRunStore.makeRecord(
                runID: "native_generate_sqlite_success_raw",
                workflow: "native_generate",
                providerPlan: ImageProviderExecutionPlan(requestedModel: .nanoBananaPro, settings: settings),
                settings: settings,
                resolution: "4K",
                aspectRatio: "16:9",
                runDirectoryURL: runDirectory,
                promptURL: prompt,
                requestURL: request,
                providerRequestURL: providerRequest,
                outputURL: output,
                metadataURL: runDirectory.appendingPathComponent("generated_4K.json"),
                eventLogURL: events,
                message: "Queued before provider call."
            ),
            repoRoot: root
        )

        try PaperBananaRunStore.writeProviderCallStartedSynchronously(
            runID: "native_generate_sqlite_success_raw",
            callID: "sqlite-success-raw-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            repoRoot: root
        )
        try PaperBananaRunStore.writeProviderImageSavedSynchronously(
            runID: "native_generate_sqlite_success_raw",
            callID: "sqlite-success-raw-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            path: rawPayload,
            raw: true,
            context: "native_generate",
            repoRoot: root
        )
        try PaperBananaRunStore.writeProviderImageSavedSynchronously(
            runID: "native_generate_sqlite_success_raw",
            callID: "sqlite-success-raw-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            path: auditArtifact,
            raw: false,
            context: "native_generate",
            repoRoot: root
        )
        try PaperBananaRunStore.writeProviderCallFinishedSynchronously(
            runID: "native_generate_sqlite_success_raw",
            callID: "sqlite-success-raw-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            success: true,
            responseCount: 1,
            message: "Image response received after retry.",
            artifacts: [auditArtifact, output],
            repoRoot: root
        )

        let call = try XCTUnwrap(ProviderRunLedgerScanner.scan(repoRootPath: root.path).first)

        XCTAssertEqual(call.status, .succeeded)
        XCTAssertEqual(call.nativeArtifactURLs.map(\.standardizedFileURL), [output.standardizedFileURL])
        XCTAssertEqual(call.rawArtifactURLs.map(\.standardizedFileURL), [rawPayload.standardizedFileURL])
        XCTAssertFalse(call.needsAttention)
        XCTAssertEqual(call.recoveryCandidateURLs, [])
    }

    func testFailedCallKeepsRecoveryCandidatesWhenNativeRunHasInputArtifact() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaFailedNativeInputRecoveryTests-\(UUID().uuidString)", isDirectory: true)
        let nativeInput = root.appendingPathComponent("results/native_refine/native_refine_failed/source.png")
        let rawResponse = root.appendingPathComponent("results/native_refine/native_refine_failed/provider_response.json")
        try FileManager.default.createDirectory(at: nativeInput.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let call = ProviderRunLedgerCall(
            callID: "failed-with-native-input",
            runID: "native_refine_failed",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_refine",
            status: .failed,
            startedAt: nil,
            updatedAt: nil,
            attempt: 1,
            maxAttempts: 1,
            responseCount: 1,
            message: "Provider response did not contain image bytes.",
            error: "",
            usageMetadata: [:],
            artifactURLs: [rawResponse],
            rawArtifactURLs: [],
            runDirectoryURL: nativeInput.deletingLastPathComponent(),
            nativeArtifactURLs: [nativeInput],
            nativePromptURL: nil,
            nativeRequestURL: nil,
            nativeProviderRequestURL: nil,
            nativeEventLogURL: nil,
            auditLogURL: nil
        )

        XCTAssertTrue(call.needsAttention)
        XCTAssertEqual(call.recoveryCandidateURLs.map(\.standardizedFileURL), [rawResponse.standardizedFileURL])
    }

    func testLedgerKeepsJSONLSuccessfulCallSucceededWhenRawPayloadAndNativeOutputExist() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaJSONLSuccessWithRawLedgerTests-\(UUID().uuidString)", isDirectory: true)
        let audit = root.appendingPathComponent("results/provider_audit", isDirectory: true)
        let runDirectory = root.appendingPathComponent("results/native_refine/native_refine_success_raw_json", isDirectory: true)
        try FileManager.default.createDirectory(at: audit, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let output = runDirectory.appendingPathComponent("candidate_0_refined_4K.png")
        let metadata = runDirectory.appendingPathComponent("candidate_0_refined_4K.json")
        let rawPayload = runDirectory.appendingPathComponent("provider_raw.bin")
        let prompt = runDirectory.appendingPathComponent("prompt.txt")
        let providerRequest = runDirectory.appendingPathComponent("provider_request.json")
        let eventLog = runDirectory.appendingPathComponent("events.jsonl")
        let tinyPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")!
        try tinyPNG.write(to: output)
        try Data("raw bytes retained from provider history".utf8).write(to: rawPayload)
        try Data("Improve labels.".utf8).write(to: prompt)
        try Data(#"{"adapter":"swift_gemini","call_id":"json-success-raw-call"}"#.utf8).write(to: providerRequest)
        try Data(#"{"stage":"complete","run_id":"native_refine_success_raw_json","output_path":"\#(output.path)"}"#.utf8).write(to: eventLog)
        try Data(
            """
            {
              "run_id": "native_refine_success_raw_json",
              "run_dir": "\(runDirectory.path)",
              "output_path": "\(output.path)",
              "prompt_path": "\(prompt.path)",
              "provider_request_path": "\(providerRequest.path)",
              "log_path": "\(eventLog.path)",
              "workflow": "native_refine"
            }
            """.utf8
        ).write(to: metadata)

        let jsonl = audit.appendingPathComponent("provider_calls_20260614.jsonl")
        try [
            #"{"timestamp":"2026-06-14T05:00:00.000Z","run_id":"native_refine_success_raw_json","event":"provider_call_started","call_id":"json-success-raw-call","provider":"gemini","model":"gemini-3-pro-image-preview","modality":"image","context":"native_refine","attempt":1,"max_attempts":2}"#,
            #"{"timestamp":"2026-06-14T05:00:01.000Z","run_id":"native_refine_success_raw_json","event":"provider_image_raw_saved","call_id":"json-success-raw-call","provider":"gemini","model":"gemini-3-pro-image-preview","path":"\#(rawPayload.path)","bytes":128,"message":"Provider returned bytes that were preserved for recovery."}"#,
            #"{"timestamp":"2026-06-14T05:00:03.000Z","run_id":"native_refine_success_raw_json","event":"provider_call_finished","call_id":"json-success-raw-call","provider":"gemini","model":"gemini-3-pro-image-preview","modality":"image","context":"native_refine","attempt":2,"success":true,"response_count":1,"artifacts":["\#(output.path)"],"message":"Image response received after retry."}"#
        ].joined(separator: "\n").write(to: jsonl, atomically: true, encoding: .utf8)

        let call = try XCTUnwrap(ProviderRunLedgerScanner.scan(repoRootPath: root.path).first)

        XCTAssertEqual(call.status, .succeeded)
        XCTAssertEqual(call.nativeArtifactURLs.map(\.standardizedFileURL), [output.standardizedFileURL])
        XCTAssertEqual(call.rawArtifactURLs.map(\.standardizedFileURL), [rawPayload.standardizedFileURL])
        XCTAssertFalse(call.needsAttention)
        XCTAssertEqual(call.recoveryCandidateURLs, [])
    }

    func testLedgerFlagsSuccessfulImageCallWithoutArtifacts() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaMissingArtifactLedgerTests-\(UUID().uuidString)", isDirectory: true)
        let audit = root.appendingPathComponent("results/provider_audit", isDirectory: true)
        try FileManager.default.createDirectory(at: audit, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let jsonl = audit.appendingPathComponent("provider_calls_20260429.jsonl")
        try [
            #"{"timestamp":"2026-04-29T01:00:00.000Z","run_id":"demo_2","event":"provider_call_started","call_id":"missing","provider":"gemini","model":"gemini-3-pro-image-preview","modality":"image","context":"refine","attempt":1,"max_attempts":1}"#,
            #"{"timestamp":"2026-04-29T01:00:03.000Z","run_id":"demo_2","event":"provider_call_finished","call_id":"missing","provider":"gemini","model":"gemini-3-pro-image-preview","modality":"image","context":"refine","attempt":1,"success":true,"response_count":1,"artifacts":[],"message":"Image response received."}"#
        ].joined(separator: "\n").write(to: jsonl, atomically: true, encoding: .utf8)

        let call = try XCTUnwrap(ProviderRunLedgerScanner.scan(repoRootPath: root.path).first)

        XCTAssertEqual(call.status, .missingArtifact)
        XCTAssertTrue(call.needsAttention)
    }

    func testLedgerTracksRawRecoveredPayloads() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaRawLedgerTests-\(UUID().uuidString)", isDirectory: true)
        let audit = root.appendingPathComponent("results/provider_audit", isDirectory: true)
        try FileManager.default.createDirectory(at: audit, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let rawPath = root.appendingPathComponent("results/provider_audit/images/provider_raw.bin").path
        let jsonl = audit.appendingPathComponent("provider_calls_20260429.jsonl")
        try [
            #"{"timestamp":"2026-04-29T01:00:00.000Z","run_id":"demo_3","event":"provider_call_started","call_id":"raw","provider":"gemini","model":"gemini-3-pro-image-preview","modality":"image","context":"refine","attempt":1,"max_attempts":1}"#,
            #"{"timestamp":"2026-04-29T01:00:02.000Z","run_id":"demo_3","event":"provider_image_raw_saved","call_id":"raw","provider":"gemini","model":"gemini-3-pro-image-preview","path":"\#(rawPath)","bytes":128,"message":"Provider returned bytes that could not be decoded as an image; raw payload preserved."}"#
        ].joined(separator: "\n").write(to: jsonl, atomically: true, encoding: .utf8)

        let call = try XCTUnwrap(ProviderRunLedgerScanner.scan(repoRootPath: root.path).first)

        XCTAssertEqual(call.status, .rawRecovered)
        XCTAssertEqual(call.rawArtifactURLs.map(\.path), [rawPath])
        XCTAssertEqual(call.recoveryCandidateURLs.map(\.path), [rawPath])
        XCTAssertTrue(call.needsAttention)
    }

    func testLedgerLinksProviderCallToNativeRunFolderArtifacts() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaLedgerRunLinkTests-\(UUID().uuidString)", isDirectory: true)
        let audit = root.appendingPathComponent("results/provider_audit", isDirectory: true)
        let runDirectory = root.appendingPathComponent("results/native_refine/native_refine_test_001", isDirectory: true)
        try FileManager.default.createDirectory(at: audit, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let output = runDirectory.appendingPathComponent("candidate_0_refined_4K.png")
        let metadata = runDirectory.appendingPathComponent("candidate_0_refined_4K.json")
        let prompt = runDirectory.appendingPathComponent("prompt.txt")
        let providerRequest = runDirectory.appendingPathComponent("provider_request.json")
        let eventLog = runDirectory.appendingPathComponent("events.jsonl")
        let tinyPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")!
        try tinyPNG.write(to: output)
        try Data("Improve labels.".utf8).write(to: prompt)
        try Data(#"{"adapter":"swift_gemini","call_id":"abc123"}"#.utf8).write(to: providerRequest)
        try Data(#"{"stage":"complete","run_id":"native_refine_test_001"}"#.utf8).write(to: eventLog)
        try Data(
            """
            {
              "run_id": "native_refine_test_001",
              "run_dir": "\(runDirectory.path)",
              "output_path": "\(output.path)",
              "prompt_path": "\(prompt.path)",
              "provider_request_path": "\(providerRequest.path)",
              "log_path": "\(eventLog.path)",
              "workflow": "native_refine"
            }
            """.utf8
        ).write(to: metadata)

        let jsonl = audit.appendingPathComponent("provider_calls_20260429.jsonl")
        try [
            #"{"timestamp":"2026-04-29T01:00:00.000Z","run_id":"native_refine_test_001","event":"provider_call_started","call_id":"abc123","provider":"gemini","model":"gemini-3-pro-image-preview","modality":"image","context":"refine","attempt":1,"max_attempts":1}"#,
            #"{"timestamp":"2026-04-29T01:00:03.000Z","run_id":"native_refine_test_001","event":"provider_call_finished","call_id":"abc123","provider":"gemini","model":"gemini-3-pro-image-preview","modality":"image","context":"refine","attempt":1,"success":true,"response_count":1,"artifacts":[],"message":"Image response received."}"#
        ].joined(separator: "\n").write(to: jsonl, atomically: true, encoding: .utf8)

        let call = try XCTUnwrap(ProviderRunLedgerScanner.scan(repoRootPath: root.path).first)

        XCTAssertEqual(call.runDirectoryURL?.standardizedFileURL, runDirectory.standardizedFileURL)
        XCTAssertEqual(call.nativeArtifactURLs.map(\.standardizedFileURL), [output.standardizedFileURL])
        XCTAssertEqual(call.status, .succeeded)
        XCTAssertEqual(call.recoveryCandidateURLs, [])
        XCTAssertEqual(call.nativePromptURL?.standardizedFileURL, prompt.standardizedFileURL)
        XCTAssertEqual(call.nativeProviderRequestURL?.standardizedFileURL, providerRequest.standardizedFileURL)
        XCTAssertEqual(call.nativeEventLogURL?.standardizedFileURL, eventLog.standardizedFileURL)
    }

    func testRecoverySurfacerCopiesAuditArtifactIntoRecoveredFolderWithCompanionMetadata() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaRecoverySurfacerTests-\(UUID().uuidString)", isDirectory: true)
        let sourceDirectory = root.appendingPathComponent("results/provider_audit/images", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = sourceDirectory.appendingPathComponent("audit_artifact.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: source)

        let call = ProviderRunLedgerCall(
            callID: "recover-call",
            runID: "native_generate_missing",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            status: .missingArtifact,
            startedAt: nil,
            updatedAt: nil,
            attempt: 1,
            maxAttempts: 1,
            responseCount: 1,
            message: "Image response received.",
            error: "",
            usageMetadata: [:],
            artifactURLs: [source],
            rawArtifactURLs: [],
            runDirectoryURL: nil,
            nativeArtifactURLs: [],
            nativePromptURL: nil,
            nativeRequestURL: nil,
            nativeProviderRequestURL: nil,
            nativeEventLogURL: nil,
            auditLogURL: nil
        )

        let recovered = try ProviderRecoverySurfacer.surfaceFirstRecoverableArtifact(
            for: call,
            repoRootPath: root.path,
            fileManager: .default
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: recovered.artifactURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recovered.metadataURL.path))
        XCTAssertTrue(recovered.artifactURL.path.contains("/results/recovered/"))
        XCTAssertEqual(try Data(contentsOf: recovered.artifactURL), try Data(contentsOf: source))

        let metadata = try JSONSerialization.jsonObject(with: Data(contentsOf: recovered.metadataURL)) as? [String: Any]
        XCTAssertEqual(metadata?["workflow"] as? String, "recovered")
        XCTAssertEqual(metadata?["provider_call_id"] as? String, "recover-call")
        XCTAssertEqual(metadata?["source_path"] as? String, source.path)
    }

    func testWorkflowEvaluatorFlagsInvisibleCompletedProviderSpend() {
        let call = ProviderRunLedgerCall(
            callID: "paid-call-without-run",
            runID: "missing_native_run",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            status: .missingArtifact,
            startedAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 4),
            attempt: 1,
            maxAttempts: 1,
            responseCount: 1,
            message: "Image response received.",
            error: "",
            usageMetadata: [:],
            artifactURLs: [],
            rawArtifactURLs: [],
            runDirectoryURL: nil,
            nativeArtifactURLs: [],
            nativePromptURL: nil,
            nativeRequestURL: nil,
            nativeProviderRequestURL: nil,
            nativeEventLogURL: nil,
            auditLogURL: nil
        )

        let findings = PaperBananaWorkflowEvaluator.evaluate(runs: [], providerCalls: [call])

        XCTAssertTrue(findings.contains {
            $0.check == .invisibleSpend &&
            $0.severity == .failure &&
            $0.subject == "paid-call-without-run"
        })
    }

    func testWorkflowEvaluatorFlagsCompletedOutputMissingMetadata() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaEvaluationMissingMetadataTests-\(UUID().uuidString)", isDirectory: true)
        let runDirectory = root.appendingPathComponent("results/native_generate/native_generate_missing_metadata", isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let output = runDirectory.appendingPathComponent("generated_4K.png")
        let prompt = runDirectory.appendingPathComponent("prompt.txt")
        let request = runDirectory.appendingPathComponent("request.json")
        let events = runDirectory.appendingPathComponent("events.jsonl")
        let tinyPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")!
        try tinyPNG.write(to: output)
        try Data("Create a figure.".utf8).write(to: prompt)
        try Data(
            """
            {
              "run_id": "native_generate_missing_metadata",
              "run_dir": "\(runDirectory.path)",
              "prompt_path": "\(prompt.path)",
              "request_path": "\(request.path)",
              "log_path": "\(events.path)",
              "output_path": "\(output.path)",
              "model": "gemini-3-pro-image-preview",
              "workflow": "native_generate",
              "status": "queued"
            }
            """.utf8
        ).write(to: request)
        try Data(#"{"stage":"complete","run_id":"native_generate_missing_metadata","output_path":"\#(output.path)"}"#.utf8).write(to: events)

        let findings = PaperBananaWorkflowEvaluator.evaluate(repoRootPath: root.path)

        XCTAssertTrue(findings.contains {
            $0.check == .metadataValidation &&
            $0.severity == .failure &&
            $0.subject == "native_generate_missing_metadata"
        })
    }

    func testWorkflowEvaluatorFlagsCompletedOutputBelowRequestedResolution() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaEvaluationLowResolutionTests-\(UUID().uuidString)", isDirectory: true)
        let runDirectory = root.appendingPathComponent("results/native_generate/native_generate_low_resolution", isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let output = runDirectory.appendingPathComponent("generated_4K.png")
        let metadata = runDirectory.appendingPathComponent("generated_4K.json")
        let prompt = runDirectory.appendingPathComponent("prompt.txt")
        let request = runDirectory.appendingPathComponent("request.json")
        let events = runDirectory.appendingPathComponent("events.jsonl")
        let tinyPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")!
        try tinyPNG.write(to: output)
        try Data("Create a high-resolution figure.".utf8).write(to: prompt)
        try Data(
            """
            {
              "run_id": "native_generate_low_resolution",
              "run_dir": "\(runDirectory.path)",
              "prompt_path": "\(prompt.path)",
              "request_path": "\(request.path)",
              "log_path": "\(events.path)",
              "output_path": "\(output.path)",
              "metadata_path": "\(metadata.path)",
              "model": "gemini-3-pro-image-preview",
              "workflow": "native_generate",
              "resolution": "4K",
              "status": "queued"
            }
            """.utf8
        ).write(to: request)
        try Data(
            """
            {
              "run_id": "native_generate_low_resolution",
              "run_dir": "\(runDirectory.path)",
              "prompt_path": "\(prompt.path)",
              "log_path": "\(events.path)",
              "output_path": "\(output.path)",
              "model": "gemini-3-pro-image-preview",
              "workflow": "native_generate",
              "resolution": "4K"
            }
            """.utf8
        ).write(to: metadata)
        try Data(#"{"stage":"complete","run_id":"native_generate_low_resolution","output_path":"\#(output.path)"}"#.utf8).write(to: events)

        let findings = PaperBananaWorkflowEvaluator.evaluate(repoRootPath: root.path)
        let imageQualityFindings = findings.filter { $0.check == .imageQuality }

        XCTAssertFalse(imageQualityFindings.isEmpty)
        XCTAssertTrue(imageQualityFindings.allSatisfy { $0.severity == .warning })
        XCTAssertTrue(imageQualityFindings.contains {
            $0.subject == "native_generate_low_resolution" &&
            $0.message.contains("4K target expects long edge")
        })
        XCTAssertTrue(imageQualityFindings.contains {
            $0.subject == "native_generate_low_resolution" &&
            $0.message.contains("4K target expects at least 6.0 MP")
        })
    }

    func testWorkflowEvaluatorPassesWhenNoRiskIsDetected() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaEvaluationPassTests-\(UUID().uuidString)", isDirectory: true)
        let runDirectory = root.appendingPathComponent("results/native_generate/native_generate_ok", isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let output = runDirectory.appendingPathComponent("generated_4K.png")
        let metadata = runDirectory.appendingPathComponent("generated_4K.json")
        let prompt = runDirectory.appendingPathComponent("prompt.txt")
        let request = runDirectory.appendingPathComponent("request.json")
        let events = runDirectory.appendingPathComponent("events.jsonl")
        try Self.writeSolidPNG(width: 3_000, height: 2_000, to: output)
        try Data("Create a figure.".utf8).write(to: prompt)
        try Data(
            """
            {
              "run_id": "native_generate_ok",
              "run_dir": "\(runDirectory.path)",
              "prompt_path": "\(prompt.path)",
              "request_path": "\(request.path)",
              "log_path": "\(events.path)",
              "output_path": "\(output.path)",
              "metadata_path": "\(metadata.path)",
              "model": "gemini-3-pro-image-preview",
              "workflow": "native_generate",
              "resolution": "4K",
              "status": "queued"
            }
            """.utf8
        ).write(to: request)
        try Data(
            """
            {
              "run_id": "native_generate_ok",
              "run_dir": "\(runDirectory.path)",
              "prompt_path": "\(prompt.path)",
              "log_path": "\(events.path)",
              "output_path": "\(output.path)",
              "model": "gemini-3-pro-image-preview",
              "workflow": "native_generate",
              "resolution": "4K"
            }
            """.utf8
        ).write(to: metadata)
        try Data(#"{"stage":"complete","run_id":"native_generate_ok","output_path":"\#(output.path)"}"#.utf8).write(to: events)

        let findings = PaperBananaWorkflowEvaluator.evaluate(repoRootPath: root.path)

        XCTAssertEqual(findings.count, 1)
        XCTAssertEqual(findings.first?.severity, .pass)
    }

    private static func writeSolidPNG(width: Int, height: Int, to url: URL) throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
              ) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}
