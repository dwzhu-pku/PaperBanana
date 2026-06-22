import Foundation

struct GoogleGeminiProviderClient: ProviderClient {
    let providerKind: ImageProviderKind = .googleGemini
    var endpointBaseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models")!
    var session: URLSession = .shared

    func execute(
        _ request: ProviderClientRequest,
        eventHandler: @escaping @Sendable (ProviderProgressEvent) -> Void
    ) async throws -> ProviderResponse {
        let apiKey = request.settings.googleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw ProviderRuntimeError.missingAPIKey("Google Gemini")
        }

        let callID = request.callID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "swift-gemini-\(UUID().uuidString)"
            : request.callID
        eventHandler(
            ProviderProgressEvent(
                stage: "model_call",
                progress: 45,
                message: "Calling image model \(request.effectiveModel).",
                callID: callID
            )
        )

        let body = try Self.makeGeminiPayload(for: request)
        if let providerRequestURL = request.providerRequestURL {
            try ProviderRequestPersistence.writeJSON(body, to: providerRequestURL)
            eventHandler(
                ProviderProgressEvent(
                    stage: "provider_request_saved",
                    progress: 43,
                    message: "Saved exact provider request body before network execution.",
                    callID: callID
                )
            )
        }
        var components = URLComponents(
            url: endpointBaseURL.appendingPathComponent("\(request.effectiveModel):generateContent"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else { throw ProviderRuntimeError.malformedProviderResponse }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = body

        let (data, response) = try await session.data(for: urlRequest)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            let bodyPreview = String(data: data.prefix(4096), encoding: .utf8) ?? ""
            throw ProviderRuntimeError.providerHTTPStatus(httpResponse.statusCode, bodyPreview, data)
        }

        let parsed: (imageData: Data?, text: String, usageMetadata: [String: String])
        do {
            parsed = try Self.extractImageAndText(from: data)
        } catch let error as ProviderRuntimeError {
            if error.rawProviderResponseData != nil {
                throw error
            }
            throw ProviderRuntimeError.malformedProviderResponseBody(error.localizedDescription, data)
        } catch {
            throw ProviderRuntimeError.malformedProviderResponseBody(error.localizedDescription, data)
        }

        eventHandler(
            ProviderProgressEvent(
                stage: "provider_response_saved",
                progress: 78,
                message: "Provider returned raw response bytes.",
                callID: callID
            )
        )
        return ProviderResponse(
            provider: providerKind,
            model: request.effectiveModel,
            callID: callID,
            rawResponseData: data,
            imageData: parsed.imageData,
            text: parsed.text,
            usageMetadata: parsed.usageMetadata
        )
    }

    private static func makeGeminiPayload(for request: ProviderClientRequest) throws -> Data {
        var parts: [[String: Any]] = []
        if let sourceImageURL = request.sourceImageURL {
            let imageData = try Data(contentsOf: sourceImageURL)
            parts.append([
                "inlineData": [
                    "mimeType": mimeType(for: sourceImageURL),
                    "data": imageData.base64EncodedString()
                ]
            ])
        }
        let taskSuffix = request.workflow == .generation
            ? "\n\nCreate a publication-quality academic \(request.task). Aspect ratio: \(request.aspectRatio). Resolution target: \(request.resolution)."
            : "\n\nModify the attached image. Preserve scientific meaning, panel labels, abbreviations, and legibility. Aspect ratio: \(request.aspectRatio). Resolution target: \(request.resolution)."
        parts.append(["text": request.prompt + taskSuffix])

        let payload: [String: Any] = [
            "contents": [
                ["parts": parts]
            ],
            "generationConfig": [
                "responseModalities": ["IMAGE", "TEXT"],
                "candidateCount": 1
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    private static func extractImageAndText(from data: Data) throws -> (imageData: Data?, text: String, usageMetadata: [String: String]) {
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderRuntimeError.malformedProviderResponse
        }
        let candidates = payload["candidates"] as? [[String: Any]] ?? []
        var imageData: Data?
        var textParts: [String] = []

        for candidate in candidates {
            guard let content = candidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else {
                continue
            }
            for part in parts {
                if let text = part["text"] as? String, !text.isEmpty {
                    textParts.append(text)
                }
                let inlineData = (part["inlineData"] as? [String: Any]) ?? (part["inline_data"] as? [String: Any])
                if let encoded = inlineData?["data"] as? String,
                   let decoded = Data(base64Encoded: encoded) {
                    imageData = decoded
                }
            }
        }

        var usage: [String: String] = [:]
        if let usagePayload = payload["usageMetadata"] as? [String: Any] {
            for (key, value) in usagePayload {
                usage[key] = "\(value)"
            }
        }
        return (imageData, textParts.joined(separator: "\n\n"), usage)
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            "image/jpeg"
        case "webp":
            "image/webp"
        default:
            "image/png"
        }
    }
}
