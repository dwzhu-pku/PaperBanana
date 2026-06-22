import Foundation
import Vision

#if canImport(FoundationModels)
import FoundationModels
#endif

enum ImageModelChoice: String, CaseIterable, Identifiable, Sendable {
    case nanoBanana2 = "gemini-3.1-flash-image-preview"
    case nanoBananaPro = "gemini-3-pro-image-preview"
    case nanoBanana = "gemini-2.5-flash-image"
    case codexFallback = "__codex_gpt55_xhigh__"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nanoBanana2: "Nano Banana 2"
        case .nanoBananaPro: "Nano Banana Pro"
        case .nanoBanana: "Nano Banana"
        case .codexFallback: "Codex fallback"
        }
    }

    var backendValue: String { rawValue }

    func resolvedForAvailableCredentials(settings: PaperBananaSettingsSnapshot) -> ImageModelChoice {
        ImageProviderExecutionPlan(requestedModel: self, settings: settings).effectiveModel
    }

    func usesPaidProvider(settings: PaperBananaSettingsSnapshot) -> Bool {
        ImageProviderExecutionPlan(requestedModel: self, settings: settings).canSpendProviderCredits
    }

    func providerLabel(settings: PaperBananaSettingsSnapshot) -> String {
        ImageProviderExecutionPlan(requestedModel: self, settings: settings).providerLabel
    }
}

enum ImageProviderKind: String, Equatable, Sendable {
    case googleGemini = "google_gemini"
    case openRouter = "openrouter"
    case codexFallback = "codex_fallback"
    case foundationModels = "foundation_models"

    var label: String {
        switch self {
        case .googleGemini: "Google Gemini"
        case .openRouter: "OpenRouter"
        case .codexFallback: "Codex"
        case .foundationModels: "Foundation Models"
        }
    }
}

enum ImageProviderCredentialSource: String, Equatable, Sendable {
    case googleAPIKey = "google_api_key"
    case openRouterAPIKey = "openrouter_api_key"
    case codexApp = "codex_app"
    case localSystem = "local_system"

    var label: String {
        switch self {
        case .googleAPIKey: "Google API key"
        case .openRouterAPIKey: "OpenRouter API key"
        case .codexApp: "Codex app handoff"
        case .localSystem: "Local system"
        }
    }
}

struct ImageProviderExecutionPlan: Equatable, Sendable {
    let requestedModel: ImageModelChoice
    let effectiveModel: ImageModelChoice
    let provider: ImageProviderKind
    let credentialSource: ImageProviderCredentialSource
    let canSpendProviderCredits: Bool

    init(requestedModel: ImageModelChoice, settings: PaperBananaSettingsSnapshot) {
        self.requestedModel = requestedModel
        let googleKeyAvailable = settings.googleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let openRouterKeyAvailable = settings.openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false

        if requestedModel == .codexFallback {
            effectiveModel = .codexFallback
            provider = .codexFallback
            credentialSource = .codexApp
            canSpendProviderCredits = false
        } else if googleKeyAvailable {
            effectiveModel = requestedModel
            provider = .googleGemini
            credentialSource = .googleAPIKey
            canSpendProviderCredits = true
        } else if openRouterKeyAvailable {
            effectiveModel = requestedModel
            provider = .openRouter
            credentialSource = .openRouterAPIKey
            canSpendProviderCredits = true
        } else {
            effectiveModel = .codexFallback
            provider = .codexFallback
            credentialSource = .codexApp
            canSpendProviderCredits = false
        }
    }

    var providerLabel: String {
        provider.label
    }

    var modelLabel: String {
        effectiveModel.label
    }

    var backendModelValue: String {
        effectiveModel.backendValue
    }

    var spendClass: String {
        canSpendProviderCredits ? "paid_provider" : "codex_fallback"
    }

    var spendSafetyLabel: String {
        canSpendProviderCredits ? "Can spend provider credits" : "No provider API spend"
    }

    var credentialSourceLabel: String {
        credentialSource.label
    }

    var durableRequestFields: [String: Any] {
        [
            "model": effectiveModel.backendValue,
            "requested_model": requestedModel.backendValue,
            "provider": providerLabel,
            "provider_kind": provider.rawValue,
            "credential_source": credentialSource.rawValue,
            "credential_source_label": credentialSourceLabel,
            "spend_class": spendClass,
            "can_spend_provider_credits": canSpendProviderCredits
        ]
    }

