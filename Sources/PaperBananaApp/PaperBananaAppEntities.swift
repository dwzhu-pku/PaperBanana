import AppIntents
import AppKit
import Foundation

struct RunEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "PaperBanana Run"
    static let defaultQuery = RunEntityQuery()

    let id: String
    let title: String
    let workflow: String
    let status: String
    let provider: String
    let model: String
    let resolution: String
    let artifactPath: String
    let providerRequestPath: String
    let rawResponsePath: String
    let updatedAt: String

    var displayRepresentation: DisplayRepresentation {
        let details = [status, ProviderRunLedgerCall.shortModelLabel(for: model), resolution, provider]
            .compactMap { $0.appIntentNilIfBlank }
            .joined(separator: " • ")
        return DisplayRepresentation(title: "\(title)", subtitle: "\(details)")
    }

    init(record: RunRecord) {
        id = record.id
        title = record.id
        workflow = record.workflow
        status = record.status.rawValue
        provider = record.provider
        model = record.model
        resolution = record.resolution
        artifactPath = record.artifactPath
        providerRequestPath = record.providerRequestPath
        rawResponsePath = record.rawResponsePath.appIntentNilIfBlank ?? record.rawPayloadPath
        updatedAt = record.updatedAt
    }
}

struct RunEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [RunEntity.ID]) async throws -> [RunEntity] {
        let ids = Set(identifiers)
        return try Self.allRuns(limit: max(identifiers.count, 1_000)).filter { ids.contains($0.id) }
    }

    func suggestedEntities() async throws -> [RunEntity] {
        try Self.allRuns(limit: 25)
    }

    func entities(matching string: String) async throws -> [RunEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard needle.isEmpty == false else {
            return try Self.allRuns(limit: 25)
        }
        return try Self.allRuns(limit: 250).filter { entity in
            [
                entity.id,
                entity.workflow,
                entity.status,
                entity.provider,
                entity.model,
                entity.resolution,
                entity.artifactPath,
                entity.providerRequestPath,
                entity.rawResponsePath
            ]
            .contains { $0.lowercased().contains(needle) }
        }
    }

    static func allRuns(limit: Int) throws -> [RunEntity] {
        try PaperBananaRunStore
            .fetchRunsSynchronously(repoRoot: PaperBananaRepoLocator.repoRootURL, limit: limit)
            .map(RunEntity.init(record:))
    }
}

struct ArtifactEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "PaperBanana Artifact"
    static let defaultQuery = ArtifactEntityQuery()

    let id: String
    let title: String
    let kind: String
    let workflow: String
    let relativePath: String
    let status: String
    let modelHint: String
    let modifiedAt: String

    var displayRepresentation: DisplayRepresentation {
        let details = [kind, workflow, status, modelHint]
            .compactMap { $0.appIntentNilIfBlank }
            .joined(separator: " • ")
        return DisplayRepresentation(title: "\(title)", subtitle: "\(details)")
    }

    init(artifact: PaperBananaArtifact) {
        id = artifact.id
        title = artifact.title
        kind = artifact.kind.label
        workflow = artifact.workflow
        relativePath = artifact.relativePath
        status = artifact.runStatus?.rawValue ?? ""
        modelHint = artifact.refinementLineage?.modelLabel ?? ""
        modifiedAt = artifact.modifiedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var url: URL {
        URL(fileURLWithPath: id)
    }
}

struct ArtifactEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [ArtifactEntity.ID]) async throws -> [ArtifactEntity] {
        let ids = Set(identifiers)
        return Self.allArtifacts(limit: 1_000).filter { ids.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ArtifactEntity] {
        Self.allArtifacts(limit: 25)
    }

    func entities(matching string: String) async throws -> [ArtifactEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard needle.isEmpty == false else {
            return Self.allArtifacts(limit: 25)
        }
        return Self.allArtifacts(limit: 250).filter { entity in
            [
                entity.title,
                entity.kind,
                entity.workflow,
                entity.relativePath,
                entity.status,
                entity.modelHint
            ]
            .contains { $0.lowercased().contains(needle) }
        }
    }

    static func allArtifacts(limit: Int) -> [ArtifactEntity] {
        Array(
            ArtifactLibraryScanner
                .scan(repoRootPath: PaperBananaRepoLocator.repoRootPath)
                .prefix(max(1, limit))
        )
        .map(ArtifactEntity.init(artifact:))
    }
}

