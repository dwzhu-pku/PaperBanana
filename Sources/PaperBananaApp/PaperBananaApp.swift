import AppKit
import AppIntents
import SwiftUI

@MainActor
final class PaperBananaAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let settings = AppSettingsStore()
    let backend = BackendSupervisor()

    private var fallbackWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        guard !PaperBananaRuntimeEnvironment.isRunningUnitTests else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.ensureMainWindow()
            self.positionMainWindowOnCodexDisplayIfAvailable()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !PaperBananaRuntimeEnvironment.isRunningUnitTests else { return false }
        if !flag {
            ensureMainWindow()
        }
        positionMainWindowOnCodexDisplayIfAvailable()
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    func applicationShouldRestoreApplicationState(_ application: NSApplication) -> Bool {
        false
    }

    func applicationShouldSaveApplicationState(_ application: NSApplication) -> Bool {
        false
    }

    private func ensureMainWindow() {
        if hasVisibleMainWindow {
            configureMainWindowIfAvailable()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        NSApp.sendAction(Selector(("newWindow:")), to: nil, from: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard !self.hasVisibleMainWindow else {
                self.configureMainWindowIfAvailable()
                NSApp.activate(ignoringOtherApps: true)
                self.positionMainWindowOnCodexDisplayIfAvailable()
                return
            }
            self.showFallbackMainWindow()
        }
    }

    private var hasVisibleMainWindow: Bool {
        NSApp.windows.contains { window in
            window.isVisible && window.title == "PaperBanana"
        }
    }

    private func showFallbackMainWindow() {
        if let window = fallbackWindowController?.window {
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = AppRootContainer(settings: settings, backend: backend)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 860),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "PaperBanana"
        window.minSize = NSSize(
            width: PaperBananaWindowPlacement.minimumUsableWindowWidth,
            height: PaperBananaWindowPlacement.minimumUsableWindowHeight
        )
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.delegate = self
        window.center()

        let controller = NSWindowController(window: window)
        fallbackWindowController = controller
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        positionMainWindowOnCodexDisplayIfAvailable()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureMainWindowIfAvailable() {
        guard let window = NSApp.windows.first(where: { $0.title == "PaperBanana" }) else { return }
        window.minSize = NSSize(
            width: PaperBananaWindowPlacement.minimumUsableWindowWidth,
            height: PaperBananaWindowPlacement.minimumUsableWindowHeight
        )
        window.isRestorable = false
        window.delegate = self
        Self.clampWindowInsideVisibleScreen(window)
    }

    private func positionMainWindowOnCodexDisplayIfAvailable() {
        guard let codexBounds = codexWindowBounds(),
              let screen = screen(containingHorizontalCenterOf: codexBounds),
              let window = NSApp.windows.first(where: { $0.title == "PaperBanana" })
        else { return }

        configureMainWindowIfAvailable()
        let frame = PaperBananaWindowPlacement.frame(
            currentFrame: window.frame,
            codexBounds: codexBounds,
            visibleFrame: screen.visibleFrame
        )
        window.setFrame(NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height), display: true)
        window.makeKeyAndOrderFront(nil)
    }

    nonisolated func windowDidResize(_ notification: Notification) {
        Task { @MainActor in
            Self.clampMainWindowInsideVisibleScreen()
        }
    }

    nonisolated func windowDidMove(_ notification: Notification) {
        Task { @MainActor in
            Self.clampMainWindowInsideVisibleScreen()
        }
    }

    nonisolated func windowDidBecomeKey(_ notification: Notification) {
        Task { @MainActor in
            Self.clampMainWindowInsideVisibleScreen()
        }
    }

    private static func clampMainWindowInsideVisibleScreen() {
        guard let window = NSApp.windows.first(where: { $0.title == "PaperBanana" }) else { return }
        clampWindowInsideVisibleScreen(window)
    }

    private static func clampWindowInsideVisibleScreen(_ window: NSWindow) {
        guard window.title == "PaperBanana",
              let screen = window.screen ?? NSScreen.screens.first(where: { $0.frame.intersects(window.frame) })
        else { return }

        let clamped = PaperBananaWindowPlacement.clampedFrame(
            currentFrame: window.frame,
            minimumSize: window.minSize,
            visibleFrame: screen.visibleFrame
        )

        guard abs(clamped.minX - window.frame.minX) > 0.5 ||
              abs(clamped.minY - window.frame.minY) > 0.5 ||
              abs(clamped.width - window.frame.width) > 0.5 ||
              abs(clamped.height - window.frame.height) > 0.5
        else { return }

        window.setFrame(clamped, display: true)
    }

    private func screen(containingHorizontalCenterOf bounds: CGRect) -> NSScreen? {
        let centerX = bounds.midX
        return NSScreen.screens.first { screen in
            centerX >= screen.frame.minX && centerX <= screen.frame.maxX
        }
    }

    private func codexWindowBounds() -> CGRect? {
        guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for info in windows {
            let owner = info[kCGWindowOwnerName as String] as? String
            let title = info[kCGWindowName as String] as? String
            guard owner == "Codex" || title == "Codex" else { continue }
            guard let boundsInfo = info[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let x = boundsInfo["X"] ?? 0
            let y = boundsInfo["Y"] ?? 0
            let width = boundsInfo["Width"] ?? 0
            let height = boundsInfo["Height"] ?? 0
            guard width > 0, height > 0 else { continue }
            return CGRect(x: x, y: y, width: width, height: height)
        }

        return nil
    }
}

struct GeneratePaperBananaFigureIntent: AppIntent {
    static let title: LocalizedStringResource = "Generate PaperBanana Figure"
    static let description = IntentDescription("Open PaperBanana to generate a new scientific figure.")
    static let openAppWhenRun = true

    @Parameter(title: "Prompt")
    var prompt: String?

    func perform() async throws -> some IntentResult {
        PaperBananaIntentBridge.request(.promptStudio)
        if let prompt, prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            UserDefaults.standard.set(prompt, forKey: "paperbanana.intent.prompt")
        }
        return .result()
    }
}