    func applyEnvironment(settings: PaperBananaSettingsSnapshot, to environment: inout [String: String]) {
        environment["PAPERBANANA_CODEX_IMAGE_HANDOFF"] = "1"
        environment["PAPERBANANA_CODEX_MODEL"] = settings.codexModel
        environment["PAPERBANANA_CODEX_REASONING_EFFORT"] = settings.codexReasoning
        environment["PAPERBANANA_IMAGE_PROVIDER_KIND"] = provider.rawValue
        environment["PAPERBANANA_REQUESTED_IMAGE_MODEL"] = requestedModel.backendValue
        environment["PAPERBANANA_EFFECTIVE_IMAGE_MODEL"] = effectiveModel.backendValue
        environment["PAPERBANANA_CAN_SPEND_PROVIDER_CREDITS"] = canSpendProviderCredits ? "1" : "0"

        switch credentialSource {
        case .googleAPIKey:
            environment["GOOGLE_API_KEY"] = settings.googleAPIKey
        case .openRouterAPIKey:
            environment["OPENROUTER_API_KEY"] = settings.openRouterAPIKey
        case .codexApp, .localSystem:
            break
        }
    }
}

enum DiagnosticSeverity: String {
    case ok = "OK"
    case warning = "Warning"
    case failure = "Failure"

    var sortOrder: Int {
        switch self {
        case .failure: 0
        case .warning: 1
        case .ok: 2
        }
    }
}

struct DiagnosticItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String
    let severity: DiagnosticSeverity
}

struct PaperBananaSettingsSnapshot: Equatable, Sendable {
    let repoPath: String
    let serverPort: Int
    let defaultImageModel: ImageModelChoice
    let codexModel: String
    let codexReasoning: String
    let googleAPIKey: String
    let openRouterAPIKey: String
}

enum PaperBananaReadinessSeverity: String, Equatable, Sendable {
    case ready
    case warning
    case blocked

    var label: String {
        switch self {
        case .ready: "Ready"
        case .warning: "Needs Review"
        case .blocked: "Blocked"
        }
    }
}

struct PaperBananaReadinessRow: Identifiable, Equatable, Sendable {
    enum RowID: String, Sendable {
        case configuredPath
        case generationKey
        case backendValidity
        case deterministicFallback
    }

    let id: RowID
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let severity: PaperBananaReadinessSeverity
}

struct PaperBananaReadinessSnapshot: Equatable, Sendable {
    let statusTitle: String
    let statusMessage: String
    let severity: PaperBananaReadinessSeverity
    let configuredPath: String
    let rows: [PaperBananaReadinessRow]

    var configuredPathRow: PaperBananaReadinessRow {
        row(.configuredPath)
    }

    var generationKeyRow: PaperBananaReadinessRow {
        row(.generationKey)
    }

    var backendValidityRow: PaperBananaReadinessRow {
        row(.backendValidity)
    }

    var deterministicFallbackRow: PaperBananaReadinessRow {
        row(.deterministicFallback)
    }

