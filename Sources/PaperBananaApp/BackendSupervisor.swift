import Foundation

@MainActor
final class BackendSupervisor: ObservableObject {
    enum State: Equatable {
        case idle
        case starting
        case ready(URL)
        case failed(String)
    }

    enum RuntimeStatus: Equatable {
        case idle
        case starting
        case ready
        case failed
    }

    struct RuntimeSnapshot: Equatable {
        var status: RuntimeStatus
        var port: Int
        var url: URL
        var processID: Int32?
        var lastHeartbeatAt: Date?
        var lastHeartbeatSucceeded: Bool
        var lastHeartbeatMessage: String
        var logFileURL: URL
        var repoPath: String
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var logTail: String = ""
    @Published private(set) var diagnostics: [DiagnosticItem] = []
    @Published private(set) var runtimeSnapshot: RuntimeSnapshot

    private var process: Process?
    private var heartbeatTask: Task<Void, Never>?
    private let heartbeatInterval: TimeInterval
    private var activeConfiguration = PaperBananaSettingsSnapshot(
        repoPath: "/Users/jeff/Codex_projects/PaperBanana",
        serverPort: 7860,
        defaultImageModel: .nanoBanana2,
        codexModel: "gpt-5.5",
        codexReasoning: "xhigh",
        googleAPIKey: "",
        openRouterAPIKey: ""
    )

    init(heartbeatInterval: TimeInterval = 2.5) {
        self.heartbeatInterval = heartbeatInterval
        let configuration = activeConfiguration
        self.runtimeSnapshot = RuntimeSnapshot(
            status: .idle,
            port: configuration.serverPort,
            url: URL(string: "http://127.0.0.1:\(configuration.serverPort)")!,
            processID: nil,
            lastHeartbeatAt: nil,
            lastHeartbeatSucceeded: false,
            lastHeartbeatMessage: "Backend has not been checked yet.",
            logFileURL: Self.logFileURL(for: configuration),
            repoPath: configuration.repoPath
        )
    }

    deinit {
        heartbeatTask?.cancel()
    }

    var webURL: URL {
        URL(string: "http://127.0.0.1:\(activeConfiguration.serverPort)")!
    }

    func start(configuration: PaperBananaSettingsSnapshot) {
        activeConfiguration = configuration
        state = .starting
        refreshRuntimeSnapshot(status: .starting, message: "Checking backend on \(webURL.absoluteString).")
        startHeartbeatLoop()
        guard process?.isRunning != true else {
            return
        }
        let port = configuration.serverPort
        Task {
            if await canReachBackend(port: port) {
                appendLog("Reusing existing PaperBanana backend at \(webURL.absoluteString).\n")
                state = .ready(webURL)
                return
            }
            launchBackend()
        }
    }

