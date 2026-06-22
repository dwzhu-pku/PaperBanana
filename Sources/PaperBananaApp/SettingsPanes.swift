import AppKit
import SwiftUI

struct WorkspaceSettingsPane: View {
    @ObservedObject var settings: AppSettingsStore
    @ObservedObject var backend: BackendSupervisor

    var body: some View {
        Form {
            Section("Native Workspace") {
                TextField("PaperBanana checkout", text: $settings.repoPath)
                    .help(settings.repoPath)
                    .accessibilityLabel("PaperBanana checkout")
                    .accessibilityValue(settings.repoPath)
                    .accessibilityIdentifier("settings-workspace-repo-path")
                Text("Native workflows scan and write run records, provider ledgers, recovered artifacts, and generated images under this checkout.")
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("PaperBanana Readiness") {
                SettingsReadinessSummary(snapshot: settings.readinessSnapshot())
            }

            Section("Image Defaults") {
                Picker("Default image model", selection: $settings.defaultImageModel) {
                    ForEach(ImageModelChoice.allCases) { model in
                        Text(model.label).tag(model)
                    }
                }
            }

            Section("Codex Fallback") {
                TextField("Model", text: $settings.codexModel)
                    .accessibilityIdentifier("settings-codex-model")
                TextField("Reasoning effort", text: $settings.codexReasoning)
                    .accessibilityIdentifier("settings-codex-reasoning")
            }

            SettingsApplyRow {
                applySettings(restart: false)
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier("settings-workspace-pane-form")
    }

    private func applySettings(restart: Bool) {
        settings.persistNonSecretSettings()
        backend.runDiagnostics(configuration: settings.snapshot)
        if restart {
            backend.restart(configuration: settings.snapshot)
        }
    }
}

struct ProviderSettingsPane: View {
    @ObservedObject var settings: AppSettingsStore
    @ObservedObject var backend: BackendSupervisor

    var body: some View {
        Form {
            Section("Secret Storage") {
                LabeledContent("Location") {
                    Text(settings.secretStoreURL.path)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .help(settings.secretStoreURL.path)
                        .accessibilityLabel("Secret storage location")
                        .accessibilityValue(settings.secretStoreURL.path)
                        .accessibilityIdentifier("settings-secret-store-location")
                }
                if let error = settings.secretStoreError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppDesignSystem.SemanticColors.statusFailed)
                }
                Button {
                    settings.refreshSecretStatus()
                    applySettings(restart: false)
                } label: {
                    Label("Refresh Secret Status", systemImage: "arrow.clockwise")
                }
            }

            Section("Google Gemini") {
                LabeledContent("Status") {
                    SettingsStatusPill(
                        text: settings.hasGoogleAPIKey ? "Saved" : "Not saved",
                        severity: settings.hasGoogleAPIKey ? .ok : .warning
                    )
                }
                SecureField("Google API key", text: $settings.pendingGoogleAPIKey)
                    .help("Stores the Google Gemini key in the local PaperBanana secrets file.")
                    .accessibilityIdentifier("settings-google-api-key-field")
                providerKeyActions(
                    saveTitle: "Save Google Key Locally",
                    saveIdentifier: "settings-save-google-key",
                    canSave: settings.pendingGoogleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                    canClear: settings.hasGoogleAPIKey,
                    clearIdentifier: "settings-clear-google-key",
                    onSave: {
                        settings.saveGoogleAPIKey()
                        applySettings(restart: false)
                    },
                    onClear: {
                        settings.clearGoogleAPIKey()
                        applySettings(restart: false)
                    }
                )
            }

            Section("OpenRouter") {
                LabeledContent("Status") {
                    SettingsStatusPill(
                        text: settings.hasOpenRouterAPIKey ? "Saved" : "Not saved",
                        severity: settings.hasOpenRouterAPIKey ? .ok : .warning
                    )
                }
                SecureField("OpenRouter API key", text: $settings.pendingOpenRouterAPIKey)
                    .help("Stores the OpenRouter key in the local PaperBanana secrets file.")
                    .accessibilityIdentifier("settings-openrouter-api-key-field")
                providerKeyActions(
                    saveTitle: "Save OpenRouter Key Locally",
                    saveIdentifier: "settings-save-openrouter-key",
                    canSave: settings.pendingOpenRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                    canClear: settings.hasOpenRouterAPIKey,
                    clearIdentifier: "settings-clear-openrouter-key",
                    onSave: {
                        settings.saveOpenRouterAPIKey()
                        applySettings(restart: false)
                    },
                    onClear: {
                        settings.clearOpenRouterAPIKey()
                        applySettings(restart: false)
                    }
                )
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier("settings-provider-pane-form")
    }

    private func providerKeyActions(
        saveTitle: String,
        saveIdentifier: String,
        canSave: Bool,
        canClear: Bool,
        clearIdentifier: String,
        onSave: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppDesignSystem.Spacing.sm) {
                providerSaveButton(title: saveTitle, identifier: saveIdentifier, canSave: canSave, onSave: onSave)
                providerClearButton(identifier: clearIdentifier, canClear: canClear, onClear: onClear)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                providerSaveButton(title: saveTitle, identifier: saveIdentifier, canSave: canSave, onSave: onSave)
                providerClearButton(identifier: clearIdentifier, canClear: canClear, onClear: onClear)
            }
        }
        .controlSize(.regular)
    }

    private func providerSaveButton(
        title: String,
        identifier: String,
        canSave: Bool,
        onSave: @escaping () -> Void
    ) -> some View {
        Button(action: onSave) {
            Label(title, systemImage: "key.fill")
        }
        .disabled(!canSave)
        .help("Save this provider key in the local PaperBanana secrets file.")
        .accessibilityIdentifier(identifier)
    }

    private func providerClearButton(
        identifier: String,
        canClear: Bool,
        onClear: @escaping () -> Void
    ) -> some View {
        Button(role: .destructive, action: onClear) {
            Label("Clear", systemImage: "trash")
        }
        .disabled(!canClear)
        .help("Remove this provider key from the local PaperBanana secrets file.")
        .accessibilityIdentifier(identifier)
    }

    private func applySettings(restart: Bool) {
        settings.persistNonSecretSettings()
        backend.runDiagnostics(configuration: settings.snapshot)
        if restart {
            backend.restart(configuration: settings.snapshot)
        }
    }
}

struct LegacySettingsPane: View {
    @ObservedObject var settings: AppSettingsStore
    @ObservedObject var backend: BackendSupervisor

