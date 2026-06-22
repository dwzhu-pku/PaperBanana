import Darwin
import Foundation

enum PaperBananaRuntimeEnvironment {
    static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static var applicationSupportDirectory: URL {
        if let rawOverride = getenv("PAPERBANANA_APPLICATION_SUPPORT_ROOT") {
            let override = String(cString: rawOverride).trimmingCharacters(in: .whitespacesAndNewlines)
            guard override.isEmpty == false else {
                return defaultApplicationSupportDirectory
            }
            return URL(fileURLWithPath: override, isDirectory: true).standardizedFileURL
        }

        return defaultApplicationSupportDirectory
    }

    private static var defaultApplicationSupportDirectory: URL {
        return FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .standardizedFileURL
    }
}
