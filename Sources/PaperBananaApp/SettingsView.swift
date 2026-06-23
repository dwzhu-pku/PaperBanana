import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettingsStore
    @ObservedObject var backend: BackendSupervisor
    @State private var selection = SettingsPane.workspace

    var body: some View {
        TabView(selection: $selection) {
            SettingsPaneContent(pane: .workspace) {
                WorkspaceSettingsPane(settings: settings, backend: backend)
            }
            .tabItem {
                Label(SettingsPane.workspace.title, systemImage: SettingsPane.workspace.systemImage)
            }
            .tag(SettingsPane.workspace)

            SettingsPaneContent(pane: .providers) {
                ProviderSettingsPane(settings: settings, backend: backend)
            }
            .tabItem {
                Label(SettingsPane.providers.title, systemImage: SettingsPane.providers.systemImage)
            }
            .tag(SettingsPane.providers)

            SettingsPaneContent(pane: .legacy) {
                LegacySettingsPane(settings: settings, backend: backend)
            }
            .tabItem {
                Label(SettingsPane.legacy.title, systemImage: SettingsPane.legacy.systemImage)
            }
            .tag(SettingsPane.legacy)
        }
        .scenePadding()
        .frame(minWidth: 680, idealWidth: 820, minHeight: 560, idealHeight: 700)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("PaperBanana Settings")
        .accessibilityValue(selection.subtitle)
        .accessibilityIdentifier("paperbanana-settings-window")
        .onAppear {
            backend.runDiagnostics(configuration: settings.snapshot)
        }
    }
}

private struct SettingsPaneContent<Content: View>: View {
    let pane: SettingsPane
    @ViewBuilder let content: Content

    init(pane: SettingsPane, @ViewBuilder content: () -> Content) {
        self.pane = pane
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(maxWidth: 860, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(pane.title) settings")
        .accessibilityValue(pane.subtitle)
        .accessibilityIdentifier("settings-pane-\(pane.rawValue)")
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case workspace
    case providers
    case legacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workspace: "Workspace"
        case .providers: "Providers"
        case .legacy: "Legacy"
        }
    }

    var subtitle: String {
        switch self {
        case .workspace:
            "Checkout path, readiness, and native generation defaults."
        case .providers:
            "Local provider credentials and saved-key status."
        case .legacy:
            "Compatibility runtime controls and diagnostics."
        }
    }

    var systemImage: String {
        switch self {
        case .workspace: "folder"
        case .providers: "key"
        case .legacy: "stethoscope"
        }
    }
}
