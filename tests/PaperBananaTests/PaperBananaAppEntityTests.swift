import XCTest
@testable import PaperBanana

final class PaperBananaAppEntityTests: XCTestCase {
    func testShortcutProviderAdvertisesCoreAndEntityBackedActions() {
        XCTAssertEqual(PaperBananaShortcutsProvider.appShortcuts.count, 9)
    }

    func testRunEntityQueryUsesDurableRunStore() async throws {
        let root = try Self.makeTemporaryRepoRoot()
        let previousRepoDefault = Self.setRepoDefault(root)
        defer {
            Self.restoreRepoDefault(previousRepoDefault)
            try? FileManager.default.removeItem(at: root)
        }

        let record = Self.makeRunRecord(repoRoot: root, runID: "entity_run_001")
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: root)
        try PaperBananaRunStore.writeEventSynchronously(
            PaperBananaRunStore.event(
                runID: record.id,
                stage: "complete",
                progress: 100,
                message: "Generated output.",
                artifactPath: record.artifactPath,
                providerCallID: "entity-call-001"
            ),
            repoRoot: root
        )

        let matched = try await RunEntityQuery().entities(matching: "entity_run")

        XCTAssertEqual(matched.map(\.id), ["entity_run_001"])
        XCTAssertEqual(matched.first?.status, "completed")
        XCTAssertEqual(matched.first?.provider, "Codex")
        XCTAssertEqual(matched.first?.artifactPath, record.artifactPath)
        XCTAssertEqual(matched.first?.providerRequestPath, record.providerRequestPath)

