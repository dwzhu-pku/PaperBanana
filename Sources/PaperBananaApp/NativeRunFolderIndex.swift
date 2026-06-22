import Foundation

struct NativeRunTimelineEvent: Identifiable, Hashable {
    let id: String
    let stage: String
    let progress: Int?
    let message: String
    let timestamp: String
    let outputURL: URL?
    let metadataURL: URL?
    let rawResponseURL: URL?
    let rawURL: URL?

    var status: ArtifactRunStatus {
        NativeRunFolderRecord.status(fromStage: stage)
    }
}

struct NativeRunFolderRecord: Hashable {
    let runID: String
    let directoryURL: URL
    let workflow: String
    let model: String
    let resolution: String
    let aspectRatio: String
    let sourceURL: URL?
    let declaredOutputURL: URL?
    let status: ArtifactRunStatus
    let artifactURLs: [URL]
    let rawResponseURLs: [URL]
    let rawPayloadURLs: [URL]
    let events: [NativeRunTimelineEvent]
    let modifiedAt: Date
    let promptURL: URL?
    let requestURL: URL?
    let providerRequestURL: URL?
    let eventLogURL: URL?
    let metadataURL: URL?

    var needsAttention: Bool {
        if status.needsAttention { return true }
        if artifactURLs.isEmpty, rawResponseURLs.isEmpty == false { return true }
        if artifactURLs.isEmpty, rawPayloadURLs.isEmpty == false { return true }
        if artifactURLs.isEmpty, status != .running { return true }
        return false
    }
}

struct NativeRunFolderIndex {
    let records: [NativeRunFolderRecord]

    private let recordsByRunID: [String: NativeRunFolderRecord]
    private let recordsByDirectoryPath: [String: NativeRunFolderRecord]
    private let recordsByMetadataPath: [String: NativeRunFolderRecord]

    static let empty = NativeRunFolderIndex(records: [])
    static let defaultStaleRunningInterval: TimeInterval = 15 * 60
    private static let nativeWorkflowDirectories = [
        "native_refine",
        "native_generate"
    ]