    static func make(
        settings: PaperBananaSettingsSnapshot,
        requestedModel: ImageModelChoice? = nil,
        fileManager: FileManager = .default
    ) -> PaperBananaReadinessSnapshot {
        let model = requestedModel ?? settings.defaultImageModel
        let providerPlan = ImageProviderExecutionPlan(requestedModel: model, settings: settings)
        let repoURL = normalizedRepoURL(from: settings.repoPath)
        let repoState = pathState(at: repoURL, expectedDirectory: true, fileManager: fileManager)
        let appState = pathState(at: repoURL.appendingPathComponent("app.py", isDirectory: false), expectedDirectory: false, fileManager: fileManager)
        let pythonState = pathState(at: repoURL.appendingPathComponent(".venv/bin/python", isDirectory: false), expectedDirectory: false, fileManager: fileManager)
        let configState = pathState(at: repoURL.appendingPathComponent("configs/model_config.yaml", isDirectory: false), expectedDirectory: false, fileManager: fileManager)
        let backendIsValid = repoState == .valid && appState == .valid && pythonState == .valid

        let pathRow = configuredPathRow(
            repoURL: repoURL,
            repoState: repoState,
            fileManager: fileManager
        )
        let keyRow = generationKeyRow(settings: settings)
        let backendRow = backendValidityRow(
            backendIsValid: backendIsValid,
            repoState: repoState,
            appState: appState,
            pythonState: pythonState,
            configState: configState
        )
        let fallbackRow = deterministicFallbackRow(
            settings: settings,
            requestedModel: model,
            providerPlan: providerPlan
        )

        let severity: PaperBananaReadinessSeverity
        let title: String
        let message: String
        if repoState != .valid {
            severity = .blocked
            title = "Path Blocked"
            message = "Correct the configured checkout path before native runs can read or write PaperBanana artifacts."
        } else if providerPlan.provider == .codexFallback && model != .codexFallback {
            severity = .warning
            title = "Ready with Codex Fallback"
            message = "No generation key is saved, so paid model requests resolve to deterministic Codex fallback."
        } else if !backendIsValid {
            severity = .warning
            title = "Native Ready"
            message = "Native workflows are available; the optional compatibility backend is incomplete."
        } else {
            severity = .ready
            title = "Ready"
            message = providerPlan.canSpendProviderCredits
                ? "Provider-backed generation is configured and can spend provider credits."
                : "Codex fallback is selected and will not spend provider API credits."
        }

        return PaperBananaReadinessSnapshot(
            statusTitle: title,
            statusMessage: message,
            severity: severity,
            configuredPath: repoURL.path,
            rows: [pathRow, keyRow, backendRow, fallbackRow]
        )
    }

    private func row(_ id: PaperBananaReadinessRow.RowID) -> PaperBananaReadinessRow {
        rows.first { $0.id == id } ?? PaperBananaReadinessRow(
            id: id,
            title: "Unknown",
            value: "Unavailable",
            detail: "Readiness state could not be computed.",
            systemImage: "questionmark.circle",
            severity: .blocked
        )
    }

    private enum PathState {
        case valid
        case missing
        case wrongType
    }

    private static func configuredPathRow(
        repoURL: URL,
        repoState: PathState,
        fileManager: FileManager
    ) -> PaperBananaReadinessRow {
        let isWritable = fileManager.isWritableFile(atPath: repoURL.path)
        let value: String
        let detail: String
        let severity: PaperBananaReadinessSeverity
        switch repoState {
        case .valid where isWritable:
            value = repoURL.path
            detail = "Native runs, recovered artifacts, ledgers, and review scans use this checkout."
            severity = .ready
        case .valid:
            value = repoURL.path
            detail = "The checkout exists, but native workflows may not be able to write results here."
            severity = .warning
        case .missing:
            value = repoURL.path
            detail = "The configured checkout path does not exist."
            severity = .blocked
        case .wrongType:
            value = repoURL.path
            detail = "The configured checkout path is not a directory."
            severity = .blocked
        }

        return PaperBananaReadinessRow(
            id: .configuredPath,
            title: "Configured Path",
            value: value,
            detail: detail,
            systemImage: "folder",
            severity: severity
        )
    }

    private static func generationKeyRow(settings: PaperBananaSettingsSnapshot) -> PaperBananaReadinessRow {
        let hasGoogle = settings.googleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasOpenRouter = settings.openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false

        let value: String
        if hasGoogle && hasOpenRouter {
            value = "Google and OpenRouter keys saved"
        } else if hasGoogle {
            value = "Google key saved"
        } else if hasOpenRouter {
            value = "OpenRouter key saved"
        } else {
            value = "No generation key saved"
        }

        return PaperBananaReadinessRow(
            id: .generationKey,
            title: "Generation Key",
            value: value,
            detail: hasGoogle || hasOpenRouter
                ? "Provider-backed generation can use saved local secrets."
                : "Paid model requests will not fail silently; they route to Codex fallback.",
            systemImage: "key",
            severity: hasGoogle || hasOpenRouter ? .ready : .warning
        )
    }

