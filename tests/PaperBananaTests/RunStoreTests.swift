import XCTest
import SQLite3
@testable import PaperBanana

final class RunStoreTests: XCTestCase {
    func testRunStorePersistsQueuedRunBeforeProviderEvent() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let settings = PaperBananaSettingsSnapshot(
            repoPath: repoRoot.path,
            serverPort: 7860,
            defaultImageModel: .nanoBananaPro,
            codexModel: "gpt-5.5",
            codexReasoning: "xhigh",
            googleAPIKey: "test-google-key",
            openRouterAPIKey: ""
        )
        let providerPlan = ImageProviderExecutionPlan(requestedModel: .nanoBananaPro, settings: settings)
        let runDirectory = repoRoot.appendingPathComponent("results/native_generate/native_generate_test", isDirectory: true)
        let promptURL = runDirectory.appendingPathComponent("prompt.txt")
        let requestURL = runDirectory.appendingPathComponent("request.json")
        let providerRequestURL = runDirectory.appendingPathComponent("provider_request.json")
        let outputURL = runDirectory.appendingPathComponent("generated_4K.png")
        let metadataURL = runDirectory.appendingPathComponent("generated_4K.json")
        let logURL = runDirectory.appendingPathComponent("events.jsonl")

        let record = PaperBananaRunStore.makeRecord(
            runID: "native_generate_test",
            workflow: "native_generate",
            providerPlan: providerPlan,
            settings: settings,
            resolution: "4K",
            aspectRatio: "16:9",
            runDirectoryURL: runDirectory,
            promptURL: promptURL,
            requestURL: requestURL,
            providerRequestURL: providerRequestURL,
            outputURL: outputURL,
            metadataURL: metadataURL,
            eventLogURL: logURL,
            message: "Queued before provider call."
        )

        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)

        let fetched = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: "native_generate_test", repoRoot: repoRoot))
        XCTAssertEqual(fetched.status, .queued)
        XCTAssertEqual(fetched.providerKind, "google_gemini")
        XCTAssertEqual(fetched.spendClass, "paid_provider")
        XCTAssertEqual(fetched.providerRequestPath, providerRequestURL.path)
        XCTAssertEqual(fetched.artifactPath, outputURL.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: PaperBananaRunStore.databaseURL(repoRoot: repoRoot).path))
    }

    func testRunStorePersistsAppendOnlyEventTimelineInSQLite() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        var record = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_generate_event_timeline")
        record.createdAt = "2026-06-14T06:00:00.000Z"
        record.updatedAt = record.createdAt
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)

        let queued = PaperBananaRunEvent(
            runID: record.id,
            stage: "queued",
            progress: 2,
            message: "Run queued before provider spend.",
            timestamp: "2026-06-14T06:00:00.000Z",
            rawResponsePath: "",
            rawPayloadPath: "",
            artifactPath: "",
            metadataPath: "",
            providerCallID: ""
        )
        let running = PaperBananaRunEvent(
            runID: record.id,
            stage: "provider_call_started",
            progress: 25,
            message: "Provider call started.",
            timestamp: "2026-06-14T06:00:03.000Z",
            rawResponsePath: "",
            rawPayloadPath: "",
            artifactPath: "",
            metadataPath: "",
            providerCallID: "call-timeline-1"
        )
        let failed = PaperBananaRunEvent(
            runID: record.id,
            stage: "failed",
            progress: 100,
            message: "Provider bytes were preserved but could not be decoded.",
            timestamp: "2026-06-14T06:00:09.250Z",
            rawResponsePath: record.runDirectoryPath + "/provider_response.json",
            rawPayloadPath: record.runDirectoryPath + "/provider_raw.bin",
            artifactPath: "",
            metadataPath: record.metadataPath,
            providerCallID: "call-timeline-1"
        )

        try PaperBananaRunStore.writeEventSynchronously(queued, repoRoot: repoRoot)
        try PaperBananaRunStore.writeEventSynchronously(running, repoRoot: repoRoot)
        try PaperBananaRunStore.writeEventSynchronously(failed, repoRoot: repoRoot)

        let events = try PaperBananaRunStore.fetchEventsSynchronously(runID: record.id, repoRoot: repoRoot)
        XCTAssertEqual(events, [queued, running, failed])

        let limitedEvents = try PaperBananaRunStore.fetchEventsSynchronously(runID: record.id, repoRoot: repoRoot, limit: 2)
        XCTAssertEqual(limitedEvents, [queued, running])

        let fetched = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: record.id, repoRoot: repoRoot))
        XCTAssertEqual(fetched.status, .failed)
        XCTAssertEqual(fetched.providerCallID, "call-timeline-1")
        XCTAssertEqual(fetched.rawResponsePath, failed.rawResponsePath)
        XCTAssertEqual(fetched.rawPayloadPath, failed.rawPayloadPath)
        XCTAssertEqual(fetched.recoveryStatus, "raw_payload")
        XCTAssertEqual(fetched.elapsedSeconds, 9.25, accuracy: 0.01)
        XCTAssertEqual(fetched.message, failed.message)
    }

    func testRunStoreRejectsOrphanEventBeforeSQLiteAppend() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let orphanEvent = PaperBananaRunStore.event(
            runID: "missing_native_run",
            stage: "failed",
            progress: 100,
            message: "This event must not be persisted without a durable run row.",
            rawResponsePath: repoRoot.appendingPathComponent("raw-response.json").path,
            rawPayloadPath: repoRoot.appendingPathComponent("raw-payload.bin").path,
            providerCallID: "orphan-call"
        )

        XCTAssertThrowsError(try PaperBananaRunStore.writeEventSynchronously(orphanEvent, repoRoot: repoRoot)) { error in
            guard case PaperBananaRunStoreError.missingRunRecord(let runID) = error else {
                XCTFail("Expected missing run record for orphan event, got \(error).")
                return
            }
            XCTAssertEqual(runID, "missing_native_run")
        }

        XCTAssertNil(try PaperBananaRunStore.fetchRunSynchronously(id: "missing_native_run", repoRoot: repoRoot))
        XCTAssertEqual(try PaperBananaRunStore.fetchEventsSynchronously(runID: "missing_native_run", repoRoot: repoRoot), [])
    }

    func testRunStoreMigratesLegacyDatabaseBeforeWritingProviderRequestPath() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        let databaseURL = PaperBananaRunStore.databaseURL(repoRoot: repoRoot)
        try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.createLegacyRunsDatabase(at: databaseURL)

        let record = Self.makeCodexRecord(repoRoot: repoRoot, runID: "legacy_provider_request_migration")
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)

        let fetched = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: record.id, repoRoot: repoRoot))
        XCTAssertEqual(fetched.providerRequestPath, record.providerRequestPath)
        XCTAssertEqual(fetched.status, .queued)
    }

    func testRunStoreEventTransitionsStatusAndKeepsRawRecoveryPaths() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        var record = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_refine_test")
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)

        let rawResponse = record.runDirectoryPath + "/provider_response.bin"
        let rawPayload = record.runDirectoryPath + "/provider_raw.bin"
        let failedEvent = PaperBananaRunStore.event(
            runID: record.id,
            stage: "failed",
            progress: 100,
            message: "Failed to decode provider image bytes.",
            rawResponsePath: rawResponse,
            rawPayloadPath: rawPayload,
            artifactPath: record.artifactPath,
            metadataPath: record.metadataPath,
            providerCallID: "call-123"
        )

        try PaperBananaRunStore.writeEventSynchronously(failedEvent, repoRoot: repoRoot)

        record = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: record.id, repoRoot: repoRoot))
        XCTAssertEqual(record.status, .failed)
        XCTAssertEqual(record.rawResponsePath, rawResponse)
        XCTAssertEqual(record.rawPayloadPath, rawPayload)
        XCTAssertEqual(record.providerCallID, "call-123")
        XCTAssertEqual(record.message, "Failed to decode provider image bytes.")
    }

    func testRunStoreEventPersistsElapsedTimeAndRawRecoveryStatus() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        var record = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_refine_terminal_state")
        record.createdAt = "2026-06-14T05:00:00.000Z"
        record.updatedAt = record.createdAt
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)

        let rawResponse = record.runDirectoryPath + "/provider_response.json"
        let rawPayload = record.runDirectoryPath + "/provider_raw.bin"
        try PaperBananaRunStore.writeEventSynchronously(
            PaperBananaRunEvent(
                runID: record.id,
                stage: "failed",
                progress: 100,
                message: "Provider payload could not be decoded; raw payload preserved.",
                timestamp: "2026-06-14T05:00:12.500Z",
                rawResponsePath: rawResponse,
                rawPayloadPath: rawPayload,
                artifactPath: record.artifactPath,
                metadataPath: record.metadataPath,
                providerCallID: "terminal-call"
            ),
            repoRoot: repoRoot
        )

        let fetched = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: record.id, repoRoot: repoRoot))
        XCTAssertEqual(fetched.status, .failed)
        XCTAssertEqual(fetched.recoveryStatus, "raw_payload")
        XCTAssertEqual(fetched.rawResponsePath, rawResponse)
        XCTAssertEqual(fetched.rawPayloadPath, rawPayload)
        XCTAssertEqual(fetched.providerCallID, "terminal-call")
        XCTAssertEqual(fetched.elapsedSeconds, 12.5, accuracy: 0.01)
    }

    func testRunStoreMarksFailedRawResponseAsRecoverableEvenWithDeclaredOutputPath() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        var record = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_generate_raw_response_only")
        record.createdAt = "2026-06-14T05:20:00.000Z"
        record.updatedAt = record.createdAt
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)

        let rawResponse = record.runDirectoryPath + "/generated_4K.provider_response.json"
        try PaperBananaRunStore.writeEventSynchronously(
            PaperBananaRunEvent(
                runID: record.id,
                stage: "failed",
                progress: 100,
                message: "Provider returned an HTTP error body; raw response preserved.",
                timestamp: "2026-06-14T05:20:04.000Z",
                rawResponsePath: rawResponse,
                rawPayloadPath: "",
                artifactPath: record.artifactPath,
                metadataPath: record.metadataPath,
                providerCallID: "raw-response-call"
            ),
            repoRoot: repoRoot
        )

        let fetched = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: record.id, repoRoot: repoRoot))
        XCTAssertEqual(fetched.status, .failed)
        XCTAssertEqual(fetched.rawResponsePath, rawResponse)
        XCTAssertEqual(fetched.rawPayloadPath, "")
        XCTAssertEqual(fetched.artifactPath, record.artifactPath)
        XCTAssertEqual(fetched.recoveryStatus, "raw_response")
    }

    func testRunStoreEventPersistsTimeoutAsTerminalState() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        var record = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_generate_timeout")
        record.createdAt = "2026-06-14T05:10:00.000Z"
        record.updatedAt = record.createdAt
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)

        try PaperBananaRunStore.writeEventSynchronously(
            PaperBananaRunEvent(
                runID: record.id,
                stage: "timeout",
                progress: 82,
                message: "No provider progress for 5m 0s; local generation process was stopped.",
                timestamp: "2026-06-14T05:15:00.000Z",
                rawResponsePath: "",
                rawPayloadPath: "",
                artifactPath: record.artifactPath,
                metadataPath: record.metadataPath,
                providerCallID: "timeout-call"
            ),
            repoRoot: repoRoot
        )

        let fetched = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: record.id, repoRoot: repoRoot))
        XCTAssertEqual(fetched.status, .timedOut)
        XCTAssertEqual(fetched.recoveryStatus, "none")
        XCTAssertEqual(fetched.elapsedSeconds, 300, accuracy: 0.01)
        XCTAssertEqual(fetched.message, "No provider progress for 5m 0s; local generation process was stopped.")
    }

    func testRunStoreDoesNotRegressTimedOutRunSnapshotAfterLateProgressEvent() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        var record = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_generate_late_progress_after_timeout")
        record.createdAt = "2026-06-14T05:10:00.000Z"
        record.updatedAt = record.createdAt
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)

        let timeoutEvent = PaperBananaRunEvent(
            runID: record.id,
            stage: "timeout",
            progress: 82,
            message: "No provider progress for 5m 0s; local generation process was stopped.",
            timestamp: "2026-06-14T05:15:00.000Z",
            rawResponsePath: "",
            rawPayloadPath: "",
            artifactPath: record.artifactPath,
            metadataPath: record.metadataPath,
            providerCallID: "timeout-call"
        )
        try PaperBananaRunStore.writeEventSynchronously(timeoutEvent, repoRoot: repoRoot)

        let lateProgressEvent = PaperBananaRunEvent(
            runID: record.id,
            stage: "stalled",
            progress: 83,
            message: "Late progress event arrived after timeout.",
            timestamp: "2026-06-14T05:15:05.000Z",
            rawResponsePath: "",
            rawPayloadPath: "",
            artifactPath: record.artifactPath,
            metadataPath: record.metadataPath,
            providerCallID: "timeout-call"
        )
        try PaperBananaRunStore.writeEventSynchronously(lateProgressEvent, repoRoot: repoRoot)

        let fetched = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: record.id, repoRoot: repoRoot))
        XCTAssertEqual(fetched.status, .timedOut)
        XCTAssertEqual(fetched.updatedAt, timeoutEvent.timestamp)
        XCTAssertEqual(fetched.message, timeoutEvent.message)
        XCTAssertEqual(fetched.elapsedSeconds, 300, accuracy: 0.01)
        XCTAssertEqual(fetched.providerCallID, "timeout-call")

        let events = try PaperBananaRunStore.fetchEventsSynchronously(runID: record.id, repoRoot: repoRoot)
        XCTAssertEqual(events.map(\.stage), ["timeout", "stalled"])
        XCTAssertEqual(events.last?.message, "Late progress event arrived after timeout.")
    }

    func testRunStoreDoesNotRegressFailedRawRecoverySnapshotAfterLateProgressEvent() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        var record = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_refine_late_progress_after_raw_failure")
        record.createdAt = "2026-06-14T05:20:00.000Z"
        record.updatedAt = record.createdAt
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)

        let rawResponse = record.runDirectoryPath + "/provider_response.json"
        let rawPayload = record.runDirectoryPath + "/provider_raw.bin"
        let failureEvent = PaperBananaRunEvent(
            runID: record.id,
            stage: "failed",
            progress: 100,
            message: "Provider payload could not be decoded; raw payload preserved.",
            timestamp: "2026-06-14T05:20:12.500Z",
            rawResponsePath: rawResponse,
            rawPayloadPath: rawPayload,
            artifactPath: record.artifactPath,
            metadataPath: record.metadataPath,
            providerCallID: "raw-failure-call"
        )
        try PaperBananaRunStore.writeEventSynchronously(failureEvent, repoRoot: repoRoot)

        try PaperBananaRunStore.writeEventSynchronously(
            PaperBananaRunEvent(
                runID: record.id,
                stage: "saving",
                progress: 80,
                message: "Late saving event arrived after raw recovery failure.",
                timestamp: "2026-06-14T05:20:15.000Z",
                rawResponsePath: "",
                rawPayloadPath: "",
                artifactPath: record.artifactPath + ".late",
                metadataPath: "",
                providerCallID: "raw-failure-call"
            ),
            repoRoot: repoRoot
        )

        let fetched = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: record.id, repoRoot: repoRoot))
        XCTAssertEqual(fetched.status, .failed)
        XCTAssertEqual(fetched.updatedAt, failureEvent.timestamp)
        XCTAssertEqual(fetched.message, failureEvent.message)
        XCTAssertEqual(fetched.rawResponsePath, rawResponse)
        XCTAssertEqual(fetched.rawPayloadPath, rawPayload)
        XCTAssertEqual(fetched.artifactPath, record.artifactPath)
        XCTAssertEqual(fetched.recoveryStatus, "raw_payload")
        XCTAssertEqual(fetched.elapsedSeconds, 12.5, accuracy: 0.01)

        let events = try PaperBananaRunStore.fetchEventsSynchronously(runID: record.id, repoRoot: repoRoot)
        XCTAssertEqual(events.map(\.stage), ["failed", "saving"])
        XCTAssertEqual(events.last?.artifactPath, record.artifactPath + ".late")
    }

    func testRunStorePersistsProviderCallLifecycleInSQLite() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let record = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_generate_provider_sqlite")
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)

        let artifact = URL(fileURLWithPath: record.artifactPath).standardizedFileURL
        try FileManager.default.createDirectory(at: artifact.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: artifact)

        try PaperBananaRunStore.writeProviderCallStartedSynchronously(
            runID: record.id,
            callID: "sqlite-call-1",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            repoRoot: repoRoot
        )

        var providerCall = try XCTUnwrap(PaperBananaRunStore.fetchProviderCallSynchronously(callID: "sqlite-call-1", repoRoot: repoRoot))
        XCTAssertEqual(providerCall.status, ProviderRunStatus.running.rawValue)
        XCTAssertEqual(providerCall.runID, record.id)
        XCTAssertEqual(providerCall.model, "gemini-3-pro-image-preview")

        var fetchedRun = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: record.id, repoRoot: repoRoot))
        XCTAssertEqual(fetchedRun.status, .running)
        XCTAssertEqual(fetchedRun.providerCallID, "sqlite-call-1")

        try PaperBananaRunStore.writeProviderImageSavedSynchronously(
            runID: record.id,
            callID: "sqlite-call-1",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            path: artifact,
            raw: false,
            context: "native_generate",
            repoRoot: repoRoot
        )
        try PaperBananaRunStore.writeProviderCallFinishedSynchronously(
            runID: record.id,
            callID: "sqlite-call-1",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            success: true,
            responseCount: 1,
            message: "Image response received.",
            artifacts: [artifact],
            usageMetadata: [
                "promptTokenCount": "12",
                "totalTokenCount": "42"
            ],
            repoRoot: repoRoot
        )

        providerCall = try XCTUnwrap(PaperBananaRunStore.fetchProviderCallSynchronously(callID: "sqlite-call-1", repoRoot: repoRoot))
        XCTAssertEqual(providerCall.status, ProviderRunStatus.succeeded.rawValue)
        XCTAssertEqual(providerCall.responseCount, 1)
        XCTAssertEqual(providerCall.usageMetadata["promptTokenCount"], "12")
        XCTAssertEqual(providerCall.usageMetadata["totalTokenCount"], "42")
        XCTAssertEqual(providerCall.artifactPaths, [artifact.path])

        let allCalls = try PaperBananaRunStore.fetchProviderCallsSynchronously(repoRoot: repoRoot)
        XCTAssertEqual(allCalls.map(\.callID), ["sqlite-call-1"])

        fetchedRun = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: record.id, repoRoot: repoRoot))
        XCTAssertEqual(fetchedRun.status, .completed)
        XCTAssertEqual(fetchedRun.providerCallID, "sqlite-call-1")
        XCTAssertEqual(fetchedRun.message, "Image response received.")
        XCTAssertEqual(fetchedRun.recoveryStatus, "none")

        let callEvents = try PaperBananaRunStore.fetchProviderCallEventsSynchronously(callID: "sqlite-call-1", repoRoot: repoRoot)
        XCTAssertEqual(callEvents.map(\.status), [
            ProviderRunStatus.running.rawValue,
            ProviderRunStatus.running.rawValue,
            ProviderRunStatus.succeeded.rawValue
        ])
        XCTAssertEqual(callEvents.map(\.message), [
            "Provider call started.",
            "Provider image artifact saved.",
            "Image response received."
        ])
        XCTAssertEqual(callEvents.map(\.callID), Array(repeating: "sqlite-call-1", count: 3))
        XCTAssertEqual(callEvents.map(\.runID), Array(repeating: record.id, count: 3))
        XCTAssertEqual(callEvents[0].artifactPaths, [])
        XCTAssertEqual(callEvents[1].artifactPaths, [artifact.path])
        XCTAssertEqual(callEvents[2].artifactPaths, [artifact.path])
        XCTAssertEqual(callEvents[2].usageMetadata["promptTokenCount"], "12")
        XCTAssertEqual(callEvents[2].usageMetadata["totalTokenCount"], "42")

        let limitedEvents = try PaperBananaRunStore.fetchProviderCallEventsSynchronously(
            callID: "sqlite-call-1",
            repoRoot: repoRoot,
            limit: 2
        )
        XCTAssertEqual(limitedEvents.map(\.message), ["Provider call started.", "Provider image artifact saved."])
    }

    func testRunStoreRejectsNewProviderCallsWithoutDurableRunRecord() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let rawPayload = repoRoot.appendingPathComponent("orphan-provider-payload.bin")
        try Data("provider bytes".utf8).write(to: rawPayload)

        func assertMissingRunRecord(_ callID: String, operation: () throws -> Void) throws {
            XCTAssertThrowsError(try operation()) { error in
                guard case PaperBananaRunStoreError.missingRunRecord(let runID) = error else {
                    XCTFail("Expected missing run record error for \(callID), got \(error).")
                    return
                }
                XCTAssertEqual(runID, "missing_native_run")
            }
            XCTAssertNil(try PaperBananaRunStore.fetchProviderCallSynchronously(callID: callID, repoRoot: repoRoot))
            XCTAssertEqual(try PaperBananaRunStore.fetchProviderCallEventsSynchronously(callID: callID, repoRoot: repoRoot), [])
        }

        try assertMissingRunRecord("orphan-start") {
            try PaperBananaRunStore.writeProviderCallStartedSynchronously(
                runID: "missing_native_run",
                callID: "orphan-start",
                provider: "gemini",
                model: "gemini-3-pro-image-preview",
                modality: "image",
                context: "native_generate",
                repoRoot: repoRoot
            )
        }
        try assertMissingRunRecord("orphan-image") {
            try PaperBananaRunStore.writeProviderImageSavedSynchronously(
                runID: "missing_native_run",
                callID: "orphan-image",
                provider: "gemini",
                model: "gemini-3-pro-image-preview",
                path: rawPayload,
                raw: true,
                context: "native_generate",
                repoRoot: repoRoot
            )
        }
        try assertMissingRunRecord("orphan-finish") {
            try PaperBananaRunStore.writeProviderCallFinishedSynchronously(
                runID: "missing_native_run",
                callID: "orphan-finish",
                provider: "gemini",
                model: "gemini-3-pro-image-preview",
                modality: "image",
                context: "native_generate",
                success: true,
                responseCount: 1,
                message: "Provider call finished without a run.",
                artifacts: [rawPayload],
                repoRoot: repoRoot
            )
        }
        try assertMissingRunRecord("orphan-fail") {
            try PaperBananaRunStore.writeProviderCallFailedSynchronously(
                runID: "missing_native_run",
                callID: "orphan-fail",
                provider: "gemini",
                model: "gemini-3-pro-image-preview",
                modality: "image",
                context: "native_generate",
                error: "Provider failed without a run.",
                repoRoot: repoRoot
            )
        }
        try assertMissingRunRecord("orphan-terminal") {
            try PaperBananaRunStore.writeProviderCallTerminalSynchronously(
                runID: "missing_native_run",
                callID: "orphan-terminal",
                provider: "gemini",
                model: "gemini-3-pro-image-preview",
                modality: "image",
                context: "native_generate",
                status: .timedOut,
                message: "Provider timed out without a run.",
                repoRoot: repoRoot
            )
        }
    }

    func testRunStoreRejectsProviderCallUpdatesWithoutStartedCall() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let record = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_generate_started_call_required")
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)

        let rawPayload = URL(fileURLWithPath: record.runDirectoryPath)
            .appendingPathComponent("provider_raw.bin")
            .standardizedFileURL
        try FileManager.default.createDirectory(at: rawPayload.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("provider bytes".utf8).write(to: rawPayload)

        func assertMissingProviderCall(_ callID: String, operation: () throws -> Void) throws {
            XCTAssertThrowsError(try operation()) { error in
                guard case PaperBananaRunStoreError.missingProviderCallRecord(let missingCallID) = error else {
                    XCTFail("Expected missing provider call error for \(callID), got \(error).")
                    return
                }
                XCTAssertEqual(missingCallID, callID)
            }
            XCTAssertNil(try PaperBananaRunStore.fetchProviderCallSynchronously(callID: callID, repoRoot: repoRoot))
        }

        try assertMissingProviderCall("unstaged-image") {
            try PaperBananaRunStore.writeProviderImageSavedSynchronously(
                runID: record.id,
                callID: "unstaged-image",
                provider: "gemini",
                model: "gemini-3-pro-image-preview",
                path: rawPayload,
                raw: true,
                context: "native_generate",
                repoRoot: repoRoot
            )
        }
        try assertMissingProviderCall("unstaged-finish") {
            try PaperBananaRunStore.writeProviderCallFinishedSynchronously(
                runID: record.id,
                callID: "unstaged-finish",
                provider: "gemini",
                model: "gemini-3-pro-image-preview",
                modality: "image",
                context: "native_generate",
                success: true,
                responseCount: 1,
                message: "Provider call finished without a start event.",
                artifacts: [rawPayload],
                repoRoot: repoRoot
            )
        }
        try assertMissingProviderCall("unstaged-fail") {
            try PaperBananaRunStore.writeProviderCallFailedSynchronously(
                runID: record.id,
                callID: "unstaged-fail",
                provider: "gemini",
                model: "gemini-3-pro-image-preview",
                modality: "image",
                context: "native_generate",
                error: "Provider failed without a start event.",
                repoRoot: repoRoot
            )
        }
        try assertMissingProviderCall("unstaged-terminal") {
            try PaperBananaRunStore.writeProviderCallTerminalSynchronously(
                runID: record.id,
                callID: "unstaged-terminal",
                provider: "gemini",
                model: "gemini-3-pro-image-preview",
                modality: "image",
                context: "native_generate",
                status: .timedOut,
                message: "Provider timed out without a start event.",
                repoRoot: repoRoot
            )
        }

        let fetchedRun = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: record.id, repoRoot: repoRoot))
        XCTAssertEqual(fetchedRun.status, .queued)
        XCTAssertEqual(fetchedRun.providerCallID, "")
    }

    func testRunStoreRejectsProviderCallIDRebindingAcrossRuns() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let firstRun = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_generate_first_call_owner")
        let secondRun = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_generate_second_call_owner")
        try PaperBananaRunStore.writeQueuedRunSynchronously(firstRun, repoRoot: repoRoot)
        try PaperBananaRunStore.writeQueuedRunSynchronously(secondRun, repoRoot: repoRoot)

        let artifact = URL(fileURLWithPath: firstRun.runDirectoryPath)
            .appendingPathComponent("output.png")
            .standardizedFileURL
        try FileManager.default.createDirectory(at: artifact.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: artifact)

        try PaperBananaRunStore.writeProviderCallStartedSynchronously(
            runID: firstRun.id,
            callID: "shared-provider-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            repoRoot: repoRoot
        )

        func assertCallIDConflict(_ operation: () throws -> Void) {
            XCTAssertThrowsError(try operation()) { error in
                guard case PaperBananaRunStoreError.providerCallIDConflict(
                    let callID,
                    let existingRunID,
                    let attemptedRunID
                ) = error else {
                    XCTFail("Expected provider call ID conflict, got \(error).")
                    return
                }
                XCTAssertEqual(callID, "shared-provider-call")
                XCTAssertEqual(existingRunID, firstRun.id)
                XCTAssertEqual(attemptedRunID, secondRun.id)
            }
        }

        assertCallIDConflict {
            try PaperBananaRunStore.writeProviderCallStartedSynchronously(
                runID: secondRun.id,
                callID: "shared-provider-call",
                provider: "gemini",
                model: "gemini-3-pro-image-preview",
                modality: "image",
                context: "native_generate",
                repoRoot: repoRoot
            )
        }
        assertCallIDConflict {
            try PaperBananaRunStore.writeProviderCallFinishedSynchronously(
                runID: secondRun.id,
                callID: "shared-provider-call",
                provider: "gemini",
                model: "gemini-3-pro-image-preview",
                modality: "image",
                context: "native_generate",
                success: true,
                responseCount: 1,
                message: "Finished from the wrong run.",
                artifacts: [artifact],
                repoRoot: repoRoot
            )
        }

        let providerCall = try XCTUnwrap(PaperBananaRunStore.fetchProviderCallSynchronously(callID: "shared-provider-call", repoRoot: repoRoot))
        XCTAssertEqual(providerCall.runID, firstRun.id)
        XCTAssertEqual(providerCall.status, ProviderRunStatus.running.rawValue)
        XCTAssertEqual(providerCall.responseCount, 0)
        XCTAssertEqual(providerCall.artifactPaths, [])

        let fetchedFirstRun = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: firstRun.id, repoRoot: repoRoot))
        XCTAssertEqual(fetchedFirstRun.providerCallID, "shared-provider-call")
        let fetchedSecondRun = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: secondRun.id, repoRoot: repoRoot))
        XCTAssertEqual(fetchedSecondRun.status, .queued)
        XCTAssertEqual(fetchedSecondRun.providerCallID, "")
    }

    func testRunStoreRejectsProviderCallRestartAfterTerminalState() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let record = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_generate_terminal_restart")
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)

        let artifact = URL(fileURLWithPath: record.artifactPath).standardizedFileURL
        try FileManager.default.createDirectory(at: artifact.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: artifact)

        try PaperBananaRunStore.writeProviderCallStartedSynchronously(
            runID: record.id,
            callID: "terminal-provider-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            repoRoot: repoRoot
        )
        try PaperBananaRunStore.writeProviderCallFinishedSynchronously(
            runID: record.id,
            callID: "terminal-provider-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            success: true,
            responseCount: 1,
            message: "Image response received.",
            artifacts: [artifact],
            repoRoot: repoRoot
        )

        XCTAssertThrowsError(
            try PaperBananaRunStore.writeProviderCallStartedSynchronously(
                runID: record.id,
                callID: "terminal-provider-call",
                provider: "gemini",
                model: "gemini-3-pro-image-preview",
                modality: "image",
                context: "native_generate",
                repoRoot: repoRoot
            )
        ) { error in
            guard case PaperBananaRunStoreError.providerCallStartRejected(let callID, let status) = error else {
                XCTFail("Expected terminal provider call restart rejection, got \(error).")
                return
            }
            XCTAssertEqual(callID, "terminal-provider-call")
            XCTAssertEqual(status, ProviderRunStatus.succeeded.rawValue)
        }

        let providerCall = try XCTUnwrap(PaperBananaRunStore.fetchProviderCallSynchronously(callID: "terminal-provider-call", repoRoot: repoRoot))
        XCTAssertEqual(providerCall.status, ProviderRunStatus.succeeded.rawValue)
        XCTAssertEqual(providerCall.responseCount, 1)
        XCTAssertEqual(providerCall.artifactPaths, [artifact.path])
    }

    func testRunStoreRejectsProviderCallMutationAfterTerminalState() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let successRecord = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_generate_terminal_success")
        try PaperBananaRunStore.writeQueuedRunSynchronously(successRecord, repoRoot: repoRoot)

        let artifact = URL(fileURLWithPath: successRecord.artifactPath).standardizedFileURL
        try FileManager.default.createDirectory(at: artifact.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: artifact)

        try PaperBananaRunStore.writeProviderCallStartedSynchronously(
            runID: successRecord.id,
            callID: "terminal-success-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            repoRoot: repoRoot
        )
        try PaperBananaRunStore.writeProviderCallFinishedSynchronously(
            runID: successRecord.id,
            callID: "terminal-success-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            success: true,
            responseCount: 1,
            message: "Image response received.",
            artifacts: [artifact],
            usageMetadata: ["totalTokenCount": "42"],
            repoRoot: repoRoot
        )

        func assertTerminalMutationRejected(callID: String, status: ProviderRunStatus, operation: () throws -> Void) {
            XCTAssertThrowsError(try operation()) { error in
                guard case PaperBananaRunStoreError.providerCallTerminalMutationRejected(let rejectedCallID, let rejectedStatus) = error else {
                    XCTFail("Expected terminal provider call mutation rejection, got \(error).")
                    return
                }
                XCTAssertEqual(rejectedCallID, callID)
                XCTAssertEqual(rejectedStatus, status.rawValue)
            }
        }

        assertTerminalMutationRejected(callID: "terminal-success-call", status: .succeeded) {
            try PaperBananaRunStore.writeProviderCallFailedSynchronously(
                runID: successRecord.id,
                callID: "terminal-success-call",
                provider: "gemini",
                model: "gemini-3-pro-image-preview",
                modality: "image",
                context: "native_generate",
                error: "Late provider failure should not rewrite success.",
                repoRoot: repoRoot
            )
        }
        assertTerminalMutationRejected(callID: "terminal-success-call", status: .succeeded) {
            try PaperBananaRunStore.writeProviderCallFinishedSynchronously(
                runID: successRecord.id,
                callID: "terminal-success-call",
                provider: "gemini",
                model: "gemini-3-pro-image-preview",
                modality: "image",
                context: "native_generate",
                success: false,
                responseCount: 1,
                message: "Late failed finish should not rewrite success.",
                artifacts: [artifact],
                repoRoot: repoRoot
            )
        }
        assertTerminalMutationRejected(callID: "terminal-success-call", status: .succeeded) {
            try PaperBananaRunStore.writeProviderImageSavedSynchronously(
                runID: successRecord.id,
                callID: "terminal-success-call",
                provider: "gemini",
                model: "gemini-3-pro-image-preview",
                path: artifact,
                raw: true,
                context: "native_generate",
                repoRoot: repoRoot
            )
        }

        let successCall = try XCTUnwrap(PaperBananaRunStore.fetchProviderCallSynchronously(callID: "terminal-success-call", repoRoot: repoRoot))
        XCTAssertEqual(successCall.status, ProviderRunStatus.succeeded.rawValue)
        XCTAssertEqual(successCall.responseCount, 1)
        XCTAssertEqual(successCall.error, "")
        XCTAssertEqual(successCall.artifactPaths, [artifact.path])

        let timedOutRecord = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_generate_terminal_timeout")
        try PaperBananaRunStore.writeQueuedRunSynchronously(timedOutRecord, repoRoot: repoRoot)
        try PaperBananaRunStore.writeProviderCallStartedSynchronously(
            runID: timedOutRecord.id,
            callID: "terminal-timeout-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            repoRoot: repoRoot
        )
        try PaperBananaRunStore.writeProviderCallTerminalSynchronously(
            runID: timedOutRecord.id,
            callID: "terminal-timeout-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            status: .timedOut,
            message: "Provider timed out locally.",
            repoRoot: repoRoot
        )
        assertTerminalMutationRejected(callID: "terminal-timeout-call", status: .timedOut) {
            try PaperBananaRunStore.writeProviderCallFinishedSynchronously(
                runID: timedOutRecord.id,
                callID: "terminal-timeout-call",
                provider: "gemini",
                model: "gemini-3-pro-image-preview",
                modality: "image",
                context: "native_generate",
                success: true,
                responseCount: 1,
                message: "Late success should not rewrite timeout.",
                artifacts: [artifact],
                repoRoot: repoRoot
            )
        }
    }

    func testRunStoreMigratesLegacyProviderCallsWithEmptyUsageMetadata() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        let databaseURL = PaperBananaRunStore.databaseURL(repoRoot: repoRoot)
        try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.createLegacyProviderCallsDatabase(at: databaseURL)

        let calls = try PaperBananaRunStore.fetchProviderCallsSynchronously(repoRoot: repoRoot)

        XCTAssertEqual(calls.map(\.callID), ["legacy-call"])
        XCTAssertEqual(calls.first?.usageMetadata, [:])
        XCTAssertEqual(try PaperBananaRunStore.fetchProviderCallEventsSynchronously(callID: "legacy-call", repoRoot: repoRoot), [])

        try PaperBananaRunStore.writeProviderCallFinishedSynchronously(
            runID: "legacy-run",
            callID: "legacy-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            success: true,
            responseCount: 1,
            message: "Usage metadata added after migration.",
            artifacts: [],
            usageMetadata: ["totalTokenCount": "99"],
            repoRoot: repoRoot
        )

        let updated = try XCTUnwrap(PaperBananaRunStore.fetchProviderCallSynchronously(callID: "legacy-call", repoRoot: repoRoot))
        XCTAssertEqual(updated.status, ProviderRunStatus.succeeded.rawValue)
        XCTAssertEqual(updated.message, "Legacy call complete.")
        XCTAssertEqual(updated.artifactPaths, [])
        XCTAssertEqual(updated.rawArtifactPaths, [])
        XCTAssertEqual(updated.usageMetadata, ["totalTokenCount": "99"])
        XCTAssertNil(try PaperBananaRunStore.fetchRunSynchronously(id: "legacy-run", repoRoot: repoRoot))

        let backfillEvents = try PaperBananaRunStore.fetchProviderCallEventsSynchronously(callID: "legacy-call", repoRoot: repoRoot)
        XCTAssertEqual(backfillEvents.count, 1)
        XCTAssertEqual(backfillEvents.first?.status, ProviderRunStatus.succeeded.rawValue)
        XCTAssertEqual(backfillEvents.first?.message, "Provider usage metadata backfilled.")
        XCTAssertEqual(backfillEvents.first?.usageMetadata, ["totalTokenCount": "99"])
        XCTAssertEqual(backfillEvents.first?.artifactPaths, [])
        XCTAssertEqual(backfillEvents.first?.rawArtifactPaths, [])

        XCTAssertThrowsError(
            try PaperBananaRunStore.writeProviderCallFinishedSynchronously(
                runID: "legacy-run",
                callID: "legacy-call",
                provider: "gemini",
                model: "gemini-3-pro-image-preview",
                modality: "image",
                context: "native_generate",
                success: true,
                responseCount: 1,
                message: "Second usage metadata rewrite must be rejected.",
                artifacts: [],
                usageMetadata: ["totalTokenCount": "101"],
                repoRoot: repoRoot
            )
        ) { error in
            guard case PaperBananaRunStoreError.providerCallTerminalMutationRejected(let callID, let status) = error else {
                XCTFail("Expected terminal provider call mutation rejection, got \(error).")
                return
            }
            XCTAssertEqual(callID, "legacy-call")
            XCTAssertEqual(status, ProviderRunStatus.succeeded.rawValue)
        }
    }

    func testRunStorePersistsRawRecoveredProviderCallInSQLite() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let record = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_refine_raw_sqlite")
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)

        let rawPayload = URL(fileURLWithPath: record.runDirectoryPath)
            .appendingPathComponent("provider_raw.bin")
            .standardizedFileURL
        try FileManager.default.createDirectory(at: rawPayload.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("raw provider bytes".utf8).write(to: rawPayload)

        try PaperBananaRunStore.writeProviderCallStartedSynchronously(
            runID: record.id,
            callID: "sqlite-raw-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_refine",
            repoRoot: repoRoot
        )
        try PaperBananaRunStore.writeProviderImageSavedSynchronously(
            runID: record.id,
            callID: "sqlite-raw-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            path: rawPayload,
            raw: true,
            context: "native_refine",
            repoRoot: repoRoot
        )
        var providerCall = try XCTUnwrap(PaperBananaRunStore.fetchProviderCallSynchronously(callID: "sqlite-raw-call", repoRoot: repoRoot))
        XCTAssertEqual(providerCall.status, ProviderRunStatus.running.rawValue)
        XCTAssertEqual(providerCall.rawArtifactPaths, [rawPayload.path])

        try PaperBananaRunStore.writeProviderCallFinishedSynchronously(
            runID: record.id,
            callID: "sqlite-raw-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_refine",
            success: false,
            responseCount: 1,
            message: "Failed to decode provider image bytes.",
            artifacts: [rawPayload],
            repoRoot: repoRoot
        )

        providerCall = try XCTUnwrap(PaperBananaRunStore.fetchProviderCallSynchronously(callID: "sqlite-raw-call", repoRoot: repoRoot))
        XCTAssertEqual(providerCall.status, ProviderRunStatus.rawRecovered.rawValue)
        XCTAssertEqual(providerCall.rawArtifactPaths, [rawPayload.path])
        XCTAssertEqual(providerCall.error, "Failed to decode provider image bytes.")

        let run = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: record.id, repoRoot: repoRoot))
        XCTAssertEqual(run.status, .recovered)
        XCTAssertEqual(run.providerCallID, "sqlite-raw-call")
        XCTAssertEqual(run.rawPayloadPath, rawPayload.path)
        XCTAssertEqual(run.recoveryStatus, "raw_payload")
        XCTAssertEqual(run.message, "Failed to decode provider image bytes.")

        XCTAssertThrowsError(
            try PaperBananaRunStore.writeProviderCallFinishedSynchronously(
                runID: record.id,
                callID: "sqlite-raw-call",
                provider: "gemini",
                model: "gemini-3-pro-image-preview",
                modality: "image",
                context: "native_refine",
                success: true,
                responseCount: 1,
                message: "Late success should not rewrite raw recovery.",
                artifacts: [rawPayload],
                repoRoot: repoRoot
            )
        ) { error in
            guard case PaperBananaRunStoreError.providerCallTerminalMutationRejected(let callID, let status) = error else {
                XCTFail("Expected raw recovered terminal mutation rejection, got \(error).")
                return
            }
            XCTAssertEqual(callID, "sqlite-raw-call")
            XCTAssertEqual(status, ProviderRunStatus.rawRecovered.rawValue)
        }
    }

    func testRunStorePersistsCancelledAndTimedOutProviderCallsInSQLite() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let cancelledRecord = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_generate_cancelled_sqlite")
        try PaperBananaRunStore.writeQueuedRunSynchronously(cancelledRecord, repoRoot: repoRoot)
        try PaperBananaRunStore.writeProviderCallStartedSynchronously(
            runID: cancelledRecord.id,
            callID: "sqlite-cancelled-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            repoRoot: repoRoot
        )
        try PaperBananaRunStore.writeProviderCallTerminalSynchronously(
            runID: cancelledRecord.id,
            callID: "sqlite-cancelled-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            status: .cancelled,
            message: "Generation cancelled by user.",
            repoRoot: repoRoot
        )

        let timedOutRecord = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_refine_timeout_sqlite")
        try PaperBananaRunStore.writeQueuedRunSynchronously(timedOutRecord, repoRoot: repoRoot)
        try PaperBananaRunStore.writeProviderCallStartedSynchronously(
            runID: timedOutRecord.id,
            callID: "sqlite-timeout-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_refine",
            repoRoot: repoRoot
        )
        try PaperBananaRunStore.writeProviderCallTerminalSynchronously(
            runID: timedOutRecord.id,
            callID: "sqlite-timeout-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_refine",
            status: .timedOut,
            message: "Provider call timed out.",
            repoRoot: repoRoot
        )

        let cancelledCall = try XCTUnwrap(PaperBananaRunStore.fetchProviderCallSynchronously(callID: "sqlite-cancelled-call", repoRoot: repoRoot))
        XCTAssertEqual(cancelledCall.status, ProviderRunStatus.cancelled.rawValue)
        XCTAssertEqual(cancelledCall.message, "Generation cancelled by user.")
        XCTAssertEqual(cancelledCall.error, "Generation cancelled by user.")

        let timedOutCall = try XCTUnwrap(PaperBananaRunStore.fetchProviderCallSynchronously(callID: "sqlite-timeout-call", repoRoot: repoRoot))
        XCTAssertEqual(timedOutCall.status, ProviderRunStatus.timedOut.rawValue)
        XCTAssertEqual(timedOutCall.message, "Provider call timed out.")
        XCTAssertEqual(timedOutCall.error, "Provider call timed out.")

        let cancelledRun = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: cancelledRecord.id, repoRoot: repoRoot))
        XCTAssertEqual(cancelledRun.status, .cancelled)
        XCTAssertEqual(cancelledRun.providerCallID, "sqlite-cancelled-call")
        XCTAssertEqual(cancelledRun.message, "Generation cancelled by user.")

        let timedOutRun = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: timedOutRecord.id, repoRoot: repoRoot))
        XCTAssertEqual(timedOutRun.status, .timedOut)
        XCTAssertEqual(timedOutRun.providerCallID, "sqlite-timeout-call")
        XCTAssertEqual(timedOutRun.message, "Provider call timed out.")

        let scannedCalls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path)
        XCTAssertEqual(scannedCalls.first { $0.callID == "sqlite-cancelled-call" }?.status, .cancelled)
        XCTAssertEqual(scannedCalls.first { $0.callID == "sqlite-timeout-call" }?.status, .timedOut)
        XCTAssertTrue(scannedCalls.first { $0.callID == "sqlite-cancelled-call" }?.needsAttention == true)
        XCTAssertTrue(scannedCalls.first { $0.callID == "sqlite-timeout-call" }?.needsAttention == true)
    }

    func testRunStoreDoesNotRewriteTerminalRunSnapshotWhenProviderCallFinishesLate() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        var record = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_generate_late_provider_success")
        record.createdAt = "2026-06-14T05:10:00.000Z"
        record.updatedAt = record.createdAt
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)

        let artifact = URL(fileURLWithPath: record.artifactPath).standardizedFileURL
        try FileManager.default.createDirectory(at: artifact.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: artifact)

        try PaperBananaRunStore.writeProviderCallStartedSynchronously(
            runID: record.id,
            callID: "late-provider-success-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            repoRoot: repoRoot
        )
        let timeoutEvent = PaperBananaRunEvent(
            runID: record.id,
            stage: "timeout",
            progress: 82,
            message: "No provider progress for 5m 0s; local generation process was stopped.",
            timestamp: "2026-06-14T05:15:00.000Z",
            rawResponsePath: "",
            rawPayloadPath: "",
            artifactPath: record.artifactPath,
            metadataPath: record.metadataPath,
            providerCallID: "late-provider-success-call"
        )
        try PaperBananaRunStore.writeEventSynchronously(timeoutEvent, repoRoot: repoRoot)

        try PaperBananaRunStore.writeProviderCallFinishedSynchronously(
            runID: record.id,
            callID: "late-provider-success-call",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_generate",
            success: true,
            responseCount: 1,
            message: "Late provider success should not rewrite timeout.",
            artifacts: [artifact],
            repoRoot: repoRoot
        )

        let providerCall = try XCTUnwrap(PaperBananaRunStore.fetchProviderCallSynchronously(callID: "late-provider-success-call", repoRoot: repoRoot))
        XCTAssertEqual(providerCall.status, ProviderRunStatus.succeeded.rawValue)
        XCTAssertEqual(providerCall.message, "Late provider success should not rewrite timeout.")

        let run = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: record.id, repoRoot: repoRoot))
        XCTAssertEqual(run.status, .timedOut)
        XCTAssertEqual(run.updatedAt, timeoutEvent.timestamp)
        XCTAssertEqual(run.message, timeoutEvent.message)
        XCTAssertEqual(run.providerCallID, "late-provider-success-call")
        XCTAssertEqual(run.elapsedSeconds, 300, accuracy: 0.01)
    }

    func testRunStoreRecoversStaleRunningProviderCallAfterRelaunch() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let record = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_refine_stale_relaunch")
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)
        try PaperBananaRunStore.writeProviderCallStartedSynchronously(
            runID: record.id,
            callID: "stale-relaunch-provider-call",
            provider: "codex",
            model: "gpt-5.5",
            modality: "image",
            context: "native_refine",
            repoRoot: repoRoot
        )

        let recovered = try PaperBananaRunStore.recoverStaleNonTerminalRunsSynchronously(
            repoRoot: repoRoot,
            now: Date().addingTimeInterval(PaperBananaRunStore.defaultStaleRunRecoveryInterval + 30),
            staleAfter: PaperBananaRunStore.defaultStaleRunRecoveryInterval
        )

        XCTAssertEqual(recovered.map(\.id), [record.id])
        let run = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: record.id, repoRoot: repoRoot))
        XCTAssertEqual(run.status, .timedOut)
        XCTAssertEqual(run.providerCallID, "stale-relaunch-provider-call")
        XCTAssertTrue(run.message.contains("marked timed out"))
        XCTAssertTrue(run.elapsedSeconds >= PaperBananaRunStore.defaultStaleRunRecoveryInterval)

        let providerCall = try XCTUnwrap(
            PaperBananaRunStore.fetchProviderCallSynchronously(
                callID: "stale-relaunch-provider-call",
                repoRoot: repoRoot
            )
        )
        XCTAssertEqual(providerCall.status, ProviderRunStatus.timedOut.rawValue)
        XCTAssertTrue(providerCall.message.contains("marked timed out"))

        let events = try PaperBananaRunStore.fetchEventsSynchronously(runID: record.id, repoRoot: repoRoot)
        XCTAssertEqual(events.last?.stage, "timeout")
        XCTAssertEqual(events.last?.providerCallID, "stale-relaunch-provider-call")
    }

    func testRunStoreDoesNotRecoverFreshNonTerminalRunsAfterRelaunch() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let record = Self.makeCodexRecord(repoRoot: repoRoot, runID: "native_refine_fresh_relaunch")
        try PaperBananaRunStore.writeQueuedRunSynchronously(record, repoRoot: repoRoot)

        let recovered = try PaperBananaRunStore.recoverStaleNonTerminalRunsSynchronously(
            repoRoot: repoRoot,
            now: Date().addingTimeInterval(PaperBananaRunStore.defaultStaleRunRecoveryInterval - 30),
            staleAfter: PaperBananaRunStore.defaultStaleRunRecoveryInterval
        )

        XCTAssertTrue(recovered.isEmpty)
        let run = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: record.id, repoRoot: repoRoot))
        XCTAssertEqual(run.status, .queued)
        XCTAssertEqual(try PaperBananaRunStore.fetchEventsSynchronously(runID: record.id, repoRoot: repoRoot), [])
    }

    @MainActor
    func testGenerationStoreCreatesSQLiteRunBeforeProviderLaunchFailure() throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let store = NativeImageGenerationStore(
            stallWarningInterval: 60,
            hardTimeoutInterval: 120,
            providerClientFactory: ProviderClientFactory(
                codexClient: BlockingRunStoreProviderClient(providerKind: .codexFallback)
            )
        )
        store.start(
            request: NativeImageGenerationRequest(
                prompt: "Create a durable SQLite run before any provider work.",
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

        let runID = try XCTUnwrap(store.runDirectoryURL?.lastPathComponent)
        let fetched = try XCTUnwrap(PaperBananaRunStore.fetchRunSynchronously(id: runID, repoRoot: repoRoot))
        XCTAssertTrue([PaperBananaRunStatus.queued, .running].contains(fetched.status))
        XCTAssertEqual(fetched.workflow, "native_generate")
        XCTAssertEqual(fetched.providerKind, "codex_fallback")
        XCTAssertEqual(fetched.requestPath, store.requestURL?.path)
        XCTAssertEqual(fetched.providerRequestPath, store.providerRequestURL?.path)

        let eventLogURL = try XCTUnwrap(store.runDirectoryURL?.appendingPathComponent("events.jsonl"))
        let eventLog = try String(contentsOf: eventLogURL, encoding: .utf8)
        XCTAssertTrue(eventLog.contains(#""stage":"queued""#), eventLog)
        if let failedRange = eventLog.range(of: #""stage":"failed""#),
           let queuedRange = eventLog.range(of: #""stage":"queued""#) {
            XCTAssertLessThan(queuedRange.lowerBound, failedRange.lowerBound)
        }

        store.cancel()
    }

    func testGoogleGeminiProviderClientExtractsImageBytesFromMockedResponse() async throws {
        let expectedImage = Data(base64Encoded: Self.tinyPNGBase64)!
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        let providerRequestURL = repoRoot.appendingPathComponent("provider_request.json")
        MockProviderURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(FileManager.default.fileExists(atPath: providerRequestURL.path))
            let savedRequestData = try Data(contentsOf: providerRequestURL)
            let savedRequestText = String(data: savedRequestData, encoding: .utf8) ?? ""
            XCTAssertTrue(savedRequestText.contains("Create a test image."), savedRequestText)
            XCTAssertTrue(savedRequestText.contains(#""responseModalities""#), savedRequestText)
            XCTAssertFalse(savedRequestText.contains("test-google-key"), savedRequestText)
            let payload: [String: Any] = [
                "candidates": [
                    [
                        "content": [
                            "parts": [
                                [
                                    "inlineData": [
                                        "mimeType": "image/png",
                                        "data": Self.tinyPNGBase64
                                    ]
                                ],
                                ["text": "Generated image."]
                            ]
                        ]
                    ]
                ],
                "usageMetadata": [
                    "totalTokenCount": 42
                ]
            ]
            let data = try JSONSerialization.data(withJSONObject: payload)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }
        defer { MockProviderURLProtocol.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockProviderURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = GoogleGeminiProviderClient(session: session)
        let response = try await client.execute(
            ProviderClientRequest(
                runID: "swift-native-provider-test",
                callID: "swift-native-provider-test-call",
                workflow: .generation,
                prompt: "Create a test image.",
                sourceImageURL: nil,
                model: .nanoBanana2,
                effectiveModel: ImageModelChoice.nanoBanana2.backendValue,
                resolution: "2K",
                aspectRatio: "16:9",
                task: "diagram",
                settings: PaperBananaSettingsSnapshot(
                    repoPath: repoRoot.path,
                    serverPort: 7860,
                    defaultImageModel: .nanoBanana2,
                    codexModel: "gpt-5.5",
                    codexReasoning: "xhigh",
                    googleAPIKey: "test-google-key",
                    openRouterAPIKey: ""
                ),
                providerRequestURL: providerRequestURL
            ),
            eventHandler: { _ in }
        )

        XCTAssertEqual(response.provider, .googleGemini)
        XCTAssertEqual(response.imageData, expectedImage)
        XCTAssertTrue(response.text.contains("Generated image."))
        XCTAssertEqual(response.usageMetadata["totalTokenCount"], "42")
        XCTAssertTrue(FileManager.default.fileExists(atPath: providerRequestURL.path))
    }

    func testGoogleGeminiProviderClientFailsBeforeNetworkWithoutAPIKey() async throws {
        MockProviderURLProtocol.handler = { _ in
            XCTFail("Provider client should not issue a network request without a Google API key.")
            throw URLError(.badServerResponse)
        }
        defer { MockProviderURLProtocol.handler = nil }

        let client = GoogleGeminiProviderClient(session: Self.mockProviderSession())
        do {
            _ = try await client.execute(Self.makeProviderRequest(apiKey: ""), eventHandler: { _ in })
            XCTFail("Expected missing API key error.")
        } catch let error as ProviderRuntimeError {
            XCTAssertEqual(error.errorDescription, "Google Gemini requires an active API key.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGoogleGeminiProviderClientSurfacesHTTPProviderErrors() async throws {
        MockProviderURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 503,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"error":"provider unavailable"}"#.utf8))
        }
        defer { MockProviderURLProtocol.handler = nil }

        let client = GoogleGeminiProviderClient(session: Self.mockProviderSession())
        do {
            _ = try await client.execute(Self.makeProviderRequest(), eventHandler: { _ in })
            XCTFail("Expected provider HTTP error.")
        } catch let error as ProviderRuntimeError {
            XCTAssertTrue(error.errorDescription?.contains("HTTP 503") == true, error.localizedDescription)
            XCTAssertTrue(error.errorDescription?.contains("provider unavailable") == true, error.localizedDescription)
            XCTAssertEqual(error.rawProviderResponseData, Data(#"{"error":"provider unavailable"}"#.utf8))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGoogleGeminiProviderClientPreservesRawResponsesWithoutImageBytes() async throws {
        let responsePayload = try JSONSerialization.data(withJSONObject: [
            "candidates": [
                [
                    "content": [
                        "parts": [
                            ["text": "No image this time."]
                        ]
                    ]
                ]
            ],
            "usageMetadata": [
                "totalTokenCount": 17
            ]
        ])
        MockProviderURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, responsePayload)
        }
        defer { MockProviderURLProtocol.handler = nil }

        let client = GoogleGeminiProviderClient(session: Self.mockProviderSession())
        let response = try await client.execute(Self.makeProviderRequest(), eventHandler: { _ in })

        XCTAssertEqual(response.provider, .googleGemini)
        XCTAssertNil(response.imageData)
        XCTAssertEqual(response.rawResponseData, responsePayload)
        XCTAssertEqual(response.text, "No image this time.")
        XCTAssertEqual(response.usageMetadata["totalTokenCount"], "17")
    }

    func testGoogleGeminiProviderClientRejectsMalformedJSON() async throws {
        MockProviderURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("not-json".utf8))
        }
        defer { MockProviderURLProtocol.handler = nil }

        let client = GoogleGeminiProviderClient(session: Self.mockProviderSession())
        do {
            _ = try await client.execute(Self.makeProviderRequest(), eventHandler: { _ in })
            XCTFail("Expected malformed provider response error.")
        } catch {
            XCTAssertTrue(error is DecodingError || error is CocoaError || error.localizedDescription.isEmpty == false)
        }
    }

    private static func makeTemporaryRepoRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaRunStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func mockProviderSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockProviderURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func makeProviderRequest(apiKey: String = "test-google-key") -> ProviderClientRequest {
        ProviderClientRequest(
            runID: "swift-native-provider-test",
            callID: "swift-native-provider-test-call",
            workflow: .generation,
            prompt: "Create a test image.",
            sourceImageURL: nil,
            model: .nanoBanana2,
            effectiveModel: ImageModelChoice.nanoBanana2.backendValue,
            resolution: "2K",
            aspectRatio: "16:9",
            task: "diagram",
            settings: PaperBananaSettingsSnapshot(
                repoPath: "/tmp/PaperBanana",
                serverPort: 7860,
                defaultImageModel: .nanoBanana2,
                codexModel: "gpt-5.5",
                codexReasoning: "xhigh",
                googleAPIKey: apiKey,
                openRouterAPIKey: ""
            )
        )
    }

    private static func makeCodexRecord(repoRoot: URL, runID: String) -> RunRecord {
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
        let runDirectory = repoRoot.appendingPathComponent("results/native_refine/\(runID)", isDirectory: true)
        return PaperBananaRunStore.makeRecord(
            runID: runID,
            workflow: "native_refine",
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

    private static func createLegacyRunsDatabase(at databaseURL: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK, let database else {
            throw NSError(domain: "RunStoreTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not open legacy test database."])
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
        """
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "unknown SQLite error"
            sqlite3_free(error)
            throw NSError(domain: "RunStoreTests", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private static func createLegacyProviderCallsDatabase(at databaseURL: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK, let database else {
            throw NSError(domain: "RunStoreTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not open legacy provider-calls test database."])
        }
        defer { sqlite3_close(database) }

        let sql = """
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
            'legacy-call', 'legacy-run', 'gemini', 'gemini-3-pro-image-preview',
            'image', 'native_generate', 'succeeded',
            '2026-06-14T05:00:00.000Z', '2026-06-14T05:00:04.000Z',
            1, 1, 1, 'Legacy call complete.', '', '[]', '[]'
        );
        """
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "unknown SQLite error"
            sqlite3_free(error)
            throw NSError(domain: "RunStoreTests", code: 4, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private static let tinyPNGBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC"
}

private final class MockProviderURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private struct BlockingRunStoreProviderClient: ProviderClient {
    let providerKind: ImageProviderKind

    func execute(
        _ request: ProviderClientRequest,
        eventHandler: @escaping @Sendable (ProviderProgressEvent) -> Void
    ) async throws -> ProviderResponse {
        while true {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
