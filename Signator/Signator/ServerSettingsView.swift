//
//  ServerSettingsView.swift
//  Server configuration UI for three-target selection: Production, Dev/QA, and Local (ngrok)
//

import SwiftUI

struct ServerSettingsView: View {
    // MARK: - State
    
    @State private var selectedPreset: ServerConfig.Preset = .production
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        Form {
            currentServerSection
            presetServersSection
            actionsSection
            developmentTipSection
        }
        .navigationTitle("Server Settings")
        .inlineNavigationTitle()
        .onAppear {
            loadCurrentConfiguration()
        }
        .alert("Configuration Updated", isPresented: $showAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Sections
    
    private var currentServerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Server")
                    .font(.headline)
                
                Text(ServerConfig.baseURL)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                
                HStack(spacing: 4) {
                    Image(systemName: currentServerIcon)
                        .foregroundColor(currentServerColor)
                        .font(.caption)
                    Text(currentServerLabel)
                        .font(.caption)
                        .foregroundColor(currentServerColor)
                }
            }
        }
    }
    
    private var presetServersSection: some View {
        Section {
            Picker("Server Environment", selection: $selectedPreset) {
                ForEach(ServerConfig.Preset.allCases, id: \.self) { preset in
                    HStack {
                        Text(preset.displayName)
                        Spacer()
                        Text(preset.url)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .tag(preset)
                }
            }
            .pickerStyle(.inline)
        } header: {
            Text("Preset Servers")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("• **Production**: Live API server")
                Text("• **Dev/QA**: Development and testing environment")
                Text("• **Local**: api.local.451.info")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
    
    private var actionsSection: some View {
        Section {
            Button {
                saveConfiguration()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save Configuration")
                }
                .frame(maxWidth: .infinity)
            }
            
            if ServerConfig.isUsingCustomServer || ServerConfig.selectedPreset != .production {
                Button(role: .destructive) {
                    resetToDefaults()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                        Text("Reset to Production Default")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    private var developmentTipSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Development Tips")
                        .font(.headline)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("**Using ngrok for local development:**")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("1. Run: `ngrok http 8080`")
                    Text("2. Copy the https URL")
                    Text("3. Update the Hetzner nginx upstream to point to the new ngrok URL")
                    Text("4. Select **Local** above to hit api.local.451.info")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("**Server priority:**")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("1. Custom Server (legacy, if set)")
                    Text("2. Selected Preset (Production, Dev/QA, or Local)")
                    Text("3. Default (Production)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentServerIcon: String {
        if ServerConfig.isUsingCustomServer {
            return "network"
        } else if ServerConfig.selectedPreset == .development {
            return "hammer.fill"
        } else if ServerConfig.selectedPreset == .local {
            return "house.fill"
        } else {
            return "globe"
        }
    }
    
    private var currentServerColor: Color {
        if ServerConfig.isUsingCustomServer {
            return .orange
        } else if ServerConfig.selectedPreset == .development {
            return .blue
        } else if ServerConfig.selectedPreset == .local {
            return .purple
        } else {
            return .green
        }
    }
    
    private var currentServerLabel: String {
        if ServerConfig.isUsingCustomServer {
            return "Custom Server (legacy)"
        } else if ServerConfig.selectedPreset == .development {
            return "Dev/QA Environment"
        } else if ServerConfig.selectedPreset == .local {
            return "Local Environment (ngrok)"
        } else {
            return "Production Environment"
        }
    }
    
    // MARK: - Actions
    
    private func loadCurrentConfiguration() {
        selectedPreset = ServerConfig.selectedPreset
    }
    
    private func saveConfiguration() {
        // Clear any legacy custom server and save preset selection
        ServerConfig.setCustomServer(nil)
        ServerConfig.selectedPreset = selectedPreset
        alertMessage = "Server configured:\n\n\(selectedPreset.displayName)\n\(ServerConfig.baseURL)"
        
        showAlert = true
    }
    
    private func resetToDefaults() {
        ServerConfig.resetToDefaults()
        loadCurrentConfiguration()
        alertMessage = "Reset to production default:\n\n\(ServerConfig.baseURL)"
        showAlert = true
    }
}

#Preview {
    NavigationStack {
        ServerSettingsView()
    }
}