struct ProviderCallEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "PaperBanana Provider Call"
    static let defaultQuery = ProviderCallEntityQuery()

    let id: String
    let runID: String
    let provider: String
    let model: String
    let status: String
    let message: String
    let updatedAt: String
    let usageSummary: String
    let providerRequestPath: String
    let artifactPaths: String
    let rawArtifactPaths: String
    let nativeArtifactPaths: String
    let auditLogPath: String
    let hasRecoverableArtifact: Bool

    var displayRepresentation: DisplayRepresentation {
        let usage = usageSummary == "No usage metadata" ? nil : usageSummary
        let details = [
            status.appIntentNilIfBlank,
            ProviderRunLedgerCall.shortModelLabel(for: model).appIntentNilIfBlank,
            provider.appIntentNilIfBlank,
            runID.appIntentNilIfBlank,
            usage
        ]
            .compactMap { $0 }
            .joined(separator: " • ")
        return DisplayRepresentation(title: "\(id)", subtitle: "\(details)")
    }

    init(call: ProviderRunLedgerCall) {
        id = call.callID
        runID = call.runID
        provider = call.provider
        model = call.model
        status = call.status.rawValue
        message = call.message.appIntentNilIfBlank ?? call.error
        updatedAt = (call.updatedAt ?? call.startedAt)?.formatted(date: .abbreviated, time: .shortened) ?? ""
        usageSummary = call.usageSummary
        providerRequestPath = call.nativeProviderRequestURL?.path ?? ""
        artifactPaths = call.artifactURLs.map(\.standardizedFileURL.path).joined(separator: "\n")
        rawArtifactPaths = call.rawArtifactURLs.map(\.standardizedFileURL.path).joined(separator: "\n")
        nativeArtifactPaths = call.nativeArtifactURLs.map(\.standardizedFileURL.path).joined(separator: "\n")
        auditLogPath = call.auditLogURL?.standardizedFileURL.path ?? ""
        hasRecoverableArtifact = call.recoveryCandidateURLs.isEmpty == false
    }
}

struct ProviderCallEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [ProviderCallEntity.ID]) async throws -> [ProviderCallEntity] {
        let ids = Set(identifiers)
        return Self.allProviderCalls(limit: 1_000).filter { ids.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ProviderCallEntity] {
        Self.allProviderCalls(limit: 25)
    }

    func entities(matching string: String) async throws -> [ProviderCallEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard needle.isEmpty == false else {
            return Self.allProviderCalls(limit: 25)
        }
        return Self.allProviderCalls(limit: 250).filter { entity in
            [
                entity.id,
                entity.runID,
                entity.provider,
                entity.model,
                ProviderRunLedgerCall.shortModelLabel(for: entity.model),
                entity.status,
                entity.message,
                entity.usageSummary,
                entity.providerRequestPath,
                entity.artifactPaths,
                entity.rawArtifactPaths,
                entity.nativeArtifactPaths,
                entity.auditLogPath
            ]
            .contains { $0.lowercased().contains(needle) }
        }
    }

    static func allProviderCalls(limit: Int) -> [ProviderCallEntity] {
        Array(
            ProviderRunLedgerScanner
                .scan(repoRootPath: PaperBananaRepoLocator.repoRootPath)
                .prefix(max(1, limit))
        )
        .map(ProviderCallEntity.init(call:))
    }
}

struct OpenPaperBananaRunIntent: AppIntent {
    static let title: LocalizedStringResource = "Open PaperBanana Run"
    static let description = IntentDescription("Open PaperBanana to inspect a specific run.")
    static let openAppWhenRun = true

    @Parameter(title: "Run")
    var run: RunEntity

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(run.id, forKey: "paperbanana.intent.runID")
        PaperBananaIntentBridge.request(.runDetails)
        return .result()
    }
}

struct OpenPaperBananaArtifactIntent: AppIntent {
    static let title: LocalizedStringResource = "Open PaperBanana Artifact"
    static let description = IntentDescription("Open a selected PaperBanana artifact.")
    static let openAppWhenRun = true

    @Parameter(title: "Artifact")
    var artifact: ArtifactEntity

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            PaperBananaShortcutActions.openURLForUserIfAppropriate(artifact.url)
        }
        UserDefaults.standard.set(artifact.id, forKey: "paperbanana.intent.artifactPath")
        PaperBananaIntentBridge.request(.recoveredImages)
        return .result()
    }
}

struct RecoverPaperBananaProviderCallIntent: AppIntent {
    static let title: LocalizedStringResource = "Recover PaperBanana Provider Call"
    static let description = IntentDescription("Recover raw provider output for a selected PaperBanana provider call.")
    static let openAppWhenRun = true

    @Parameter(title: "Provider Call")
    var providerCall: ProviderCallEntity

    func perform() async throws -> some IntentResult {
        _ = await MainActor.run {
            PaperBananaShortcutActions.recoverProviderArtifact(callID: providerCall.id)
        }
        UserDefaults.standard.set(providerCall.id, forKey: "paperbanana.intent.providerCallID")
        PaperBananaIntentBridge.request(.runDetails)
        return .result()
    }
}

struct SearchPaperBananaRunsAndArtifactsIntent: AppIntent {
    static let title: LocalizedStringResource = "Search PaperBanana Runs and Artifacts"
    static let description = IntentDescription("Open PaperBanana with a run or artifact search query.")
    static let openAppWhenRun = true

    @Parameter(title: "Search Query")
    var query: String

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(query, forKey: "paperbanana.intent.search")
        PaperBananaIntentBridge.request(.runDetails)
        return .result()
    }
}

private extension String {
    var appIntentNilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
