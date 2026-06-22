import Foundation

enum PaperBananaRepoLocator {
    static let repoPathDefaultsKey = "settings.repoPath"

    static var repoRootPath: String {
        let storedPath = UserDefaults.standard.string(forKey: repoPathDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let storedPath, storedPath.isEmpty == false {
            return (storedPath as NSString).expandingTildeInPath
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Codex_projects/PaperBanana", isDirectory: true),
            home.appendingPathComponent("Downloads/PaperBanana", isDirectory: true),
            home.appendingPathComponent("PaperBanana", isDirectory: true)
        ]

        if let existing = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return existing.path
        }

        return candidates[0].path
    }

    static var repoRootURL: URL {
        URL(fileURLWithPath: repoRootPath, isDirectory: true).standardizedFileURL
    }
}
