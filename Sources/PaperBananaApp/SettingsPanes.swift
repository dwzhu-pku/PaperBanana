import AppKit
import SwiftUI

struct WorkspaceSettingsPane: View {
    @ObservedObject var settings: AppSettingsStore
    @ObservedObject var backend: BackendSupervisor

    var body: some View {
        Form {
            Section("Native Workspace") {
                TextField("PaperBanana checkout", text: $settings.repoPath)
                Text("Native workflows scan and write run records, provider ledgers, recovered artifacts, and generated images under this checkout.")
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("PaperBanana Readiness") {
                PaperBananaReadinessPanel(snapshot: settings.readinessSnapshot())
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
                TextField("Reasoning effort", text: $settings.codexReasoning)
            }

            SettingsApplyRow {
                applySettings(restart: false)
            }
        }
        .formStyle(.grouped)
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
                        .textSelection(.enabled)
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
                providerKeyActions(
                    saveTitle: "Save Google Key Locally",
                    canSave: settings.pendingGoogleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                    canClear: settings.hasGoogleAPIKey,
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
                providerKeyActions(
                    saveTitle: "Save OpenRouter Key Locally",
                    canSave: settings.pendingOpenRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                    canClear: settings.hasOpenRouterAPIKey,
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
    }

    private func providerKeyActions(
        saveTitle: String,
        canSave: Bool,
        canClear: Bool,
        onSave: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        HStack {
            Button(action: onSave) {
                Label(saveTitle, systemImage: "key.fill")
            }
            .disabled(!canSave)

            Button(role: .destructive, action: onClear) {
                Label("Clear", systemImage: "trash")
            }
            .disabled(!canClear)
        }
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
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
            legacyCompatibilityPanel
            diagnosticsActions
            diagnosticsList
        }
    }

    private var legacyCompatibilityPanel: some View {
        WorkbenchSection(
            "Legacy Gradio Compatibility",
            systemImage: "globe.badge.chevron.backward",
            subtitle: "Use only for the older pipeline UI. Native generation, refinement, recovery, and provider auditing do not require this backend."
        ) {
            HStack(spacing: AppDesignSystem.Spacing.md) {
                Stepper(value: $settings.serverPort, in: 1024...65535) {
                    LabeledContent("Local server port") {
                        Text("\(settings.serverPort)")
                            .monospacedDigit()
                    }
                }

                Spacer(minLength: AppDesignSystem.Spacing.lg)

                Button {
                    applySettings(restart: false)
                } label: {
                    Label("Apply Legacy Settings", systemImage: "checkmark")
                }

                Button {
                    applySettings(restart: true)
                } label: {
                    Label("Apply and Start Compatibility Runtime", systemImage: "play")
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.small)
        }
    }

    private var diagnosticsActions: some View {
        HStack {
            Button {
                backend.runDiagnostics(configuration: settings.snapshot)
            } label: {
                Label("Run Diagnostics", systemImage: "checklist")
            }

            Button {
                copyDiagnostics()
            } label: {
                Label("Copy Diagnostics", systemImage: "doc.on.doc")
            }
            .disabled(backend.diagnostics.isEmpty)

            Spacer()
        }
        .controlSize(.small)
    }

    private var diagnosticsList: some View {
        List(backend.diagnostics) { item in
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
                Text(item.severity.rawValue)
                    .font(AppDesignSystem.Typography.caption)
                    .foregroundStyle(color(for: item.severity))
            }
            .padding(.vertical, 4)
        }
        .listStyle(.inset)
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
    }

    private var color: Color {
        switch severity {
        case .ok: AppDesignSystem.SemanticColors.statusReady
        case .warning: AppDesignSystem.SemanticColors.statusStarting
        case .failure: AppDesignSystem.SemanticColors.statusFailed
        }
    }
}
