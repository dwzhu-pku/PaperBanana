import Foundation
import SQLite3

enum PaperBananaRunStatus: String, Codable, Sendable {
    case queued
    case running
    case completed
    case recovered
    case failed
    case cancelled
    case timedOut
}

struct RunRecord: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var workflow: String
    var status: PaperBananaRunStatus
    var provider: String
    var providerKind: String
    var model: String
    var requestedModel: String
    var resolution: String
    var aspectRatio: String
    var projectPath: String
    var runDirectoryPath: String
    var promptPath: String
    var requestPath: String
    var providerRequestPath: String
    var rawResponsePath: String
    var rawPayloadPath: String
    var artifactPath: String
    var metadataPath: String
    var eventLogPath: String
    var providerCallID: String
    var spendClass: String
    var recoveryStatus: String
    var createdAt: String
    var updatedAt: String
    var elapsedSeconds: TimeInterval
    var message: String
}

struct PaperBananaRunEvent: Codable, Equatable, Sendable {
    var runID: String
    var stage: String
    var progress: Int
    var message: String
    var timestamp: String
    var rawResponsePath: String
    var rawPayloadPath: String
    var artifactPath: String
    var metadataPath: String
    var providerCallID: String
}

struct PaperBananaProviderCallRecord: Codable, Equatable, Identifiable, Sendable {
    var id: String { callID }

    var callID: String
    var runID: String
    var provider: String
    var model: String
    var modality: String
    var context: String
    var status: String
    var startedAt: String
    var updatedAt: String
    var attempt: Int
    var maxAttempts: Int
    var responseCount: Int
    var message: String
    var error: String
    var usageMetadata: [String: String]
    var artifactPaths: [String]
    var rawArtifactPaths: [String]
}

struct PaperBananaProviderCallEvent: Codable, Equatable, Sendable {
    var callID: String
    var runID: String
    var provider: String
    var model: String
    var modality: String
    var context: String
    var status: String
    var timestamp: String
    var responseCount: Int
    var message: String
    var error: String
    var usageMetadata: [String: String]
    var artifactPaths: [String]
    var rawArtifactPaths: [String]
}

enum PaperBananaRunStoreError: LocalizedError {
    case sqliteOpen(String)
    case sqlitePrepare(String)
    case sqliteStep(String)
    case sqliteExecute(String)
    case missingRunID
    case missingRunRecord(String)
    case missingProviderCallRecord(String)
    case providerCallIDConflict(String, String, String)
    case providerCallStartRejected(String, String)
    case providerCallTerminalMutationRejected(String, String)

    var errorDescription: String? {
        switch self {
        case .sqliteOpen(let message):
            "Could not open PaperBanana run ledger: \(message)"
        case .sqlitePrepare(let message):
            "Could not prepare PaperBanana run ledger statement: \(message)"
        case .sqliteStep(let message):
            "Could not update PaperBanana run ledger: \(message)"
        case .sqliteExecute(let message):
            "Could not initialize PaperBanana run ledger: \(message)"
        case .missingRunID:
            "A run ledger event was missing a run identifier."
        case .missingRunRecord(let runID):
            "Provider call cannot be recorded before durable run \(runID) exists."
        case .missingProviderCallRecord(let callID):
            "Provider call \(callID) cannot be updated before its start event is recorded."
        case .providerCallIDConflict(let callID, let existingRunID, let attemptedRunID):
            "Provider call \(callID) is already linked to run \(existingRunID) and cannot be rebound to run \(attemptedRunID)."
        case .providerCallStartRejected(let callID, let status):
            "Provider call \(callID) cannot be restarted after reaching status \(status)."
        case .providerCallTerminalMutationRejected(let callID, let status):
            "Provider call \(callID) cannot be changed after reaching terminal status \(status)."
        }
    }
}