    static func scan(
        resultsRoot: URL,
        fileManager: FileManager = .default,
        now: Date = Date(),
        staleRunningInterval: TimeInterval = defaultStaleRunningInterval
    ) -> NativeRunFolderIndex {
        let runDirectories = nativeWorkflowDirectories.flatMap { workflow -> [URL] in
            let nativeRoot = resultsRoot.appendingPathComponent(workflow, isDirectory: true)
            return (try? fileManager.contentsOfDirectory(
                at: nativeRoot,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
        }

        let records = runDirectories.compactMap { directory -> NativeRunFolderRecord? in
            guard (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
            return NativeRunFolderRecord(
                directoryURL: directory.standardizedFileURL,
                fileManager: fileManager,
                now: now,
                staleRunningInterval: staleRunningInterval
            )
        }
        return NativeRunFolderIndex(records: records)
    }

    init(records: [NativeRunFolderRecord]) {
        self.records = records.sorted { lhs, rhs in
            if lhs.modifiedAt == rhs.modifiedAt {
                return lhs.runID.localizedStandardCompare(rhs.runID) == .orderedAscending
            }
            return lhs.modifiedAt > rhs.modifiedAt
        }
        recordsByRunID = records.reduce(into: [:]) { result, record in
            result[record.runID] = record
        }
        recordsByDirectoryPath = records.reduce(into: [:]) { result, record in
            result[record.directoryURL.standardizedFileURL.path] = record
        }
        recordsByMetadataPath = records.reduce(into: [:]) { result, record in
            guard let metadataURL = record.metadataURL else { return }
            result[metadataURL.standardizedFileURL.path] = record
        }
    }

    func record(runID: String) -> NativeRunFolderRecord? {
        recordsByRunID[runID]
    }

    func record(containing url: URL, metadataURL: URL?) -> NativeRunFolderRecord? {
        if let metadataPath = metadataURL?.standardizedFileURL.path,
           let record = recordsByMetadataPath[metadataPath] {
            return record
        }

        let standardizedPath = url.standardizedFileURL.path
        return recordsByDirectoryPath
            .filter { standardizedPath.hasPrefix($0.key + "/") }
            .max { $0.key.count < $1.key.count }?
            .value
    }
}

private extension NativeRunFolderRecord {
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "webp", "heic"]
    private static let rawPayloadExtensions: Set<String> = ["bin", "txt", "json"]

    init?(
        directoryURL: URL,
        fileManager: FileManager,
        now: Date,
        staleRunningInterval: TimeInterval
    ) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let metadataURLs = contents
            .filter { $0.pathExtension.lowercased() == "json" }
            .sortedByModificationDateDescending()
        let outputMetadataURLs = metadataURLs.filter { url in
            url.lastPathComponent != "request.json" && url.lastPathComponent != "provider_request.json"
        }
        let metadataPayloads = outputMetadataURLs.compactMap { NativeRunMetadata(url: $0) }
        let primaryMetadata = metadataPayloads.first
        let requestURL = Self.existing(directoryURL.appendingPathComponent("request.json"), fileManager: fileManager)
        let requestRecord = requestURL.flatMap { NativeRunRequestRecord(url: $0) }

        let resolvedRunID = primaryMetadata?.runID.nilIfBlank
            ?? requestRecord?.runID.nilIfBlank
            ?? directoryURL.lastPathComponent
        let resolvedDirectory = primaryMetadata?.runDirectoryURL
            ?? requestRecord?.runDirectoryURL
            ?? directoryURL.standardizedFileURL
        let promptURL = primaryMetadata?.promptURL(existingWith: fileManager)
            ?? requestRecord?.promptURL(existingWith: fileManager)
            ?? Self.existing(resolvedDirectory.appendingPathComponent("prompt.txt"), fileManager: fileManager)
        let providerRequestURL = primaryMetadata?.providerRequestURL(existingWith: fileManager)
            ?? requestRecord?.providerRequestURL(existingWith: fileManager)
            ?? Self.existing(resolvedDirectory.appendingPathComponent("provider_request.json"), fileManager: fileManager)
        let eventLogURL = primaryMetadata?.logURL(existingWith: fileManager)
            ?? requestRecord?.logURL(existingWith: fileManager)
            ?? Self.existing(resolvedDirectory.appendingPathComponent("events.jsonl"), fileManager: fileManager)
        let metadataURL = primaryMetadata?.sourceURL
            ?? requestRecord?.metadataURL(existingWith: fileManager)
            ?? outputMetadataURLs.first?.standardizedFileURL
        let timelineEvents = Self.events(from: eventLogURL, fileManager: fileManager)
        let declaredOutputURL = primaryMetadata?.declaredOutputURL
            ?? requestRecord?.declaredOutputURL

        let explicitOutputs = (
            metadataPayloads.compactMap { $0.outputURL(existingWith: fileManager) }
            + [requestRecord?.outputURL(existingWith: fileManager)].compactMap { $0 }
        )
            .uniqueStandardized()
        let inferredOutputs = contents
            .filter { Self.imageExtensions.contains($0.pathExtension.lowercased()) }
            .map(\.standardizedFileURL)
            .uniqueStandardized()
        let artifactURLs = explicitOutputs.isEmpty ? inferredOutputs : explicitOutputs
        let rawResponseURLs = Self.rawResponseURLs(
            contents: contents,
            events: timelineEvents,
            fileManager: fileManager
        )
        let rawPayloadURLs = Self.rawPayloadURLs(
            contents: contents,
            events: timelineEvents,
            fileManager: fileManager
        )
        let latestContentDate = contents
            .compactMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
            .max()
        let directoryDate = (try? directoryURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        let modifiedAt = latestContentDate ?? directoryDate
        let latestProgressDate = timelineEvents
            .compactMap { Self.eventDate($0.timestamp) }
            .max() ?? modifiedAt
        let rawStatus = timelineEvents.last.map { Self.status(fromStage: $0.stage) } ?? .unknown

        runID = resolvedRunID
        self.directoryURL = resolvedDirectory
        workflow = primaryMetadata?.workflow.nilIfBlank
            ?? requestRecord?.workflow.nilIfBlank
            ?? directoryURL.deletingLastPathComponent().lastPathComponent
        model = primaryMetadata?.model.nilIfBlank
            ?? requestRecord?.model.nilIfBlank
            ?? ""
        resolution = primaryMetadata?.resolution.nilIfBlank
            ?? requestRecord?.resolution.nilIfBlank
            ?? ""
        aspectRatio = primaryMetadata?.aspectRatio.nilIfBlank
            ?? requestRecord?.aspectRatio.nilIfBlank
            ?? ""
        sourceURL = requestRecord?.sourceURL
        self.declaredOutputURL = declaredOutputURL
        status = Self.resolvedStatus(
            rawStatus,
            latestProgressDate: latestProgressDate,
            now: now,
            staleRunningInterval: staleRunningInterval
        )
        self.artifactURLs = artifactURLs
        self.rawResponseURLs = rawResponseURLs
        self.rawPayloadURLs = rawPayloadURLs
        self.events = timelineEvents
        self.modifiedAt = modifiedAt
        self.promptURL = promptURL
        self.requestURL = requestURL
        self.providerRequestURL = providerRequestURL
        self.eventLogURL = eventLogURL
        self.metadataURL = metadataURL
    }

    private static func events(from eventLogURL: URL?, fileManager: FileManager) -> [NativeRunTimelineEvent] {
        guard let eventLogURL,
              let contents = try? String(contentsOf: eventLogURL, encoding: .utf8) else {
            return []
        }

        return contents
            .split(whereSeparator: \.isNewline)
            .enumerated()
            .compactMap { offset, line -> NativeRunTimelineEvent? in
                guard let event = NativeRunEvent(jsonLine: String(line)) else { return nil }
                return event.timelineEvent(index: offset, fileManager: fileManager)
            }
    }

    static func status(fromStage stage: String) -> ArtifactRunStatus {
        let stage = stage.lowercased()

        switch stage {
        case "complete", "completed", "succeeded", "success", "saved":
            return .completed
        case "cancel", "cancelled", "canceled":
            return .cancelled
        case "timeout", "timed_out", "timedout":
            return .timedOut
        case "stalled", "hung":
            return .stalled
        case "failed", "failure", "error":
            return .failed
        case "queued", "prepared", "started", "running", "model_call", "saving", "fallback":
            return .running
        default:
            return .unknown
        }
    }

    private static func resolvedStatus(
        _ status: ArtifactRunStatus,
        latestProgressDate: Date,
        now: Date,
        staleRunningInterval: TimeInterval
    ) -> ArtifactRunStatus {
        guard status == .running,
              staleRunningInterval > 0,
              now.timeIntervalSince(latestProgressDate) >= staleRunningInterval else {
            return status
        }
        return .stalled
    }

    private static func eventDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: trimmed) {
            return date
        }

        return ISO8601DateFormatter().date(from: trimmed)
    }

