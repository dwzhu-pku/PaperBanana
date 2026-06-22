import Foundation
import SQLite3

extension PaperBananaRunStore {
    nonisolated static func writeProviderCallStartedSynchronously(
        runID: String,
        callID: String,
        provider: String,
        model: String,
        modality: String,
        context: String,
        attempt: Int = 1,
        maxAttempts: Int = 1,
        repoRoot: URL
    ) throws {
        guard !runID.isEmpty else { throw PaperBananaRunStoreError.missingRunID }
        let now = timestamp()
        try withDatabase(repoRoot: repoRoot) { database in
            try withImmediateTransaction(database: database) {
                try requireRunRecord(runID: runID, database: database)
                if let existingRecord = try fetchProviderCall(callID: callID, database: database) {
                    try requireProviderCallOwnership(existingRecord, runID: runID)
                    guard existingRecord.status == ProviderRunStatus.running.rawValue else {
                        throw PaperBananaRunStoreError.providerCallStartRejected(callID, existingRecord.status)
                    }
                    guard existingRecord.provider == provider,
                          existingRecord.model == model,
                          existingRecord.modality == modality,
                          existingRecord.context == context else {
                        throw PaperBananaRunStoreError.providerCallIDConflict(callID, existingRecord.runID, runID)
                    }
                    try updateRunProviderCall(
                        database: database,
                        runID: runID,
                        callID: callID,
                        timestamp: now,
                        message: "Provider call already running."
                    )
                    var eventRecord = existingRecord
                    eventRecord.updatedAt = now
                    eventRecord.message = "Provider call already running."
                    try appendProviderCallEvent(eventRecord, database: database)
                    return
                }
                let record = PaperBananaProviderCallRecord(
                    callID: callID,
                    runID: runID,
                    provider: provider,
                    model: model,
                    modality: modality,
                    context: context,
                    status: ProviderRunStatus.running.rawValue,
                    startedAt: now,
                    updatedAt: now,
                    attempt: attempt,
                    maxAttempts: maxAttempts,
                    responseCount: 0,
                    message: "Provider call started.",
                    error: "",
                    usageMetadata: [:],
                    artifactPaths: [],
                    rawArtifactPaths: []
                )
                try upsertProviderCall(record, database: database)
                try updateRunProviderCall(
                    database: database,
                    runID: runID,
                    callID: callID,
                    timestamp: now,
                    message: record.message
                )
                try appendProviderCallEvent(record, database: database)
            }
        }
    }

    nonisolated static func writeProviderImageSavedSynchronously(
        runID: String,
        callID: String,
        provider: String,
        model: String,
        path: URL,
        raw: Bool,
        context: String,
        repoRoot: URL
    ) throws {
        guard !runID.isEmpty else { throw PaperBananaRunStoreError.missingRunID }
        let now = timestamp()
        try withDatabase(repoRoot: repoRoot) { database in
            try withImmediateTransaction(database: database) {
                var record = try requireMutableProviderCallRecord(callID: callID, runID: runID, database: database)
                record.runID = runID
                record.provider = provider
                record.model = model
                record.modality = "image"
                record.context = context
                record.updatedAt = now
                record.message = raw ? "Raw provider image payload saved." : "Provider image artifact saved."
                let pathValue = path.standardizedFileURL.path
                if raw {
                    if record.rawArtifactPaths.contains(pathValue) == false {
                        record.rawArtifactPaths.append(pathValue)
                    }
                } else if record.artifactPaths.contains(pathValue) == false {
                    record.artifactPaths.append(pathValue)
                }
                try upsertProviderCall(record, database: database)
                try updateRunProviderCall(
                    database: database,
                    runID: runID,
                    callID: callID,
                    timestamp: now,
                    message: record.message
                )
                try appendProviderCallEvent(record, database: database)
            }
        }
    }

