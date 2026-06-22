import Foundation

enum ProviderRunStatus: String, CaseIterable, Identifiable {
    case running
    case succeeded
    case failed
    case cancelled
    case timedOut
    case missingArtifact
    case rawRecovered

    var id: String { rawValue }

    var label: String {
        switch self {
        case .running: "Running"
        case .succeeded: "Succeeded"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        case .timedOut: "Timed out"
        case .missingArtifact: "Missing artifact"
        case .rawRecovered: "Raw recovered"
        }
    }

    var systemImage: String {
        switch self {
        case .running: "clock"
        case .succeeded: "checkmark.circle"
        case .failed: "xmark.octagon"
        case .cancelled: "xmark.circle"
        case .timedOut: "timer"
        case .missingArtifact: "exclamationmark.triangle"
        case .rawRecovered: "shippingbox"
        }
    }
}

struct ProviderRunLedgerCall: Identifiable, Hashable {
    let callID: String
    let runID: String
    let provider: String
    let model: String
    let modality: String
    let context: String
    let status: ProviderRunStatus
    let startedAt: Date?
    let updatedAt: Date?
    let attempt: Int?
    let maxAttempts: Int?
    let responseCount: Int
    let message: String
    let error: String
    let usageMetadata: [String: String]
    let artifactURLs: [URL]
    let rawArtifactURLs: [URL]
    let runDirectoryURL: URL?
    let nativeArtifactURLs: [URL]
    let nativePromptURL: URL?
    let nativeRequestURL: URL?
    let nativeProviderRequestURL: URL?
    let nativeEventLogURL: URL?
    let auditLogURL: URL?

    var id: String { callID }

    var needsAttention: Bool {
        status == .failed
            || status == .cancelled
            || status == .timedOut
            || status == .missingArtifact
            || status == .rawRecovered
    }

    var allArtifactURLs: [URL] {
        artifactURLs + nativeArtifactURLs + rawArtifactURLs
    }

    var recoveryCandidateURLs: [URL] {
        if status == .rawRecovered {
            return rawArtifactURLs.uniqueStandardized()
        }
        guard needsAttention else { return [] }
        return (artifactURLs + rawArtifactURLs).uniqueStandardized()
    }

    var displayDate: String {
        guard let date = updatedAt ?? startedAt else { return "Unknown" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    var shortModel: String {
        Self.shortModelLabel(for: model)
    }

    var usageSummary: String {
        guard usageMetadata.isEmpty == false else { return "No usage metadata" }
        return usageMetadata
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")
    }

    var searchablePathText: String {
        let urls = artifactURLs
            + nativeArtifactURLs
            + rawArtifactURLs
            + [
                runDirectoryURL,
                nativePromptURL,
                nativeRequestURL,
                nativeProviderRequestURL,
                nativeEventLogURL,
                auditLogURL
            ].compactMap { $0 }
        return urls
            .map(\.standardizedFileURL.path)
            .joined(separator: "\n")
    }

    static func shortModelLabel(for model: String) -> String {
        switch model {
        case "gemini-3.1-flash-image-preview": "Nano Banana 2"
        case "gemini-3-pro-image-preview": "Nano Banana Pro"
        case "__codex_gpt55_xhigh__": "Codex fallback"
        default: model
        }
    }
}

enum ProviderRunLedgerFilter: String, AppFilterOption {
    case all
    case attention
    case failed
    case missingArtifacts
    case rawRecovered
    case lastHour

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All"
        case .attention: "Needs Attention"
        case .failed: "Failed"
        case .missingArtifacts: "Missing Artifacts"
        case .rawRecovered: "Raw Recovered"
        case .lastHour: "Last Hour"
        }
    }
}

struct NativeRunCockpitItem: Identifiable, Hashable {
    let run: NativeRunFolderRecord
    let providerCalls: [ProviderRunLedgerCall]

    var id: String { run.directoryURL.standardizedFileURL.path }

    var title: String {
        run.runID.isEmpty ? run.directoryURL.lastPathComponent : run.runID
    }

    var needsAttention: Bool {
        run.needsAttention || providerCalls.contains(where: \.needsAttention)
    }

    var status: ArtifactRunStatus {
        run.status
    }