    private static func rawPayloadURLs(
        contents: [URL],
        events: [NativeRunTimelineEvent],
        fileManager: FileManager
    ) -> [URL] {
        let fromEvents = events
            .compactMap(\.rawURL)
            .filter { fileManager.fileExists(atPath: $0.path) }
        let fromDirectory = contents.filter { url in
            let filename = url.lastPathComponent.lowercased()
            return rawPayloadExtensions.contains(url.pathExtension.lowercased())
                && (filename.contains("provider_raw") || filename.contains("_raw_"))
        }
        return (fromEvents + fromDirectory).uniqueStandardized()
    }

    private static func rawResponseURLs(
        contents: [URL],
        events: [NativeRunTimelineEvent],
        fileManager: FileManager
    ) -> [URL] {
        let fromEvents = events
            .compactMap(\.rawResponseURL)
            .filter { fileManager.fileExists(atPath: $0.path) }
        let fromDirectory = contents.filter { url in
            let filename = url.lastPathComponent.lowercased()
            return rawPayloadExtensions.contains(url.pathExtension.lowercased())
                && filename.contains("provider_response")
        }
        return (fromEvents + fromDirectory).uniqueStandardized()
    }

    private static func existing(_ url: URL, fileManager: FileManager) -> URL? {
        fileManager.fileExists(atPath: url.path) ? url.standardizedFileURL : nil
    }
}

