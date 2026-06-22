import Foundation

struct OpenRouterProviderClient: ProviderClient {
    let providerKind: ImageProviderKind = .openRouter
    var endpointURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    var session: URLSession = .shared

    func execute(
        _ request: ProviderClientRequest,
        eventHandler: @escaping @Sendable (ProviderProgressEvent) -> Void
    ) async throws -> ProviderResponse {
        let apiKey = request.settings.openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw ProviderRuntimeError.missingAPIKey("OpenRouter")
        }

        let callID = request.callID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "swift-openrouter-\(UUID().uuidString)"
            : request.callID
        eventHandler(
            ProviderProgressEvent(
                stage: "model_call",
                progress: 45,
                message: "Calling OpenRouter image model \(openRouterModelID(for: request.effectiveModel)).",
                callID: callID
            )
        )

        let body = try makeOpenRouterPayload(for: request)
        if let providerRequestURL = request.providerRequestURL {
            try ProviderRequestPersistence.writeJSON(body, to: providerRequestURL)
            eventHandler(
                ProviderProgressEvent(
                    stage: "provider_request_saved",
                    progress: 43,
                    message: "Saved exact OpenRouter provider request body before network execution.",
                    callID: callID
                )
            )
        }

        var urlRequest = URLRequest(url: endpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("enabled", forHTTPHeaderField: "X-OpenRouter-Metadata")
        urlRequest.httpBody = body

        let (data, response) = try await session.data(for: urlRequest)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            let bodyPreview = String(data: data.prefix(4096), encoding: .utf8) ?? ""
            throw ProviderRuntimeError.providerHTTPStatus(httpResponse.statusCode, bodyPreview, data)
        }

        let parsed: (imageData: Data?, text: String, usageMetadata: [String: String])
        do {
            parsed = try extractImageAndText(from: data)
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
                message: "OpenRouter returned raw response bytes.",
                callID: callID
            )
        )

        return ProviderResponse(
            provider: providerKind,
            model: openRouterModelID(for: request.effectiveModel),
            callID: callID,
            rawResponseData: data,
            imageData: parsed.imageData,
            text: parsed.text,
            usageMetadata: parsed.usageMetadata
        )
    }

    func makeOpenRouterPayload(for request: ProviderClientRequest) throws -> Data {
        let promptSuffix = request.workflow == .generation
            ? "\n\nCreate a publication-quality academic \(request.task). Aspect ratio: \(request.aspectRatio). Resolution target: \(request.resolution)."
            : "\n\nModify the attached image. Preserve scientific meaning, panel labels, abbreviations, and legibility. Aspect ratio: \(request.aspectRatio). Resolution target: \(request.resolution)."
        var content: [[String: Any]] = [
            [
                "type": "text",
                "text": request.prompt + promptSuffix
            ]
        ]
        if let sourceImageURL = request.sourceImageURL {
            let imageData = try Data(contentsOf: sourceImageURL)
            content.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:\(mimeType(for: sourceImageURL));base64,\(imageData.base64EncodedString())"
                ]
            ])
        }

        let payload: [String: Any] = [
            "model": openRouterModelID(for: request.effectiveModel),
            "messages": [
                [
                    "role": "user",
                    "content": content
                ]
            ],
            "modalities": ["image", "text"],
            "stream": false,
            "image_config": [
                "aspect_ratio": request.aspectRatio,
                "image_size": request.resolution
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    func extractImageAndText(from data: Data) throws -> (imageData: Data?, text: String, usageMetadata: [String: String]) {
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderRuntimeError.malformedProviderResponse
        }
        let choices = payload["choices"] as? [[String: Any]] ?? []
        var imageData: Data?
        var textParts: [String] = []

        for choice in choices {
            guard let message = choice["message"] as? [String: Any] else { continue }
            if let text = message["content"] as? String, !text.isEmpty {
                textParts.append(text)
                if imageData == nil {
                    imageData = Self.imageData(fromPotentialDataURL: text)
                }
            } else if let contentParts = message["content"] as? [[String: Any]] {
                for part in contentParts {
                    if let text = part["text"] as? String, !text.isEmpty {
                        textParts.append(text)
                    }
                    if imageData == nil,
                       let inlineData = part["inline_data"] as? [String: Any],
                       let encoded = inlineData["data"] as? String {
                        imageData = Data(base64Encoded: encoded)
                    }
                }
            }

            guard imageData == nil else { continue }
            let images = message["images"] as? [[String: Any]] ?? []
            for image in images {
                if let imageURL = image["image_url"] as? [String: Any],
                   let url = imageURL["url"] as? String {
                    imageData = Self.imageData(fromPotentialDataURL: url)
                } else if let url = image["url"] as? String {
                    imageData = Self.imageData(fromPotentialDataURL: url)
                }
                if imageData != nil { break }
            }
        }

        var usage: [String: String] = [:]
        if let usagePayload = payload["usage"] as? [String: Any] {
            for (key, value) in usagePayload {
                usage[key] = "\(value)"
            }
        }
        if let metadata = payload["openrouter_metadata"] as? [String: Any] {
            for (key, value) in metadata {
                usage["openrouter_\(key)"] = "\(value)"
            }
        }
        return (imageData, textParts.joined(separator: "\n\n"), usage)
    }

    func openRouterModelID(for model: String) -> String {
        if model.contains("/") { return model }
        if model.hasPrefix("gemini") { return "google/\(model)" }
        return model
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            "image/jpeg"
        case "webp":
            "image/webp"
        default:
            "image/png"
        }
    }

    private static func imageData(fromPotentialDataURL value: String) -> Data? {
        let encoded: String
        if let commaIndex = value.firstIndex(of: ",") {
            encoded = String(value[value.index(after: commaIndex)...])
        } else {
            encoded = value
        }
        return Data(base64Encoded: encoded.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
