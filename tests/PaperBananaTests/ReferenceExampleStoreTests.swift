import Foundation
import XCTest
@testable import PaperBanana

@MainActor
final class ReferenceExampleStoreTests: XCTestCase {
    func testLoadValidDiagramReferenceExamples() throws {
        let repoRoot = try Self.makeRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        try Self.writeReferenceJSON(
            """
            [
              {
                "id": "diagram_002",
                "visual_intent": "Show a retrieval-augmented workflow.",
                "content": {"method": "Retrieve, plan, render, critique."},
                "path_to_gt_image": "images/diagram_002.png"
              },
              {
                "id": "diagram_001",
                "visual_intent": "Show an encoder-decoder model.",
                "content": "Encode tokens, attend over latent states, and decode labels.",
                "path_to_gt_image": "images/diagram_001.png"
              }
            ]
            """,
            repoRoot: repoRoot
        )
        try Self.writeBenchmarkImage("images/diagram_001.png", repoRoot: repoRoot)
        try Self.writeBenchmarkImage("images/diagram_002.png", repoRoot: repoRoot)

        let state = ReferenceExampleStore.loadState(repoRootPath: repoRoot.path)
        guard case .available(let examples) = state else {
            return XCTFail("Expected available examples, got \(state)")
        }

        XCTAssertEqual(examples.map(\.id), ["diagram_001", "diagram_002"])
        XCTAssertEqual(state.missingImageCount, 0)
        XCTAssertEqual(examples[0].visualIntent, "Show an encoder-decoder model.")
        XCTAssertEqual(examples[0].imageRelativePath, "images/diagram_001.png")
        XCTAssertTrue(examples[0].imageAvailable)
        XCTAssertEqual(
            examples[0].imageURL.path,
            repoRoot.appendingPathComponent("data/PaperBananaBench/diagram/images/diagram_001.png").path
        )
        XCTAssertTrue(examples[1].contentSummary.contains(#""method":"Retrieve, plan, render, critique.""#))
        XCTAssertTrue(examples[1].imageAvailable)
    }

    func testLoadDiagramReferenceExamplesSurfacesMissingImagesWithoutDisablingSelection() throws {
        let repoRoot = try Self.makeRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        try Self.writeReferenceJSON(
            """
            [
              {
                "id": "diagram_present",
                "visual_intent": "Show a complete local image reference.",
                "content": "Use the available local thumbnail.",
                "path_to_gt_image": "images/present.png"
              },
              {
                "id": "diagram_missing",
                "visual_intent": "Show a reference whose image path is absent.",
                "content": "The metadata remains useful even when the local image is missing.",
                "path_to_gt_image": "images/missing.png"
              }
            ]
            """,
            repoRoot: repoRoot
        )
        try Self.writeBenchmarkImage("images/present.png", repoRoot: repoRoot)

        let state = ReferenceExampleStore.loadState(repoRootPath: repoRoot.path)
        guard case .available(let examples) = state else {
            return XCTFail("Expected available examples, got \(state)")
        }

        XCTAssertEqual(examples.map(\.id), ["diagram_missing", "diagram_present"])
        XCTAssertEqual(state.missingImageCount, 1)
        XCTAssertEqual(state.missingImageExamples.map(\.id), ["diagram_missing"])
        XCTAssertEqual(state.statusDetail, "1 referenced image path is missing locally.")
        XCTAssertFalse(try XCTUnwrap(examples.first { $0.id == "diagram_missing" }).imageAvailable)
        XCTAssertTrue(try XCTUnwrap(examples.first { $0.id == "diagram_present" }).imageAvailable)

        let selected = ReferenceExampleStore()
        selected.load(repoRootPath: repoRoot.path)
        let selectedExamples = selected.selectedExamples(for: ["diagram_missing"])
        XCTAssertEqual(selectedExamples.map(\.id), ["diagram_missing"])
        let missingSelection = try XCTUnwrap(selectedExamples.first)
        XCTAssertNil(missingSelection.durablePayload["image_available"])
        XCTAssertNil(missingSelection.durablePayload["imageAvailable"])
    }

    func testMissingDatasetReportsDisabledState() throws {
        let repoRoot = try Self.makeRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let state = ReferenceExampleStore.loadState(repoRootPath: repoRoot.path)

        guard case .missing(let expectedURL) = state else {
            return XCTFail("Expected missing state, got \(state)")
        }
        XCTAssertTrue(expectedURL.path.hasSuffix("data/PaperBananaBench/diagram"))
        XCTAssertEqual(state.examples, [])
    }

    func testMalformedDatasetReportsErrorState() throws {
        let repoRoot = try Self.makeRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        try Self.writeReferenceJSON("{not json", repoRoot: repoRoot)

        let state = ReferenceExampleStore.loadState(repoRootPath: repoRoot.path)

        guard case .malformed(let url, let reason) = state else {
            return XCTFail("Expected malformed state, got \(state)")
        }
        XCTAssertEqual(url.lastPathComponent, "ref.json")
        XCTAssertFalse(reason.isEmpty)
    }

    func testEmptyDatasetReportsEmptyState() throws {
        let repoRoot = try Self.makeRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }
        try Self.writeReferenceJSON("[]", repoRoot: repoRoot)

        let state = ReferenceExampleStore.loadState(repoRootPath: repoRoot.path)

        guard case .empty(let url) = state else {
            return XCTFail("Expected empty state, got \(state)")
        }
        XCTAssertEqual(url.lastPathComponent, "ref.json")
    }

    func testSelectionCapKeepsFirstTenOrderedExamples() {
        let examples = (1...12).map { index in
            ReferenceExample(
                id: "diagram_\(String(format: "%03d", index))",
                visualIntent: "Intent \(index)",
                contentText: "Content \(index)",
                contentSummary: "Content \(index)",
                imageRelativePath: "images/\(index).png",
                imageURL: URL(fileURLWithPath: "/tmp/\(index).png")
            )
        }
        let selectedIDs = Set(examples.map(\.id))

        let limited = ReferenceExampleSelection.limitedIDs(selectedIDs, orderedExamples: examples)

        XCTAssertEqual(limited.count, ReferenceExampleSelection.maximumSelectionCount)
        XCTAssertTrue(limited.contains("diagram_001"))
        XCTAssertTrue(limited.contains("diagram_010"))
        XCTAssertFalse(limited.contains("diagram_011"))
        XCTAssertFalse(limited.contains("diagram_012"))
    }

    func testPromptEnrichmentIncludesSelectedReferenceFields() {
        let request = NativeImageGenerationRequest(
            prompt: "Create a concise model architecture diagram.",
            model: .nanoBananaPro,
            resolution: "2K",
            aspectRatio: "16:9",
            task: "scientific diagram",
            settings: Self.settings(repoPath: "/tmp/PaperBanana"),
            referenceExamples: [
                ReferenceExampleSelection(
                    id: "diagram_101",
                    visualIntent: "Compare pretraining and finetuning.",
                    contentSummary: "Two-stage pipeline with frozen encoder.",
                    imagePath: "images/diagram_101.png"
                )
            ]
        )

        XCTAssertTrue(request.providerPrompt.contains("Create a concise model architecture diagram."))
        XCTAssertTrue(request.providerPrompt.contains("Selected Reference Examples"))
        XCTAssertTrue(request.providerPrompt.contains("ID: diagram_101"))
        XCTAssertTrue(request.providerPrompt.contains("Visual intent: Compare pretraining and finetuning."))
        XCTAssertTrue(request.providerPrompt.contains("Content summary: Two-stage pipeline with frozen encoder."))
        XCTAssertTrue(request.providerPrompt.contains("Image path: images/diagram_101.png"))
    }

    private static func makeRepoRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaReferenceExamples-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func writeReferenceJSON(_ json: String, repoRoot: URL) throws {
        let directory = repoRoot.appendingPathComponent("data/PaperBananaBench/diagram", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: directory.appendingPathComponent("ref.json"), options: .atomic)
    }

    private static func writeBenchmarkImage(_ relativePath: String, repoRoot: URL) throws {
        let url = repoRoot
            .appendingPathComponent("data/PaperBananaBench/diagram", isDirectory: true)
            .appendingPathComponent(relativePath, isDirectory: false)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: url, options: .atomic)
    }

    private static func settings(repoPath: String) -> PaperBananaSettingsSnapshot {
        PaperBananaSettingsSnapshot(
            repoPath: repoPath,
            serverPort: 7860,
            defaultImageModel: .nanoBananaPro,
            codexModel: "gpt-5.5",
            codexReasoning: "xhigh",
            googleAPIKey: "",
            openRouterAPIKey: ""
        )
    }
}