    private static func backendValidityRow(
        backendIsValid: Bool,
        repoState: PathState,
        appState: PathState,
        pythonState: PathState,
        configState: PathState
    ) -> PaperBananaReadinessRow {
        let value: String
        let detail: String
        let severity: PaperBananaReadinessSeverity
        if backendIsValid {
            value = "Compatibility backend valid"
            detail = "The optional Python compatibility backend has app.py and a virtualenv Python."
            severity = .ready
        } else if repoState != .valid {
            value = "Backend unavailable"
            detail = "Backend validity cannot be checked until the configured checkout path is valid."
            severity = .blocked
        } else {
            value = "Optional backend incomplete"
            let missing = [
                missingLabel("app.py", state: appState),
                missingLabel(".venv/bin/python", state: pythonState),
                missingLabel("configs/model_config.yaml", state: configState),
            ].compactMap { $0 }
            detail = "Missing or invalid: \(missing.joined(separator: ", ")). Native generation and review do not require this backend."
            severity = .warning
        }

        return PaperBananaReadinessRow(
            id: .backendValidity,
            title: "Backend Validity",
            value: value,
            detail: detail,
            systemImage: "server.rack",
            severity: severity
        )
    }

    private static func deterministicFallbackRow(
        settings: PaperBananaSettingsSnapshot,
        requestedModel: ImageModelChoice,
        providerPlan: ImageProviderExecutionPlan
    ) -> PaperBananaReadinessRow {
        let isMissingKeyFallback = requestedModel != .codexFallback && providerPlan.provider == .codexFallback
        let value: String
        let detail: String
        let severity: PaperBananaReadinessSeverity

        if isMissingKeyFallback {
            value = "\(requestedModel.label) resolves to Codex fallback"
            detail = "Generation uses \(settings.codexModel) with \(settings.codexReasoning) reasoning and records no provider API spend."
            severity = .ready
        } else if providerPlan.canSpendProviderCredits {
            value = "\(providerPlan.providerLabel) via \(providerPlan.credentialSourceLabel)"
            detail = "\(providerPlan.modelLabel) can spend provider credits; preflight confirms before execution."
            severity = .ready
        } else {
            value = "Codex fallback selected"
            detail = "Generation uses \(settings.codexModel) with \(settings.codexReasoning) reasoning and records no provider API spend."
            severity = .ready
        }

        return PaperBananaReadinessRow(
            id: .deterministicFallback,
            title: "Deterministic Fallback",
            value: value,
            detail: detail,
            systemImage: "arrow.triangle.2.circlepath",
            severity: severity
        )
    }

    private static func normalizedRepoURL(from path: String) -> URL {
        let expandedPath = (path as NSString)
            .expandingTildeInPath
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(fileURLWithPath: expandedPath.isEmpty ? "." : expandedPath, isDirectory: true)
            .standardizedFileURL
    }

    private static func pathState(
        at url: URL,
        expectedDirectory: Bool,
        fileManager: FileManager
    ) -> PathState {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return .missing
        }
        guard expectedDirectory == isDirectory.boolValue else {
            return .wrongType
        }
        return .valid
    }

    private static func missingLabel(_ label: String, state: PathState) -> String? {
        switch state {
        case .valid:
            return nil
        case .missing:
            return label
        case .wrongType:
            return "\(label) type"
        }
    }
}

enum PaperBananaAssistantTask: String, CaseIterable, Identifiable {
    case improvePrompt
    case critiqueFigure
    case extractText
    case nameArtifact
    case summarizeRun
    case explainRecovery
    case generateMetadata

    var id: String { rawValue }

    var label: String {
        switch self {
        case .improvePrompt: "Improve prompt"
        case .critiqueFigure: "Critique figure"
        case .extractText: "Extract text"
        case .nameArtifact: "Name artifact"
        case .summarizeRun: "Summarize run"
        case .explainRecovery: "Explain recovery"
        case .generateMetadata: "Generate metadata"
        }
    }