private struct NativeRunMetadata {
    let sourceURL: URL
    let runID: String
    let runDirectoryPath: String
    let outputPath: String
    let promptPath: String
    let providerRequestPath: String
    let logPath: String
    let metadataPath: String
    let workflow: String
    let model: String
    let resolution: String
    let aspectRatio: String

    var runDirectoryURL: URL? {
        guard let path = runDirectoryPath.nilIfBlank else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }

    var declaredOutputURL: URL? {
        guard let path = outputPath.nilIfBlank else { return nil }
        return URL(fileURLWithPath: path).standardizedFileURL
    }

    init?(url: URL) {
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return nil
        }
        sourceURL = url.standardizedFileURL
        runID = payload.runID ?? ""
        runDirectoryPath = payload.runDirectory ?? ""
        outputPath = payload.outputPath ?? ""
        promptPath = payload.promptPath ?? ""
        providerRequestPath = payload.providerRequestPath ?? ""
        logPath = payload.logPath ?? ""
        metadataPath = payload.metadataPath ?? ""
        workflow = payload.workflow ?? ""
        model = payload.model ?? ""
        resolution = payload.resolution ?? ""
        aspectRatio = payload.aspectRatio ?? ""
    }

    func outputURL(existingWith fileManager: FileManager) -> URL? {
        existingFile(at: outputPath, fileManager: fileManager)
    }

    func promptURL(existingWith fileManager: FileManager) -> URL? {
        existingFile(at: promptPath, fileManager: fileManager)
    }

    func providerRequestURL(existingWith fileManager: FileManager) -> URL? {
        existingFile(at: providerRequestPath, fileManager: fileManager)
    }

    func logURL(existingWith fileManager: FileManager) -> URL? {
        existingFile(at: logPath, fileManager: fileManager)
    }

    func metadataURL(existingWith fileManager: FileManager) -> URL? {
        existingFile(at: metadataPath, fileManager: fileManager)
    }

    private func existingFile(at path: String, fileManager: FileManager) -> URL? {
        guard let path = path.nilIfBlank else { return nil }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    private struct Payload: Decodable {
        let runID: String?
        let runDirectory: String?
        let outputPath: String?
        let promptPath: String?
        let providerRequestPath: String?
        let logPath: String?
        let metadataPath: String?
        let workflow: String?
        let model: String?
        let resolution: String?
        let aspectRatio: String?

        enum CodingKeys: String, CodingKey {
            case runID = "run_id"
            case runDirectory = "run_dir"
            case outputPath = "output_path"
            case promptPath = "prompt_path"
            case providerRequestPath = "provider_request_path"
            case logPath = "log_path"
            case metadataPath = "metadata_path"
            case workflow
            case model
            case resolution
            case aspectRatio = "aspect_ratio"
        }
    }
}

private struct NativeRunRequestRecord {
    let sourceURL: URL?
    let runID: String
    let runDirectoryPath: String
    let outputPath: String
    let promptPath: String
    let providerRequestPath: String
    let logPath: String
    let metadataPath: String
    let workflow: String
    let model: String
    let resolution: String
    let aspectRatio: String

    var runDirectoryURL: URL? {
        guard let path = runDirectoryPath.nilIfBlank else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }

    var declaredOutputURL: URL? {
        guard let path = outputPath.nilIfBlank else { return nil }
        return URL(fileURLWithPath: path).standardizedFileURL
    }

