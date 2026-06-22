import Foundation

struct ArtifactLineage: Equatable {
    let sourceURL: URL
    let outputURL: URL
    let prompt: String
    let model: String
    let resolution: String
    let aspectRatio: String
    let providerMessage: String
    let createdAt: String
    let workflow: String

    var modelLabel: String {
        ImageModelChoice(rawValue: model)?.label ?? model
    }

    init?(metadataURL: URL) {
        guard
            let data = try? Data(contentsOf: metadataURL),
            let payload = try? JSONDecoder().decode(Payload.self, from: data),
            let sourcePath = payload.sourcePath?.nilIfBlank,
            let outputPath = payload.outputPath?.nilIfBlank
        else {
            return nil
        }

        sourceURL = URL(fileURLWithPath: sourcePath).standardizedFileURL
        outputURL = URL(fileURLWithPath: outputPath).standardizedFileURL
        prompt = payload.prompt ?? ""
        model = payload.model ?? ""
        resolution = payload.resolution ?? ""
        aspectRatio = payload.aspectRatio ?? ""
        providerMessage = payload.providerMessage ?? ""
        createdAt = payload.createdAt ?? ""
        workflow = payload.workflow ?? ""
    }

    private struct Payload: Decodable {
        let sourcePath: String?
        let outputPath: String?
        let prompt: String?
        let model: String?
        let resolution: String?
        let aspectRatio: String?
        let providerMessage: String?
        let createdAt: String?
        let workflow: String?

        enum CodingKeys: String, CodingKey {
            case sourcePath = "source_path"
            case outputPath = "output_path"
            case prompt
            case model
            case resolution
            case aspectRatio = "aspect_ratio"
            case providerMessage = "provider_message"
            case createdAt = "created_at"
            case workflow
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