    var body: some View {
        Form {
            Section("Legacy Gradio Compatibility") {
                Text("Use only for the older pipeline UI. Native generation, refinement, recovery, and provider auditing do not require this backend.")
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Stepper(value: $settings.serverPort, in: 1024...65535) {
                    LabeledContent("Local server port") {
                        Text("\(settings.serverPort)")
                            .monospacedDigit()
                    }
                }
                .accessibilityIdentifier("settings-legacy-server-port")

                legacyCompatibilityActions
            }

            Section("Diagnostics") {
                diagnosticsActions
                diagnosticsRows
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier("settings-legacy-pane-form")
    }

    private var legacyCompatibilityActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppDesignSystem.Spacing.sm) {
                applyLegacyButton
                startCompatibilityButton
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                applyLegacyButton
                startCompatibilityButton
            }
        }
        .controlSize(.regular)
    }

    private var applyLegacyButton: some View {
        Button {
            applySettings(restart: false)
        } label: {
            Label("Apply Legacy Settings", systemImage: "checkmark")
        }
        .accessibilityIdentifier("settings-apply-legacy-settings")
    }

    private var startCompatibilityButton: some View {
        Button {
            applySettings(restart: true)
        } label: {
            Label("Apply and Start Compatibility Runtime", systemImage: "play")
        }
        .help("Starts the optional legacy compatibility runtime after saving settings.")
        .accessibilityIdentifier("settings-start-compatibility-runtime")
    }

