import Foundation

extension PaperBananaRunStore {
    nonisolated static let defaultStaleRunRecoveryInterval: TimeInterval = 15 * 60

    @discardableResult
    nonisolated static func recoverStaleNonTerminalRunsSynchronously(
        repoRoot: URL,
        now: Date = Date(),
        staleAfter: TimeInterval = defaultStaleRunRecoveryInterval
    ) throws -> [RunRecord] {
        guard staleAfter > 0 else { return [] }

        let candidates = try fetchRunsSynchronously(
            repoRoot: repoRoot,
            limit: 1_000,
            statuses: [.queued, .running]
        )
        let staleRuns = candidates.filter { run in
            guard let updatedAt = date(fromTimestamp: run.updatedAt) else { return false }
            return now.timeIntervalSince(updatedAt) >= staleAfter
        }

        var recovered: [RunRecord] = []
        let recoveryTimestamp = timestamp(from: now)
        for run in staleRuns {
            let staleSeconds = max(0, now.timeIntervalSince(date(fromTimestamp: run.updatedAt) ?? now))
            let message = "Run was still \(run.status.rawValue) after app relaunch with no progress for \(formatDuration(staleSeconds)); marked timed out to keep provider spend visible."

            if run.providerCallID.isEmpty == false,
               let providerCall = try fetchProviderCallSynchronously(callID: run.providerCallID, repoRoot: repoRoot),
               providerCall.status == ProviderRunStatus.running.rawValue {
                try writeProviderCallTerminalSynchronously(
                    runID: run.id,
                    callID: providerCall.callID,
                    provider: providerCall.provider,
                    model: providerCall.model,
                    modality: providerCall.modality,
                    context: providerCall.context,
                    status: .timedOut,
                    message: message,
                    repoRoot: repoRoot
                )
            }

            let event = PaperBananaRunEvent(
                runID: run.id,
                stage: "timeout",
                progress: 100,
                message: message,
                timestamp: recoveryTimestamp,
                rawResponsePath: run.rawResponsePath,
                rawPayloadPath: run.rawPayloadPath,
                artifactPath: run.artifactPath,
                metadataPath: run.metadataPath,
                providerCallID: run.providerCallID
            )
            try writeEventSynchronously(event, repoRoot: repoRoot)

            if let updatedRun = try fetchRunSynchronously(id: run.id, repoRoot: repoRoot) {
                recovered.append(updatedRun)
            }
        }
        return recovered
    }

    nonisolated static func timestamp(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    nonisolated static func date(fromTimestamp timestamp: String) -> Date? {
        let trimmed = timestamp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: trimmed) {
            return date
        }

        return ISO8601DateFormatter().date(from: trimmed)
    }

    private nonisolated static func formatDuration(_ seconds: TimeInterval) -> String {
        let roundedSeconds = max(0, Int(seconds.rounded()))
        if roundedSeconds < 60 {
            return "\(roundedSeconds)s"
        }
        let minutes = roundedSeconds / 60
        let remainingSeconds = roundedSeconds % 60
        if minutes < 60 {
            return "\(minutes)m \(remainingSeconds)s"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}
