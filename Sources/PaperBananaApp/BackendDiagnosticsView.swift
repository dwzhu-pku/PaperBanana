import AppKit
import SwiftUI

struct BackendDiagnosticsView: View {
    @ObservedObject var settings: AppSettingsStore
    @ObservedObject var backend: BackendSupervisor

    private var snapshot: BackendSupervisor.RuntimeSnapshot {
        backend.runtimeSnapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.lg) {
            header
            statusGrid
            actions
            logPanel
            Spacer(minLength: 0)
        }
        .padding(AppDesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppDesignSystem.Surfaces.content)
        .onAppear {
            backend.runDiagnostics(configuration: settings.snapshot)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
            Label("Compatibility Diagnostics", systemImage: "stethoscope")
                .font(AppDesignSystem.Typography.title)
            Text(snapshot.lastHeartbeatMessage)
                .font(AppDesignSystem.Typography.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private var statusGrid: some View {
        WorkbenchSection("Compatibility Runtime", systemImage: "server.rack", subtitle: "Optional Python compatibility process state and paths.") {
            Grid(alignment: .leading, horizontalSpacing: AppDesignSystem.Spacing.xl, verticalSpacing: AppDesignSystem.Spacing.sm) {
                diagnosticRow("Status", statusLabel)
                diagnosticRow("PID", snapshot.processID.map(String.init) ?? "None")
                diagnosticRow("Port", "\(snapshot.port)")
                diagnosticRow("URL", snapshot.url.absoluteString)
                diagnosticRow("Last heartbeat", snapshot.lastHeartbeatAt?.formatted(date: .abbreviated, time: .standard) ?? "Never")
                diagnosticRow("Log file", snapshot.logFileURL.path)
                diagnosticRow("Repository", snapshot.repoPath)
            }
        }
    }

    private func diagnosticRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .font(AppDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(AppDesignSystem.Typography.body)
                .textSelection(.enabled)
        }
    }

    private var actions: some View {
        HStack(spacing: AppDesignSystem.Spacing.sm) {
            Button {
                settings.persistNonSecretSettings()
                backend.restart(configuration: settings.snapshot)
            } label: {
                Label(legacyBackendActionTitle, systemImage: legacyBackendActionSystemImage)
            }
            .buttonStyle(.borderedProminent)

            Button {
                NSWorkspace.shared.open(snapshot.url)
            } label: {
                Label("Open URL", systemImage: "safari")
            }
            .disabled(snapshot.status != .ready)

            Button {
                openLog()
            } label: {
                Label("Open Log", systemImage: "doc.text")
            }

            Button {
                revealRuntimeFolder()
            } label: {
                Label("Reveal Runtime Folder", systemImage: "folder")
            }

            Button {
                copyDiagnostics()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }

    private var logPanel: some View {
        WorkbenchSection("Recent Compatibility Output", systemImage: "terminal") {
            ScrollView {
                Text(backend.logTail.isEmpty ? "No backend output captured yet." : backend.logTail)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 220)
        }
    }

    private var statusLabel: String {
        switch snapshot.status {
        case .idle: "Idle"
        case .starting: "Starting"
        case .ready: "Ready"
        case .failed: "Failed"
        }
    }

    private var legacyBackendActionTitle: String {
        switch snapshot.status {
        case .idle: "Start Compatibility Runtime"
        case .starting, .ready, .failed: "Restart Compatibility Runtime"
        }
    }

    private var legacyBackendActionSystemImage: String {
        switch snapshot.status {
        case .idle: "play"
        case .starting, .ready, .failed: "arrow.clockwise"
        }
    }

    private func openLog() {
        let logURL = snapshot.logFileURL
        try? FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        NSWorkspace.shared.open(logURL)
    }

    private func revealRuntimeFolder() {
        let folder = snapshot.logFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    private func copyDiagnostics() {
        let lines = [
            "Status: \(statusLabel)",
            "PID: \(snapshot.processID.map(String.init) ?? "None")",
            "Port: \(snapshot.port)",
            "URL: \(snapshot.url.absoluteString)",
            "Last heartbeat: \(snapshot.lastHeartbeatAt?.formatted(date: .abbreviated, time: .standard) ?? "Never")",
            "Message: \(snapshot.lastHeartbeatMessage)",
            "Log: \(snapshot.logFileURL.path)",
            "Repository: \(snapshot.repoPath)"
        ]
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }
}
