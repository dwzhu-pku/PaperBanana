import Foundation

struct NativeImageGenerationRequest {
    let prompt: String
    let model: ImageModelChoice
    let resolution: String
    let aspectRatio: String
    let task: String
    let settings: PaperBananaSettingsSnapshot
    let executionMode: NativeImageGenerationExecutionMode
    let preflightRunID: String?

    init(
        prompt: String,
        model: ImageModelChoice,
        resolution: String,
        aspectRatio: String,
        task: String,
        settings: PaperBananaSettingsSnapshot,
        executionMode: NativeImageGenerationExecutionMode = .live,
        preflightRunID: String? = nil
    ) {
        self.prompt = prompt
        self.model = model
        self.resolution = resolution
        self.aspectRatio = aspectRatio
        self.task = task
        self.settings = settings
        self.executionMode = executionMode
        self.preflightRunID = preflightRunID
    }

    func withPreflightRunID(_ runID: String) -> NativeImageGenerationRequest {
        NativeImageGenerationRequest(
            prompt: prompt,
            model: model,
            resolution: resolution,
            aspectRatio: aspectRatio,
            task: task,
            settings: settings,
            executionMode: executionMode,
            preflightRunID: runID
        )
    }
}

enum NativeImageGenerationExecutionMode: Equatable {
    case live
    case dryRun
}
