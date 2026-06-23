import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ProviderWorkflow: String, Codable, Sendable {
    case generation = "native_generate"
    case refinement = "native_refine"
}

struct ProviderClientRequest: Sendable {
    let runID: String
    let callID: String
    let workflow: ProviderWorkflow
    let prompt: String
    let sourceImageURL: URL?
    let model: ImageModelChoice
    let effectiveModel: String
    let resolution: String
    let aspectRatio: String
    let task: String
    let settings: PaperBananaSettingsSnapshot
    let outputURL: URL?
    let providerRequestURL: URL?

    init(
        runID: String,
        callID: String,
        workflow: ProviderWorkflow,
        prompt: String,
        sourceImageURL: URL?,
        model: ImageModelChoice,
        effectiveModel: String,
        resolution: String,
        aspectRatio: String,
        task: String,
        settings: PaperBananaSettingsSnapshot,
        outputURL: URL? = nil,
        providerRequestURL: URL? = nil
    ) {
        self.runID = runID
        self.callID = callID
        self.workflow = workflow
        self.prompt = prompt
        self.sourceImageURL = sourceImageURL
        self.model = model
        self.effectiveModel = effectiveModel
        self.resolution = resolution
        self.aspectRatio = aspectRatio
        self.task = task
        self.settings = settings
        self.outputURL = outputURL
        self.providerRequestURL = providerRequestURL
    }
}

struct ProviderProgressEvent: Sendable {
    let stage: String
    let progress: Int
    let message: String
    let callID: String
    let nativeRunEvent: NativeRefinementEvent?

    init(
        stage: String,
        progress: Int,
        message: String,
        callID: String,
        nativeRunEvent: NativeRefinementEvent? = nil
    ) {
        self.stage = stage
        self.progress = progress
        self.message = message
        self.callID = callID
        self.nativeRunEvent = nativeRunEvent
    }
}

struct ProviderResponse: Sendable {
    let provider: ImageProviderKind
    let model: String
    let callID: String
    let rawResponseData: Data
    let imageData: Data?
    let text: String
    let usageMetadata: [String: String]
}

protocol ProviderClient: Sendable {
    var providerKind: ImageProviderKind { get }

    func execute(
        _ request: ProviderClientRequest,
        eventHandler: @escaping @Sendable (ProviderProgressEvent) -> Void
    ) async throws -> ProviderResponse
}

enum ProviderRuntimeError: LocalizedError {
    case missingAPIKey(String)
    case missingSourceImage
    case missingCodexOutputPath
    case codexHandoffFailed(String)
    case codexHandoffTimedOut(String)
    case unsupportedNativeProvider(String)
    case providerHTTPStatus(Int, String, Data?)
    case providerReturnedNoImage
    case malformedProviderResponse
    case malformedProviderResponseBody(String, Data)
    case legacyPythonProcessFailed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            "\(provider) requires an active API key."
        case .missingSourceImage:
            "Refinement requires a source image."
        case .missingCodexOutputPath:
            "Codex image handoff requires a durable output path before execution starts."
        case .codexHandoffFailed(let message):
            "Codex image handoff failed: \(message)"
        case .codexHandoffTimedOut(let message):
            "Codex image handoff timed out: \(message)"
        case .unsupportedNativeProvider(let provider):
            "\(provider) does not have a direct Swift provider client yet."
        case .providerHTTPStatus(let status, let body, _):
            "Provider request failed with HTTP \(status): \(body)"
        case .providerReturnedNoImage:
            "Provider response did not contain image bytes."
        case .malformedProviderResponse:
            "Provider response could not be decoded."
        case .malformedProviderResponseBody(let reason, _):
            "Provider response could not be decoded: \(reason)"
        case .legacyPythonProcessFailed(let status, let message):
            "Legacy Python provider exited with status \(status): \(message)"
        }
    }

    var rawProviderResponseData: Data? {
        switch self {
        case .providerHTTPStatus(_, _, let data):
            data
        case .malformedProviderResponseBody(_, let data):
            data
        default:
            nil
        }
    }
}

struct ProviderClientFactory: Sendable {
    private let googleClient: any ProviderClient
    private let openRouterClient: any ProviderClient
    private let codexClient: any ProviderClient

    init(
        googleClient: any ProviderClient = GoogleGeminiProviderClient(),
        openRouterClient: any ProviderClient = OpenRouterProviderClient(),
        codexClient: any ProviderClient = CodexFallbackProviderClient()
    ) {
        self.googleClient = googleClient
        self.openRouterClient = openRouterClient
        self.codexClient = codexClient
    }

    func client(for providerPlan: ImageProviderExecutionPlan) -> any ProviderClient {
        switch providerPlan.provider {
        case .googleGemini:
            googleClient
        case .codexFallback:
            codexClient
        case .openRouter:
            openRouterClient
        case .foundationModels:
            FoundationModelsProviderClient()
        }
    }
}

enum ProviderImagePersistence {
    static func writePNG(imageData: Data, to outputURL: URL) throws {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ProviderRuntimeError.malformedProviderResponse
        }

        let temporaryURL = outputURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(outputURL.lastPathComponent).\(UUID().uuidString).tmp")
        guard let destination = CGImageDestinationCreateWithURL(
            temporaryURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw CocoaError(.fileWriteUnknown)
        }
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: outputURL)
    }
}

enum ProviderRequestPersistence {
    static func writeJSON(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

struct FoundationModelsProviderClient: ProviderClient {
    let providerKind: ImageProviderKind = .foundationModels

    func execute(
        _ request: ProviderClientRequest,
        eventHandler: @escaping @Sendable (ProviderProgressEvent) -> Void
    ) async throws -> ProviderResponse {
        throw ProviderRuntimeError.unsupportedNativeProvider(providerKind.label)
    }
}
