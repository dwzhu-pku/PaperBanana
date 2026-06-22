import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettingsStore
    @ObservedObject var backend: BackendSupervisor

    var body: some View {
        TabView {
            WorkspaceSettingsPane(settings: settings, backend: backend)
                .tabItem {
                    Label("Workspace", systemImage: "folder")
                }

            ProviderSettingsPane(settings: settings, backend: backend)
                .tabItem {
                    Label("Providers", systemImage: "key")
                }

            LegacySettingsPane(settings: settings, backend: backend)
                .tabItem {
                    Label("Legacy", systemImage: "stethoscope")
                }
        }
        .scenePadding()
        .frame(minWidth: 640, idealWidth: 760, minHeight: 520, idealHeight: 620)
        .onAppear {
            backend.runDiagnostics(configuration: settings.snapshot)
        }
    }
}