    nonisolated static func writeProviderCallFinishedSynchronously(
        runID: String,
        callID: String,
        provider: String,
        model: String,
        modality: String,
        context: String,
        success: Bool,
        responseCount: Int,
        message: String,
        artifacts: [URL],
        usageMetadata: [String: String] = [:],
        repoRoot: URL
    ) throws {
        guard !runID.isEmpty else { throw PaperBananaRunStoreError.missingRunID }
        let now = timestamp()
        try withDatabase(repoRoot: repoRoot) { database in
            try withImmediateTransaction(database: database) {
                var record = try requireProviderCallRecord(callID: callID, runID: runID, database: database)
                if record.status != ProviderRunStatus.running.rawValue {
                    guard canBackfillTerminalUsageMetadata(
                        record,
                        provider: provider,
                        model: model,
                        modality: modality,
                        context: context,
                        success: success,
                        artifacts: artifacts,
                        usageMetadata: usageMetadata
                    ) else {
                        throw PaperBananaRunStoreError.providerCallTerminalMutationRejected(callID, record.status)
                    }
                    record.usageMetadata = usageMetadata
                    record.updatedAt = now
                    try upsertProviderCall(record, database: database)
                    var eventRecord = record
                    eventRecord.message = "Provider usage metadata backfilled."
                    try appendProviderCallEvent(eventRecord, database: database)
                    return
                }
                record.runID = runID
                record.provider = provider
                record.model = model
                record.modality = modality
                record.context = context
                record.updatedAt = now
                record.responseCount = responseCount
                record.message = message
                if usageMetadata.isEmpty == false {
                    record.usageMetadata = usageMetadata
                }
                for artifact in artifacts.map(\.standardizedFileURL.path) where record.artifactPaths.contains(artifact) == false {
                    record.artifactPaths.append(artifact)
                }
                if success {
                    record.status = ProviderRunStatus.succeeded.rawValue
                } else {
                    record.status = record.rawArtifactPaths.isEmpty ? ProviderRunStatus.failed.rawValue : ProviderRunStatus.rawRecovered.rawValue
                    record.error = message
                }
                try upsertProviderCall(record, database: database)
                try updateRunProviderCallTerminalSnapshot(
                    database: database,
                    runID: runID,
                    record: record,
                    timestamp: now,
                    message: message
                )
                try appendProviderCallEvent(record, database: database)
            }
        }
    }

    nonisolated static func writeProviderCallFailedSynchronously(
        runID: String,
        callID: String,
        provider: String,
        model: String,
        modality: String,
        context: String,
        error: String,
        repoRoot: URL
    ) throws {
        guard !runID.isEmpty else { throw PaperBananaRunStoreError.missingRunID }
        let now = timestamp()
        try withDatabase(repoRoot: repoRoot) { database in
            try withImmediateTransaction(database: database) {
                var record = try requireMutableProviderCallRecord(callID: callID, runID: runID, database: database)
                record.runID = runID
                record.provider = provider
                record.model = model
                record.modality = modality
                record.context = context
                record.status = ProviderRunStatus.failed.rawValue
                record.updatedAt = now
                record.error = error
                record.message = error
                try upsertProviderCall(record, database: database)
                try updateRunProviderCallTerminalSnapshot(
                    database: database,
                    runID: runID,
                    record: record,
                    timestamp: now,
                    message: error
                )
                try appendProviderCallEvent(record, database: database)
            }
        }
    }

    nonisolated static func writeProviderCallTerminalSynchronously(
        runID: String,
        callID: String,
        provider: String,
        model: String,
        modality: String,
        context: String,
        status: ProviderRunStatus,
        message: String,
        repoRoot: URL
    ) throws {
        guard !runID.isEmpty else { throw PaperBananaRunStoreError.missingRunID }
        let now = timestamp()
        try withDatabase(repoRoot: repoRoot) { database in
            try withImmediateTransaction(database: database) {
                var record = try requireMutableProviderCallRecord(callID: callID, runID: runID, database: database)
                record.runID = runID
                record.provider = provider
                record.model = model
                record.modality = modality
                record.context = context
                record.status = status.rawValue
                record.updatedAt = now
                record.message = message
                record.error = message
                try upsertProviderCall(record, database: database)
                try updateRunProviderCallTerminalSnapshot(
                    database: database,
                    runID: runID,
                    record: record,
                    timestamp: now,
                    message: message
                )
                try appendProviderCallEvent(record, database: database)
            }
        }
    }

    nonisolated static func fetchProviderCallSynchronously(
        callID: String,
        repoRoot: URL
    ) throws -> PaperBananaProviderCallRecord? {
        try withDatabase(repoRoot: repoRoot) { database in
            try fetchProviderCall(callID: callID, database: database)
        }
    }

