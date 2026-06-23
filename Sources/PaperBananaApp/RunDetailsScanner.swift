import Foundation

enum NativeRunCockpitScanner {
    static func scan(repoRootPath: String, fileManager: FileManager = .default, now: Date = Date()) -> [NativeRunCockpitItem] {
        RunDetailsScanner.scan(repoRootPath: repoRootPath, fileManager: fileManager, now: now)
    }
}

enum RunDetailsScanner {
    static func scan(repoRootPath: String, fileManager: FileManager = .default, now: Date = Date()) -> [RunDetailsItem] {
        let repoRoot = URL(fileURLWithPath: repoRootPath, isDirectory: true).standardizedFileURL
        let resultsRoot = repoRoot.appendingPathComponent("results", isDirectory: true)
        let auditRoot = resultsRoot.appendingPathComponent("provider_audit", isDirectory: true)
        let nativeRunIndex = NativeRunFolderIndex.scan(resultsRoot: resultsRoot, fileManager: fileManager, now: now)
        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRoot.path, fileManager: fileManager, now: now)
        let callsByRunID = Dictionary(grouping: calls, by: \.runID)
        let nativeRunIDs = Set(nativeRunIndex.records.map(\.runID))

        let nativeItems = nativeRunIndex.records
            .map { record in
                RunDetailsItem(run: record, providerCalls: callsByRunID[record.runID] ?? [])
            }

        let orphanItems = Dictionary(grouping: calls.filter { call in
            call.runDirectoryURL == nil && nativeRunIDs.contains(call.runID) == false
        }) { call in
            call.runID.nilIfBlank ?? call.callID
        }
        .map { runID, providerCalls in
            RunDetailsItem(
                run: syntheticRunRecord(
                    runID: runID,
                    providerCalls: providerCalls,
                    auditRoot: auditRoot
                ),
                providerCalls: providerCalls
            )
        }

        return (nativeItems + orphanItems)
            .sorted { lhs, rhs in
                if lhs.needsAttention != rhs.needsAttention {
                    return lhs.needsAttention && !rhs.needsAttention
                }
                if lhs.run.modifiedAt == rhs.run.modifiedAt {
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
                return lhs.run.modifiedAt > rhs.run.modifiedAt
            }
    }

    private static func syntheticRunRecord(
        runID: String,
        providerCalls: [ProviderRunLedgerCall],
        auditRoot: URL
    ) -> NativeRunFolderRecord {
        let sortedCalls = providerCalls.sorted {
            ($0.updatedAt ?? $0.startedAt ?? .distantPast) < ($1.updatedAt ?? $1.startedAt ?? .distantPast)
        }
        let artifactURLs = sortedCalls.flatMap(\.artifactURLs).uniqueStandardized()
        let rawPayloadURLs = sortedCalls.flatMap(\.rawArtifactURLs).uniqueStandardized()
        let status = syntheticStatus(for: sortedCalls)
        let modifiedAt = sortedCalls
            .compactMap { $0.updatedAt ?? $0.startedAt }
            .max() ?? .distantPast
        let auditLogURL = sortedCalls.compactMap(\.auditLogURL).last

        return NativeRunFolderRecord(
            runID: runID,
            directoryURL: auditLogURL?.deletingLastPathComponent().standardizedFileURL ?? auditRoot.standardizedFileURL,
            workflow: sortedCalls.first?.context ?? "provider_audit",
            model: sortedCalls.first?.model ?? "",
            resolution: "",
            aspectRatio: "",
            sourceURL: nil,
            declaredOutputURL: nil,
            status: status,
            artifactURLs: artifactURLs,
            rawResponseURLs: [],
            rawPayloadURLs: rawPayloadURLs,
            events: sortedCalls.map { call in
                NativeRunTimelineEvent(
                    id: "provider-\(call.callID)",
                    stage: call.status.rawValue,
                    progress: nil,
                    message: call.message.nilIfBlank ?? call.error.nilIfBlank ?? call.status.label,
                    timestamp: (call.updatedAt ?? call.startedAt)?.formatted(date: .numeric, time: .standard) ?? "",
                    outputURL: call.artifactURLs.first,
                    metadataURL: nil,
                    rawResponseURL: nil,
                    rawURL: call.rawArtifactURLs.first
                )
            },
            modifiedAt: modifiedAt,
            promptURL: nil,
            requestURL: nil,
            providerRequestURL: nil,
            eventLogURL: auditLogURL,
            metadataURL: nil,
            referenceProvenance: sortedCalls.first(where: { $0.referenceProvenance.isManual })?.referenceProvenance ?? .empty
        )
    }

    private static func syntheticStatus(for calls: [ProviderRunLedgerCall]) -> ArtifactRunStatus {
        if calls.contains(where: { $0.status == .running }) {
            return .running
        }
        if calls.contains(where: { $0.status == .failed }) {
            return .failed
        }
        if calls.contains(where: { $0.status == .missingArtifact || $0.status == .rawRecovered }) {
            return .unknown
        }
        if calls.isEmpty == false, calls.allSatisfy({ $0.status == .succeeded }) {
            return .completed
        }
        return .unknown
    }
}

private extension Array where Element == URL {
    func uniqueStandardized() -> [URL] {
        var seen = Set<String>()
        var urls: [URL] = []
        for url in map(\.standardizedFileURL) {
            guard seen.insert(url.path).inserted else { continue }
            urls.append(url)
        }
        return urls
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
