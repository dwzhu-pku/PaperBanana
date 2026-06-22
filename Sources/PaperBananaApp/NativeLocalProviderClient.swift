import AppKit
import Foundation

struct NativeLocalProviderClient: ProviderClient {
    enum Mode: String, Sendable {
        case dryRun = "dry_run"
        case mockValid = "mock_valid"
        case mockInvalidPayload = "mock_invalid_payload"

        var message: String {
            switch self {
            case .dryRun:
                "Completed local dry run without provider spend."
            case .mockValid:
                "Completed local mock provider response without provider spend."
            case .mockInvalidPayload:
                "Returned local mock invalid image payload without provider spend."
            }
        }
    }

    let providerKind: ImageProviderKind
    let mode: Mode

    init(providerKind: ImageProviderKind, mode: Mode) {
        self.providerKind = providerKind
        self.mode = mode
    }

    func execute(
        _ request: ProviderClientRequest,
        eventHandler: @escaping @Sendable (ProviderProgressEvent) -> Void
    ) async throws -> ProviderResponse {
        let callID = request.callID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "swift-local-\(UUID().uuidString)"
            : request.callID

        eventHandler(
            ProviderProgressEvent(
                stage: "prepared",
                progress: 10,
                message: "Prepared local Swift provider execution.",
                callID: callID
            )
        )

        if let providerRequestURL = request.providerRequestURL {
            let manifest = try providerRequestManifest(for: request, callID: callID)
            try ProviderRequestPersistence.writeJSON(manifest, to: providerRequestURL)
            eventHandler(
                ProviderProgressEvent(
                    stage: "provider_request_saved",
                    progress: 12,
                    message: "Saved local Swift provider request manifest before execution.",
                    callID: callID
                )
            )
        }

        eventHandler(
            ProviderProgressEvent(
                stage: "model_call",
                progress: 45,
                message: "Running local Swift \(mode.rawValue) provider path.",
                callID: callID
            )
        )

        let imageData = try responseImageData(for: request)
        let rawResponseData = try rawResponseData(for: request, callID: callID, imageData: imageData)

        eventHandler(
            ProviderProgressEvent(
                stage: "provider_response_saved",
                progress: 78,
                message: "Local Swift provider returned response bytes.",
                callID: callID
            )
        )

        return ProviderResponse(
            provider: providerKind,
            model: request.effectiveModel,
            callID: callID,
            rawResponseData: rawResponseData,
            imageData: imageData,
            text: mode.message,
            usageMetadata: [
                "adapter": "swift_local",
                "local_mode": mode.rawValue,
                "provider_spend": "none"
            ]
        )
    }

    private func responseImageData(for request: ProviderClientRequest) throws -> Data {
        switch mode {
        case .dryRun, .mockValid:
            if request.workflow == .refinement {
                guard let sourceImageURL = request.sourceImageURL else {
                    throw ProviderRuntimeError.missingSourceImage
                }
                return try Data(contentsOf: sourceImageURL)
            }
            return try Self.makePlaceholderPNG()
        case .mockInvalidPayload:
            return Data("swift-local-invalid-image-payload-\(request.runID)".utf8)
        }
    }

    private func providerRequestManifest(for request: ProviderClientRequest, callID: String) throws -> Data {
        var manifest: [String: Any] = [
            "adapter": "swift_local",
            "mode": mode.rawValue,
            "run_id": request.runID,
            "call_id": callID,
            "workflow": request.workflow.rawValue,
            "provider": providerKind.rawValue,
            "model": request.effectiveModel,
            "requested_model": request.model.backendValue,
            "resolution": request.resolution,
            "aspect_ratio": request.aspectRatio,
            "task": request.task,
            "prompt": request.prompt,
            "provider_spend": "none",
            "local_execution": true,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        if let sourceImageURL = request.sourceImageURL {
            manifest["source_image_path"] = sourceImageURL.path
        }
        if let outputURL = request.outputURL {
            manifest["output_path"] = outputURL.path
        }
        return try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
    }

    private func rawResponseData(for request: ProviderClientRequest, callID: String, imageData: Data) throws -> Data {
        let payload: [String: Any] = [
            "adapter": "swift_local",
            "mode": mode.rawValue,
            "run_id": request.runID,
            "call_id": callID,
            "workflow": request.workflow.rawValue,
            "provider": providerKind.rawValue,
            "model": request.effectiveModel,
            "message": mode.message,
            "image_bytes": imageData.count,
            "provider_spend": "none",
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    private static func makePlaceholderPNG() throws -> Data {
        let width = 16
        let height = 9
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }

        for y in 0..<height {
            for x in 0..<width {
                let red = CGFloat(x) / CGFloat(max(width - 1, 1))
                let green = CGFloat(y) / CGFloat(max(height - 1, 1))
                bitmap.setColor(
                    NSColor(calibratedRed: red, green: green, blue: 0.45, alpha: 1),
                    atX: x,
                    y: y
                )
            }
        }

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
}
