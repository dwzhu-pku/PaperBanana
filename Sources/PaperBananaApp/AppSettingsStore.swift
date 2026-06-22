import Foundation

@MainActor
final class AppSettingsStore: ObservableObject {
    private enum DefaultsKey {
        static let repoPath = "settings.repoPath"
        static let serverPort = "settings.serverPort"
        static let defaultImageModel = "settings.defaultImageModel"
        static let codexModel = "settings.codexModel"
        static let codexReasoning = "settings.codexReasoning"
    }

    @Published var repoPath: String
    @Published var serverPort: Int
    @Published var defaultImageModel: ImageModelChoice
    @Published var codexModel: String
    @Published var codexReasoning: String
    @Published private(set) var hasGoogleAPIKey: Bool
    @Published private(set) var hasOpenRouterAPIKey: Bool

    @Published var pendingGoogleAPIKey: String = ""
    @Published var pendingOpenRouterAPIKey: String = ""
    @Published private(set) var secretStoreError: String?

    private let defaults: UserDefaults
    private var cachedGoogleAPIKey: String = ""
    private var cachedOpenRouterAPIKey: String = ""
    var secretStoreURL: URL { PaperBananaSecretStore.defaultURL }

    func readinessSnapshot(requestedModel: ImageModelChoice? = nil) -> PaperBananaReadinessSnapshot {
        PaperBananaReadinessSnapshot.make(
            settings: snapshot,
            requestedModel: requestedModel ?? defaultImageModel
        )
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        repoPath = defaults.string(forKey: DefaultsKey.repoPath) ?? "/Users/jeff/Codex_projects/PaperBanana"
        let savedPort = defaults.integer(forKey: DefaultsKey.serverPort)
        serverPort = savedPort > 0 ? savedPort : 7860
        let savedModel = defaults.string(forKey: DefaultsKey.defaultImageModel) ?? ImageModelChoice.nanoBanana2.rawValue
        defaultImageModel = ImageModelChoice(rawValue: savedModel) ?? .nanoBanana2
        codexModel = defaults.string(forKey: DefaultsKey.codexModel) ?? "gpt-5.5"
        codexReasoning = defaults.string(forKey: DefaultsKey.codexReasoning) ?? "xhigh"
        hasGoogleAPIKey = false
        hasOpenRouterAPIKey = false
        refreshSecretStatus()
    }

    var snapshot: PaperBananaSettingsSnapshot {
        PaperBananaSettingsSnapshot(
            repoPath: repoPath,
            serverPort: max(serverPort, 1),
            defaultImageModel: defaultImageModel,
            codexModel: codexModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "gpt-5.5" : codexModel,
            codexReasoning: codexReasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "xhigh" : codexReasoning,
            googleAPIKey: cachedGoogleAPIKey,
            openRouterAPIKey: cachedOpenRouterAPIKey
        )
    }

    func persistNonSecretSettings() {
        defaults.set(repoPath, forKey: DefaultsKey.repoPath)
        defaults.set(max(serverPort, 1), forKey: DefaultsKey.serverPort)
        defaults.set(defaultImageModel.rawValue, forKey: DefaultsKey.defaultImageModel)
        defaults.set(codexModel, forKey: DefaultsKey.codexModel)
        defaults.set(codexReasoning, forKey: DefaultsKey.codexReasoning)
    }

    func saveGoogleAPIKey() {
        let trimmed = pendingGoogleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        cachedGoogleAPIKey = trimmed
        persistSecrets()
        pendingGoogleAPIKey = ""
    }

    func clearGoogleAPIKey() {
        pendingGoogleAPIKey = ""
        cachedGoogleAPIKey = ""
        persistSecrets()
    }

    func saveOpenRouterAPIKey() {
        let trimmed = pendingOpenRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        cachedOpenRouterAPIKey = trimmed
        persistSecrets()
        pendingOpenRouterAPIKey = ""
    }

    func clearOpenRouterAPIKey() {
        pendingOpenRouterAPIKey = ""
        cachedOpenRouterAPIKey = ""
        persistSecrets()
    }

    func refreshSecretStatus() {
        do {
            let secrets = try PaperBananaSecretStore.load()
            cachedGoogleAPIKey = secrets.googleAPIKey
            cachedOpenRouterAPIKey = secrets.openRouterAPIKey
            hasGoogleAPIKey = !secrets.googleAPIKey.isEmpty
            hasOpenRouterAPIKey = !secrets.openRouterAPIKey.isEmpty
            secretStoreError = nil
        } catch {
            cachedGoogleAPIKey = ""
            cachedOpenRouterAPIKey = ""
            hasGoogleAPIKey = false
            hasOpenRouterAPIKey = false
            secretStoreError = error.localizedDescription
        }
    }

    private func persistSecrets() {
        let secrets = PaperBananaSecrets(
            googleAPIKey: cachedGoogleAPIKey,
            openRouterAPIKey: cachedOpenRouterAPIKey
        )

        do {
            try PaperBananaSecretStore.save(secrets)
            hasGoogleAPIKey = !cachedGoogleAPIKey.isEmpty
            hasOpenRouterAPIKey = !cachedOpenRouterAPIKey.isEmpty
            secretStoreError = nil
        } catch {
            secretStoreError = error.localizedDescription
        }
    }
}