    var instruction: String {
        switch self {
        case .improvePrompt:
            "Improve this PaperBanana scientific image prompt. Preserve scientific meaning. Add concrete layout, labeling, style, resolution, and legibility requirements."
        case .critiqueFigure:
            "Critique this scientific figure description for publication readiness. Focus on labeling, panel structure, visual hierarchy, accessibility, and likely rendering failure points."
        case .extractText:
            "Convert OCR or figure text into clean, structured figure text. Preserve labels, abbreviations, measurements, and panel identifiers."
        case .nameArtifact:
            "Create a short filesystem-safe artifact name for this PaperBanana output. Use only letters, numbers, hyphens, and underscores."
        case .summarizeRun:
            "Summarize this PaperBanana run for a run ledger. Include model, provider, output, failure or recovery state, and next action."
        case .explainRecovery:
            "Explain why this provider output is recoverable and what file the user should inspect next. Keep it concise and operational."
        case .generateMetadata:
            "Generate structured JSON metadata for this PaperBanana image workflow. Include artifact name, run status, model or provider if known, resolution if known, prompt preview, recovery state, and next action. Return JSON only."
        }
    }
}

struct PaperBananaAssistantResult: Equatable {
    let task: PaperBananaAssistantTask
    let text: String
    let usedFoundationModels: Bool
    let fallbackReason: String?
}

enum PaperBananaIntentDestination: String {
    case promptStudio
    case refineImage
    case recoveredImages
    case runDetails
    case runLedger
}

enum PaperBananaIntentBridge {
    static let destinationKey = "paperbanana.intent.destination"

    static func request(_ destination: PaperBananaIntentDestination) {
        UserDefaults.standard.set(destination.rawValue, forKey: destinationKey)
    }

    static func consume() -> PaperBananaIntentDestination? {
        guard let rawValue = UserDefaults.standard.string(forKey: destinationKey),
              let destination = PaperBananaIntentDestination(rawValue: rawValue) else {
            return nil
        }
        UserDefaults.standard.removeObject(forKey: destinationKey)
        return destination
    }
}

struct PaperBananaOCRResult: Equatable {
    let imageURL: URL
    let text: String

    var hasText: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

enum PaperBananaVisionTextExtractor {
    static func extractText(from imageURL: URL) throws -> PaperBananaOCRResult {
        var recognizedText: [String] = []
        var recognitionError: Error?
        let request = VNRecognizeTextRequest { request, error in
            recognitionError = error
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { $0.isEmpty == false }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(url: imageURL, options: [:])
        try handler.perform([request])
        if let recognitionError {
            throw recognitionError
        }

        return PaperBananaOCRResult(
            imageURL: imageURL,
            text: recognizedText.joined(separator: "\n")
        )
    }
}

enum PaperBananaFoundationAssistant {
    static func run(
        task: PaperBananaAssistantTask,
        input: String,
        imageURL: URL? = nil,
        context: String = "",
        preferFoundationModels: Bool = true
    ) async -> PaperBananaAssistantResult {
        let ocrResult = (task == .extractText && imageURL != nil)
            ? (try? PaperBananaVisionTextExtractor.extractText(from: imageURL!))
            : nil
        let combinedInput = [
            input.trimmingCharacters(in: .whitespacesAndNewlines),
            ocrResult?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        ]
            .filter { $0.isEmpty == false }
            .joined(separator: "\n\n")
        let trimmedInput = combinedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedInput.isEmpty == false || trimmedContext.isEmpty == false else {
            let reason = imageURL == nil ? "No input provided." : "No text was recognized from the selected image."
            return fallback(task: task, input: trimmedInput, context: trimmedContext, reason: reason)
        }

        guard preferFoundationModels else {
            return fallback(task: task, input: trimmedInput, context: trimmedContext, reason: "Foundation Models disabled for this request.")
        }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            do {
                let response = try await respondWithFoundationModels(
                    task: task,
                    input: trimmedInput,
                    context: trimmedContext
                )
                return PaperBananaAssistantResult(
                    task: task,
                    text: response,
                    usedFoundationModels: true,
                    fallbackReason: nil
                )
            } catch {
                return fallback(
                    task: task,
                    input: trimmedInput,
                    context: trimmedContext,
                    reason: error.localizedDescription
                )
            }
        }
        #endif

        return fallback(
            task: task,
            input: trimmedInput,
            context: trimmedContext,
            reason: "Foundation Models require macOS 26 or later."
        )
    }

