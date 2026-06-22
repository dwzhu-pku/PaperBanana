import Foundation

enum ReferenceExampleLoadState: Equatable {
    case idle
    case available([ReferenceExample])
    case missing(URL)
    case malformed(URL, String)
    case empty(URL)

    var examples: [ReferenceExample] {
        switch self {
        case .available(let examples):
            examples
        case .idle, .missing, .malformed, .empty:
            []
        }
    }

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    var statusTitle: String {
        switch self {
        case .idle:
            "Not Loaded"
        case .available(let examples):
            "\(examples.count) Examples"
        case .missing:
            "Dataset Missing"
        case .malformed:
            "Dataset Unreadable"
        case .empty:
            "No Examples"
        }
    }

    var statusDetail: String {
        switch self {
        case .idle:
            "PaperBanana has not scanned the local benchmark yet."
        case .available:
            "Manual diagram examples can enrich the next native generation prompt."
        case .missing(let url):
            "Expected local benchmark data at \(url.path)."
        case .malformed(_, let reason):
            reason
        case .empty(let url):
            "The benchmark reference file contains no examples: \(url.path)."
        }
    }
}

@MainActor
final class ReferenceExampleStore: ObservableObject {
    @Published private(set) var state: ReferenceExampleLoadState = .idle

    func load(repoRootPath: String, fileManager: FileManager = .default) {
        state = Self.loadState(repoRootPath: repoRootPath, fileManager: fileManager)
    }

    func selectedExamples(for ids: Set<String>) -> [ReferenceExampleSelection] {
        let limitedIDs = ReferenceExampleSelection.limitedIDs(ids, orderedExamples: state.examples)
        return state.examples
            .filter { limitedIDs.contains($0.id) }
            .prefix(ReferenceExampleSelection.maximumSelectionCount)
            .map(\.selection)
    }

    static func loadState(
        repoRootPath: String,
        fileManager: FileManager = .default
    ) -> ReferenceExampleLoadState {
        let repoRoot = URL(fileURLWithPath: repoRootPath, isDirectory: true).standardizedFileURL
        let benchmarkRoot = repoRoot.appendingPathComponent("data/PaperBananaBench/diagram", isDirectory: true)
        let refURL = benchmarkRoot.appendingPathComponent("ref.json", isDirectory: false)

        guard fileManager.fileExists(atPath: refURL.path) else {
            return .missing(benchmarkRoot)
        }

        do {
            let examples = try loadExamples(refURL: refURL, benchmarkRoot: benchmarkRoot)
            guard !examples.isEmpty else { return .empty(refURL) }
            return .available(examples)
        } catch {
            return .malformed(refURL, error.localizedDescription)
        }
    }

    private static func loadExamples(refURL: URL, benchmarkRoot: URL) throws -> [ReferenceExample] {
        let data = try Data(contentsOf: refURL)
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ReferenceExampleStoreError.expectedArray
        }

        return payload.compactMap { item in
            guard let id = nonEmptyString(item["id"]),
                  let visualIntent = nonEmptyString(item["visual_intent"]),
                  let imagePath = nonEmptyString(item["path_to_gt_image"]) else {
                return nil
            }

            let contentText = normalizedString(from: item["content"] ?? "")
            return ReferenceExample(
                id: id,
                visualIntent: visualIntent,
                contentText: contentText,
                contentSummary: summary(contentText, limit: 360),
                imageRelativePath: imagePath,
                imageURL: benchmarkRoot.appendingPathComponent(imagePath, isDirectory: false)
            )
        }
        .sorted { lhs, rhs in
            lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
        }
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedString(from value: Any) -> String {
        if value is NSNull { return "" }
        if let string = value as? String {
            return string.collapsedWhitespace
        }
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            return string.collapsedWhitespace
        }
        return "\(value)".collapsedWhitespace
    }

    private static func summary(_ value: String, limit: Int) -> String {
        let collapsed = value.collapsedWhitespace
        guard collapsed.count > limit else { return collapsed }
        let end = collapsed.index(collapsed.startIndex, offsetBy: limit)
        return String(collapsed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}

private enum ReferenceExampleStoreError: LocalizedError {
    case expectedArray

    var errorDescription: String? {
        switch self {
        case .expectedArray:
            "Expected PaperBananaBench diagram ref.json to contain an array of examples."
        }
    }
}

private extension String {
    var collapsedWhitespace: String {
        components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
