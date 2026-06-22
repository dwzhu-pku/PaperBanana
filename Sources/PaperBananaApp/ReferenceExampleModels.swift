import Foundation

enum ReferenceExampleBenchmarkTask: String, Hashable, Sendable {
    case diagram
    case plot

    init(taskName: String) {
        self = taskName.localizedCaseInsensitiveContains("plot") ? .plot : .diagram
    }

    var referenceSource: String {
        "PaperBananaBench/\(rawValue)"
    }

    var displayName: String {
        switch self {
        case .diagram: "diagram"
        case .plot: "plot"
        }
    }

    var capitalizedDisplayName: String {
        switch self {
        case .diagram: "Diagram"
        case .plot: "Plot"
        }
    }

    var promptGuidance: String {
        switch self {
        case .diagram:
            "Use these manually selected PaperBananaBench diagram examples as style, structure, and content guidance. Do not copy paper-specific identifiers unless they are explicitly present in the requested figure."
        case .plot:
            "Use these manually selected PaperBananaBench plot examples as chart-type, data-encoding, and styling guidance. Do not copy source data values unless they are explicitly present in the requested plot."
        }
    }
}

struct ReferenceExample: Identifiable, Hashable {
    let id: String
    let visualIntent: String
    let contentText: String
    let contentSummary: String
    let imageRelativePath: String
    let imageURL: URL
    let imageAvailable: Bool
    let benchmarkTask: ReferenceExampleBenchmarkTask

    init(
        id: String,
        visualIntent: String,
        contentText: String,
        contentSummary: String,
        imageRelativePath: String,
        imageURL: URL,
        imageAvailable: Bool = true,
        benchmarkTask: ReferenceExampleBenchmarkTask = .diagram
    ) {
        self.id = id
        self.visualIntent = visualIntent
        self.contentText = contentText
        self.contentSummary = contentSummary
        self.imageRelativePath = imageRelativePath
        self.imageURL = imageURL
        self.imageAvailable = imageAvailable
        self.benchmarkTask = benchmarkTask
    }

    var selection: ReferenceExampleSelection {
        ReferenceExampleSelection(
            id: id,
            visualIntent: visualIntent,
            contentSummary: contentSummary,
            imagePath: imageRelativePath,
            referenceSource: benchmarkTask.referenceSource
        )
    }
}

struct ReferenceExampleSelection: Codable, Hashable, Identifiable, Sendable {
    static let maximumSelectionCount = 10

    let id: String
    let visualIntent: String
    let contentSummary: String
    let imagePath: String
    let referenceSource: String

    init(
        id: String,
        visualIntent: String,
        contentSummary: String,
        imagePath: String,
        referenceSource: String = ReferenceExampleBenchmarkTask.diagram.referenceSource
    ) {
        self.id = id
        self.visualIntent = visualIntent
        self.contentSummary = contentSummary
        self.imagePath = imagePath
        self.referenceSource = referenceSource
    }

    var durablePayload: [String: String] {
        [
            "id": id,
            "visual_intent": visualIntent,
            "content_summary": contentSummary,
            "image_path": imagePath,
            "reference_source": referenceSource
        ]
    }

    func isCompatible(with taskName: String) -> Bool {
        referenceSource == ReferenceExampleBenchmarkTask(taskName: taskName).referenceSource
    }

    enum CodingKeys: String, CodingKey {
        case id
        case visualIntent = "visual_intent"
        case contentSummary = "content_summary"
        case imagePath = "image_path"
        case referenceSource = "reference_source"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        visualIntent = try container.decode(String.self, forKey: .visualIntent)
        contentSummary = try container.decode(String.self, forKey: .contentSummary)
        imagePath = try container.decode(String.self, forKey: .imagePath)
        referenceSource = try container.decodeIfPresent(String.self, forKey: .referenceSource)
            ?? ReferenceExampleBenchmarkTask.diagram.referenceSource
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(visualIntent, forKey: .visualIntent)
        try container.encode(contentSummary, forKey: .contentSummary)
        try container.encode(imagePath, forKey: .imagePath)
        try container.encode(referenceSource, forKey: .referenceSource)
    }

    static func durablePayload(for selections: [ReferenceExampleSelection]) -> [[String: String]] {
        selections.map(\.durablePayload)
    }

    static func limitedIDs(
        _ ids: Set<String>,
        orderedExamples: [ReferenceExample],
        limit: Int = maximumSelectionCount
    ) -> Set<String> {
        var limited = Set<String>()
        for example in orderedExamples where ids.contains(example.id) {
            guard limited.count < limit else { break }
            limited.insert(example.id)
        }
        return limited
    }

    static func toggledIDs(
        _ ids: Set<String>,
        id: String,
        orderedExamples: [ReferenceExample],
        limit: Int = maximumSelectionCount
    ) -> Set<String> {
        var updated = ids
        if updated.contains(id) {
            updated.remove(id)
            return updated
        }
        guard updated.count < limit else { return limitedIDs(updated, orderedExamples: orderedExamples, limit: limit) }
        updated.insert(id)
        return limitedIDs(updated, orderedExamples: orderedExamples, limit: limit)
    }
}

enum ReferenceExamplePromptBuilder {
    static func enrichedPrompt(
        sourcePrompt: String,
        referenceExamples: [ReferenceExampleSelection]
    ) -> String {
        let trimmedPrompt = sourcePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !referenceExamples.isEmpty else { return trimmedPrompt }

        let benchmarkTask = referenceExamples.contains {
            $0.referenceSource == ReferenceExampleBenchmarkTask.plot.referenceSource
        } ? ReferenceExampleBenchmarkTask.plot : .diagram

        let examplesBlock = referenceExamples.enumerated().map { index, example in
            """
            \(index + 1). ID: \(example.id)
               Visual intent: \(example.visualIntent)
               Content summary: \(example.contentSummary)
               Image path: \(example.imagePath)
            """
        }
        .joined(separator: "\n")

        return """
        \(trimmedPrompt)

        Selected Reference Examples
        \(benchmarkTask.promptGuidance)
        \(examplesBlock)
        """
    }
}

extension NativeImageGenerationRequest {
    var providerPrompt: String {
        ReferenceExamplePromptBuilder.enrichedPrompt(
            sourcePrompt: prompt,
            referenceExamples: referenceExamples
        )
    }
}
