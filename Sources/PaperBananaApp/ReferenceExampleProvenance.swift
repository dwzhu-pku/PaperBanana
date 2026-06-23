import Foundation
import SwiftUI

struct ReferenceExampleProvenance: Hashable {
    struct Example: Hashable, Identifiable, Decodable {
        let id: String
        let visualIntent: String
        let contentSummary: String
        let imagePath: String
        let referenceSource: String

        enum CodingKeys: String, CodingKey {
            case id
            case visualIntent = "visual_intent"
            case contentSummary = "content_summary"
            case imagePath = "image_path"
            case referenceSource = "reference_source"
        }
    }

    static let empty = ReferenceExampleProvenance(
        sourcePrompt: "",
        mode: "none",
        declaredCount: 0,
        examples: []
    )

    let sourcePrompt: String
    let mode: String
    let declaredCount: Int
    let examples: [Example]

    var isManual: Bool {
        mode == "manual_native_prompt_enrichment" || !examples.isEmpty || declaredCount > 0
    }

    var count: Int {
        examples.isEmpty ? declaredCount : examples.count
    }

    var summaryText: String {
        guard isManual else { return "" }
        let countText = "\(count) manual reference example\(count == 1 ? "" : "s")"
        let ids = examples.prefix(4).map(\.id).joined(separator: ", ")
        guard !ids.isEmpty else { return countText }
        return "\(countText): \(ids)"
    }

    var searchableText: String {
        ([mode, sourcePrompt, summaryText] + examples.flatMap { example in
            [
                example.id,
                example.visualIntent,
                example.contentSummary,
                example.imagePath,
                example.referenceSource
            ]
        })
        .joined(separator: "\n")
    }

    static func best(_ lhs: ReferenceExampleProvenance, _ rhs: ReferenceExampleProvenance) -> ReferenceExampleProvenance {
        if lhs.isManual { return lhs }
        return rhs
    }
}

extension ReferenceExampleProvenance: Decodable {
    enum CodingKeys: String, CodingKey {
        case sourcePrompt = "source_prompt"
        case mode = "reference_mode"
        case declaredCount = "reference_example_count"
        case examples = "reference_examples"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourcePrompt = try container.decodeIfPresent(String.self, forKey: .sourcePrompt) ?? ""
        mode = try container.decodeIfPresent(String.self, forKey: .mode) ?? "none"
        declaredCount = try container.decodeFlexibleIntIfPresent(forKey: .declaredCount) ?? 0
        examples = try container.decodeIfPresent([Example].self, forKey: .examples) ?? []
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        if let int = try decodeIfPresent(Int.self, forKey: key) {
            return int
        }
        if let string = try decodeIfPresent(String.self, forKey: key) {
            return Int(string)
        }
        return nil
    }
}

struct ReferenceExampleProvenanceSection: View {
    let provenance: ReferenceExampleProvenance

    var body: some View {
        if provenance.isManual {
            WorkbenchSection(
                "Reference Examples",
                systemImage: "quote.bubble",
                subtitle: provenance.summaryText
            ) {
                VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                    if !provenance.sourcePrompt.isEmpty {
                        LabeledContent("Source prompt", value: provenance.sourcePrompt)
                            .lineLimit(3)
                    }

                    if provenance.examples.isEmpty {
                        Text("This run records \(provenance.count) selected reference examples, but no per-example metadata was stored.")
                            .font(AppDesignSystem.Typography.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ForEach(provenance.examples) { example in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: AppDesignSystem.Spacing.xs) {
                                    Text(example.id)
                                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                                        .lineLimit(1)
                                    Spacer(minLength: AppDesignSystem.Spacing.xs)
                                    Text(example.referenceSource)
                                        .font(AppDesignSystem.Typography.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Text(example.visualIntent)
                                    .font(AppDesignSystem.Typography.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)

                                Text(example.contentSummary)
                                    .font(AppDesignSystem.Typography.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)

                                Text(example.imagePath)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(AppDesignSystem.Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppDesignSystem.Surfaces.content, in: RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppDesignSystem.Radius.panel, style: .continuous)
                                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                            }
                        }
                    }
                }
                .font(AppDesignSystem.Typography.body)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Reference examples")
            .accessibilityValue(provenance.summaryText)
        }
    }
}
