import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

enum PaperBananaSpotlightIndexer {
    static let artifactDomain = "local.paperbanana.artifacts"
    static let runDomain = "local.paperbanana.runs"
    static let providerCallDomain = "local.paperbanana.provider-calls"

    static func index(
        artifacts: [PaperBananaArtifact],
        runs: [NativeRunCockpitItem],
        providerCalls: [ProviderRunLedgerCall] = []
    ) {
        let items = searchableItems(
            artifacts: artifacts,
            runs: runs,
            providerCalls: providerCalls
        )
        guard items.isEmpty == false else { return }
        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }

    static func searchableItems(
        artifacts: [PaperBananaArtifact],
        runs: [NativeRunCockpitItem],
        providerCalls: [ProviderRunLedgerCall] = []
    ) -> [CSSearchableItem] {
        artifacts.map(artifactItem) + runs.map(runItem) + providerCalls.map(providerCallItem)
    }

    private static func artifactItem(_ artifact: PaperBananaArtifact) -> CSSearchableItem {
        let contentType = contentTypeIdentifier(for: artifact)
        let attributes = CSSearchableItemAttributeSet(contentType: contentType)
        attributes.title = artifact.title
        attributes.displayName = artifact.url.lastPathComponent
        attributes.contentDescription = [
            "PaperBanana artifact",
            "Project: PaperBanana",
            "Workflow: \(artifact.workflow)",
            "Run: \(artifact.runID.nilIfBlank ?? "unknown")",
            "Modified: \(artifact.modifiedAt.formatted(date: .abbreviated, time: .shortened))",
            "Path: \(artifact.relativePath)"
        ].joined(separator: "\n")
        attributes.keywords = [
            "PaperBanana",
            "PaperBanana artifact",
            artifact.kind.label,
            artifact.workflow,
            artifact.runID,
            artifact.relativePath,
            artifact.runStatus?.label ?? "",
            artifact.modifiedAt.formatted(date: .numeric, time: .omitted)
        ].filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        attributes.contentModificationDate = artifact.modifiedAt
        attributes.contentURL = artifact.url
        if artifact.kind == .image {
            attributes.thumbnailURL = artifact.url
        }

        return CSSearchableItem(
            uniqueIdentifier: "artifact:\(artifact.url.standardizedFileURL.path)",
            domainIdentifier: artifactDomain,
            attributeSet: attributes
        )
    }

    private static func runItem(_ run: NativeRunCockpitItem) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: UTType.data)
        attributes.title = run.title
        attributes.displayName = run.title
        attributes.contentDescription = [
            "PaperBanana native run",
            "Project: PaperBanana",
            "Workflow: \(run.workflow)",
            "Model: \(run.modelLabel)",
            "Status: \(run.status.label)",
            "Stage: \(run.currentStage)",
            "Resolution: \(run.resolution)",
            "Aspect Ratio: \(run.aspectRatio)",
            "Provider: \(run.providerSummary)",
            "Provider Call IDs: \(run.providerCallIDs.joined(separator: ", ").nilIfBlank ?? "none")",
            "Elapsed: \(run.elapsedTimeText)",
            "Prompt: \(promptPreview(for: run.promptURL) ?? "none")",
            "Output: \(run.outputURLs.first?.path ?? "none")"
        ].joined(separator: "\n")
        attributes.keywords = [
            "PaperBanana",
            "Native Run",
            "PaperBanana run",
            run.workflow,
            run.modelLabel,
            run.status.label,
            run.currentStage,
            run.resolution,
            run.aspectRatio,
            run.providerSummary,
            run.providerCallIDs.joined(separator: " "),
            promptPreview(for: run.promptURL) ?? ""
        ].filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        attributes.contentModificationDate = run.run.modifiedAt
        attributes.contentURL = run.run.directoryURL
        attributes.relatedUniqueIdentifier = run.run.runID

        return CSSearchableItem(
            uniqueIdentifier: "run:\(run.id)",
            domainIdentifier: runDomain,
            attributeSet: attributes
        )
    }

    private static func providerCallItem(_ call: ProviderRunLedgerCall) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: UTType.data)
        attributes.title = call.callID
        attributes.displayName = call.callID
        attributes.contentDescription = [
            "PaperBanana provider call",
            "Project: PaperBanana",
            "Run: \(call.runID.nilIfBlank ?? "unknown")",
            "Provider: \(call.provider)",
            "Model: \(ProviderRunLedgerCall.shortModelLabel(for: call.model))",
            "Backend Model: \(call.model)",
            "Status: \(call.status.label)",
            "Context: \(call.context)",
            "Usage: \(call.usageSummary)",
            "Recovery Candidates: \(call.recoveryCandidateURLs.count)",
            "Provider Request: \(call.nativeProviderRequestURL?.path ?? "none")",
            "Artifacts: \(pathList(call.artifactURLs + call.nativeArtifactURLs))",
            "Raw Artifacts: \(pathList(call.rawArtifactURLs))",
            "Audit Log: \(call.auditLogURL?.path ?? "none")"
        ].joined(separator: "\n")
        attributes.keywords = [
            "PaperBanana",
            "PaperBanana provider call",
            call.callID,
            call.runID,
            call.provider,
            call.model,
            ProviderRunLedgerCall.shortModelLabel(for: call.model),
            call.status.label,
            call.status.rawValue,
            call.context,
            call.usageSummary,
            call.nativeProviderRequestURL?.lastPathComponent ?? "",
            call.auditLogURL?.lastPathComponent ?? "",
            call.needsAttention ? "needs attention" : "",
            call.recoveryCandidateURLs.isEmpty ? "" : "recoverable",
            pathList(call.artifactURLs + call.nativeArtifactURLs + call.rawArtifactURLs)
        ].filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        attributes.contentModificationDate = call.updatedAt ?? call.startedAt
        attributes.contentURL = call.nativeArtifactURLs.first
            ?? call.artifactURLs.first
            ?? call.rawArtifactURLs.first
            ?? call.nativeProviderRequestURL
            ?? call.runDirectoryURL
        attributes.relatedUniqueIdentifier = call.runID

        return CSSearchableItem(
            uniqueIdentifier: "provider-call:\(call.callID)",
            domainIdentifier: providerCallDomain,
            attributeSet: attributes
        )
    }

    private static func contentTypeIdentifier(for artifact: PaperBananaArtifact) -> UTType {
        switch artifact.kind {
        case .image:
            return .image
        case .archive:
            return .archive
        case .data:
            return .data
        case .document:
            return .content
        }
    }

    private static func promptPreview(for url: URL?) -> String? {
        guard let url,
              let value = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        let normalized = value
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
        guard normalized.isEmpty == false else { return nil }
        return String(normalized.prefix(240))
    }

    private static func pathList(_ urls: [URL]) -> String {
        let paths = urls
            .map(\.standardizedFileURL.path)
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        return paths.isEmpty ? "none" : paths.joined(separator: "\n")
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