    nonisolated static func fetchProviderCallsSynchronously(
        repoRoot: URL,
        limit: Int = 1_000
    ) throws -> [PaperBananaProviderCallRecord] {
        try withDatabase(repoRoot: repoRoot) { database in
            let boundedLimit = max(1, min(limit, 10_000))
            let sql = """
            SELECT call_id, run_id, provider, model, modality, context, status,
                   started_at, updated_at, attempt, max_attempts, response_count,
                   message, error, usage_metadata, artifact_paths, raw_artifact_paths
            FROM provider_calls
            ORDER BY updated_at DESC, started_at DESC, call_id ASC
            LIMIT ?
            """
            return try withStatement(database: database, sql: sql) { statement -> [PaperBananaProviderCallRecord] in
                sqlite3_bind_int(statement, 1, Int32(boundedLimit))
                var records: [PaperBananaProviderCallRecord] = []
                while true {
                    let result = sqlite3_step(statement)
                    if result == SQLITE_DONE {
                        return records
                    }
                    guard result == SQLITE_ROW else {
                        throw PaperBananaRunStoreError.sqliteStep(errorMessage(database))
                    }
                    records.append(providerCall(from: statement))
                }
            }
        }
    }

    nonisolated static func fetchProviderCallEventsSynchronously(
        callID: String,
        repoRoot: URL,
        limit: Int = 1_000
    ) throws -> [PaperBananaProviderCallEvent] {
        try withDatabase(repoRoot: repoRoot) { database in
            let boundedLimit = max(1, min(limit, 10_000))
            let sql = """
            SELECT call_id, run_id, provider, model, modality, context, status,
                   timestamp, response_count, message, error, usage_metadata,
                   artifact_paths, raw_artifact_paths
            FROM provider_call_events
            WHERE call_id=?
            ORDER BY id ASC
            LIMIT ?
            """
            return try withStatement(database: database, sql: sql) { statement -> [PaperBananaProviderCallEvent] in
                bindText(statement, 1, callID)
                sqlite3_bind_int(statement, 2, Int32(boundedLimit))
                var events: [PaperBananaProviderCallEvent] = []
                while true {
                    let result = sqlite3_step(statement)
                    if result == SQLITE_DONE {
                        return events
                    }
                    guard result == SQLITE_ROW else {
                        throw PaperBananaRunStoreError.sqliteStep(errorMessage(database))
                    }
                    events.append(providerCallEvent(from: statement))
                }
            }
        }
    }

    private nonisolated static func fetchProviderCall(
        callID: String,
        database: OpaquePointer
    ) throws -> PaperBananaProviderCallRecord? {
        let sql = """
        SELECT call_id, run_id, provider, model, modality, context, status,
               started_at, updated_at, attempt, max_attempts, response_count,
               message, error, usage_metadata, artifact_paths, raw_artifact_paths
        FROM provider_calls
        WHERE call_id=?
        """
        return try withStatement(database: database, sql: sql) { statement -> PaperBananaProviderCallRecord? in
            bindText(statement, 1, callID)
            let result = sqlite3_step(statement)
            guard result == SQLITE_ROW else {
                if result == SQLITE_DONE { return nil }
                throw PaperBananaRunStoreError.sqliteStep(errorMessage(database))
            }
            return providerCall(from: statement)
        }
    }

