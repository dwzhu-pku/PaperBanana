import Foundation

struct PaperBananaSecrets: Codable, Equatable {
    var googleAPIKey: String = ""
    var openRouterAPIKey: String = ""
}

struct PaperBananaSecretStoreStatus: Equatable {
    let fileURL: URL
    let exists: Bool
    let isReadable: Bool
    let filePermissions: Int?
    let directoryPermissions: Int?
    let errorMessage: String?

    var usesRestrictedFilePermissions: Bool {
        filePermissions == 0o600 || exists == false
    }

    var usesRestrictedDirectoryPermissions: Bool {
        directoryPermissions == 0o700 || exists == false
    }
}

enum PaperBananaSecretStore {
    private static let directoryName = "PaperBanana"
    private static let fileName = "secrets.json"

    static var defaultURL: URL {
        PaperBananaRuntimeEnvironment.applicationSupportDirectory
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    static func load(from fileURL: URL = defaultURL) throws -> PaperBananaSecrets {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return PaperBananaSecrets()
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(PaperBananaSecrets.self, from: data)
    }

    static func save(_ secrets: PaperBananaSecrets, to fileURL: URL = defaultURL) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(secrets)
        try data.write(to: fileURL, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    static func status(for fileURL: URL = defaultURL) -> PaperBananaSecretStoreStatus {
        let fileManager = FileManager.default
        let directoryURL = fileURL.deletingLastPathComponent()
        let exists = fileManager.fileExists(atPath: fileURL.path)
        let isReadable = exists ? fileManager.isReadableFile(atPath: fileURL.path) : false
        let filePermissions = permissions(at: fileURL)
        let directoryPermissions = permissions(at: directoryURL)

        let errorMessage: String?
        if exists && !isReadable {
            errorMessage = "Secrets file exists but is not readable."
        } else if exists && filePermissions != 0o600 {
            errorMessage = "Secrets file permissions should be 0600."
        } else if exists && directoryPermissions != 0o700 {
            errorMessage = "Secrets directory permissions should be 0700."
        } else {
            errorMessage = nil
        }

        return PaperBananaSecretStoreStatus(
            fileURL: fileURL,
            exists: exists,
            isReadable: isReadable,
            filePermissions: filePermissions,
            directoryPermissions: directoryPermissions,
            errorMessage: errorMessage
        )
    }

    private static func permissions(at url: URL) -> Int? {
        guard let permissions = try? FileManager.default
            .attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber else {
            return nil
        }
        return permissions.intValue & 0o777
    }
}