actor PaperBananaRunStore {
    let repoRoot: URL
    let databaseURL: URL

    init(repoRoot: URL) {
        self.repoRoot = repoRoot
        self.databaseURL = Self.databaseURL(repoRoot: repoRoot)
    }

    func upsertQueuedRun(_ record: RunRecord) throws {
        try Self.writeQueuedRunSynchronously(record, repoRoot: repoRoot)
    }

    func appendEvent(_ event: PaperBananaRunEvent) throws {
        try Self.writeEventSynchronously(event, repoRoot: repoRoot)
    }

    func fetchRun(id: String) throws -> RunRecord? {
        try Self.fetchRunSynchronously(id: id, repoRoot: repoRoot)
    }

    func fetchRuns(limit: Int = 100, statuses: Set<PaperBananaRunStatus> = []) throws -> [RunRecord] {
        try Self.fetchRunsSynchronously(repoRoot: repoRoot, limit: limit, statuses: statuses)
    }

    func fetchProviderCalls() throws -> [PaperBananaProviderCallRecord] {
        try Self.fetchProviderCallsSynchronously(repoRoot: repoRoot)
    }

    func fetchProviderCallEvents(callID: String) throws -> [PaperBananaProviderCallEvent] {
        try Self.fetchProviderCallEventsSynchronously(callID: callID, repoRoot: repoRoot)
    }

    func fetchEvents(runID: String) throws -> [PaperBananaRunEvent] {
        try Self.fetchEventsSynchronously(runID: runID, repoRoot: repoRoot)
    }

    nonisolated static func databaseURL(repoRoot: URL) -> URL {
        repoRoot
            .appendingPathComponent("results", isDirectory: true)
            .appendingPathComponent("run_store", isDirectory: true)
            .appendingPathComponent("paperbanana_runs.sqlite", isDirectory: false)
    }

    nonisolated static func makeRecord(
        runID: String,
        workflow: String,
        providerPlan: ImageProviderExecutionPlan,
        settings: PaperBananaSettingsSnapshot,
        resolution: String,
        aspectRatio: String,
        runDirectoryURL: URL,
        promptURL: URL,
        requestURL: URL,
        providerRequestURL: URL? = nil,
        outputURL: URL,
        metadataURL: URL,
        eventLogURL: URL,
        message: String
    ) -> RunRecord {
        let now = Self.timestamp()
        return RunRecord(
            id: runID,
            workflow: workflow,
            status: .queued,
            provider: providerPlan.providerLabel,
            providerKind: providerPlan.provider.rawValue,
            model: providerPlan.effectiveModel.backendValue,
            requestedModel: providerPlan.requestedModel.backendValue,
            resolution: resolution,
            aspectRatio: aspectRatio,
            projectPath: settings.repoPath,
            runDirectoryPath: runDirectoryURL.path,
            promptPath: promptURL.path,
            requestPath: requestURL.path,
            providerRequestPath: providerRequestURL?.path ?? "",
            rawResponsePath: "",
            rawPayloadPath: "",
            artifactPath: outputURL.path,
            metadataPath: metadataURL.path,
            eventLogPath: eventLogURL.path,
            providerCallID: "",
            spendClass: providerPlan.spendClass,
            recoveryStatus: "none",
            createdAt: now,
            updatedAt: now,
            elapsedSeconds: 0,
            message: message
        )
    }

    nonisolated static func event(
        runID: String,
        stage: String,
        progress: Int,
        message: String,
        rawResponsePath: String = "",
        rawPayloadPath: String = "",
        artifactPath: String = "",
        metadataPath: String = "",
        providerCallID: String = ""
    ) -> PaperBananaRunEvent {
        PaperBananaRunEvent(
            runID: runID,
            stage: stage,
            progress: progress,
            message: message,
            timestamp: timestamp(),
            rawResponsePath: rawResponsePath,
            rawPayloadPath: rawPayloadPath,
            artifactPath: artifactPath,
            metadataPath: metadataPath,
            providerCallID: providerCallID
        )
    }

    nonisolated static func writeQueuedRunSynchronously(_ record: RunRecord, repoRoot: URL) throws {
        try withDatabase(repoRoot: repoRoot) { database in
            let sql = """
            INSERT INTO runs (
                id, workflow, status, provider, provider_kind, model, requested_model,
                resolution, aspect_ratio, project_path, run_dir, prompt_path, request_path,
                provider_request_path, raw_response_path, raw_payload_path, artifact_path, metadata_path,
                event_log_path, provider_call_id, spend_class, recovery_status,
                created_at, updated_at, elapsed_seconds, message
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                workflow=excluded.workflow,
                status=excluded.status,
                provider=excluded.provider,
                provider_kind=excluded.provider_kind,
                model=excluded.model,
                requested_model=excluded.requested_model,
                resolution=excluded.resolution,
                aspect_ratio=excluded.aspect_ratio,
                project_path=excluded.project_path,
                run_dir=excluded.run_dir,
                prompt_path=excluded.prompt_path,
                request_path=excluded.request_path,
                provider_request_path=excluded.provider_request_path,
                artifact_path=excluded.artifact_path,
                metadata_path=excluded.metadata_path,
                event_log_path=excluded.event_log_path,
                spend_class=excluded.spend_class,
                updated_at=excluded.updated_at,
                message=excluded.message
            """
            try withStatement(database: database, sql: sql) { statement in
                bindText(statement, 1, record.id)
                bindText(statement, 2, record.workflow)
                bindText(statement, 3, record.status.rawValue)
                bindText(statement, 4, record.provider)
                bindText(statement, 5, record.providerKind)
                bindText(statement, 6, record.model)
                bindText(statement, 7, record.requestedModel)
                bindText(statement, 8, record.resolution)
                bindText(statement, 9, record.aspectRatio)
                bindText(statement, 10, record.projectPath)
                bindText(statement, 11, record.runDirectoryPath)
                bindText(statement, 12, record.promptPath)
                bindText(statement, 13, record.requestPath)
                bindText(statement, 14, record.providerRequestPath)
                bindText(statement, 15, record.rawResponsePath)
                bindText(statement, 16, record.rawPayloadPath)
                bindText(statement, 17, record.artifactPath)
                bindText(statement, 18, record.metadataPath)
                bindText(statement, 19, record.eventLogPath)
                bindText(statement, 20, record.providerCallID)
                bindText(statement, 21, record.spendClass)
                bindText(statement, 22, record.recoveryStatus)
                bindText(statement, 23, record.createdAt)
                bindText(statement, 24, record.updatedAt)
                sqlite3_bind_double(statement, 25, record.elapsedSeconds)
                bindText(statement, 26, record.message)
                try stepDone(statement, database: database)
            }
        }
    }

    nonisolated static func writeEventSynchronously(_ event: PaperBananaRunEvent, repoRoot: URL) throws {
        guard !event.runID.isEmpty else { throw PaperBananaRunStoreError.missingRunID }
        let status = status(forStage: event.stage)
        let recoveryStatus = recoveryStatus(for: event, status: status)
        try withDatabase(repoRoot: repoRoot) { database in
            try withImmediateTransaction(database: database) {
                try requireRunRecord(runID: event.runID, database: database)
                let currentStatus = try fetchRunStatus(runID: event.runID, database: database)

                let eventSQL = """
                INSERT INTO events (
                    run_id, stage, progress, message, timestamp, raw_response_path,
                    raw_payload_path, artifact_path, metadata_path, provider_call_id
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """
                try withStatement(database: database, sql: eventSQL) { statement in
                    bindText(statement, 1, event.runID)
                    bindText(statement, 2, event.stage)
                    sqlite3_bind_int(statement, 3, Int32(event.progress))
                    bindText(statement, 4, event.message)
                    bindText(statement, 5, event.timestamp)
                    bindText(statement, 6, event.rawResponsePath)
                    bindText(statement, 7, event.rawPayloadPath)
                    bindText(statement, 8, event.artifactPath)
                    bindText(statement, 9, event.metadataPath)
                    bindText(statement, 10, event.providerCallID)
                    try stepDone(statement, database: database)
                }

                guard shouldUpdateRunSnapshot(currentStatus: currentStatus, incomingStatus: status) else {
                    return
                }

                let updateSQL = """
                UPDATE runs SET
                    status=?,
                    updated_at=?,
                    message=?,
                    raw_response_path=CASE WHEN ? = '' THEN raw_response_path ELSE ? END,
                    raw_payload_path=CASE WHEN ? = '' THEN raw_payload_path ELSE ? END,
                    artifact_path=CASE WHEN ? = '' THEN artifact_path ELSE ? END,
                    metadata_path=CASE WHEN ? = '' THEN metadata_path ELSE ? END,
                    provider_call_id=CASE WHEN ? = '' THEN provider_call_id ELSE ? END,
                    recovery_status=CASE WHEN ? = '' THEN recovery_status ELSE ? END,
                    elapsed_seconds=CASE
                        WHEN julianday(?) IS NOT NULL
                         AND julianday(created_at) IS NOT NULL
                         AND (julianday(?) - julianday(created_at)) >= 0
                        THEN (julianday(?) - julianday(created_at)) * 86400.0
                        ELSE elapsed_seconds
                    END
                WHERE id=?
                """
                try withStatement(database: database, sql: updateSQL) { statement in
                    bindText(statement, 1, status.rawValue)
                    bindText(statement, 2, event.timestamp)
                    bindText(statement, 3, event.message)
                    bindText(statement, 4, event.rawResponsePath)
                    bindText(statement, 5, event.rawResponsePath)
                    bindText(statement, 6, event.rawPayloadPath)
                    bindText(statement, 7, event.rawPayloadPath)
                    bindText(statement, 8, event.artifactPath)
                    bindText(statement, 9, event.artifactPath)
                    bindText(statement, 10, event.metadataPath)
                    bindText(statement, 11, event.metadataPath)
                    bindText(statement, 12, event.providerCallID)
                    bindText(statement, 13, event.providerCallID)
                    bindText(statement, 14, recoveryStatus)
                    bindText(statement, 15, recoveryStatus)
                    bindText(statement, 16, event.timestamp)
                    bindText(statement, 17, event.timestamp)
                    bindText(statement, 18, event.timestamp)
                    bindText(statement, 19, event.runID)
                    try stepDone(statement, database: database)
                }
                guard sqlite3_changes(database) > 0 else {
                    throw PaperBananaRunStoreError.missingRunRecord(event.runID)
                }
            }
        }
    }

    nonisolated static func status(forStage stage: String) -> PaperBananaRunStatus {
        switch stage {
        case "queued":
            .queued
        case "complete":
            .completed
        case "recovered":
            .recovered
        case "failed":
            .failed
        case "cancelled":
            .cancelled
        case "timeout":
            .timedOut
        default:
            .running
        }
    }

    nonisolated static func recoveryStatus(for event: PaperBananaRunEvent, status: PaperBananaRunStatus) -> String {
        if event.rawPayloadPath.isEmpty == false {
            return "raw_payload"
        }
        if status == .failed, event.rawResponsePath.isEmpty == false {
            return "raw_response"
        }
        if status == .recovered {
            return "recovered"
        }
        return ""
    }

    nonisolated static func shouldUpdateRunSnapshot(
        currentStatus: PaperBananaRunStatus,
        incomingStatus: PaperBananaRunStatus
    ) -> Bool {
        if isTerminalStatus(currentStatus) {
            return currentStatus == incomingStatus
        }
        return true
    }

    private nonisolated static func isTerminalStatus(_ status: PaperBananaRunStatus) -> Bool {
        switch status {
        case .completed, .recovered, .failed, .cancelled, .timedOut:
            true
        case .queued, .running:
            false
        }
    }

    nonisolated static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    nonisolated static func withDatabase<T>(
        repoRoot: URL,
        body: (OpaquePointer) throws -> T
    ) throws -> T {
        let url = databaseURL(repoRoot: repoRoot)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
            let message = database.map(errorMessage) ?? "sqlite3_open returned nil database"
            if let database { sqlite3_close(database) }
            throw PaperBananaRunStoreError.sqliteOpen(message)
        }
        defer { sqlite3_close(database) }
        try initialize(database)
        return try body(database)
    }

    private nonisolated static func initialize(_ database: OpaquePointer) throws {
        let sql = """
        PRAGMA journal_mode=WAL;
        PRAGMA synchronous=NORMAL;
        CREATE TABLE IF NOT EXISTS runs (
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
            provider_request_path TEXT NOT NULL DEFAULT '',
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
        CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            run_id TEXT NOT NULL,
            stage TEXT NOT NULL,
            progress INTEGER NOT NULL,
            message TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            raw_response_path TEXT NOT NULL DEFAULT '',
            raw_payload_path TEXT NOT NULL DEFAULT '',
            artifact_path TEXT NOT NULL DEFAULT '',
            metadata_path TEXT NOT NULL DEFAULT '',
            provider_call_id TEXT NOT NULL DEFAULT ''
        );
        CREATE TABLE IF NOT EXISTS provider_calls (
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
            usage_metadata TEXT NOT NULL DEFAULT '{}',
            artifact_paths TEXT NOT NULL DEFAULT '[]',
            raw_artifact_paths TEXT NOT NULL DEFAULT '[]'
        );
        CREATE TABLE IF NOT EXISTS provider_call_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            call_id TEXT NOT NULL,
            run_id TEXT NOT NULL,
            provider TEXT NOT NULL,
            model TEXT NOT NULL,
            modality TEXT NOT NULL,
            context TEXT NOT NULL,
            status TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            response_count INTEGER NOT NULL DEFAULT 0,
            message TEXT NOT NULL DEFAULT '',
            error TEXT NOT NULL DEFAULT '',
            usage_metadata TEXT NOT NULL DEFAULT '{}',
            artifact_paths TEXT NOT NULL DEFAULT '[]',
            raw_artifact_paths TEXT NOT NULL DEFAULT '[]'
        );
        CREATE INDEX IF NOT EXISTS idx_events_run_id ON events(run_id);
        CREATE INDEX IF NOT EXISTS idx_runs_status ON runs(status);
        CREATE INDEX IF NOT EXISTS idx_runs_updated_at ON runs(updated_at);
        CREATE INDEX IF NOT EXISTS idx_provider_calls_run_id ON provider_calls(run_id);
        CREATE INDEX IF NOT EXISTS idx_provider_calls_updated_at ON provider_calls(updated_at);
        CREATE INDEX IF NOT EXISTS idx_provider_call_events_call_id ON provider_call_events(call_id, id);
        CREATE INDEX IF NOT EXISTS idx_provider_call_events_run_id ON provider_call_events(run_id, id);
        """
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(database, sql, nil, nil, &error) != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? errorMessage(database)
            sqlite3_free(error)
            throw PaperBananaRunStoreError.sqliteExecute(message)
        }
        try migrate(database)
    }

    private nonisolated static func migrate(_ database: OpaquePointer) throws {
        let runColumns = try tableColumns("runs", database: database)
        if runColumns.contains("provider_request_path") == false {
            try executeMigration(
                "ALTER TABLE runs ADD COLUMN provider_request_path TEXT NOT NULL DEFAULT '';",
                database: database
            )
        }

        let providerCallColumns = try tableColumns("provider_calls", database: database)
        if providerCallColumns.contains("usage_metadata") == false {
            try executeMigration(
                "ALTER TABLE provider_calls ADD COLUMN usage_metadata TEXT NOT NULL DEFAULT '{}';",
                database: database
            )
        }
    }

    private nonisolated static func executeMigration(_ sql: String, database: OpaquePointer) throws {
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(database, sql, nil, nil, &error) != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? errorMessage(database)
            sqlite3_free(error)
            throw PaperBananaRunStoreError.sqliteExecute(message)
        }
    }

    nonisolated static func withImmediateTransaction<T>(
        database: OpaquePointer,
        body: () throws -> T
    ) throws -> T {
        try executeMigration("BEGIN IMMEDIATE;", database: database)
        var committed = false
        defer {
            if committed == false {
                try? executeMigration("ROLLBACK;", database: database)
            }
        }
        let result = try body()
        try executeMigration("COMMIT;", database: database)
        committed = true
        return result
    }

    private nonisolated static func tableColumns(_ table: String, database: OpaquePointer) throws -> Set<String> {
        try withStatement(database: database, sql: "PRAGMA table_info(\(table));") { statement in
            var columns = Set<String>()
            while true {
                let result = sqlite3_step(statement)
                if result == SQLITE_DONE {
                    return columns
                }
                guard result == SQLITE_ROW else {
                    throw PaperBananaRunStoreError.sqliteStep(errorMessage(database))
                }
                columns.insert(columnText(statement, 1))
            }
        }
    }

    nonisolated static func withStatement<T>(
        database: OpaquePointer,
        sql: String,
        body: (OpaquePointer) throws -> T
    ) throws -> T {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw PaperBananaRunStoreError.sqlitePrepare(errorMessage(database))
        }
        defer { sqlite3_finalize(statement) }
        return try body(statement)
    }

    nonisolated static func bindText(_ statement: OpaquePointer, _ index: Int32, _ value: String) {
        _ = value.withCString { pointer in
            sqlite3_bind_text(statement, index, pointer, -1, sqliteTransient)
        }
    }

    nonisolated static func stepDone(_ statement: OpaquePointer, database: OpaquePointer) throws {
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE else {
            throw PaperBananaRunStoreError.sqliteStep(errorMessage(database))
        }
    }

    nonisolated static func columnText(_ statement: OpaquePointer, _ index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: UnsafeRawPointer(text).assumingMemoryBound(to: CChar.self))
    }

    nonisolated static func errorMessage(_ database: OpaquePointer) -> String {
        guard let message = sqlite3_errmsg(database) else { return "unknown SQLite error" }
        return String(cString: message)
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