    init?(url: URL) {
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return nil
        }
        runID = payload.runID ?? ""
        runDirectoryPath = payload.runDirectory ?? ""
        outputPath = payload.outputPath ?? ""
        promptPath = payload.promptPath ?? ""
        providerRequestPath = payload.providerRequestPath ?? ""
        logPath = payload.logPath ?? ""
        metadataPath = payload.metadataPath ?? ""
        workflow = payload.workflow ?? ""
        model = payload.model ?? ""
        resolution = payload.resolution ?? ""
        aspectRatio = payload.aspectRatio ?? ""
        if let sourceCopyPath = payload.sourceCopyPath?.nilIfBlank {
            sourceURL = URL(fileURLWithPath: sourceCopyPath).standardizedFileURL
        } else if let sourcePath = payload.sourcePath?.nilIfBlank {
            sourceURL = URL(fileURLWithPath: sourcePath).standardizedFileURL
        } else {
            sourceURL = nil
        }
    }

    func outputURL(existingWith fileManager: FileManager) -> URL? {
        existingFile(at: outputPath, fileManager: fileManager)
    }

    func promptURL(existingWith fileManager: FileManager) -> URL? {
        existingFile(at: promptPath, fileManager: fileManager)
    }

    func providerRequestURL(existingWith fileManager: FileManager) -> URL? {
        existingFile(at: providerRequestPath, fileManager: fileManager)
    }

    func logURL(existingWith fileManager: FileManager) -> URL? {
        existingFile(at: logPath, fileManager: fileManager)
    }

    func metadataURL(existingWith fileManager: FileManager) -> URL? {
        existingFile(at: metadataPath, fileManager: fileManager)
    }

    private func existingFile(at path: String, fileManager: FileManager) -> URL? {
        guard let path = path.nilIfBlank else { return nil }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    private struct Payload: Decodable {
        let runID: String?
        let runDirectory: String?
        let outputPath: String?
        let promptPath: String?
        let providerRequestPath: String?
        let logPath: String?
        let metadataPath: String?
        let workflow: String?
        let model: String?
        let resolution: String?
        let aspectRatio: String?
        let sourcePath: String?
        let sourceCopyPath: String?

        enum CodingKeys: String, CodingKey {
            case runID = "run_id"
            case runDirectory = "run_dir"
            case outputPath = "output_path"
            case promptPath = "prompt_path"
            case providerRequestPath = "provider_request_path"
            case logPath = "log_path"
            case metadataPath = "metadata_path"
            case workflow
            case model
            case resolution
            case aspectRatio = "aspect_ratio"
            case sourcePath = "source_path"
            case sourceCopyPath = "source_copy_path"
        }
    }
}

private struct NativeRunEvent {
    let stage: String
    let progress: Int?
    let message: String
    let timestamp: String
    let outputPath: String
    let metadataPath: String
    let rawResponsePath: String
    let rawPath: String

    init?(jsonLine: String) {
        guard let data = jsonLine.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        stage = (payload["stage"] as? String)
            ?? (payload["event"] as? String)
            ?? (payload["status"] as? String)
            ?? ""
        progress = payload["progress"] as? Int
        message = payload["message"] as? String ?? ""
        timestamp = payload["timestamp"] as? String
            ?? payload["created_at"] as? String
            ?? payload["updated_at"] as? String
            ?? ""
        outputPath = payload["output_path"] as? String
            ?? payload["path"] as? String
            ?? ""
        metadataPath = payload["metadata_path"] as? String
            ?? payload["native_metadata_path"] as? String
            ?? ""
        rawResponsePath = payload["raw_response_path"] as? String
            ?? payload["provider_response_path"] as? String
            ?? ""
        rawPath = payload["raw_path"] as? String
            ?? payload["raw_payload_path"] as? String
            ?? ""
    }

    func timelineEvent(index: Int, fileManager: FileManager) -> NativeRunTimelineEvent {
        NativeRunTimelineEvent(
            id: "\(index)-\(stage)-\(timestamp)",
            stage: stage,
            progress: progress,
            message: message,
            timestamp: timestamp,
            outputURL: existingFile(at: outputPath, fileManager: fileManager),
            metadataURL: existingFile(at: metadataPath, fileManager: fileManager),
            rawResponseURL: existingFile(at: rawResponsePath, fileManager: fileManager),
            rawURL: existingFile(at: rawPath, fileManager: fileManager)
        )
    }

    private func existingFile(at path: String, fileManager: FileManager) -> URL? {
        guard let path = path.nilIfBlank else { return nil }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        return fileManager.fileExists(atPath: url.path) ? url : nil
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

    func sortedByModificationDateDescending() -> [URL] {
        sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if lhsDate == rhsDate { return lhs.lastPathComponent < rhs.lastPathComponent }
            return lhsDate > rhsDate
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
