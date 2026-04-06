import SwiftUI
import TokenBarCore

struct SettingsView: View {
    var pollingService: UsagePollingService

    var body: some View {
        TabView {
            GeneralSettingsTab(pollingService: pollingService)
                .tabItem { Label("General", systemImage: "gear") }
            ProvidersSettingsTab()
                .tabItem { Label("Providers", systemImage: "network") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 420, height: 300)
    }
}

private struct GeneralSettingsTab: View {
    var pollingService: UsagePollingService

    var body: some View {
        Form {
            Picker("Refresh interval", selection: Bindable(pollingService).interval) {
                ForEach(UsagePollingService.RefreshInterval.allCases, id: \.self) { interval in
                    Text(interval.displayName).tag(interval)
                }
            }
        }
        .padding()
    }
}

private struct ProvidersSettingsTab: View {
    @State private var claudeEnabled = ProviderRegistry.shared.isEnabled(.claude)
    @State private var openAIEnabled = ProviderRegistry.shared.isEnabled(.openai)
    @State private var openAIKey: String = ""
    @State private var saveStatus: String = ""

    var body: some View {
        Form {
            Section("Claude") {
                Toggle("Enable Claude", isOn: $claudeEnabled)
                    .onChange(of: claudeEnabled) { _, val in
                        ProviderRegistry.shared.setEnabled(.claude, enabled: val)
                    }
                Text("Reads sessionKey cookie from your browser.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("OpenAI") {
                Toggle("Enable OpenAI", isOn: $openAIEnabled)
                    .onChange(of: openAIEnabled) { _, val in
                        ProviderRegistry.shared.setEnabled(.openai, enabled: val)
                    }
                SecureField("API Key", text: $openAIKey)
                Button("Save Key") {
                    Task {
                        try? await KeychainManager.shared.save(key: "openai.apiKey", value: openAIKey)
                        saveStatus = "Saved"
                    }
                }
                if !saveStatus.isEmpty {
                    Text(saveStatus).font(.caption).foregroundStyle(.green)
                }
            }
        }
        .padding()
    }
}

private struct AboutTab: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("TokenBar")
                .font(.title)
            Text("Version \(appVersion)")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}