    private func launchBackend() {
        let repoRoot = URL(fileURLWithPath: activeConfiguration.repoPath, isDirectory: true)
        let python = repoRoot.appendingPathComponent(".venv/bin/python").path
        let app = repoRoot.appendingPathComponent("app.py").path
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: python)
        proc.arguments = [app]
        proc.currentDirectoryURL = repoRoot
        var env = ProcessInfo.processInfo.environment
        env["PAPERBANANA_CODEX_IMAGE_HANDOFF"] = "1"
        env["PAPERBANANA_CODEX_MODEL"] = activeConfiguration.codexModel
        env["PAPERBANANA_CODEX_REASONING_EFFORT"] = activeConfiguration.codexReasoning
        env["PAPERBANANA_SERVER_PORT"] = "\(activeConfiguration.serverPort)"
        env["PAPERBANANA_SERVER_NAME"] = "127.0.0.1"
        env["IMAGE_GEN_MODEL_NAME"] = activeConfiguration.defaultImageModel.backendValue
        if !activeConfiguration.googleAPIKey.isEmpty {
            env["GOOGLE_API_KEY"] = activeConfiguration.googleAPIKey
        }
        if !activeConfiguration.openRouterAPIKey.isEmpty {
            env["OPENROUTER_API_KEY"] = activeConfiguration.openRouterAPIKey
        }
        proc.environment = env

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.appendLog(text)
            }
        }
        proc.terminationHandler = { [weak self] process in
            Task { @MainActor in
                guard process.terminationStatus != 0 else { return }
                self?.state = .failed("PaperBanana backend exited with status \(process.terminationStatus).")
            }
        }

        do {
            try proc.run()
            process = proc
            Task { await waitUntilReady() }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func stop() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        process?.terminate()
        process = nil
        state = .idle
        refreshRuntimeSnapshot(status: .idle, message: "Backend stopped.")
    }

    func restart(configuration: PaperBananaSettingsSnapshot) {
        stop()
        start(configuration: configuration)
    }

    func runDiagnostics(configuration: PaperBananaSettingsSnapshot) {
        activeConfiguration = configuration
        let repoRoot = URL(fileURLWithPath: configuration.repoPath, isDirectory: true)
        let python = repoRoot.appendingPathComponent(".venv/bin/python")
        let app = repoRoot.appendingPathComponent("app.py")
        let config = repoRoot.appendingPathComponent("configs/model_config.yaml")

        var items: [DiagnosticItem] = []
        items.append(fileCheck(title: "PaperBanana checkout", url: repoRoot, expectedDirectory: true))
        items.append(fileCheck(title: "Python virtual environment", url: python, expectedDirectory: false))
        items.append(fileCheck(title: "Gradio backend", url: app, expectedDirectory: false))
        items.append(fileCheck(title: "Model config", url: config, expectedDirectory: false))
        items.append(DiagnosticItem(
            title: "Default image model",
            detail: "\(configuration.defaultImageModel.label) (\(configuration.defaultImageModel.backendValue))",
            severity: .ok
        ))

        let secretStatus = PaperBananaSecretStore.status()
        let secretSeverity: DiagnosticSeverity = secretStatus.errorMessage == nil ? .ok : .failure
        items.append(DiagnosticItem(
            title: "Secret storage",
            detail: secretStatus.errorMessage ?? "Local file storage active at \(secretStatus.fileURL.path)",
            severity: secretSeverity
        ))
        items.append(DiagnosticItem(
            title: "Google API key",
            detail: configuration.googleAPIKey.isEmpty ? "Not saved in local secrets file" : "Loaded from local secrets file",
            severity: configuration.googleAPIKey.isEmpty ? .warning : .ok
        ))
        items.append(DiagnosticItem(
            title: "OpenRouter API key",
            detail: configuration.openRouterAPIKey.isEmpty ? "Not saved in local secrets file" : "Loaded from local secrets file",
            severity: configuration.openRouterAPIKey.isEmpty ? .warning : .ok
        ))
        items.append(DiagnosticItem(
            title: "Codex fallback",
            detail: "\(configuration.codexModel), reasoning \(configuration.codexReasoning)",
            severity: .ok
        ))
        items.append(DiagnosticItem(
            title: "Backend heartbeat",
            detail: runtimeSnapshot.lastHeartbeatMessage,
            severity: runtimeSnapshot.lastHeartbeatSucceeded ? .ok : .warning
        ))
        items.append(DiagnosticItem(
            title: "Backend process",
            detail: runtimeSnapshot.processID.map { "PID \($0)" } ?? "No backend process currently associated with the app.",
            severity: runtimeSnapshot.processID == nil ? .warning : .ok
        ))
        items.append(DiagnosticItem(
            title: "Backend log",
            detail: runtimeSnapshot.logFileURL.path,
            severity: .ok
        ))

        diagnostics = items.sorted { lhs, rhs in
            if lhs.severity.sortOrder == rhs.severity.sortOrder {
                return lhs.title < rhs.title
            }
            return lhs.severity.sortOrder < rhs.severity.sortOrder
        }
    }

    private func appendLog(_ text: String) {
        logTail += text
        if logTail.count > 8000 {
            logTail = String(logTail.suffix(8000))
        }
        appendToLogFile(text)
    }

    private func waitUntilReady() async {
        let deadline = Date().addingTimeInterval(90)
        let port = activeConfiguration.serverPort
        while Date() < deadline {
            if await canReachBackend(port: port) {
                state = .ready(webURL)
                return
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        state = .failed("PaperBanana backend did not become ready on \(webURL.absoluteString).")
    }

    private func startHeartbeatLoop() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.performHeartbeat()
                let delay = UInt64(max(self?.heartbeatInterval ?? 2.5, 0.25) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
            }
        }
    }

    private func performHeartbeat() async {
        let port = activeConfiguration.serverPort
        let reachable = await canReachBackend(port: port)
        let externalPID = await processIDListening(on: port)
        applyHeartbeat(
            reachable: reachable,
            managedProcessID: process?.processIdentifier,
            managedProcessRunning: process?.isRunning ?? false,
            externalProcessID: externalPID,
            date: Date()
        )
    }

    private func applyHeartbeat(
        reachable: Bool,
        managedProcessID: Int32?,
        managedProcessRunning: Bool,
        externalProcessID: Int32?,
        date: Date
    ) {
        let pid = managedProcessID ?? externalProcessID
        if reachable {
            state = .ready(webURL)
            runtimeSnapshot = RuntimeSnapshot(
                status: .ready,
                port: activeConfiguration.serverPort,
                url: webURL,
                processID: pid,
                lastHeartbeatAt: date,
                lastHeartbeatSucceeded: true,
                lastHeartbeatMessage: "Backend responded on \(webURL.absoluteString)",
                logFileURL: Self.logFileURL(for: activeConfiguration),
                repoPath: activeConfiguration.repoPath
            )
            return
        }

        let message: String
        if let managedProcessID, !managedProcessRunning {
            message = "Managed backend process \(managedProcessID) is not running and port \(activeConfiguration.serverPort) is unreachable."
            state = .failed(message)
        } else if managedProcessRunning {
            message = "Backend process \(managedProcessID.map(String.init) ?? "unknown") is running, but port \(activeConfiguration.serverPort) is not responding yet."
            if case .failed = state {
                state = .starting
            }
        } else {
            message = "No backend process is associated with the app and port \(activeConfiguration.serverPort) is unreachable."
            if case .ready = state {
                state = .failed(message)
            }
        }

        runtimeSnapshot = RuntimeSnapshot(
            status: state.runtimeStatus,
            port: activeConfiguration.serverPort,
            url: webURL,
            processID: pid,
            lastHeartbeatAt: date,
            lastHeartbeatSucceeded: false,
            lastHeartbeatMessage: message,
            logFileURL: Self.logFileURL(for: activeConfiguration),
            repoPath: activeConfiguration.repoPath
        )
    }

    private func refreshRuntimeSnapshot(status: RuntimeStatus, message: String) {
        runtimeSnapshot = RuntimeSnapshot(
            status: status,
            port: activeConfiguration.serverPort,
            url: webURL,
            processID: process?.processIdentifier,
            lastHeartbeatAt: runtimeSnapshot.lastHeartbeatAt,
            lastHeartbeatSucceeded: runtimeSnapshot.lastHeartbeatSucceeded,
            lastHeartbeatMessage: message,
            logFileURL: Self.logFileURL(for: activeConfiguration),
            repoPath: activeConfiguration.repoPath
        )
    }

    private nonisolated func canReachBackend(port: Int) async -> Bool {
        let url = URL(string: "http://127.0.0.1:\(port)")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private nonisolated func processIDListening(on port: Int) async -> Int32? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-tiTCP:\(port)", "-sTCP:LISTEN"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard process.terminationStatus == 0,
                  let output = String(data: data, encoding: .utf8)
            else { return nil }
            return output
                .split(whereSeparator: \.isNewline)
                .compactMap { Int32($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                .first
        } catch {
            return nil
        }
    }

    private func fileCheck(title: String, url: URL, expectedDirectory: Bool) -> DiagnosticItem {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        let typeMatches = expectedDirectory ? isDirectory.boolValue : !isDirectory.boolValue
        if exists && typeMatches {
            return DiagnosticItem(title: title, detail: url.path, severity: .ok)
        }
        if exists {
            return DiagnosticItem(title: title, detail: "Unexpected file type at \(url.path)", severity: .failure)
        }
        return DiagnosticItem(title: title, detail: "Missing at \(url.path)", severity: .failure)
    }

    private func appendToLogFile(_ text: String) {
        let logURL = Self.logFileURL(for: activeConfiguration)
        do {
            try FileManager.default.createDirectory(
                at: logURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            guard let data = text.data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: logURL.path) {
                let handle = try FileHandle(forWritingTo: logURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: logURL, options: .atomic)
            }
        } catch {
            logTail += "\n[PaperBanana] Could not write backend log: \(error.localizedDescription)\n"
        }
    }

    private static func logFileURL(for configuration: PaperBananaSettingsSnapshot) -> URL {
        URL(fileURLWithPath: configuration.repoPath, isDirectory: true)
            .appendingPathComponent("log", isDirectory: true)
            .appendingPathComponent("macos_backend.log", isDirectory: false)
    }
}

extension BackendSupervisor.State {
    var runtimeStatus: BackendSupervisor.RuntimeStatus {
        switch self {
        case .idle: .idle
        case .starting: .starting
        case .ready: .ready
        case .failed: .failed
        }
    }
}

#if DEBUG
extension BackendSupervisor {
    func configureForTesting(configuration: PaperBananaSettingsSnapshot, state: State) {
        activeConfiguration = configuration
        self.state = state
        refreshRuntimeSnapshot(status: state.runtimeStatus, message: "Test configuration loaded.")
    }

    func applyHeartbeatForTesting(
        reachable: Bool,
        managedProcessID: Int32?,
        managedProcessRunning: Bool,
        externalProcessID: Int32?,
        date: Date
    ) {
        applyHeartbeat(
            reachable: reachable,
            managedProcessID: managedProcessID,
            managedProcessRunning: managedProcessRunning,
            externalProcessID: externalProcessID,
            date: date
        )
    }
}
#endif
