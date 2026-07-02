//
//  ServerSettingsView.swift
//  Server configuration UI with segmented control: Production, Dev/QA, or Local
//

import SwiftUI

struct ServerSettingsViewSegmented: View {
    // MARK: - Server Selection Mode
    
    enum ServerMode: String, CaseIterable {
        case production = "Production"
        case devQA = "Dev/QA"
        case local = "Local"
        
        var icon: String {
            switch self {
            case .production: return "globe"
            case .devQA: return "hammer.fill"
            case .local: return "house.fill"
            }
        }
    }
    
    // MARK: - State
    
    @State private var serverMode: ServerMode = .devQA  // Default to Dev/QA
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        Form {
            currentServerSection
            serverSelectionSection
            actionsSection
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
                Text("Current Active Server")
                    .font(.headline)
                
                Text(ServerConfig.baseURL)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                
                HStack(spacing: 6) {
                    Image(systemName: serverMode.icon)
                        .foregroundColor(currentServerColor)
                    Text(serverMode.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(currentServerColor)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var serverSelectionSection: some View {
        Section {
            Picker("Server Environment", selection: $serverMode) {
                ForEach(ServerMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: serverMode) { newMode in
                autoSavePreset(newMode)
            }
        } header: {
            Text("Select Server Environment")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                switch serverMode {
                case .production:
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("**✓ Production Server Active**")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            Text("Live API: \(ServerConfig.Preset.production.url)")
                                .font(.system(.caption, design: .monospaced))
                            Text("Use for production builds and real data.")
                        }
                    }
                case .devQA:
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("**✓ Dev/QA Server Active**")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            Text("Dev API: \(ServerConfig.Preset.development.url)")
                                .font(.system(.caption, design: .monospaced))
                            Text("Use for testing and development. This is the default.")
                        }
                    }
                case .local:
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.purple)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("**✓ Local Server Active**")
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                            Text("Local API: \(ServerConfig.Preset.local.url)")
                                .font(.system(.caption, design: .monospaced))
                            Text("Use for local development.")
                        }
                    }
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
    
    private var actionsSection: some View {
        Section {
            // Show reset button when not using default Dev/QA
            if ServerConfig.selectedPreset != .development {
                Button(role: .destructive) {
                    resetToDevDefault()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                        Text("Reset to Dev/QA Default")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        } footer: {
            Text("Servers are activated immediately when selected.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentServerColor: Color {
        switch serverMode {
        case .production: return .green
        case .devQA: return .blue
        case .local: return .purple
        }
    }
    
    // MARK: - Actions
    
    private func loadCurrentConfiguration() {
        switch ServerConfig.selectedPreset {
        case .production:
            serverMode = .production
        case .development:
            serverMode = .devQA
        case .local:
            serverMode = .local
        }
    }
    
    private func autoSavePreset(_ mode: ServerMode) {
        ServerConfig.setCustomServer(nil)  // Clear any custom server
        
        switch mode {
        case .production:
            ServerConfig.selectedPreset = .production
        case .devQA:
            ServerConfig.selectedPreset = .development
        case .local:
            ServerConfig.selectedPreset = .local
        }
        
        print("🔄 Auto-saved server preset: \(mode.rawValue) → \(ServerConfig.baseURL)")
    }
    
    private func resetToDevDefault() {
        ServerConfig.setCustomServer(nil)
        ServerConfig.selectedPreset = .development
        serverMode = .devQA
        alertMessage = "✅ Reset to Dev/QA default:\n\n\(ServerConfig.baseURL)"
        showAlert = true
    }
}

#Preview {
    NavigationStack {
        ServerSettingsViewSegmented()
    }
}
