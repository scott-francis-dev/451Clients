//
//  PersonaDebugView.swift
//  451Wallet
//
//  Debug view to help diagnose persona storage issues
//

import SwiftUI

struct PersonaDebugView: View {
    @ObservedObject var personaManager: PersonaManager
    @State private var auditResults: String = ""
    @State private var recoveryDID: String = ""
    @State private var recoveryStatus: String = ""
    @State private var isRecovering = false
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Personas in Memory")
                        .font(.headline)
                    Text("\(personaManager.personas.count) persona(s)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Persona List") {
                if personaManager.personas.isEmpty {
                    Text("No personas found in PersonaManager")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(personaManager.personas, id: \.id) { persona in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(persona.name)
                                .font(.headline)
                            Text(persona.id)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Key exists: \(SecureEnclaveKeyStore.keyExists(for: persona.id) ? "✅ Yes" : "❌ No")")
                                .font(.caption2)
                                .foregroundColor(SecureEnclaveKeyStore.keyExists(for: persona.id) ? .green : .red)
                        }
                    }
                }
            }
            
            Section("Audit Secure Enclave") {
                Button {
                    runAudit()
                } label: {
                    Label("Run Audit", systemImage: "magnifyingglass")
                }
                
                if !auditResults.isEmpty {
                    Text(auditResults)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Recover Persona by DID") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("If you know a DID that should exist but isn't showing up, enter it here:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("did:451:...", text: $recoveryDID)
                        .textFieldStyle(.roundedBorder)
                        .platformAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button {
                        recoverPersona()
                    } label: {
                        if isRecovering {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Recover Persona", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(recoveryDID.isEmpty || isRecovering)
                    .buttonStyle(.bordered)
                    
                    if !recoveryStatus.isEmpty {
                        Text(recoveryStatus)
                            .font(.caption)
                            .foregroundColor(recoveryStatus.contains("✅") ? .green : .red)
                    }
                }
            }
            
            Section("Storage Location") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Personas are stored in:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("UserDefaults (App Group)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Keys: group.org.the451project.451apps")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .monospaced()
                    
                    Divider()
                    
                    Text("Private keys are stored in:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Secure Enclave / Keychain")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Tag: org.the451project.secureenclave.[DID]")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .monospaced()
                }
            }
            
            Section("Understanding the Architecture") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How personas work:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("1️⃣")
                            Text("Persona metadata (name, email, etc.) is stored in UserDefaults")
                                .font(.caption)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("2️⃣")
                            Text("Private keys are stored separately in the Secure Enclave")
                                .font(.caption)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("3️⃣")
                            Text("The app displays personas from UserDefaults only")
                                .font(.caption)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("⚠️")
                            Text("If metadata isn't saved to UserDefaults, the persona won't appear even if the key exists")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            
            Section("Manual Key Deletion") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Delete a Secure Enclave key by DID:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("did:451:...", text: $recoveryDID)
                        .textFieldStyle(.roundedBorder)
                        .platformAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button(role: .destructive) {
                        deleteKeyByDID(recoveryDID)
                    } label: {
                        Label("Delete Key from Secure Enclave", systemImage: "key.slash")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(recoveryDID.isEmpty)
                    .buttonStyle(.bordered)
                    
                    Text("⚠️ This deletes only the Secure Enclave key, not persona metadata")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            Section("Danger Zone") {
                Button(role: .destructive) {
                    personaManager.deleteAllPersonas()
                    auditResults = ""
                    recoveryStatus = ""
                } label: {
                    Label("Delete All Personas & Keys", systemImage: "trash.fill")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Debug Personas")
    }
    
    private func runAudit() {
        auditResults = "Running audit...\n"
        
        auditResults += "\n📊 Personas in UserDefaults: \(personaManager.personas.count)\n"
        
        for persona in personaManager.personas {
            let hasKey = SecureEnclaveKeyStore.keyExists(for: persona.id)
            auditResults += "\n\(hasKey ? "✅" : "❌") \(persona.name)\n"
            auditResults += "   DID: \(persona.id)\n"
            auditResults += "   Key: \(hasKey ? "Found" : "MISSING")\n"
        }
        
        if personaManager.personas.isEmpty {
            auditResults += "\n⚠️ No personas in UserDefaults\n"
            auditResults += "\nThis means either:\n"
            auditResults += "• You haven't created any personas yet\n"
            auditResults += "• Or the personas were created but metadata wasn't saved\n"
        }
        
        auditResults += "\n💡 Note: The Secure Enclave doesn't provide a 'list all keys' API\n"
        auditResults += "We can only check for keys of known personas\n"
    }
    
    private func recoverPersona() {
        isRecovering = true
        recoveryStatus = "Recovering..."
        
        Task {
            do {
                try await personaManager.recoverPersonaByDID(recoveryDID)
                await MainActor.run {
                    recoveryStatus = "✅ Persona recovered successfully"
                    recoveryDID = ""
                    isRecovering = false
                }
            } catch {
                await MainActor.run {
                    recoveryStatus = "❌ Recovery failed: \(error.localizedDescription)"
                    isRecovering = false
                }
            }
        }
    }
    
    private func deleteKeyByDID(_ did: String) {
        guard !did.isEmpty else { return }
        
        // Check if key exists before deletion
        let exists = SecureEnclaveKeyStore.keyExists(for: did)
        
        if exists {
            PrivateKeyStore.deletePrivateKey(for: did)
            recoveryStatus = "✅ Deleted Secure Enclave key for: \(did)"
        } else {
            recoveryStatus = "⚠️ No key found for: \(did)"
        }
        
        recoveryDID = ""
    }
}

#Preview {
    NavigationStack {
        PersonaDebugView(personaManager: PersonaManager())
    }
}
