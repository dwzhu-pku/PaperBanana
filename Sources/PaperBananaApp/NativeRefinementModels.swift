import Foundation

struct NativeRefinementEvent: Equatable, Sendable {
    let stage: String
    let progress: Int
    let message: String
    let runID: String
    let runDirectoryURL: URL?
    let outputURL: URL?
    let metadataURL: URL?
    let logURL: URL?
    let promptURL: URL?
    let requestURL: URL?
    let callID: String
    let rawResponseURL: URL?
    let rawPayloadURL: URL?

    init?(jsonLine: String) {
        guard let data = jsonLine.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stage = payload["stage"] as? String,
              let progress = payload["progress"] as? Int,
              let message = payload["message"] as? String else {
            return nil
        }

        self.stage = stage
        self.progress = progress
        self.message = message
        runID = payload["run_id"] as? String ?? ""
        runDirectoryURL = Self.fileURL(payload["run_dir"] as? String)
        outputURL = Self.fileURL(payload["output_path"] as? String)
        metadataURL = Self.fileURL(payload["metadata_path"] as? String)
        logURL = Self.fileURL(payload["log_path"] as? String)
        promptURL = Self.fileURL(payload["prompt_path"] as? String)
        requestURL = Self.fileURL(payload["request_path"] as? String)
        callID = payload["call_id"] as? String ?? ""
        rawResponseURL = Self.fileURL(payload["raw_response_path"] as? String)
        rawPayloadURL = Self.fileURL(payload["raw_path"] as? String)
    }

    private static func fileURL(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
    }
}

enum NativeRefinementMilestoneState: Equatable {
    case pending
    case active
    case completed
    case recovered
    case failed
    case cancelled
    case timedOut
}

struct NativeRefinementMilestone: Identifiable, Equatable {
    let stage: String
    let title: String
    let state: NativeRefinementMilestoneState

    var id: String { stage }

    static let orderedStages: [(stage: String, title: String)] = [
        ("queued", "Queued"),
        ("prepared", "Prepared"),
        ("model_call", "Model call"),
        ("saving", "Saving"),
        ("complete", "Complete")
    ]

    static func timeline(currentStage: String) -> [NativeRefinementMilestone] {
        let activeStage = normalizedStage(currentStage)
        let activeIndex = orderedStages.firstIndex { $0.stage == activeStage } ?? 0
        let terminalState: NativeRefinementMilestoneState? = {
            switch currentStage {
            case "recovered":
                .recovered
            case "failed":
                .failed
            case "cancelled":
                .cancelled
            case "timeout", "timedOut":
                .timedOut
            default:
                nil
            }
        }()
        return orderedStages.enumerated().map { index, stage in
            let state: NativeRefinementMilestoneState
            if let terminalState {
                state = index <= activeIndex ? terminalState : .pending
            } else if currentStage == "complete" || index < activeIndex {
                state = .completed
            } else if index == activeIndex {
                state = .active
            } else {
                state = .pending
            }
            return NativeRefinementMilestone(stage: stage.stage, title: stage.title, state: state)
        }
    }

    private static func normalizedStage(_ stage: String) -> String {
        switch stage {
        case "started", "running", "fallback":
            return "model_call"
        case "cancelled", "timeout", "timedOut", "failed", "recovered":
            return "model_call"
        default:
            return stage
        }
    }
}

struct NativeRefinementRequest {
    let sourceURL: URL
    let prompt: String
    let model: ImageModelChoice
    let resolution: String
    let aspectRatio: String
    let settings: PaperBananaSettingsSnapshot
    let executionMode: NativeRefinementExecutionMode
    let preflightRunID: String?

    init(
        sourceURL: URL,
        prompt: String,
        model: ImageModelChoice,
        resolution: String,
        aspectRatio: String,
        settings: PaperBananaSettingsSnapshot,
        executionMode: NativeRefinementExecutionMode = .live,
        preflightRunID: String? = nil
    ) {
        self.sourceURL = sourceURL
        self.prompt = prompt
        self.model = model
        self.resolution = resolution
        self.aspectRatio = aspectRatio
        self.settings = settings
        self.executionMode = executionMode
        self.preflightRunID = preflightRunID
    }

    func withPreflightRunID(_ runID: String) -> NativeRefinementRequest {
        NativeRefinementRequest(
            sourceURL: sourceURL,
            prompt: prompt,
            model: model,
            resolution: resolution,
            aspectRatio: aspectRatio,
            settings: settings,
            executionMode: executionMode,
            preflightRunID: runID
        )
    }
}

enum NativeRefinementExecutionMode: Equatable {
    case live
    case dryRun
    case mockProviderValid
    case mockProviderInvalidPayload
}