    private var diagnosticsActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppDesignSystem.Spacing.sm) {
                runDiagnosticsButton
                copyDiagnosticsButton
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                runDiagnosticsButton
                copyDiagnosticsButton
            }
        }
        .controlSize(.small)
    }

    private var runDiagnosticsButton: some View {
        Button {
            backend.runDiagnostics(configuration: settings.snapshot)
        } label: {
            Label("Run Diagnostics", systemImage: "checklist")
        }
        .accessibilityIdentifier("settings-run-diagnostics")
    }

    private var copyDiagnosticsButton: some View {
        Button {
            copyDiagnostics()
        } label: {
            Label("Copy Diagnostics", systemImage: "doc.on.doc")
        }
        .disabled(backend.diagnostics.isEmpty)
        .accessibilityIdentifier("settings-copy-diagnostics")
    }

    @ViewBuilder
    private var diagnosticsRows: some View {
        if backend.diagnostics.isEmpty {
            Text("No diagnostics have been captured yet.")
                .font(AppDesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(backend.diagnostics) { item in
                HStack(alignment: .top, spacing: AppDesignSystem.Spacing.sm) {
                    Image(systemName: iconName(for: item.severity))
                        .foregroundStyle(color(for: item.severity))
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(AppDesignSystem.Typography.headline)
                        Text(item.detail)
                            .font(AppDesignSystem.Typography.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    SettingsStatusPill(text: item.severity.rawValue, severity: item.severity)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(item.title), \(item.severity.rawValue)")
                .accessibilityValue(item.detail)
            }
        }
    }

    private func applySettings(restart: Bool) {
        settings.persistNonSecretSettings()
        backend.runDiagnostics(configuration: settings.snapshot)
        if restart {
            backend.restart(configuration: settings.snapshot)
        }
    }

    private func copyDiagnostics() {
        let lines = backend.diagnostics.map { "\($0.severity.rawValue): \($0.title) - \($0.detail)" }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }

    private func iconName(for severity: DiagnosticSeverity) -> String {
        switch severity {
        case .ok: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failure: "xmark.octagon.fill"
        }
    }

    private func color(for severity: DiagnosticSeverity) -> Color {
        switch severity {
        case .ok: AppDesignSystem.SemanticColors.statusReady
        case .warning: AppDesignSystem.SemanticColors.statusStarting
        case .failure: AppDesignSystem.SemanticColors.statusFailed
        }
    }
}

private struct SettingsApplyRow: View {
    let onApply: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: onApply) {
                Label("Apply", systemImage: "checkmark")
            }
            .accessibilityIdentifier("settings-apply")
        }
    }
}

private struct SettingsReadinessSummary: View {
    let snapshot: PaperBananaReadinessSnapshot

    var body: some View {
        LabeledContent("Status") {
            SettingsReadinessStatusPill(
                text: snapshot.statusTitle,
                severity: snapshot.severity
            )
        }

        Text(snapshot.statusMessage)
            .font(AppDesignSystem.Typography.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

        ForEach(snapshot.rows) { row in
            LabeledContent {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(row.value)
                        .font(row.id == .configuredPath ? .system(.caption, design: .monospaced) : AppDesignSystem.Typography.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(row.id == .configuredPath ? 2 : 1)
                        .truncationMode(.middle)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                        .help(row.value)

                    Text(row.detail)
                        .font(AppDesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.trailing)
                }
            } label: {
                Label(row.title, systemImage: row.systemImage)
                    .foregroundStyle(color(for: row.severity))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(row.title)
            .accessibilityValue("\(row.value). \(row.detail)")
        }
    }

    private func color(for severity: PaperBananaReadinessSeverity) -> Color {
        switch severity {
        case .ready: AppDesignSystem.SemanticColors.statusReady
        case .warning: AppDesignSystem.SemanticColors.statusStarting
        case .blocked: AppDesignSystem.SemanticColors.statusFailed
        }
    }
}

private struct SettingsReadinessStatusPill: View {
    let text: String
    let severity: PaperBananaReadinessSeverity

    var body: some View {
        Text(text)
            .font(AppDesignSystem.Typography.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
            .overlay {
                Capsule()
                    .stroke(color.opacity(0.28), lineWidth: 1)
            }
            .accessibilityLabel(text)
    }

    private var color: Color {
        switch severity {
        case .ready: AppDesignSystem.SemanticColors.statusReady
        case .warning: AppDesignSystem.SemanticColors.statusStarting
        case .blocked: AppDesignSystem.SemanticColors.statusFailed
        }
    }
}

private struct SettingsStatusPill: View {
    let text: String
    let severity: DiagnosticSeverity

    var body: some View {
        Text(text)
            .font(AppDesignSystem.Typography.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
            .overlay {
                Capsule()
                    .stroke(color.opacity(0.28), lineWidth: 1)
            }
            .accessibilityLabel(text)
    }

    private var color: Color {
        switch severity {
        case .ok: AppDesignSystem.SemanticColors.statusReady
        case .warning: AppDesignSystem.SemanticColors.statusStarting
        case .failure: AppDesignSystem.SemanticColors.statusFailed
        }
    }
}
