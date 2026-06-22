import CoreSpotlight
import XCTest
@testable import PaperBanana

final class ArtifactLibraryScannerTests: XCTestCase {
    func testScannerFindsSupportedArtifactsAndCompanions() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaScannerTests-\(UUID().uuidString)", isDirectory: true)
        let results = root.appendingPathComponent("results/demo/candidates", isDirectory: true)
        let handoff = root.appendingPathComponent(".paperbanana_codex_handoff", isDirectory: true)
        try FileManager.default.createDirectory(at: results, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: handoff, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let image = results.appendingPathComponent("candidate_0.png")
        let metadata = root.appendingPathComponent("results/demo/demo.json")
        let prompt = handoff.appendingPathComponent("candidate_0.prompt.md")
        let ignored = results.appendingPathComponent("notes.txt")

        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: image)
        try Data("{}".utf8).write(to: metadata)
        try Data("# Prompt".utf8).write(to: prompt)
        try Data("ignored".utf8).write(to: ignored)

        let artifacts = ArtifactLibraryScanner.scan(repoRootPath: root.path)
        let imageArtifact = try XCTUnwrap(artifacts.first { $0.url.lastPathComponent == "candidate_0.png" })

        XCTAssertEqual(artifacts.count, 2)
        XCTAssertEqual(imageArtifact.kind, .image)
        XCTAssertEqual(imageArtifact.workflow, "demo")
        XCTAssertEqual(imageArtifact.promptURL?.standardizedFileURL, prompt.standardizedFileURL)
        XCTAssertEqual(imageArtifact.metadataURL?.standardizedFileURL, metadata.standardizedFileURL)
        XCTAssertFalse(artifacts.contains { $0.url.lastPathComponent == "notes.txt" })
    }

    func testNativeRefinementLineageParsesCompanionMetadata() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaLineageTests-\(UUID().uuidString)", isDirectory: true)
        let outputDirectory = root.appendingPathComponent("results/native_refine", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = outputDirectory.appendingPathComponent("candidate_0.png")
        let output = outputDirectory.appendingPathComponent("candidate_0_refined_4K.png")
        let metadata = outputDirectory.appendingPathComponent("candidate_0_refined_4K.json")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: source)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: output)
        try Data(
            """
            {
              "source_path": "\(source.path)",
              "output_path": "\(output.path)",
              "prompt": "Improve label clarity.",
              "model": "gemini-3-pro-image-preview",
              "resolution": "4K",
              "aspect_ratio": "16:9",
              "provider_message": "Image refined successfully!",
              "created_at": "2026-04-28T21:49:27",
              "workflow": "native_refine"
            }
            """.utf8
        ).write(to: metadata)

        let artifact = try XCTUnwrap(ArtifactLibraryScanner.scan(repoRootPath: root.path).first { $0.url == output.standardizedFileURL })
        let lineage = try XCTUnwrap(artifact.refinementLineage)

        XCTAssertEqual(lineage.sourceURL.standardizedFileURL, source.standardizedFileURL)
        XCTAssertEqual(lineage.outputURL.standardizedFileURL, output.standardizedFileURL)
        XCTAssertEqual(lineage.prompt, "Improve label clarity.")
        XCTAssertEqual(lineage.modelLabel, "Nano Banana Pro")
        XCTAssertEqual(lineage.resolution, "4K")
        XCTAssertEqual(lineage.aspectRatio, "16:9")
        XCTAssertEqual(lineage.providerMessage, "Image refined successfully!")
        XCTAssertEqual(lineage.workflow, "native_refine")
        XCTAssertTrue(artifact.wasNativeRefined)
    }

    func testNativeRunFolderIndexesStatusPromptAndEventLog() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaNativeRunFolderTests-\(UUID().uuidString)", isDirectory: true)
        let runDirectory = root.appendingPathComponent("results/native_refine/native_refine_test_001", isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let output = runDirectory.appendingPathComponent("candidate_0_refined_4K.png")
        let metadata = runDirectory.appendingPathComponent("candidate_0_refined_4K.json")
        let prompt = runDirectory.appendingPathComponent("prompt.txt")
        let eventLog = runDirectory.appendingPathComponent("events.jsonl")

        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: output)
        try Data("Improve labels.".utf8).write(to: prompt)
        try [
            #"{"stage":"queued","progress":0,"message":"Queued","run_id":"native_refine_test_001","run_dir":"\#(runDirectory.path)"}"#,
            #"{"stage":"timeout","progress":82,"message":"No provider progress","run_id":"native_refine_test_001","run_dir":"\#(runDirectory.path)"}"#
        ].joined(separator: "\n").write(to: eventLog, atomically: true, encoding: .utf8)
        try Data(
            """
            {
              "run_id": "native_refine_test_001",
              "run_dir": "\(runDirectory.path)",
              "source_path": "\(output.path)",
              "output_path": "\(output.path)",
              "prompt_path": "\(prompt.path)",
              "log_path": "\(eventLog.path)",
              "prompt": "Improve labels.",
              "model": "gemini-3-pro-image-preview",
              "resolution": "4K",
              "aspect_ratio": "16:9",
              "source_prompt": "Improve labels.",
              "reference_mode": "manual_native_prompt_enrichment",
              "reference_example_count": 1,
              "reference_examples": [
                {
                  "id": "ref_artifact",
                  "visual_intent": "Show a native generation workflow.",
                  "content_summary": "A concise panel layout with labeled data flow.",
                  "image_path": "images/ref_artifact.jpg",
                  "reference_source": "PaperBananaBench/diagram"
                }
              ],
              "provider_message": "Timed out",
              "workflow": "native_refine"
            }
            """.utf8
        ).write(to: metadata)

        let artifact = try XCTUnwrap(ArtifactLibraryScanner.scan(repoRootPath: root.path).first { $0.url == output.standardizedFileURL })

        XCTAssertEqual(artifact.runID, "native_refine_test_001")
        XCTAssertEqual(artifact.runDirectoryURL?.standardizedFileURL, runDirectory.standardizedFileURL)
        XCTAssertEqual(artifact.runStatus, .timedOut)
        XCTAssertEqual(artifact.promptURL?.standardizedFileURL, prompt.standardizedFileURL)
        XCTAssertEqual(artifact.logURL?.standardizedFileURL, eventLog.standardizedFileURL)
        XCTAssertEqual(artifact.metadataURL?.standardizedFileURL, metadata.standardizedFileURL)
        XCTAssertTrue(artifact.referenceProvenance.isManual)
        XCTAssertEqual(artifact.referenceProvenance.examples.first?.id, "ref_artifact")
        XCTAssertTrue(artifact.referenceProvenance.searchableText.contains("labeled data flow"))
    }

    func testNativeRunIndexSurfacesFailedRunWithRawPayloadAndTimeline() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaFailedNativeRunTests-\(UUID().uuidString)", isDirectory: true)
        let resultsRoot = root.appendingPathComponent("results", isDirectory: true)
        let runDirectory = resultsRoot.appendingPathComponent("native_refine/native_refine_failed_001", isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let prompt = runDirectory.appendingPathComponent("prompt.txt")
        let eventLog = runDirectory.appendingPathComponent("events.jsonl")
        let rawPayload = runDirectory.appendingPathComponent("source_refined_4K_provider_raw_20260429.bin")

        try Data("Refine this image at 4K.".utf8).write(to: prompt)
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: rawPayload)
        try [
            #"{"stage":"queued","progress":0,"message":"Queued","run_id":"native_refine_failed_001","run_dir":"\#(runDirectory.path)","timestamp":"2026-04-29T00:24:01"}"#,
            #"{"stage":"saving","progress":88,"message":"Saving provider response","run_id":"native_refine_failed_001","run_dir":"\#(runDirectory.path)","timestamp":"2026-04-29T00:26:12","raw_path":"\#(rawPayload.path)"}"#,
            #"{"stage":"failed","progress":100,"message":"Provider payload could not be decoded","run_id":"native_refine_failed_001","run_dir":"\#(runDirectory.path)","timestamp":"2026-04-29T00:26:13","raw_path":"\#(rawPayload.path)"}"#
        ].joined(separator: "\n").write(to: eventLog, atomically: true, encoding: .utf8)

        let index = NativeRunFolderIndex.scan(resultsRoot: resultsRoot)
        let record = try XCTUnwrap(index.records.first { $0.runID == "native_refine_failed_001" })

        XCTAssertEqual(record.status, .failed)
        XCTAssertTrue(record.needsAttention)
        XCTAssertEqual(record.artifactURLs, [])
        XCTAssertEqual(record.promptURL?.standardizedFileURL, prompt.standardizedFileURL)
        XCTAssertEqual(record.eventLogURL?.standardizedFileURL, eventLog.standardizedFileURL)
        XCTAssertEqual(record.rawPayloadURLs.map(\.standardizedFileURL), [rawPayload.standardizedFileURL])
        XCTAssertEqual(record.events.map(\.stage), ["queued", "saving", "failed"])
        XCTAssertEqual(record.events.last?.message, "Provider payload could not be decoded")
        XCTAssertEqual(record.events.last?.rawURL?.standardizedFileURL, rawPayload.standardizedFileURL)
    }

    func testRunDetailsScannerJoinsNativeRunsToProviderLedgerCalls() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaRunDetailsTests-\(UUID().uuidString)", isDirectory: true)
        let resultsRoot = root.appendingPathComponent("results", isDirectory: true)
        let runDirectory = resultsRoot.appendingPathComponent("native_refine/native_refine_joined_001", isDirectory: true)
        let auditDirectory = resultsRoot.appendingPathComponent("provider_audit", isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: auditDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let output = runDirectory.appendingPathComponent("source_refined_4K.png")
        let metadata = runDirectory.appendingPathComponent("source_refined_4K.json")
        let prompt = runDirectory.appendingPathComponent("prompt.txt")
        let eventLog = runDirectory.appendingPathComponent("events.jsonl")
        let auditLog = auditDirectory.appendingPathComponent("provider_calls_20260429.jsonl")

        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: output)
        try Data("Sharpen the labels.".utf8).write(to: prompt)
        try [
            #"{"stage":"queued","progress":0,"message":"Queued","run_id":"native_refine_joined_001","run_dir":"\#(runDirectory.path)"}"#,
            #"{"stage":"complete","progress":100,"message":"Image refined successfully","run_id":"native_refine_joined_001","run_dir":"\#(runDirectory.path)","output_path":"\#(output.path)","metadata_path":"\#(metadata.path)"}"#
        ].joined(separator: "\n").write(to: eventLog, atomically: true, encoding: .utf8)
        try Data(
            """
            {
              "run_id": "native_refine_joined_001",
              "run_dir": "\(runDirectory.path)",
              "output_path": "\(output.path)",
              "prompt_path": "\(prompt.path)",
              "log_path": "\(eventLog.path)",
              "prompt": "Sharpen the labels.",
              "model": "gemini-3-pro-image-preview",
              "resolution": "4K",
              "aspect_ratio": "16:9",
              "provider_message": "Image refined successfully",
              "workflow": "native_refine"
            }
            """.utf8
        ).write(to: metadata)
        try [
            #"{"event":"started","call_id":"call-joined-001","run_id":"native_refine_joined_001","provider":"google","model":"gemini-3-pro-image-preview","operation":"refine","prompt":"Sharpen the labels.","resolution":"4K","aspect_ratio":"16:9","created_at":"2026-04-29T00:24:01","run_dir":"\#(runDirectory.path)"}"#,
            #"{"event":"finished","call_id":"call-joined-001","run_id":"native_refine_joined_001","provider":"google","model":"gemini-3-pro-image-preview","operation":"refine","status":"completed","created_at":"2026-04-29T00:26:13","artifact_paths":["\#(output.path)"],"native_metadata_path":"\#(metadata.path)"}"#
        ].joined(separator: "\n").write(to: auditLog, atomically: true, encoding: .utf8)

        let item = try XCTUnwrap(RunDetailsScanner.scan(repoRootPath: root.path).first { $0.run.runID == "native_refine_joined_001" })

        XCTAssertFalse(item.needsAttention)
        XCTAssertEqual(item.run.status, .completed)
        XCTAssertEqual(item.run.artifactURLs.map(\.standardizedFileURL), [output.standardizedFileURL])
        XCTAssertEqual(item.providerCalls.map(\.callID), ["call-joined-001"])
        XCTAssertEqual(item.providerCalls.first?.nativeArtifactURLs.map(\.standardizedFileURL), [output.standardizedFileURL])
    }

    func testRunDetailsScannerSurfacesProviderCallsWithoutNativeRunFolder() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaOrphanRunDetailsTests-\(UUID().uuidString)", isDirectory: true)
        let auditDirectory = root.appendingPathComponent("results/provider_audit", isDirectory: true)
        try FileManager.default.createDirectory(at: auditDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let auditLog = auditDirectory.appendingPathComponent("provider_calls_20260429.jsonl")
        try [
            #"{"timestamp":"2026-04-29T01:00:00.000Z","run_id":"native_refine_orphan_001","event":"provider_call_started","call_id":"orphan-call-001","provider":"gemini","model":"gemini-3-pro-image-preview","modality":"image","context":"refine","attempt":1,"max_attempts":1}"#,
            #"{"timestamp":"2026-04-29T01:00:03.000Z","run_id":"native_refine_orphan_001","event":"provider_call_finished","call_id":"orphan-call-001","provider":"gemini","model":"gemini-3-pro-image-preview","modality":"image","context":"refine","attempt":1,"success":true,"response_count":1,"artifacts":[],"message":"Image response received."}"#
        ].joined(separator: "\n").write(to: auditLog, atomically: true, encoding: .utf8)

        let item = try XCTUnwrap(RunDetailsScanner.scan(repoRootPath: root.path).first { $0.title == "native_refine_orphan_001" })

        XCTAssertTrue(item.needsAttention)
        XCTAssertEqual(item.run.status, .unknown)
        XCTAssertEqual(item.run.directoryURL.standardizedFileURL, auditDirectory.standardizedFileURL)
        XCTAssertEqual(item.run.artifactURLs, [])
        XCTAssertEqual(item.providerCalls.map(\.callID), ["orphan-call-001"])
        XCTAssertEqual(item.providerCalls.first?.status, .missingArtifact)
    }

    func testRecoveredArtifactsAreMarkedForDedicatedLibraryView() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaRecoveredTests-\(UUID().uuidString)", isDirectory: true)
        let recovered = root.appendingPathComponent("results/recovered", isDirectory: true)
        try FileManager.default.createDirectory(at: recovered, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let image = recovered.appendingPathComponent("PaperBanana_Recovered_CIED_Workflow.png")
        let metadata = recovered.appendingPathComponent("PaperBanana_Recovered_CIED_Workflow.json")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: image)
        try Data("{}".utf8).write(to: metadata)

        let artifact = try XCTUnwrap(ArtifactLibraryScanner.scan(repoRootPath: root.path).first { $0.url == image.standardizedFileURL })

        XCTAssertEqual(artifact.workflow, "recovered")
        XCTAssertTrue(artifact.isRecovered)
        XCTAssertEqual(artifact.metadataURL?.standardizedFileURL, metadata.standardizedFileURL)
    }

    func testSpotlightItemsContainArtifactMetadata() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaSpotlightTests-\(UUID().uuidString)", isDirectory: true)
        let results = root.appendingPathComponent("results/native_generate/native_generate_spotlight", isDirectory: true)
        try FileManager.default.createDirectory(at: results, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let image = results.appendingPathComponent("generated_4K.png")
        try Self.writeTinyPNG(to: image)

        let artifact = try XCTUnwrap(ArtifactLibraryScanner.scan(repoRootPath: root.path).first { $0.url == image.standardizedFileURL })
        let item = try XCTUnwrap(PaperBananaSpotlightIndexer.searchableItems(artifacts: [artifact], runs: []).first)

        XCTAssertEqual(item.domainIdentifier, PaperBananaSpotlightIndexer.artifactDomain)
        XCTAssertTrue(item.uniqueIdentifier.contains(image.path))
        XCTAssertEqual(item.attributeSet.title, "generated_4K")
        XCTAssertTrue(item.attributeSet.keywords?.contains("PaperBanana") == true)
        XCTAssertTrue(item.attributeSet.keywords?.contains("PaperBanana artifact") == true)
        XCTAssertTrue(item.attributeSet.contentDescription?.contains("Workflow: native_generate") == true)
        XCTAssertTrue(item.attributeSet.contentDescription?.contains("Project: PaperBanana") == true)
    }

    func testSpotlightItemsContainProviderCallRecoveryMetadata() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaProviderCallSpotlightTests-\(UUID().uuidString)", isDirectory: true)
        let runDirectory = root.appendingPathComponent("results/native_refine/native_refine_spotlight", isDirectory: true)
        let auditDirectory = root.appendingPathComponent("results/provider_audit", isDirectory: true)
        let rawDirectory = auditDirectory.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rawDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let providerRequest = runDirectory.appendingPathComponent("provider_request.json")
        let rawPayload = rawDirectory.appendingPathComponent("provider_raw_payload.bin")
        let auditLog = auditDirectory.appendingPathComponent("provider_calls_20260614.jsonl")
        try Data(#"{"adapter":"swift_gemini","call_id":"spotlight-call"}"#.utf8).write(to: providerRequest)
        try Data("raw paid provider bytes".utf8).write(to: rawPayload)
        try Data("{}".utf8).write(to: auditLog)

        let call = ProviderRunLedgerCall(
            callID: "spotlight-call",
            runID: "native_refine_spotlight",
            provider: "gemini",
            model: "gemini-3-pro-image-preview",
            modality: "image",
            context: "native_refine",
            status: .rawRecovered,
            startedAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_200),
            attempt: 1,
            maxAttempts: 1,
            responseCount: 1,
            message: "Provider returned bytes that could not be decoded.",
            error: "Decode failed after provider spend.",
            usageMetadata: ["totalTokenCount": "42"],
            artifactURLs: [],
            rawArtifactURLs: [rawPayload],
            runDirectoryURL: runDirectory,
            nativeArtifactURLs: [],
            nativePromptURL: runDirectory.appendingPathComponent("prompt.txt"),
            nativeRequestURL: runDirectory.appendingPathComponent("request.json"),
            nativeProviderRequestURL: providerRequest,
            nativeEventLogURL: runDirectory.appendingPathComponent("events.jsonl"),
            auditLogURL: auditLog
        )

        let item = try XCTUnwrap(
            PaperBananaSpotlightIndexer
                .searchableItems(artifacts: [], runs: [], providerCalls: [call])
                .first
        )

        XCTAssertEqual(item.domainIdentifier, PaperBananaSpotlightIndexer.providerCallDomain)
        XCTAssertEqual(item.uniqueIdentifier, "provider-call:spotlight-call")
        XCTAssertEqual(item.attributeSet.title, "spotlight-call")
        XCTAssertEqual(item.attributeSet.relatedUniqueIdentifier, "native_refine_spotlight")
        XCTAssertTrue(item.attributeSet.keywords?.contains("Nano Banana Pro") == true)
        XCTAssertTrue(item.attributeSet.keywords?.contains("rawRecovered") == true)
        XCTAssertTrue(item.attributeSet.keywords?.contains("recoverable") == true)
        XCTAssertTrue(item.attributeSet.keywords?.contains("totalTokenCount: 42") == true)
        XCTAssertTrue(item.attributeSet.contentDescription?.contains("Provider: gemini") == true)
        XCTAssertTrue(item.attributeSet.contentDescription?.contains("Status: Raw recovered") == true)
        XCTAssertTrue(item.attributeSet.contentDescription?.contains("Provider Request: \(providerRequest.path)") == true)
        XCTAssertTrue(item.attributeSet.contentDescription?.contains("Raw Artifacts: \(rawPayload.path)") == true)
        XCTAssertEqual(item.attributeSet.contentURL?.standardizedFileURL, rawPayload.standardizedFileURL)
    }

    @MainActor
    func testShortcutLatest4KOutputResolverSelectsNewestMatchingArtifact() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaShortcutLatestTests-\(UUID().uuidString)", isDirectory: true)
        let olderResults = root.appendingPathComponent("results/native_generate/native_generate_old", isDirectory: true)
        let newerResults = root.appendingPathComponent("results/native_refine/native_refine_new", isDirectory: true)
        try FileManager.default.createDirectory(at: olderResults, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newerResults, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let older = olderResults.appendingPathComponent("generated_4K.png")
        let newer = newerResults.appendingPathComponent("refined_4K.png")
        try Self.writeTinyPNG(to: older)
        try Self.writeTinyPNG(to: newer)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_000)],
            ofItemAtPath: older.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 2_000)],
            ofItemAtPath: newer.path
        )

        let latest = PaperBananaShortcutActions.latest4KOutputURL(repoRootPath: root.path)

        XCTAssertEqual(latest?.standardizedFileURL, newer.standardizedFileURL)
    }

    func testImageQualityInspectorReadsImageDimensionsAndWarnings() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaImageQualityTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let image = root.appendingPathComponent("tiny.png")
        try Self.writeTinyPNG(to: image)

        let report = try XCTUnwrap(PaperBananaImageQualityInspector.inspect(image))

        XCTAssertEqual(report.pixelWidth, 1)
        XCTAssertEqual(report.pixelHeight, 1)
        XCTAssertEqual(report.resolutionText, "1x1")
        XCTAssertEqual(report.megapixelsText, "0.0 MP")
        XCTAssertTrue(report.warnings.contains("Shortest edge is under 1K."))
        XCTAssertTrue(report.targetWarnings(for: "4K").contains { $0.contains("4K target expects long edge") })
        XCTAssertTrue(report.targetWarnings(for: "4K").contains { $0.contains("4K target expects at least 6.0 MP") })
    }

    private static func writeTinyPNG(to url: URL) throws {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC"
        try Data(base64Encoded: base64)!.write(to: url)
    }
}