@MainActor
enum PaperBananaShortcutActions {
    static var repoRootPath: String {
        PaperBananaRepoLocator.repoRootPath
    }

    static func latest4KOutputURL(repoRootPath: String? = nil) -> URL? {
        let rootPath = repoRootPath ?? self.repoRootPath
        return ArtifactLibraryScanner.scan(repoRootPath: rootPath)
            .filter { artifact in
                guard artifact.kind == .image else { return false }
                if artifact.title.localizedCaseInsensitiveContains("4K") {
                    return true
                }
                guard let quality = PaperBananaImageQualityInspector.inspect(artifact.url) else {
                    return false
                }
                return quality.pixelWidth >= 3_840 || quality.pixelHeight >= 2_160
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .first?
            .url
    }

    @discardableResult
    static func openLatest4KOutput(repoRootPath: String? = nil) -> URL? {
        guard let url = latest4KOutputURL(repoRootPath: repoRootPath) else {
            return nil
        }
        openURLForUserIfAppropriate(url)
        return url
    }

    @discardableResult
    static func recoverFirstProviderArtifact(repoRootPath: String? = nil) -> ProviderRecoveryResult? {
        let rootPath = repoRootPath ?? self.repoRootPath
        let calls = ProviderRunLedgerScanner.scan(repoRootPath: rootPath)
            .filter { call in
                call.recoveryCandidateURLs.isEmpty == false && call.nativeArtifactURLs.isEmpty
            }
            .sorted { lhs, rhs in
                (lhs.updatedAt ?? lhs.startedAt ?? .distantPast) > (rhs.updatedAt ?? rhs.startedAt ?? .distantPast)
            }

        for call in calls {
            if let result = try? ProviderRecoverySurfacer.surfaceFirstRecoverableArtifact(
                for: call,
                repoRootPath: rootPath
            ) {
                revealRecoveredArtifactIfAppropriate(result.artifactURL)
                return result
            }
        }
        return nil
    }

    @discardableResult
    static func recoverProviderArtifact(callID: String, repoRootPath: String? = nil) -> ProviderRecoveryResult? {
        let rootPath = repoRootPath ?? self.repoRootPath
        guard let call = ProviderRunLedgerScanner.scan(repoRootPath: rootPath)
            .first(where: { $0.callID == callID })
        else {
            return nil
        }

        guard let result = try? ProviderRecoverySurfacer.surfaceFirstRecoverableArtifact(
            for: call,
            repoRootPath: rootPath
        ) else {
            return nil
        }

        revealRecoveredArtifactIfAppropriate(result.artifactURL)
        return result
    }

    static func openURLForUserIfAppropriate(_ url: URL) {
        guard PaperBananaRuntimeEnvironment.isRunningUnitTests == false else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private static func revealRecoveredArtifactIfAppropriate(_ url: URL) {
        guard PaperBananaRuntimeEnvironment.isRunningUnitTests == false else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

struct RefineSelectedPaperBananaImageIntent: AppIntent {
    static let title: LocalizedStringResource = "Refine Selected PaperBanana Image"
    static let description = IntentDescription("Open PaperBanana to refine an existing image.")
    static let openAppWhenRun = true

    @Parameter(title: "Modification Instructions")
    var instructions: String?

    func perform() async throws -> some IntentResult {
        PaperBananaIntentBridge.request(.refineImage)
        if let instructions, instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            UserDefaults.standard.set(instructions, forKey: "paperbanana.intent.refineInstructions")
        }
        return .result()
    }
}

struct OpenLatest4KPaperBananaOutputIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Latest 4K PaperBanana Output"
    static let description = IntentDescription("Open PaperBanana's recovered images and latest generated artifacts.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        _ = await MainActor.run {
            PaperBananaShortcutActions.openLatest4KOutput()
        }
        PaperBananaIntentBridge.request(.recoveredImages)
        return .result()
    }
}

struct RecoverMissingProviderArtifactIntent: AppIntent {
    static let title: LocalizedStringResource = "Recover Missing Provider Artifact"
    static let description = IntentDescription("Open the native run cockpit to inspect missing or recoverable provider artifacts.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        _ = await MainActor.run {
            PaperBananaShortcutActions.recoverFirstProviderArtifact()
        }
        PaperBananaIntentBridge.request(.runDetails)
        return .result()
    }
}

struct ShowFailedPaperBananaRunsIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Failed PaperBanana Runs"
    static let description = IntentDescription("Open PaperBanana's provider ledger and failed run details.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        PaperBananaIntentBridge.request(.runLedger)
        return .result()
    }
}

struct PaperBananaShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GeneratePaperBananaFigureIntent(),
            phrases: [
                "Generate a \(.applicationName) figure",
                "Create a figure in \(.applicationName)"
            ],
            shortTitle: "Generate Figure",
            systemImageName: "photo.badge.plus"
        )
        AppShortcut(
            intent: RefineSelectedPaperBananaImageIntent(),
            phrases: [
                "Refine image in \(.applicationName)",
                "Modify a \(.applicationName) image"
            ],
            shortTitle: "Refine Image",
            systemImageName: "wand.and.sparkles"
        )
        AppShortcut(
            intent: OpenLatest4KPaperBananaOutputIntent(),
            phrases: [
                "Open latest \(.applicationName) output",
                "Show latest 4K \(.applicationName) image"
            ],
            shortTitle: "Latest 4K Output",
            systemImageName: "photo"
        )
        AppShortcut(
            intent: RecoverMissingProviderArtifactIntent(),
            phrases: [
                "Recover missing \(.applicationName) artifact",
                "Show recoverable \(.applicationName) output"
            ],
            shortTitle: "Recover Artifact",
            systemImageName: "shippingbox"
        )
        AppShortcut(
            intent: ShowFailedPaperBananaRunsIntent(),
            phrases: [
                "Show failed \(.applicationName) runs",
                "Open \(.applicationName) failures"
            ],
            shortTitle: "Failed Runs",
            systemImageName: "exclamationmark.triangle"
        )
        AppShortcut(
            intent: OpenPaperBananaRunIntent(),
            phrases: [
                "Open a \(.applicationName) run",
                "Inspect a \(.applicationName) run"
            ],
            shortTitle: "Open Run",
            systemImageName: "waveform.path.ecg.rectangle"
        )
        AppShortcut(
            intent: OpenPaperBananaArtifactIntent(),
            phrases: [
                "Open a \(.applicationName) artifact",
                "Show a \(.applicationName) artifact"
            ],
            shortTitle: "Open Artifact",
            systemImageName: "photo.stack"
        )
        AppShortcut(
            intent: RecoverPaperBananaProviderCallIntent(),
            phrases: [
                "Recover a \(.applicationName) provider call",
                "Surface a \(.applicationName) provider artifact"
            ],
            shortTitle: "Recover Call",
            systemImageName: "arrow.down.doc"
        )
        AppShortcut(
            intent: SearchPaperBananaRunsAndArtifactsIntent(),
            phrases: [
                "Search \(.applicationName) runs",
                "Find \(.applicationName) artifacts"
            ],
            shortTitle: "Search Runs",
            systemImageName: "magnifyingglass"
        )
    }
}

@main
struct PaperBananaApp: App {
    @NSApplicationDelegateAdaptor(PaperBananaAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("PaperBanana") {
            if PaperBananaRuntimeEnvironment.isRunningUnitTests {
                PaperBananaTestHostView()
            } else {
                AppRootContainer(settings: appDelegate.settings, backend: appDelegate.backend)
            }
        }
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView(settings: appDelegate.settings, backend: appDelegate.backend)
        }
    }
}

private struct PaperBananaTestHostView: View {
    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityHidden(true)
    }
}
