import XCTest
@testable import PaperBanana

final class PaperBananaSecretStoreTests: XCTestCase {
    func testSaveAndLoadSecretsWithoutSystemCredentialServices() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaSecretStoreTests-\(UUID().uuidString)", isDirectory: true)
        let secretsURL = root
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("PaperBanana", isDirectory: true)
            .appendingPathComponent("secrets.json", isDirectory: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let secrets = PaperBananaSecrets(
            googleAPIKey: "google-test-key",
            openRouterAPIKey: "openrouter-test-key"
        )

        try PaperBananaSecretStore.save(secrets, to: secretsURL)
        let loaded = try PaperBananaSecretStore.load(from: secretsURL)

        XCTAssertEqual(loaded, secrets)
        XCTAssertEqual(permissions(at: secretsURL), 0o600)
        XCTAssertEqual(permissions(at: secretsURL.deletingLastPathComponent()), 0o700)
    }

    func testMissingSecretsFileLoadsEmptySecrets() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaMissingSecretStoreTests-\(UUID().uuidString)", isDirectory: true)
        let secretsURL = root.appendingPathComponent("secrets.json", isDirectory: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let secrets = try PaperBananaSecretStore.load(from: secretsURL)

        XCTAssertEqual(secrets, PaperBananaSecrets())
    }

    func testStatusFlagsLoosePermissions() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperBananaSecretStatusTests-\(UUID().uuidString)", isDirectory: true)
        let secretsURL = root.appendingPathComponent("secrets.json", isDirectory: false)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: secretsURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: secretsURL.path)

        let status = PaperBananaSecretStore.status(for: secretsURL)

        XCTAssertTrue(status.exists)
        XCTAssertEqual(status.filePermissions, 0o644)
        XCTAssertEqual(status.errorMessage, "Secrets file permissions should be 0600.")
    }

    private func permissions(at url: URL) -> Int? {
        guard let permissions = try? FileManager.default
            .attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber else {
            return nil
        }
        return permissions.intValue & 0o777
    }
}
