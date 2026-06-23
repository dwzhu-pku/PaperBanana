import Darwin
import SQLite3
import XCTest
@testable import PaperBanana

@MainActor
final class WP109RuntimeUserDataMigrationTests: XCTestCase {
    func testRuntimeUserDataMigrationUsesIsolatedApplicationSupportAndPreservesRepoArtifacts() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaWP109RuntimeTests-\(UUID().uuidString)", isDirectory: true)
        let appSupportRoot = root.appendingPathComponent("Application Support", isDirectory: true)
        let repoRoot = root.appendingPathComponent("repo", isDirectory: true)
        let suiteName = "local.paperbanana.gui.wp109.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated UserDefaults suite.")
        }
        defer {
            unsetenv("PAPERBANANA_APPLICATION_SUPPORT_ROOT")
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: appSupportRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        setenv("PAPERBANANA_APPLICATION_SUPPORT_ROOT", appSupportRoot.path, 1)
        defaults.set(repoRoot.path, forKey: "settings.repoPath")

        let sentinelSecrets = PaperBananaSecrets(
            googleAPIKey: "wp109-google-fake-sentinel",
            openRouterAPIKey: "wp109-openrouter-fake-sentinel"
        )
        try PaperBananaSecretStore.save(sentinelSecrets)
        let secretsURL = PaperBananaSecretStore.defaultURL
        XCTAssertTrue(secretsURL.path.hasPrefix(appSupportRoot.path))
        let secretBytesBefore = try Data(contentsOf: secretsURL)

        let settings = AppSettingsStore(defaults: defaults)
        XCTAssertEqual(settings.repoPath, repoRoot.path)
        XCTAssertEqual(settings.snapshot.googleAPIKey, sentinelSecrets.googleAPIKey)
        XCTAssertEqual(settings.snapshot.openRouterAPIKey, sentinelSecrets.openRouterAPIKey)
        XCTAssertEqual(PaperBananaSecretStore.status().filePermissions, 0o600)
        XCTAssertEqual(PaperBananaSecretStore.status().directoryPermissions, 0o700)

        let runID = "wp109_stale_runtime_run"
        let callID = "wp109-stale-provider-call"
        let runDirectory = repoRoot.appendingPathComponent("results/native_refine/\(runID)", isDirectory: true)
        let outputURL = runDirectory.appendingPathComponent("output.png")
        let metadataURL = runDirectory.appendingPathComponent("output.json")
        let promptURL = runDirectory.appendingPathComponent("prompt.txt")
        let requestURL = runDirectory.appendingPathComponent("request.json")
        let providerRequestURL = runDirectory.appendingPathComponent("provider_request.json")
        let eventLogURL = runDirectory.appendingPathComponent("events.jsonl")
        try seedNativeRunFolder(
            runID: runID,
            callID: callID,
            repoRoot: repoRoot,
            runDirectory: runDirectory,
            outputURL: outputURL,
            metadataURL: metadataURL,
            promptURL: promptURL,
            requestURL: requestURL,
            providerRequestURL: providerRequestURL,
            eventLogURL: eventLogURL
        )
        let outputBytesBefore = try Data(contentsOf: outputURL)
        let metadataBytesBefore = try Data(contentsOf: metadataURL)

        let databaseURL = PaperBananaRunStore.databaseURL(repoRoot: repoRoot)
        try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try createLegacyRunStoreDatabase(
            at: databaseURL,
            runID: runID,
            callID: callID,
            repoRoot: repoRoot,
            runDirectory: runDirectory,
            outputURL: outputURL,
            metadataURL: metadataURL,
            promptURL: promptURL,
            requestURL: requestURL,
            eventLogURL: eventLogURL
        )

        let recovered = try PaperBananaRunStore.recoverStaleNonTerminalRunsSynchronously(
            repoRoot: repoRoot,
            now: Date(timeIntervalSinceReferenceDate: 1_000_000),
            staleAfter: 1
        )

        XCTAssertEqual(recovered.map(\.id), [runID])
        let migratedRun = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot))
        XCTAssertEqual(migratedRun.status, .timedOut)
        XCTAssertEqual(migratedRun.providerRequestPath, "")
        XCTAssertEqual(migratedRun.providerCallID, callID)
        XCTAssertEqual(migratedRun.projectPath, repoRoot.path)
        XCTAssertTrue(migratedRun.message.contains("marked timed out"))

        let migratedCall = try XCTUnwrap(PaperBananaRunStore.fetchProviderCallSynchronously(callID: callID, repoRoot: repoRoot))
        XCTAssertEqual(migratedCall.status, ProviderRunStatus.timedOut.rawValue)
        XCTAssertEqual(migratedCall.usageMetadata, [:])
        XCTAssertEqual(migratedCall.runID, runID)

        let runDetails = RunDetailsScanner.scan(repoRootPath: repoRoot.path)
        let cockpitItem = try XCTUnwrap(runDetails.first { $0.run.runID == runID })
        XCTAssertEqual(cockpitItem.providerCalls.map(\.callID), [callID])
        XCTAssertTrue(cockpitItem.needsAttention)

        let ledgerCalls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        let ledgerCall = try XCTUnwrap(ledgerCalls.first { $0.callID == callID })
        XCTAssertEqual(ledgerCall.status, .timedOut)
        XCTAssertEqual(ledgerCall.runDirectoryURL?.path, runDirectory.path)
        XCTAssertTrue(ledgerCall.needsAttention)

        let artifacts = ArtifactLibraryScanner.scan(repoRootPath: repoRoot.path)
        let outputArtifact = try XCTUnwrap(artifacts.first { $0.url == outputURL.standardizedFileURL })
        XCTAssertEqual(outputArtifact.runID, runID)
        XCTAssertEqual(outputArtifact.runStatus, .stalled)
        XCTAssertEqual(outputArtifact.referenceProvenance.summaryText, "1 manual reference example: wp109_ref")

        XCTAssertEqual(try Data(contentsOf: secretsURL), secretBytesBefore)
        XCTAssertEqual(try Data(contentsOf: outputURL), outputBytesBefore)
        XCTAssertEqual(try Data(contentsOf: metadataURL), metadataBytesBefore)
        XCTAssertFalse(FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("results/provider_audit").path))
    }

    private func seedNativeRunFolder(
        runID: String,
        callID: String,
        repoRoot: URL,
        runDirectory: URL,
        outputURL: URL,
        metadataURL: URL,
        promptURL: URL,
        requestURL: URL,
        providerRequestURL: URL,
        eventLogURL: URL
    ) throws {
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        try Data(base64Encoded: Self.tinyPNGBase64).map { try $0.write(to: outputURL) }
        try "WP-109 runtime migration fixture prompt.".write(to: promptURL, atomically: true, encoding: .utf8)
        try """
        {
          "adapter": "wp109-fixture",
          "provider_spend": "none",
          "run_id": "\(runID)"
        }
        """.write(to: providerRequestURL, atomically: true, encoding: .utf8)
        try """
        {
          "run_id": "\(runID)",
          "run_dir": "\(runDirectory.path)",
          "workflow": "native_refine",
          "model": "__codex_gpt55_xhigh__",
          "resolution": "4K",
          "aspect_ratio": "16:9",
          "output_path": "\(outputURL.path)",
          "prompt_path": "\(promptURL.path)",
          "provider_request_path": "\(providerRequestURL.path)",
          "log_path": "\(eventLogURL.path)",
          "metadata_path": "\(metadataURL.path)",
          "reference_mode": "manual_native_prompt_enrichment",
          "reference_example_count": 1,
          "reference_examples": [
            {
              "id": "wp109_ref",
              "visual_intent": "Preserve user runtime data during upgrade.",
              "content_summary": "Fake non-private WP-109 migration fixture.",
              "image_path": "data/PaperBananaBench/diagram/images/wp109_ref.png",
              "reference_source": "wp109_fixture"
            }
          ]
        }
        """.write(to: metadataURL, atomically: true, encoding: .utf8)
        try """
        {
          "run_id": "\(runID)",
          "workflow": "native_refine",
          "run_dir": "\(runDirectory.path)",
          "output_path": "\(outputURL.path)",
          "prompt_path": "\(promptURL.path)",
          "provider_request_path": "\(providerRequestURL.path)",
          "log_path": "\(eventLogURL.path)",
          "metadata_path": "\(metadataURL.path)",
          "reference_mode": "manual_native_prompt_enrichment",
          "reference_example_count": 1,
          "reference_examples": [
            {
              "id": "wp109_ref",
              "visual_intent": "Preserve user runtime data during upgrade.",
              "content_summary": "Fake non-private WP-109 migration fixture.",
              "image_path": "data/PaperBananaBench/diagram/images/wp109_ref.png",
              "reference_source": "wp109_fixture"
            }
          ]
        }
        """.write(to: requestURL, atomically: true, encoding: .utf8)
        try """
        {"run_id":"\(runID)","stage":"running","progress":50,"message":"Provider call still running before upgrade.","timestamp":"2001-01-01T00:00:00.000Z","output_path":"\(outputURL.path)","metadata_path":"\(metadataURL.path)","provider_call_id":"\(callID)"}
        """.write(to: eventLogURL, atomically: true, encoding: .utf8)

        _ = repoRoot
    }

    private func createLegacyRunStoreDatabase(
        at databaseURL: URL,
        runID: String,
        callID: String,
        repoRoot: URL,
        runDirectory: URL,
        outputURL: URL,
        metadataURL: URL,
        promptURL: URL,
        requestURL: URL,
        eventLogURL: URL
    ) throws {
        var database: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK, let database else {
            throw NSError(domain: "WP109RuntimeUserDataMigrationTests", code: 1)
        }
        defer { sqlite3_close(database) }

        let sql = """
        CREATE TABLE runs (
            id TEXT PRIMARY KEY,
            workflow TEXT NOT NULL,
            status TEXT NOT NULL,
            provider TEXT NOT NULL,
            provider_kind TEXT NOT NULL,
            model TEXT NOT NULL,
            requested_model TEXT NOT NULL,
            resolution TEXT NOT NULL,
            aspect_ratio TEXT NOT NULL,
            project_path TEXT NOT NULL,
            run_dir TEXT NOT NULL,
            prompt_path TEXT NOT NULL,
            request_path TEXT NOT NULL,
            raw_response_path TEXT NOT NULL DEFAULT '',
            raw_payload_path TEXT NOT NULL DEFAULT '',
            artifact_path TEXT NOT NULL DEFAULT '',
            metadata_path TEXT NOT NULL DEFAULT '',
            event_log_path TEXT NOT NULL DEFAULT '',
            provider_call_id TEXT NOT NULL DEFAULT '',
            spend_class TEXT NOT NULL DEFAULT '',
            recovery_status TEXT NOT NULL DEFAULT 'none',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            elapsed_seconds REAL NOT NULL DEFAULT 0,
            message TEXT NOT NULL DEFAULT ''
        );
        INSERT INTO runs (
            id, workflow, status, provider, provider_kind, model, requested_model,
            resolution, aspect_ratio, project_path, run_dir, prompt_path, request_path,
            raw_response_path, raw_payload_path, artifact_path, metadata_path,
            event_log_path, provider_call_id, spend_class, recovery_status,
            created_at, updated_at, elapsed_seconds, message
        ) VALUES (
            '\(sql(runID))', 'native_refine', 'running', 'Codex fallback',
            'codex_fallback', '__codex_gpt55_xhigh__', 'gemini-3-pro-image-preview',
            '4K', '16:9', '\(sql(repoRoot.path))', '\(sql(runDirectory.path))',
            '\(sql(promptURL.path))', '\(sql(requestURL.path))', '', '',
            '\(sql(outputURL.path))', '\(sql(metadataURL.path))',
            '\(sql(eventLogURL.path))', '\(sql(callID))', 'no_provider_spend',
            'none', '2001-01-01T00:00:00.000Z', '2001-01-01T00:00:00.000Z',
            0, 'Legacy running run before upgrade.'
        );
        CREATE TABLE provider_calls (
            call_id TEXT PRIMARY KEY,
            run_id TEXT NOT NULL,
            provider TEXT NOT NULL,
            model TEXT NOT NULL,
            modality TEXT NOT NULL,
            context TEXT NOT NULL,
            status TEXT NOT NULL,
            started_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            attempt INTEGER NOT NULL DEFAULT 0,
            max_attempts INTEGER NOT NULL DEFAULT 0,
            response_count INTEGER NOT NULL DEFAULT 0,
            message TEXT NOT NULL DEFAULT '',
            error TEXT NOT NULL DEFAULT '',
            artifact_paths TEXT NOT NULL DEFAULT '[]',
            raw_artifact_paths TEXT NOT NULL DEFAULT '[]'
        );
        INSERT INTO provider_calls (
            call_id, run_id, provider, model, modality, context, status,
            started_at, updated_at, attempt, max_attempts, response_count,
            message, error, artifact_paths, raw_artifact_paths
        ) VALUES (
            '\(sql(callID))', '\(sql(runID))', 'codex', '__codex_gpt55_xhigh__',
            'image', 'native_refine', 'running',
            '2001-01-01T00:00:00.000Z', '2001-01-01T00:00:00.000Z',
            1, 1, 0, 'Legacy provider call still running before upgrade.', '', '[]', '[]'
        );
        """

        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "unknown SQLite error"
            sqlite3_free(error)
            throw NSError(
                domain: "WP109RuntimeUserDataMigrationTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }

    private func sql(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    private static let tinyPNGBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
}
