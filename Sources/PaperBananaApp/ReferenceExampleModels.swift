import Foundation

struct ReferenceExample: Identifiable, Hashable {
    let id: String
    let visualIntent: String
    let contentText: String
    let contentSummary: String
    let imageRelativePath: String
    let imageURL: URL

    var selection: ReferenceExampleSelection {
        ReferenceExampleSelection(
            id: id,
            visualIntent: visualIntent,
            contentSummary: contentSummary,
            imagePath: imageRelativePath
        )
    }
}

struct ReferenceExampleSelection: Codable, Hashable, Identifiable, Sendable {
    static let maximumSelectionCount = 10

    let id: String
    let visualIntent: String
    let contentSummary: String
    let imagePath: String

    var durablePayload: [String: String] {
        [
            "id": id,
            "visual_intent": visualIntent,
            "content_summary": contentSummary,
            "image_path": imagePath,
            "reference_source": "PaperBananaBench/diagram"
        ]
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
        Use these manually selected PaperBananaBench diagram examples as style, structure, and content guidance. Do not copy paper-specific identifiers unless they are explicitly present in the requested figure.
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
