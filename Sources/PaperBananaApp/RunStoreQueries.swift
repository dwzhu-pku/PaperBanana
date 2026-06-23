import Foundation
import SQLite3

extension PaperBananaRunStore {
    nonisolated static func fetchRunSynchronously(id: String, repoRoot: URL) throws -> RunRecord? {
        try withDatabase(repoRoot: repoRoot) { database in
            let sql = """
            SELECT id, workflow, status, provider, provider_kind, model, requested_model,
                   resolution, aspect_ratio, project_path, run_dir, prompt_path, request_path,
                   provider_request_path, raw_response_path, raw_payload_path, artifact_path, metadata_path,
                   event_log_path, provider_call_id, spend_class, recovery_status,
                   created_at, updated_at, elapsed_seconds, message
            FROM runs WHERE id=?
            """
            return try withStatement(database: database, sql: sql) { statement -> RunRecord? in
                bindText(statement, 1, id)
                let result = sqlite3_step(statement)
                guard result == SQLITE_ROW else {
                    if result == SQLITE_DONE { return nil }
                    throw PaperBananaRunStoreError.sqliteStep(errorMessage(database))
                }
                return record(from: statement)
            }
        }
    }

    nonisolated static func fetchRunsSynchronously(
        repoRoot: URL,
        limit: Int = 100,
        statuses: Set<PaperBananaRunStatus> = []
    ) throws -> [RunRecord] {
        try withDatabase(repoRoot: repoRoot) { database in
            let boundedLimit = max(1, min(limit, 1_000))
            let statusValues = statuses.map(\.rawValue).sorted()
            let placeholders = statusValues.map { _ in "?" }.joined(separator: ",")
            let whereClause = statusValues.isEmpty ? "" : "WHERE status IN (\(placeholders))"
            let sql = """
            SELECT id, workflow, status, provider, provider_kind, model, requested_model,
                   resolution, aspect_ratio, project_path, run_dir, prompt_path, request_path,
                   provider_request_path, raw_response_path, raw_payload_path, artifact_path, metadata_path,
                   event_log_path, provider_call_id, spend_class, recovery_status,
                   created_at, updated_at, elapsed_seconds, message
            FROM runs
            \(whereClause)
            ORDER BY updated_at DESC, created_at DESC, id ASC
            LIMIT ?
            """
            return try withStatement(database: database, sql: sql) { statement -> [RunRecord] in
                for (index, status) in statusValues.enumerated() {
                    bindText(statement, Int32(index + 1), status)
                }
                sqlite3_bind_int(statement, Int32(statusValues.count + 1), Int32(boundedLimit))

                var records: [RunRecord] = []
                while true {
                    let result = sqlite3_step(statement)
                    if result == SQLITE_DONE {
                        return records
                    }
                    guard result == SQLITE_ROW else {
                        throw PaperBananaRunStoreError.sqliteStep(errorMessage(database))
                    }
                    records.append(record(from: statement))
                }
            }
        }
    }

    nonisolated static func fetchEventsSynchronously(
        runID: String,
        repoRoot: URL,
        limit: Int = 1_000
    ) throws -> [PaperBananaRunEvent] {
        try withDatabase(repoRoot: repoRoot) { database in
            let boundedLimit = max(1, min(limit, 10_000))
            let sql = """
            SELECT run_id, stage, progress, message, timestamp, raw_response_path,
                   raw_payload_path, artifact_path, metadata_path, provider_call_id
            FROM events
            WHERE run_id=?
            ORDER BY id ASC
            LIMIT ?
            """
            return try withStatement(database: database, sql: sql) { statement -> [PaperBananaRunEvent] in
                bindText(statement, 1, runID)
                sqlite3_bind_int(statement, 2, Int32(boundedLimit))

                var events: [PaperBananaRunEvent] = []
                while true {
                    let result = sqlite3_step(statement)
                    if result == SQLITE_DONE {
                        return events
                    }
                    guard result == SQLITE_ROW else {
                        throw PaperBananaRunStoreError.sqliteStep(errorMessage(database))
                    }
                    events.append(event(from: statement))
                }
            }
        }
    }

    private nonisolated static func record(from statement: OpaquePointer) -> RunRecord {
        RunRecord(
            id: columnText(statement, 0),
            workflow: columnText(statement, 1),
            status: PaperBananaRunStatus(rawValue: columnText(statement, 2)) ?? .failed,
            provider: columnText(statement, 3),
            providerKind: columnText(statement, 4),
            model: columnText(statement, 5),
            requestedModel: columnText(statement, 6),
            resolution: columnText(statement, 7),
            aspectRatio: columnText(statement, 8),
            projectPath: columnText(statement, 9),
            runDirectoryPath: columnText(statement, 10),
            promptPath: columnText(statement, 11),
            requestPath: columnText(statement, 12),
            providerRequestPath: columnText(statement, 13),
            rawResponsePath: columnText(statement, 14),
            rawPayloadPath: columnText(statement, 15),
            artifactPath: columnText(statement, 16),
            metadataPath: columnText(statement, 17),
            eventLogPath: columnText(statement, 18),
            providerCallID: columnText(statement, 19),
            spendClass: columnText(statement, 20),
            recoveryStatus: columnText(statement, 21),
            createdAt: columnText(statement, 22),
            updatedAt: columnText(statement, 23),
            elapsedSeconds: sqlite3_column_double(statement, 24),
            message: columnText(statement, 25)
        )
    }

    private nonisolated static func event(from statement: OpaquePointer) -> PaperBananaRunEvent {
        PaperBananaRunEvent(
            runID: columnText(statement, 0),
            stage: columnText(statement, 1),
            progress: Int(sqlite3_column_int(statement, 2)),
            message: columnText(statement, 3),
            timestamp: columnText(statement, 4),
            rawResponsePath: columnText(statement, 5),
            rawPayloadPath: columnText(statement, 6),
            artifactPath: columnText(statement, 7),
            metadataPath: columnText(statement, 8),
            providerCallID: columnText(statement, 9)
        )
    }
}