    var workflow: String {
        run.workflow.nilIfBlank
            ?? providerCalls.first?.context.nilIfBlank
            ?? run.directoryURL.deletingLastPathComponent().lastPathComponent
    }

    var model: String {
        run.model.nilIfBlank
            ?? providerCalls.first?.model.nilIfBlank
            ?? ""
    }

    var modelLabel: String {
        guard let model = model.nilIfBlank else { return "Unknown model" }
        return ImageModelChoice(rawValue: model)?.label ?? ProviderRunLedgerCall.shortModelLabel(for: model)
    }

    var resolution: String {
        run.resolution.nilIfBlank ?? "Unknown"
    }

    var aspectRatio: String {
        run.aspectRatio.nilIfBlank ?? "Unknown"
    }

    var currentStage: String {
        run.events.last?.stage.nilIfBlank ?? run.status.rawValue
    }

    var elapsedSeconds: TimeInterval? {
        if let nativeElapsedSeconds = Self.elapsedSeconds(from: run.events) {
            return nativeElapsedSeconds
        }

        let providerDates = providerCalls.flatMap { call in
            [call.startedAt, call.updatedAt].compactMap { $0 }
        }
        guard let firstDate = providerDates.min(),
              let lastDate = providerDates.max(),
              lastDate >= firstDate else {
            return nil
        }
        return lastDate.timeIntervalSince(firstDate)
    }

    var elapsedTimeText: String {
        guard let elapsedSeconds else { return "Unknown" }
        return Self.formatElapsedTime(elapsedSeconds)
    }

    var outputURLs: [URL] {
        let declared = [run.declaredOutputURL].compactMap { $0 }
        return (run.artifactURLs + declared + providerCalls.flatMap(\.nativeArtifactURLs)).uniqueStandardized()
    }

    var rawResponseURLs: [URL] {
        run.rawResponseURLs.uniqueStandardized()
    }

    var rawPayloadURLs: [URL] {
        (run.rawPayloadURLs + providerCalls.flatMap(\.rawArtifactURLs)).uniqueStandardized()
    }

    var recoverableURLs: [URL] {
        let nativeRecoverable = (run.rawPayloadURLs + run.rawResponseURLs).uniqueStandardized()
        if nativeRecoverable.isEmpty == false {
            return nativeRecoverable
        }
        return providerCalls.flatMap(\.recoveryCandidateURLs).uniqueStandardized()
    }

    var providerCallIDs: [String] {
        providerCalls.map(\.callID).filter { $0.isEmpty == false }
    }

    var providerCallSummary: String {
        providerCallIDs.isEmpty ? "No provider call linked" : providerCallIDs.joined(separator: ", ")
    }

    var promptURL: URL? {
        run.promptURL
    }

    var requestURL: URL? {
        run.requestURL
    }

    var providerRequestURL: URL? {
        run.providerRequestURL
    }

    var eventLogURL: URL? {
        run.eventLogURL
    }

    var metadataURL: URL? {
        run.metadataURL
    }

    var hasDurableSpendTrace: Bool {
        run.promptURL != nil && run.requestURL != nil && run.providerRequestURL != nil && run.eventLogURL != nil
    }

    var providerSummary: String {
        let models = providerCalls.map(\.shortModel).filter { $0.isEmpty == false }
        return Array(NSOrderedSet(array: models)).compactMap { $0 as? String }.joined(separator: ", ").nilIfBlank
            ?? "No provider call linked"
    }

    private static func elapsedSeconds(from events: [NativeRunTimelineEvent]) -> TimeInterval? {
        let dates = events.compactMap { parseTimestamp($0.timestamp) }
        guard let firstDate = dates.min(),
              let lastDate = dates.max(),
              lastDate >= firstDate else {
            return nil
        }
        return lastDate.timeIntervalSince(firstDate)
    }

    private static func parseTimestamp(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: trimmed) {
            return date
        }

        return ISO8601DateFormatter().date(from: trimmed)
    }

    private static func formatElapsedTime(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        }
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

typealias RunDetailsItem = NativeRunCockpitItem

enum RunDetailsFilter: String, AppFilterOption {
    case all
    case attention
    case running
    case failed
    case completed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All"
        case .attention: "Needs Attention"
        case .running: "Running"
        case .failed: "Failed"
        case .completed: "Completed"
        }
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