    private nonisolated static func appendProviderCallEvent(
        _ record: PaperBananaProviderCallRecord,
        database: OpaquePointer
    ) throws {
        let sql = """
        INSERT INTO provider_call_events (
            call_id, run_id, provider, model, modality, context, status,
            timestamp, response_count, message, error, usage_metadata,
            artifact_paths, raw_artifact_paths
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        try withStatement(database: database, sql: sql) { statement in
            bindText(statement, 1, record.callID)
            bindText(statement, 2, record.runID)
            bindText(statement, 3, record.provider)
            bindText(statement, 4, record.model)
            bindText(statement, 5, record.modality)
            bindText(statement, 6, record.context)
            bindText(statement, 7, record.status)
            bindText(statement, 8, record.updatedAt)
            sqlite3_bind_int(statement, 9, Int32(record.responseCount))
            bindText(statement, 10, record.message)
            bindText(statement, 11, record.error)
            bindText(statement, 12, encodeStringDictionary(record.usageMetadata))
            bindText(statement, 13, encodeStringArray(record.artifactPaths))
            bindText(statement, 14, encodeStringArray(record.rawArtifactPaths))
            try stepDone(statement, database: database)
        }
    }

    private nonisolated static func requireProviderCallRecord(
        callID: String,
        runID: String,
        database: OpaquePointer
    ) throws -> PaperBananaProviderCallRecord {
        guard let record = try fetchProviderCall(callID: callID, database: database) else {
            try requireRunRecord(runID: runID, database: database)
            throw PaperBananaRunStoreError.missingProviderCallRecord(callID)
        }
        try requireProviderCallOwnership(record, runID: runID)
        return record
    }

    private nonisolated static func requireMutableProviderCallRecord(
        callID: String,
        runID: String,
        database: OpaquePointer
    ) throws -> PaperBananaProviderCallRecord {
        let record = try requireProviderCallRecord(callID: callID, runID: runID, database: database)
        guard record.status == ProviderRunStatus.running.rawValue else {
            throw PaperBananaRunStoreError.providerCallTerminalMutationRejected(callID, record.status)
        }
        return record
    }

    private nonisolated static func canBackfillTerminalUsageMetadata(
        _ record: PaperBananaProviderCallRecord,
        provider: String,
        model: String,
        modality: String,
        context: String,
        success: Bool,
        artifacts: [URL],
        usageMetadata: [String: String]
    ) -> Bool {
        record.status == ProviderRunStatus.succeeded.rawValue
            && success
            && record.provider == provider
            && record.model == model
            && record.modality == modality
            && record.context == context
            && artifacts.isEmpty
            && record.usageMetadata.isEmpty
            && usageMetadata.isEmpty == false
    }

    private nonisolated static func requireProviderCallOwnership(
        _ record: PaperBananaProviderCallRecord,
        runID: String
    ) throws {
        guard record.runID == runID else {
            throw PaperBananaRunStoreError.providerCallIDConflict(record.callID, record.runID, runID)
        }
    }

    nonisolated static func requireRunRecord(runID: String, database: OpaquePointer) throws {
        let sql = "SELECT 1 FROM runs WHERE id=? LIMIT 1"
        let exists = try withStatement(database: database, sql: sql) { statement -> Bool in
            bindText(statement, 1, runID)
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                return true
            }
            if result == SQLITE_DONE {
                return false
            }
            throw PaperBananaRunStoreError.sqliteStep(errorMessage(database))
        }
        if exists == false {
            throw PaperBananaRunStoreError.missingRunRecord(runID)
        }
    }

    nonisolated static func fetchRunStatus(
        runID: String,
        database: OpaquePointer
    ) throws -> PaperBananaRunStatus {
        let sql = "SELECT status FROM runs WHERE id=? LIMIT 1"
        return try withStatement(database: database, sql: sql) { statement -> PaperBananaRunStatus in
            bindText(statement, 1, runID)
            let result = sqlite3_step(statement)
            guard result == SQLITE_ROW else {
                if result == SQLITE_DONE {
                    throw PaperBananaRunStoreError.missingRunRecord(runID)
                }
                throw PaperBananaRunStoreError.sqliteStep(errorMessage(database))
            }
            return PaperBananaRunStatus(rawValue: columnText(statement, 0)) ?? .failed
        }
    }

    private nonisolated static func upsertProviderCall(
        _ record: PaperBananaProviderCallRecord,
        database: OpaquePointer
    ) throws {
        let sql = """
        INSERT INTO provider_calls (
            call_id, run_id, provider, model, modality, context, status,
            started_at, updated_at, attempt, max_attempts, response_count,
            message, error, usage_metadata, artifact_paths, raw_artifact_paths
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(call_id) DO UPDATE SET
            run_id=excluded.run_id,
            provider=excluded.provider,
            model=excluded.model,
            modality=excluded.modality,
            context=excluded.context,
            status=excluded.status,
            updated_at=excluded.updated_at,
            attempt=excluded.attempt,
            max_attempts=excluded.max_attempts,
            response_count=excluded.response_count,
            message=excluded.message,
            error=excluded.error,
            usage_metadata=excluded.usage_metadata,
            artifact_paths=excluded.artifact_paths,
            raw_artifact_paths=excluded.raw_artifact_paths
        """
        try withStatement(database: database, sql: sql) { statement in
            bindText(statement, 1, record.callID)
            bindText(statement, 2, record.runID)
            bindText(statement, 3, record.provider)
            bindText(statement, 4, record.model)
            bindText(statement, 5, record.modality)
            bindText(statement, 6, record.context)
            bindText(statement, 7, record.status)
            bindText(statement, 8, record.startedAt)
            bindText(statement, 9, record.updatedAt)
            sqlite3_bind_int(statement, 10, Int32(record.attempt))
            sqlite3_bind_int(statement, 11, Int32(record.maxAttempts))
            sqlite3_bind_int(statement, 12, Int32(record.responseCount))
            bindText(statement, 13, record.message)
            bindText(statement, 14, record.error)
            bindText(statement, 15, encodeStringDictionary(record.usageMetadata))
            bindText(statement, 16, encodeStringArray(record.artifactPaths))
            bindText(statement, 17, encodeStringArray(record.rawArtifactPaths))
            try stepDone(statement, database: database)
        }
    }

    private nonisolated static func updateRunProviderCall(
        database: OpaquePointer,
        runID: String,
        callID: String,
        timestamp: String,
        message: String
    ) throws {
        let currentStatus = try fetchRunStatus(runID: runID, database: database)
        guard shouldUpdateRunSnapshot(currentStatus: currentStatus, incomingStatus: .running) else {
            try updateRunProviderCallID(database: database, runID: runID, callID: callID)
            return
        }
        let sql = """
        UPDATE runs SET
            status=CASE WHEN status='queued' THEN 'running' ELSE status END,
            updated_at=?,
            message=?,
            provider_call_id=CASE WHEN ? = '' THEN provider_call_id ELSE ? END
        WHERE id=?
        """
        try withStatement(database: database, sql: sql) { statement in
            bindText(statement, 1, timestamp)
            bindText(statement, 2, message)
            bindText(statement, 3, callID)
            bindText(statement, 4, callID)
            bindText(statement, 5, runID)
            try stepDone(statement, database: database)
        }
    }

    private nonisolated static func updateRunProviderCallTerminalSnapshot(
        database: OpaquePointer,
        runID: String,
        record: PaperBananaProviderCallRecord,
        timestamp: String,
        message: String
    ) throws {
        guard let providerStatus = ProviderRunStatus(rawValue: record.status),
              let incomingStatus = runStatus(for: providerStatus) else {
            try updateRunProviderCall(database: database, runID: runID, callID: record.callID, timestamp: timestamp, message: message)
            return
        }
        let currentStatus = try fetchRunStatus(runID: runID, database: database)
        guard shouldUpdateRunSnapshot(currentStatus: currentStatus, incomingStatus: incomingStatus) else {
            try updateRunProviderCallID(database: database, runID: runID, callID: record.callID)
            return
        }

        let rawPayloadPath = record.rawArtifactPaths.first ?? ""
        let rawResponsePath = rawResponseArtifactPath(from: record)
        let recoveryStatus = recoveryStatus(
            providerStatus: providerStatus,
            rawResponsePath: rawResponsePath,
            rawPayloadPath: rawPayloadPath
        )
        let sql = """
        UPDATE runs SET
            status=?,
            updated_at=?,
            message=?,
            raw_response_path=CASE WHEN ? = '' THEN raw_response_path ELSE ? END,
            raw_payload_path=CASE WHEN ? = '' THEN raw_payload_path ELSE ? END,
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
        try withStatement(database: database, sql: sql) { statement in
            bindText(statement, 1, incomingStatus.rawValue)
            bindText(statement, 2, timestamp)
            bindText(statement, 3, message)
            bindText(statement, 4, rawResponsePath)
            bindText(statement, 5, rawResponsePath)
            bindText(statement, 6, rawPayloadPath)
            bindText(statement, 7, rawPayloadPath)
            bindText(statement, 8, record.callID)
            bindText(statement, 9, record.callID)
            bindText(statement, 10, recoveryStatus)
            bindText(statement, 11, recoveryStatus)
            bindText(statement, 12, timestamp)
            bindText(statement, 13, timestamp)
            bindText(statement, 14, timestamp)
            bindText(statement, 15, runID)
            try stepDone(statement, database: database)
        }
    }

    private nonisolated static func updateRunProviderCallID(
        database: OpaquePointer,
        runID: String,
        callID: String
    ) throws {
        let sql = """
        UPDATE runs SET
            provider_call_id=CASE WHEN ? = '' THEN provider_call_id ELSE ? END
        WHERE id=?
        """
        try withStatement(database: database, sql: sql) { statement in
            bindText(statement, 1, callID)
            bindText(statement, 2, callID)
            bindText(statement, 3, runID)
            try stepDone(statement, database: database)
        }
    }

    private nonisolated static func runStatus(for providerStatus: ProviderRunStatus) -> PaperBananaRunStatus? {
        switch providerStatus {
        case .running:
            .running
        case .succeeded:
            .completed
        case .failed, .missingArtifact, .rawRecovered:
            providerStatus == .rawRecovered ? .recovered : .failed
        case .cancelled:
            .cancelled
        case .timedOut:
            .timedOut
        }
    }

    private nonisolated static func rawResponseArtifactPath(from record: PaperBananaProviderCallRecord) -> String {
        record.artifactPaths.first { path in
            let name = URL(fileURLWithPath: path).lastPathComponent.lowercased()
            return name.contains("provider_response") || name.hasSuffix(".json")
        } ?? ""
    }

    private nonisolated static func recoveryStatus(
        providerStatus: ProviderRunStatus,
        rawResponsePath: String,
        rawPayloadPath: String
    ) -> String {
        if rawPayloadPath.isEmpty == false || providerStatus == .rawRecovered {
            return "raw_payload"
        }
        if rawResponsePath.isEmpty == false {
            return "raw_response"
        }
        return ""
    }

    private nonisolated static func providerCall(from statement: OpaquePointer) -> PaperBananaProviderCallRecord {
        PaperBananaProviderCallRecord(
            callID: columnText(statement, 0),
            runID: columnText(statement, 1),
            provider: columnText(statement, 2),
            model: columnText(statement, 3),
            modality: columnText(statement, 4),
            context: columnText(statement, 5),
            status: columnText(statement, 6),
            startedAt: columnText(statement, 7),
            updatedAt: columnText(statement, 8),
            attempt: Int(sqlite3_column_int(statement, 9)),
            maxAttempts: Int(sqlite3_column_int(statement, 10)),
            responseCount: Int(sqlite3_column_int(statement, 11)),
            message: columnText(statement, 12),
            error: columnText(statement, 13),
            usageMetadata: decodeStringDictionary(columnText(statement, 14)),
            artifactPaths: decodeStringArray(columnText(statement, 15)),
            rawArtifactPaths: decodeStringArray(columnText(statement, 16))
        )
    }

    private nonisolated static func providerCallEvent(from statement: OpaquePointer) -> PaperBananaProviderCallEvent {
        PaperBananaProviderCallEvent(
            callID: columnText(statement, 0),
            runID: columnText(statement, 1),
            provider: columnText(statement, 2),
            model: columnText(statement, 3),
            modality: columnText(statement, 4),
            context: columnText(statement, 5),
            status: columnText(statement, 6),
            timestamp: columnText(statement, 7),
            responseCount: Int(sqlite3_column_int(statement, 8)),
            message: columnText(statement, 9),
            error: columnText(statement, 10),
            usageMetadata: decodeStringDictionary(columnText(statement, 11)),
            artifactPaths: decodeStringArray(columnText(statement, 12)),
            rawArtifactPaths: decodeStringArray(columnText(statement, 13))
        )
    }

    private nonisolated static func encodeStringArray(_ values: [String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return text
    }

    private nonisolated static func decodeStringArray(_ value: String) -> [String] {
        guard let data = value.data(using: .utf8),
              let values = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }
        return values
    }

    private nonisolated static func encodeStringDictionary(_ values: [String: String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private nonisolated static func decodeStringDictionary(_ value: String) -> [String: String] {
        guard let data = value.data(using: .utf8),
              let values = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }
        return values
    }
}
