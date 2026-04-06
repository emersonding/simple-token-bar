import SwiftUI
import TokenBarCore

struct PopoverContentView: View {
    @State var pollingService: UsagePollingService
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if showSettings {
                InlineSettingsView(pollingService: pollingService)
                    .frame(height: 340)
            } else {
                content
            }
            Divider()
            footer
        }
        .frame(width: 320)
    }

    private var header: some View {
        HStack {
            if showSettings {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showSettings = false }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                Text("Settings")
                    .font(.headline)
            } else {
                Text("TokenBar")
                    .font(.headline)
            }
            Spacer()
            if !showSettings {
                Button {
                    Task { await pollingService.refreshNow() }
                } label: {
                    Image(systemName: pollingService.isRefreshing ? "arrow.circlepath" : "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(pollingService.isRefreshing)
            }
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showSettings.toggle() }
            } label: {
                Image(systemName: "gear")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var content: some View {
        Group {
            let enabledIDs = ProviderID.allCases.filter { ProviderRegistry.shared.isEnabled($0) }
            if enabledIDs.isEmpty {
                VStack(spacing: 8) {
                    Text("No providers configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") {
                        withAnimation(.easeInOut(duration: 0.15)) { showSettings = true }
                    }
                    .buttonStyle(.borderless)
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(enabledIDs, id: \.self) { id in
                            if let result = pollingService.snapshots[id] {
                                ProviderRowView(providerID: id, result: result)
                                    .padding(.horizontal, 12)
                            }
                            if id != enabledIDs.last {
                                Divider().padding(.horizontal, 12)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if showSettings {
                Button("Quit TokenBar") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .font(.caption)
            } else if let updated = pollingService.lastUpdated {
                Text("Updated \(updated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if !showSettings {
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Quit TokenBar")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Inline Settings (within the popover)

private struct InlineSettingsView: View {
    var pollingService: UsagePollingService
    @State private var claudeEnabled = ProviderRegistry.shared.isEnabled(.claude)
    @State private var openAIEnabled = ProviderRegistry.shared.isEnabled(.openai)
    @State private var openAIKey: String = ""
    @State private var saveStatus: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Refresh interval
                VStack(alignment: .leading, spacing: 4) {
                    Text("Refresh Interval")
                        .font(.subheadline.bold())
                    Picker("", selection: Bindable(pollingService).interval) {
                        ForEach(UsagePollingService.RefreshInterval.allCases, id: \.self) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                Divider()

                // Claude
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Claude", isOn: $claudeEnabled)
                        .onChange(of: claudeEnabled) { _, val in
                            ProviderRegistry.shared.setEnabled(.claude, enabled: val)
                        }
                    Text("Reads sessionKey cookie from Chrome")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // OpenAI / Codex
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("OpenAI / Codex", isOn: $openAIEnabled)
                        .onChange(of: openAIEnabled) { _, val in
                            ProviderRegistry.shared.setEnabled(.openai, enabled: val)
                        }
                    Text("Auto-detects from Codex CLI (~/.codex/auth.json)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    DisclosureGroup("Manual API Key") {
                        HStack {
                            SecureField("API Key", text: $openAIKey)
                                .textFieldStyle(.roundedBorder)
                            Button("Save") {
                                Task {
                                    try? await KeychainManager.shared.save(key: "openai.apiKey", value: openAIKey)
                                    saveStatus = "Saved!"
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saveStatus = "" }
                                }
                            }
                        }
                        if !saveStatus.isEmpty {
                            Text(saveStatus).font(.caption).foregroundStyle(.green)
                        }
                    }
                    .font(.caption)
                }

                Divider()

                // About
                HStack {
                    Text("TokenBar v1.0.0")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
            .padding(12)
        }
    }
}