        let providerRequestMatches = try await RunEntityQuery().entities(matching: "provider_request.json")
        XCTAssertEqual(providerRequestMatches.map(\.id), ["entity_run_001"])
    }

    func testArtifactEntityQuerySearchesIndexedArtifacts() async throws {
        let root = try Self.makeTemporaryRepoRoot()
        let previousRepoDefault = Self.setRepoDefault(root)
        defer {
            Self.restoreRepoDefault(previousRepoDefault)
            try? FileManager.default.removeItem(at: root)
        }

        let artifactDirectory = root.appendingPathComponent("results/native_generate", isDirectory: true)
        try FileManager.default.createDirectory(at: artifactDirectory, withIntermediateDirectories: true)
        let image = artifactDirectory.appendingPathComponent("CIED_workflow_4K.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: image)

        let matched = try await ArtifactEntityQuery().entities(matching: "CIED")

        XCTAssertEqual(matched.map(\.id), [image.standardizedFileURL.path])
        XCTAssertEqual(matched.first?.kind, "Image")
        XCTAssertEqual(matched.first?.workflow, "native_generate")
    }

    func testProviderCallEntityQuerySurfacesRecoverableCalls() async throws {
        let root = try Self.makeTemporaryRepoRoot()
        let previousRepoDefault = Self.setRepoDefault(root)
        defer {
            Self.restoreRepoDefault(previousRepoDefault)
            try? FileManager.default.removeItem(at: root)
        }

        let runDirectory = root.appendingPathComponent("results/native_generate/entity_orphan_run", isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        let providerRequest = runDirectory.appendingPathComponent("provider_request.json")
        try Data(#"{"adapter":"swift_gemini","call_id":"entity-call-001"}"#.utf8).write(to: providerRequest)
        try Data(
            """
            {
              "run_id": "entity_orphan_run",
              "run_dir": "\(runDirectory.path)",
              "provider_request_path": "\(providerRequest.path)",
              "model": "gemini-3-pro-image-preview",
              "workflow": "native_generate"
            }
            """.utf8
        ).write(to: runDirectory.appendingPathComponent("request.json"))
        let auditDirectory = root.appendingPathComponent("results/provider_audit", isDirectory: true)
        let artifactDirectory = auditDirectory.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: artifactDirectory, withIntermediateDirectories: true)
        let rawImage = artifactDirectory.appendingPathComponent("provider_output.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: rawImage)
        let rawPayload = artifactDirectory.appendingPathComponent("provider_raw_payload.bin")
        try Data("raw provider bytes".utf8).write(to: rawPayload)
        let auditLog = auditDirectory.appendingPathComponent("provider_calls_20260614.jsonl")
        try [
            #"{"timestamp":"2026-06-14T05:00:00.000Z","run_id":"entity_orphan_run","event":"provider_call_started","call_id":"entity-call-001","provider":"gemini","model":"gemini-3-pro-image-preview","modality":"image","context":"native_generate","attempt":1,"max_attempts":1}"#,
            #"{"timestamp":"2026-06-14T05:00:02.000Z","run_id":"entity_orphan_run","event":"provider_call_finished","call_id":"entity-call-001","provider":"gemini","model":"gemini-3-pro-image-preview","modality":"image","context":"native_generate","attempt":1,"success":true,"response_count":1,"artifacts":["\#(rawImage.path)"],"usage_metadata":{"totalTokenCount":"42"},"message":"Provider returned an image."}"#,
            #"{"timestamp":"2026-06-14T04:59:00.000Z","run_id":"entity_raw_run","event":"provider_call_started","call_id":"entity-call-raw","provider":"gemini","model":"gemini-3.1-flash-image-preview","modality":"image","context":"native_refine","attempt":1,"max_attempts":1}"#,
            #"{"timestamp":"2026-06-14T04:59:02.000Z","run_id":"entity_raw_run","event":"provider_call_failed","call_id":"entity-call-raw","provider":"gemini","model":"gemini-3.1-flash-image-preview","modality":"image","context":"native_refine","attempt":1,"success":false,"error":"decode failed after provider spend"}"#,
            #"{"timestamp":"2026-06-14T04:59:03.000Z","run_id":"entity_raw_run","event":"provider_image_raw_saved","call_id":"entity-call-raw","provider":"gemini","model":"gemini-3.1-flash-image-preview","modality":"image","context":"native_refine","path":"\#(rawPayload.path)"}"#
        ].joined(separator: "\n").write(to: auditLog, atomically: true, encoding: .utf8)

        let matched = try await ProviderCallEntityQuery().entities(matching: "Nano Banana Pro")

        XCTAssertEqual(matched.map(\.id), ["entity-call-001"])
        XCTAssertEqual(matched.first?.runID, "entity_orphan_run")
        XCTAssertEqual(matched.first?.status, "missingArtifact")
        XCTAssertEqual(matched.first?.usageSummary, "totalTokenCount: 42")
        XCTAssertEqual(matched.first?.providerRequestPath, providerRequest.path)
        XCTAssertTrue(try XCTUnwrap(matched.first?.artifactPaths).contains(rawImage.path))
        XCTAssertEqual(matched.first?.auditLogPath, auditLog.path)
        XCTAssertTrue(try XCTUnwrap(matched.first).hasRecoverableArtifact)

        let usageMatches = try await ProviderCallEntityQuery().entities(matching: "totalTokenCount")
        XCTAssertEqual(usageMatches.map(\.id), ["entity-call-001"])

        let providerRequestMatches = try await ProviderCallEntityQuery().entities(matching: "provider_request.json")
        XCTAssertEqual(providerRequestMatches.map(\.id), ["entity-call-001"])

        let artifactMatches = try await ProviderCallEntityQuery().entities(matching: "provider_output.png")
        XCTAssertEqual(artifactMatches.map(\.id), ["entity-call-001"])

        let auditLogMatches = try await ProviderCallEntityQuery().entities(matching: "provider_calls_20260614")
        XCTAssertEqual(Set(auditLogMatches.map(\.id)), ["entity-call-001", "entity-call-raw"])

        let rawPayloadMatches = try await ProviderCallEntityQuery().entities(matching: "provider_raw_payload.bin")
        XCTAssertEqual(rawPayloadMatches.map(\.id), ["entity-call-raw"])
        XCTAssertTrue(try XCTUnwrap(rawPayloadMatches.first?.rawArtifactPaths).contains(rawPayload.path))
        XCTAssertEqual(rawPayloadMatches.first?.status, "rawRecovered")
    }

    @MainActor
    func testRecoverProviderCallIntentSurfacesArtifactAndRoutesRunDetails() async throws {
        let root = try Self.makeTemporaryRepoRoot()
        let previousRepoDefault = Self.setRepoDefault(root)
        defer {
            Self.restoreRepoDefault(previousRepoDefault)
            Self.clearIntentState()
            try? FileManager.default.removeItem(at: root)
        }

        let rawPayload = try Self.createRecoverableProviderCallFixture(
            root: root,
            callID: "intent-call-raw",
            runID: "intent_raw_run"
        )

        let entities = try await ProviderCallEntityQuery().entities(matching: "intent-call-raw")
        let entity = try XCTUnwrap(entities.first)
        XCTAssertTrue(entity.hasRecoverableArtifact)

        let intent = RecoverPaperBananaProviderCallIntent()
        intent.providerCall = entity
        _ = try await intent.perform()

        let recoveredDirectory = root.appendingPathComponent("results/recovered", isDirectory: true)
        let recoveredArtifacts = try FileManager.default.contentsOfDirectory(
            at: recoveredDirectory,
            includingPropertiesForKeys: nil
        )
        let recoveredPayload = try XCTUnwrap(
            recoveredArtifacts.first {
                $0.pathExtension == rawPayload.pathExtension
                    && $0.lastPathComponent.hasSuffix(".\(rawPayload.pathExtension)")
            }
        )
        let recoveredMetadata = recoveredPayload.deletingPathExtension().appendingPathExtension("json")

        XCTAssertEqual(try Data(contentsOf: recoveredPayload), try Data(contentsOf: rawPayload))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recoveredMetadata.path))
        XCTAssertEqual(UserDefaults.standard.string(forKey: "paperbanana.intent.providerCallID"), "intent-call-raw")
        XCTAssertEqual(PaperBananaIntentBridge.consume(), .runDetails)
    }

    func testGenerateAndRefineIntentsPersistParametersAndRouteNativeWorkflows() async throws {
        defer { Self.clearIntentState() }

        let generate = GeneratePaperBananaFigureIntent()
        generate.prompt = "Build a CONSORT-style MR-linac workflow diagram."
        _ = try await generate.perform()

        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "paperbanana.intent.prompt"),
            "Build a CONSORT-style MR-linac workflow diagram."
        )
        XCTAssertEqual(PaperBananaIntentBridge.consume(), .promptStudio)

        let refine = RefineSelectedPaperBananaImageIntent()
        refine.instructions = "Increase label contrast and preserve panel lettering."
        _ = try await refine.perform()

        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "paperbanana.intent.refineInstructions"),
            "Increase label contrast and preserve panel lettering."
        )
        XCTAssertEqual(PaperBananaIntentBridge.consume(), .refineImage)
    }

    func testOpenRunArtifactSearchFailedAndLatest4KIntentsRouteWithoutExternalSideEffects() async throws {
        let root = try Self.makeTemporaryRepoRoot()
        let previousRepoDefault = Self.setRepoDefault(root)
        defer {
            Self.restoreRepoDefault(previousRepoDefault)
            Self.clearIntentState()
            try? FileManager.default.removeItem(at: root)
        }

        let record = Self.makeRunRecord(repoRoot: root, runID: "intent_failed_run")
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: root)
        try PaperBananaRunStore.writeEventSynchronously(
            PaperBananaRunStore.event(
                runID: record.id,
                stage: "failed",
                progress: 100,
                message: "Provider failed after spend.",
                providerCallID: "intent-failed-call"
            ),
            repoRoot: root
        )

        let artifactDirectory = root.appendingPathComponent("results/native_generate/intent_failed_run", isDirectory: true)
        try FileManager.default.createDirectory(at: artifactDirectory, withIntermediateDirectories: true)
        let latest4K = artifactDirectory.appendingPathComponent("Intent_Latest_4K_Output.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: latest4K)

        let runs = try await RunEntityQuery().entities(matching: "intent_failed_run")
        let run = try XCTUnwrap(runs.first)
        let openRun = OpenPaperBananaRunIntent()
        openRun.run = run
        _ = try await openRun.perform()
        XCTAssertEqual(UserDefaults.standard.string(forKey: "paperbanana.intent.runID"), "intent_failed_run")
        XCTAssertEqual(PaperBananaIntentBridge.consume(), .runDetails)

        let artifacts = try await ArtifactEntityQuery().entities(matching: "Intent_Latest_4K_Output")
        let artifact = try XCTUnwrap(artifacts.first)
        let openArtifact = OpenPaperBananaArtifactIntent()
        openArtifact.artifact = artifact
        _ = try await openArtifact.perform()
        XCTAssertEqual(UserDefaults.standard.string(forKey: "paperbanana.intent.artifactPath"), artifact.id)
        XCTAssertEqual(PaperBananaIntentBridge.consume(), .recoveredImages)

        let search = SearchPaperBananaRunsAndArtifactsIntent()
        search.query = "provider failed after spend"
        _ = try await search.perform()
        XCTAssertEqual(UserDefaults.standard.string(forKey: "paperbanana.intent.search"), "provider failed after spend")
        XCTAssertEqual(PaperBananaIntentBridge.consume(), .runDetails)

        _ = try await ShowFailedPaperBananaRunsIntent().perform()
        XCTAssertEqual(PaperBananaIntentBridge.consume(), .runLedger)

        _ = try await OpenLatest4KPaperBananaOutputIntent().perform()
        XCTAssertEqual(PaperBananaIntentBridge.consume(), .recoveredImages)
    }

    func testRecoverMissingProviderArtifactIntentSurfacesNewestRecoverableArtifact() async throws {
        let root = try Self.makeTemporaryRepoRoot()
        let previousRepoDefault = Self.setRepoDefault(root)
        defer {
            Self.restoreRepoDefault(previousRepoDefault)
            Self.clearIntentState()
            try? FileManager.default.removeItem(at: root)
        }

        let rawPayload = try Self.createRecoverableProviderCallFixture(
            root: root,
            callID: "intent-missing-call",
            runID: "intent_missing_run"
        )

        _ = try await RecoverMissingProviderArtifactIntent().perform()

        let recoveredDirectory = root.appendingPathComponent("results/recovered", isDirectory: true)
        let recoveredArtifacts = try FileManager.default.contentsOfDirectory(
            at: recoveredDirectory,
            includingPropertiesForKeys: nil
        )
        let recoveredPayload = try XCTUnwrap(
            recoveredArtifacts.first {
                $0.pathExtension == rawPayload.pathExtension
                    && $0.lastPathComponent.hasSuffix(".\(rawPayload.pathExtension)")
            }
        )

        XCTAssertEqual(try Data(contentsOf: recoveredPayload), try Data(contentsOf: rawPayload))
        XCTAssertEqual(PaperBananaIntentBridge.consume(), .runDetails)
    }

    private static func makeTemporaryRepoRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaAppEntityTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func setRepoDefault(_ root: URL) -> String? {
        let key = PaperBananaRepoLocator.repoPathDefaultsKey
        let previous = UserDefaults.standard.string(forKey: key)
        UserDefaults.standard.set(root.path, forKey: key)
        return previous
    }

    private static func restoreRepoDefault(_ previous: String?) {
        let key = PaperBananaRepoLocator.repoPathDefaultsKey
        if let previous {
            UserDefaults.standard.set(previous, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private static func clearIntentState() {
        [
            PaperBananaIntentBridge.destinationKey,
            "paperbanana.intent.prompt",
            "paperbanana.intent.refineInstructions",
            "paperbanana.intent.runID",
            "paperbanana.intent.artifactPath",
            "paperbanana.intent.providerCallID",
            "paperbanana.intent.search"
        ].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
    }

    private static func makeRunRecord(repoRoot: URL, runID: String) -> RunRecord {
        let settings = PaperBananaSettingsSnapshot(
            repoPath: repoRoot.path,
            serverPort: 7860,
            defaultImageModel: .codexFallback,
            codexModel: "gpt-5.5",
            codexReasoning: "xhigh",
            googleAPIKey: "",
            openRouterAPIKey: ""
        )
        let providerPlan = ImageProviderExecutionPlan(requestedModel: .codexFallback, settings: settings)
        let runDirectory = repoRoot.appendingPathComponent("results/native_generate/\(runID)", isDirectory: true)
        return PaperBananaRunStore.makeRecord(
            runID: runID,
            workflow: "native_generate",
            providerPlan: providerPlan,
            settings: settings,
            resolution: "4K",
            aspectRatio: "16:9",
            runDirectoryURL: runDirectory,
            promptURL: runDirectory.appendingPathComponent("prompt.txt"),
            requestURL: runDirectory.appendingPathComponent("request.json"),
            providerRequestURL: runDirectory.appendingPathComponent("provider_request.json"),
            outputURL: runDirectory.appendingPathComponent("output.png"),
            metadataURL: runDirectory.appendingPathComponent("output.json"),
            eventLogURL: runDirectory.appendingPathComponent("events.jsonl"),
            message: "Queued."
        )
    }

    private static func createRecoverableProviderCallFixture(
        root: URL,
        callID: String,
        runID: String
    ) throws -> URL {
        let auditDirectory = root.appendingPathComponent("results/provider_audit", isDirectory: true)
        let artifactDirectory = auditDirectory.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: artifactDirectory, withIntermediateDirectories: true)

        let rawPayload = artifactDirectory.appendingPathComponent("\(callID)_raw_payload.bin")
        try Data("raw provider bytes from app intent".utf8).write(to: rawPayload)

        let auditLog = auditDirectory.appendingPathComponent("provider_calls_20260614.jsonl")
        try [
            #"{"timestamp":"2026-06-14T05:10:00.000Z","run_id":"\#(runID)","event":"provider_call_started","call_id":"\#(callID)","provider":"gemini","model":"gemini-3.1-flash-image-preview","modality":"image","context":"native_refine","attempt":1,"max_attempts":1}"#,
            #"{"timestamp":"2026-06-14T05:10:02.000Z","run_id":"\#(runID)","event":"provider_call_failed","call_id":"\#(callID)","provider":"gemini","model":"gemini-3.1-flash-image-preview","modality":"image","context":"native_refine","attempt":1,"success":false,"error":"decode failed after provider spend"}"#,
            #"{"timestamp":"2026-06-14T05:10:03.000Z","run_id":"\#(runID)","event":"provider_image_raw_saved","call_id":"\#(callID)","provider":"gemini","model":"gemini-3.1-flash-image-preview","modality":"image","context":"native_refine","path":"\#(rawPayload.path)"}"#
        ].joined(separator: "\n").write(to: auditLog, atomically: true, encoding: .utf8)

        return rawPayload
    }
}
