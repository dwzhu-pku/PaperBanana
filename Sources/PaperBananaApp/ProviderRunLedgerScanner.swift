import Foundation

enum ProviderRunLedgerScanner {
    static func scan(repoRootPath: String, fileManager: FileManager = .default, now: Date = Date()) -> [ProviderRunLedgerCall] {
        let repoRoot = URL(fileURLWithPath: repoRootPath, isDirectory: true).standardizedFileURL
        let auditRoot = repoRoot.appendingPathComponent("results/provider_audit", isDirectory: true)
        let resultsRoot = repoRoot.appendingPathComponent("results", isDirectory: true)
        let nativeRunIndex = NativeRunFolderIndex.scan(resultsRoot: resultsRoot, fileManager: fileManager, now: now)
        let logs = providerLogFiles(in: auditRoot, fileManager: fileManager)
        var builders: [String: ProviderRunBuilder] = [:]

        for logURL in logs {
            guard let contents = try? String(contentsOf: logURL, encoding: .utf8) else { continue }
            for line in contents.split(whereSeparator: \.isNewline) {
                guard let event = ProviderAuditEvent(jsonLine: String(line)) else { continue }
                let key = event.callID.isEmpty ? "\(logURL.lastPathComponent)-\(builders.count)" : event.callID
                var builder = builders[key] ?? ProviderRunBuilder(callID: key, auditLogURL: logURL)
                builder.apply(event)
                builders[key] = builder
            }
        }

        let jsonCalls = builders.values
            .map { $0.call(now: now, nativeRun: nativeRunIndex.record(runID: $0.runID)) }
        var callsByID = Dictionary(uniqueKeysWithValues: jsonCalls.map { ($0.callID, $0) })

        let sqliteRecords = (try? PaperBananaRunStore.fetchProviderCallsSynchronously(repoRoot: repoRoot, limit: 10_000)) ?? []
        for record in sqliteRecords {
            callsByID[record.callID] = call(
                from: record,
                nativeRun: nativeRunIndex.record(runID: record.runID),
                jsonFallback: callsByID[record.callID]
            )
        }

        return callsByID.values
            .sorted {
                let left = $0.updatedAt ?? $0.startedAt ?? .distantPast
                let right = $1.updatedAt ?? $1.startedAt ?? .distantPast
                if left == right { return $0.callID < $1.callID }
                return left > right
            }
    }

