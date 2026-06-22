import AppKit
import Foundation
import XCTest
@testable import PaperBanana

final class NativeArtifactSecretLeakTests: XCTestCase {
    private let googleSentinel = "test-google-sentinel-AIza-secret"
    private let openRouterSentinel = "test-openrouter-sentinel-sk-secret"

    @MainActor
    func testGenerationDryRunArtifactsDoNotPersistConfiguredProviderSecrets() async throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let store = NativeImageGenerationStore(stallWarningInterval: 60, hardTimeoutInterval: 120)
        let outputURL = await withCheckedContinuation { continuation in
            store.start(
                request: NativeImageGenerationRequest(
                    prompt: "Create a no-spend sentinel generation artifact scan.",
                    model: .nanoBananaPro,
                    resolution: "2K",
                    aspectRatio: "16:9",
                    task: "scientific diagram",
                    settings: settings(repoRoot: repoRoot),
                    executionMode: .dryRun
                ),
                onCompletion: { url in
                    continuation.resume(returning: url)
                }
            )
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(store.runState, .complete(outputURL))
        try assertNoSecretMarkersPersisted(under: repoRoot)
    }

    @MainActor
    func testRefinementDryRunArtifactsDoNotPersistConfiguredProviderSecrets() async throws {
        let repoRoot = try Self.makeTemporaryRepoRoot()
        defer { try? FileManager.default.removeItem(at: repoRoot) }

        let sourceURL = repoRoot.appendingPathComponent("source.png")
        try Self.writeTinyPNG(to: sourceURL)

        let store = NativeRefinementStore(stallWarningInterval: 60, hardTimeoutInterval: 120)
        let outputURL = await withCheckedContinuation { continuation in
            store.start(
                request: NativeRefinementRequest(
                    sourceURL: sourceURL,
                    prompt: "Create a no-spend sentinel refinement artifact scan.",
                    model: .nanoBananaPro,
                    resolution: "2K",
                    aspectRatio: "16:9",
                    settings: settings(repoRoot: repoRoot),
                    executionMode: .dryRun
                ),
                onCompletion: { url in
                    continuation.resume(returning: url)
                }
            )
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(store.runState, .complete(outputURL))
        try assertNoSecretMarkersPersisted(under: repoRoot)
    }

    private func settings(repoRoot: URL) -> PaperBananaSettingsSnapshot {
        PaperBananaSettingsSnapshot(
            repoPath: repoRoot.path,
            serverPort: 7860,
            defaultImageModel: .nanoBananaPro,
            codexModel: "gpt-5.5",
            codexReasoning: "xhigh",
            googleAPIKey: googleSentinel,
            openRouterAPIKey: openRouterSentinel
        )
    }

    private func assertNoSecretMarkersPersisted(under repoRoot: URL) throws {
        let resultsURL = repoRoot.appendingPathComponent("results", isDirectory: true)
        let files = try Self.regularFiles(under: resultsURL)
        XCTAssertFalse(files.isEmpty, "Expected native dry-run artifacts under \(resultsURL.path)")

        let forbiddenMarkers = [
            googleSentinel,
            openRouterSentinel,
            "GOOGLE_API_KEY",
            "OPENROUTER_API_KEY",
            "Authorization",
            "Bearer"
        ]

        for file in files {
            let data = try Data(contentsOf: file)
            for marker in forbiddenMarkers {
                let markerData = Data(marker.utf8)
                XCTAssertNil(
                    data.range(of: markerData),
                    "Forbidden marker \(marker) persisted in \(file.path)"
                )
            }
        }
    }

    private static func makeTemporaryRepoRoot() throws -> URL {
        let repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaArtifactSecretLeak-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
        return repoRoot
    }

    private static func regularFiles(under root: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        let keys: Set<URLResourceKey> = [.isRegularFileKey]
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )
        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            let values = try url.resourceValues(forKeys: keys)
            if values.isRegularFile == true {
                files.append(url)
            }
        }
        return files.sorted { $0.path < $1.path }
    }

    private static func writeTinyPNG(to url: URL) throws {
        try tinyPNGData.write(to: url)
    }

    private static var tinyPNGData: Data {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 4,
            bitsPerPixel: 32
        )!
        bitmap.setColor(NSColor(calibratedRed: 0.2, green: 0.7, blue: 1, alpha: 1), atX: 0, y: 0)
        return bitmap.representation(using: .png, properties: [:])!
    }
}