    static func fallback(
        task: PaperBananaAssistantTask,
        input: String,
        context: String = "",
        reason: String
    ) -> PaperBananaAssistantResult {
        let text: String
        switch task {
        case .improvePrompt:
            text = deterministicPromptImprovement(input)
        case .critiqueFigure:
            text = deterministicCritique(input)
        case .extractText:
            text = deterministicTextExtractionCleanup(input)
        case .nameArtifact:
            text = deterministicArtifactName(input)
        case .summarizeRun:
            text = deterministicRunSummary(input: input, context: context)
        case .explainRecovery:
            text = deterministicRecoveryExplanation(input: input, context: context)
        case .generateMetadata:
            text = deterministicMetadata(input: input, context: context)
        }
        return PaperBananaAssistantResult(
            task: task,
            text: text,
            usedFoundationModels: false,
            fallbackReason: reason
        )
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private static func respondWithFoundationModels(
        task: PaperBananaAssistantTask,
        input: String,
        context: String
    ) async throws -> String {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw CocoaError(.featureUnsupported)
        }

        let instructions = """
        You are the local PaperBanana assistant. Support scientific image workflows only. Do not render images. Do not spend provider credits. Preserve scientific terms, dimensions, abbreviations, and labels. Return concise, directly usable output.
        """
        let session = LanguageModelSession(model: model, instructions: instructions)
        let prompt = """
        Task: \(task.instruction)

        Context:
        \(context.isEmpty ? "None" : context)

        Input:
        \(input)
        """
        let response = try await session.respond(to: prompt)
        let trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw CocoaError(.coderInvalidValue)
        }
        return trimmed
    }
    #endif

    private static func deterministicPromptImprovement(_ input: String) -> String {
        let base = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let seed = base.isEmpty ? "Create a publication-ready scientific figure." : base
        return """
        \(seed)

        Requirements:
        - Build a clean publication-ready scientific diagram with clear panel structure.
        - Preserve all domain terms, abbreviations, numeric values, and labels exactly.
        - Use high-contrast text, aligned connectors, consistent spacing, and legible typography.
        - Avoid decorative clutter; prioritize traceable workflow logic and figure readability.
        - Render at the selected PaperBanana resolution and aspect ratio.
        """
    }

    private static func deterministicCritique(_ input: String) -> String {
        let subject = input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "the figure" : input
        return """
        Critique for \(subject):
        - Verify every panel label, axis label, and abbreviation is readable at final export size.
        - Check that arrows, callouts, and hard-stop markers connect to the intended objects.
        - Confirm color choices remain distinguishable in light mode, dark mode, grayscale, and color-blind review.
        - Inspect for duplicated panels, hallucinated words, misspellings, and truncated labels.
        - Rebuild with Nano Banana Pro only after the candidate passes structure and text checks.
        """
    }

    private static func deterministicTextExtractionCleanup(_ input: String) -> String {
        input
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")
    }

    private static func deterministicArtifactName(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let compact = input
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "_" }
        let name = String(compact)
            .split(separator: "_")
            .prefix(8)
            .joined(separator: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
        return name.isEmpty ? "paperbanana_artifact" : name
    }

    private static func deterministicRunSummary(input: String, context: String) -> String {
        let body = [context, input]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")
        return body.isEmpty
            ? "No run details were provided."
            : "Run summary: \(body.prefix(700))"
    }

    private static func deterministicRecoveryExplanation(input: String, context: String) -> String {
        let detail = [context, input]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
        return """
        Recovery explanation: provider bytes or an audit artifact were preserved even though the native output path was incomplete. Inspect the recoverable raw response or recovered artifact listed in the run cockpit. \(detail)
        """
    }

    private static func deterministicMetadata(input: String, context: String) -> String {
        let detail = [context, input]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")
        let preview = detail
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = preview.lowercased()
        let artifactName = deterministicArtifactName(preview.isEmpty ? "paperbanana_artifact" : preview)
        return """
        {
          "artifact_name": "\(jsonEscaped(artifactName))",
          "workflow": "paperbanana",
          "prompt_preview": "\(jsonEscaped(String(preview.prefix(220))))",
          "provider_spend": "none",
          "contains_output_signal": \(lowercased.contains("output")),
          "contains_recovery_signal": \(lowercased.contains("recover")),
          "next_action": "\(jsonEscaped(lowercased.contains("recover") ? "Inspect recovered artifact or raw provider payload in the run cockpit." : "Validate output artifact, metadata companion, and prompt-to-output trace."))"
        }
        """
    }

    private static func jsonEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}