    private static func providerLogFiles(in auditRoot: URL, fileManager: FileManager) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: auditRoot,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents
            .filter { $0.lastPathComponent.hasPrefix("provider_calls_") && $0.pathExtension == "jsonl" }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                if lhsDate == rhsDate { return lhs.lastPathComponent < rhs.lastPathComponent }
                return lhsDate < rhsDate
            }
    }

    private static func call(
        from record: PaperBananaProviderCallRecord,
        nativeRun: NativeRunFolderRecord?,
        jsonFallback: ProviderRunLedgerCall?
    ) -> ProviderRunLedgerCall {
        let artifactURLs = uniqueStandardized(urls(from: record.artifactPaths) + (jsonFallback?.artifactURLs ?? []))
        let rawArtifactURLs = uniqueStandardized(urls(from: record.rawArtifactPaths) + (jsonFallback?.rawArtifactURLs ?? []))
        let nativeArtifactURLs = nativeRun?.artifactURLs ?? jsonFallback?.nativeArtifactURLs ?? []

        return ProviderRunLedgerCall(
            callID: record.callID,
            runID: nonEmpty(record.runID, fallback: jsonFallback?.runID ?? ""),
            provider: nonEmpty(record.provider, fallback: jsonFallback?.provider ?? ""),
            model: nonEmpty(record.model, fallback: jsonFallback?.model ?? ""),
            modality: nonEmpty(record.modality, fallback: jsonFallback?.modality ?? ""),
            context: nonEmpty(record.context, fallback: jsonFallback?.context ?? ""),
            status: status(for: record, nativeArtifactURLs: nativeArtifactURLs, rawArtifactURLs: rawArtifactURLs, fallback: jsonFallback?.status),
            startedAt: parseDate(record.startedAt) ?? jsonFallback?.startedAt,
            updatedAt: parseDate(record.updatedAt) ?? jsonFallback?.updatedAt,
            attempt: record.attempt > 0 ? record.attempt : jsonFallback?.attempt,
            maxAttempts: record.maxAttempts > 0 ? record.maxAttempts : jsonFallback?.maxAttempts,
            responseCount: record.responseCount > 0 ? record.responseCount : jsonFallback?.responseCount ?? 0,
            message: nonEmpty(record.message, fallback: jsonFallback?.message ?? ""),
            error: nonEmpty(record.error, fallback: jsonFallback?.error ?? ""),
            usageMetadata: record.usageMetadata.isEmpty ? jsonFallback?.usageMetadata ?? [:] : record.usageMetadata,
            artifactURLs: artifactURLs,
            rawArtifactURLs: rawArtifactURLs,
            runDirectoryURL: nativeRun?.directoryURL ?? jsonFallback?.runDirectoryURL,
            nativeArtifactURLs: nativeArtifactURLs,
            nativePromptURL: nativeRun?.promptURL ?? jsonFallback?.nativePromptURL,
            nativeRequestURL: nativeRun?.requestURL ?? jsonFallback?.nativeRequestURL,
            nativeProviderRequestURL: nativeRun?.providerRequestURL ?? jsonFallback?.nativeProviderRequestURL,
            nativeEventLogURL: nativeRun?.eventLogURL ?? jsonFallback?.nativeEventLogURL,
            auditLogURL: jsonFallback?.auditLogURL
        )
    }

    private static func status(
        for record: PaperBananaProviderCallRecord,
        nativeArtifactURLs: [URL],
        rawArtifactURLs: [URL],
        fallback: ProviderRunStatus?
    ) -> ProviderRunStatus {
        let status = ProviderRunStatus(rawValue: record.status) ?? fallback ?? .running
        switch status {
        case .succeeded:
            if record.modality == "image", record.responseCount > 0, nativeArtifactURLs.isEmpty {
                return rawArtifactURLs.isEmpty ? .missingArtifact : .rawRecovered
            }
            return .succeeded
        case .missingArtifact, .failed:
            if nativeArtifactURLs.isEmpty, rawArtifactURLs.isEmpty == false {
                return .rawRecovered
            }
            return status
        case .rawRecovered, .cancelled, .timedOut, .running:
            return status
        }
    }

    private static func urls(from paths: [String]) -> [URL] {
        paths
            .filter { $0.isEmpty == false }
            .map { URL(fileURLWithPath: $0).standardizedFileURL }
    }

    private static func uniqueStandardized(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []
        for url in urls.map(\.standardizedFileURL) {
            guard seen.insert(url.path).inserted else { continue }
            result.append(url)
        }
        return result
    }

    private static func nonEmpty(_ value: String, fallback: String) -> String {
        value.isEmpty ? fallback : value
    }

    private static func parseDate(_ value: String) -> Date? {
        guard value.isEmpty == false else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }
}

private struct ProviderAuditEvent {
    let timestamp: Date?
    let runID: String
    let event: String
    let callID: String
    let provider: String
    let model: String
    let modality: String
    let context: String
    let attempt: Int?
    let maxAttempts: Int?
    let success: Bool?
    let responseCount: Int?
    let message: String
    let error: String
    let usageMetadata: [String: String]
    let path: String
    let artifacts: [String]

    init?(jsonLine: String) {
        guard let data = jsonLine.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = payload["event"] as? String else {
            return nil
        }

        self.timestamp = Self.parseDate(payload["timestamp"] as? String)
        self.runID = payload["run_id"] as? String ?? ""
        self.event = event
        self.callID = payload["call_id"] as? String ?? ""
        self.provider = payload["provider"] as? String ?? ""
        self.model = payload["model"] as? String ?? ""
        self.modality = payload["modality"] as? String ?? ""
        self.context = payload["context"] as? String ?? ""
        self.attempt = payload["attempt"] as? Int
        self.maxAttempts = payload["max_attempts"] as? Int
        self.success = payload["success"] as? Bool
        self.responseCount = payload["response_count"] as? Int
        self.message = payload["message"] as? String ?? ""
        self.error = payload["error"] as? String ?? ""
        self.usageMetadata = Self.stringDictionary(payload["usage_metadata"])
        self.path = payload["path"] as? String ?? ""
        self.artifacts = payload["artifacts"] as? [String] ?? []
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }

    private static func stringDictionary(_ value: Any?) -> [String: String] {
        guard let payload = value as? [String: Any] else { return [:] }
        return payload.reduce(into: [:]) { result, item in
            result[item.key] = "\(item.value)"
        }
    }
}

private struct ProviderRunBuilder {
    let callID: String
    let auditLogURL: URL
    var runID = ""
    var provider = ""
    var model = ""
    var modality = ""
    var context = ""
    var startedAt: Date?
    var updatedAt: Date?
    var attempt: Int?
    var maxAttempts: Int?
    var success: Bool?
    var responseCount = 0
    var message = ""
    var error = ""
    var usageMetadata: [String: String] = [:]
    var artifacts: [URL] = []
    var rawArtifacts: [URL] = []

    mutating func apply(_ event: ProviderAuditEvent) {
        if !event.runID.isEmpty { runID = event.runID }
        if !event.provider.isEmpty { provider = event.provider }
        if !event.model.isEmpty { model = event.model }
        if !event.modality.isEmpty { modality = event.modality }
        if !event.context.isEmpty { context = event.context }
        if let attempt = event.attempt { self.attempt = attempt }
        if let maxAttempts = event.maxAttempts { self.maxAttempts = maxAttempts }
        if let timestamp = event.timestamp {
            updatedAt = timestamp
            if event.event == "provider_call_started" || startedAt == nil {
                startedAt = timestamp
            }
        }
        if !event.message.isEmpty { message = event.message }
        if !event.error.isEmpty { error = event.error }
        if event.usageMetadata.isEmpty == false { usageMetadata = event.usageMetadata }
        if let responseCount = event.responseCount {
            self.responseCount = responseCount
        }

        switch event.event {
        case "provider_call_finished":
            success = event.success
            Self.appendArtifacts(event.artifacts, to: &artifacts)
        case "provider_call_failed":
            success = false
        case "provider_image_saved":
            Self.appendArtifact(event.path, to: &artifacts)
        case "provider_image_raw_saved":
            Self.appendArtifact(event.path, to: &rawArtifacts)
        default:
            break
        }
    }

    func call(now _: Date, nativeRun: NativeRunFolderRecord?) -> ProviderRunLedgerCall {
        ProviderRunLedgerCall(
            callID: callID,
            runID: runID,
            provider: provider,
            model: model,
            modality: modality,
            context: context,
            status: status(nativeArtifactURLs: nativeRun?.artifactURLs ?? []),
            startedAt: startedAt,
            updatedAt: updatedAt,
            attempt: attempt,
            maxAttempts: maxAttempts,
            responseCount: responseCount,
            message: message,
            error: error,
            usageMetadata: usageMetadata,
            artifactURLs: artifacts,
            rawArtifactURLs: rawArtifacts,
            runDirectoryURL: nativeRun?.directoryURL,
            nativeArtifactURLs: nativeRun?.artifactURLs ?? [],
            nativePromptURL: nativeRun?.promptURL,
            nativeRequestURL: nativeRun?.requestURL,
            nativeProviderRequestURL: nativeRun?.providerRequestURL,
            nativeEventLogURL: nativeRun?.eventLogURL,
            auditLogURL: auditLogURL
        )
    }

    private func status(nativeArtifactURLs: [URL]) -> ProviderRunStatus {
        if success == false || !error.isEmpty {
            if nativeArtifactURLs.isEmpty, rawArtifacts.isEmpty == false {
                return .rawRecovered
            }
            return .failed
        }
        if success == true {
            if modality == "image", responseCount > 0, nativeArtifactURLs.isEmpty {
                return rawArtifacts.isEmpty ? .missingArtifact : .rawRecovered
            }
            return .succeeded
        }
        if nativeArtifactURLs.isEmpty, rawArtifacts.isEmpty == false {
            return .rawRecovered
        }
        return .running
    }

    private static func appendArtifacts(_ paths: [String], to target: inout [URL]) {
        for path in paths {
            appendArtifact(path, to: &target)
        }
    }

    private static func appendArtifact(_ path: String, to target: inout [URL]) {
        guard !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        if target.contains(url) == false {
            target.append(url)
        }
    }
}
