// BackgroundCheckRequestView.swift
// UI for requesting background check / identity verification

import SwiftUI

struct BackgroundCheckRequestView: View {
    @ObservedObject var personaManager: PersonaManager
    @Binding var backgroundCheckRequired: Bool
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedMethod: BackgroundCheckMethod = .humanToPersona
    @State private var personaDID: String = ""
    @State private var isLoading: Bool = false
    @State private var validationResult: String? = nil
    @State private var validationError: String? = nil
    
    enum BackgroundCheckMethod: String, CaseIterable {
        case humanToPersona = "Human-to-Persona Verification"
        case documentBased = "Document-Based Verification"
        case witnessAttestation = "Witness Attestation"
        
        var description: String {
            switch self {
            case .humanToPersona:
                return "Link your real identity to your digital persona using biometric verification and location data."
            case .documentBased:
                return "Upload government-issued ID documents for manual verification."
            case .witnessAttestation:
                return "Have trusted witnesses attest to your identity."
            }
        }
        
        var icon: String {
            switch self {
            case .humanToPersona:
                return "person.text.rectangle"
            case .documentBased:
                return "doc.text.fill"
            case .witnessAttestation:
                return "person.2.fill"
            }
        }
    }
    
    var body: some View {
        Form {
            Section {
                Text("Background checks provide additional trust and legal validity to your persona by linking it to your real-world identity.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Section {
                Picker("Verification Method", selection: $selectedMethod) {
                    ForEach(BackgroundCheckMethod.allCases, id: \.self) { method in
                        Label(method.rawValue, systemImage: method.icon)
                            .tag(method)
                    }
                }
                .pickerStyle(.menu)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: selectedMethod.icon)
                            .foregroundColor(.blue)
                        Text(selectedMethod.rawValue)
                            .font(.headline)
                    }
                    Text(selectedMethod.description)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Verification Method")
            }
            
            if selectedMethod == .humanToPersona {
                humanToPersonaSection
            } else if selectedMethod == .documentBased {
                documentBasedSection
            } else {
                witnessSection
            }
            
            if let result = validationResult {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Request Submitted", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        ScrollView {
                            Text(result)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.platformSecondaryBackground)
                                .cornerRadius(6)
                        }
                        .frame(maxHeight: 200)
                    }
                } header: {
                    Text("Verification Details")
                }
            }
            
            if let error = validationError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            }
            
            Section {
                Button {
                    initiateBackgroundCheck()
                } label: {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("Processing...")
                        }
                    } else {
                        Text(validationResult != nil ? "Submit Another Request" : "Submit Verification Request")
                    }
                }
                .disabled(isLoading || !canSubmit)
                
                if validationResult != nil {
                    Button {
                        markAsComplete()
                    } label: {
                        Text("Mark as Complete & Return")
                    }
                }
            }
        }
        .navigationTitle("Background Check")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear {
            // Pre-fill persona DID if available
            if let activePersona = personaManager.personas.first {
                personaDID = activePersona.id
            }
        }
    }
    
    private var humanToPersonaSection: some View {
        Section {
            TextField("Persona DID", text: $personaDID)
                .autocorrectionDisabled(true)
                .platformAutocapitalization(.never)

            VStack(alignment: .leading, spacing: 8) {
                Label("Required:", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("• Valid government-issued photo ID")
                    .font(.caption)
                Text("• Biometric data (Face ID / Touch ID)")
                    .font(.caption)
                Text("• GPS location verification")
                    .font(.caption)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Persona Information")
        } footer: {
            Text("You'll be asked to take a photo of your ID and a selfie for biometric matching.")
                .font(.footnote)
        }
    }
    
    private var documentBasedSection: some View {
        Section {
            TextField("Persona DID", text: $personaDID)
                .autocorrectionDisabled(true)
                .platformAutocapitalization(.never)

            VStack(alignment: .leading, spacing: 8) {
                Label("Accepted Documents:", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("• Driver's License")
                    .font(.caption)
                Text("• Passport")
                    .font(.caption)
                Text("• State ID Card")
                    .font(.caption)
                Text("• Birth Certificate")
                    .font(.caption)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Document Information")
        } footer: {
            Text("Manual review typically takes 1-3 business days.")
                .font(.footnote)
        }
    }
    
    private var witnessSection: some View {
        Section {
            TextField("Persona DID", text: $personaDID)
                .autocorrectionDisabled(true)
                .platformAutocapitalization(.never)

            VStack(alignment: .leading, spacing: 8) {
                Label("Requirements:", systemImage: "person.2")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("• Minimum 2 witnesses required")
                    .font(.caption)
                Text("• Witnesses must have validated personas")
                    .font(.caption)
                Text("• Witnesses will sign cryptographically")
                    .font(.caption)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Witness Attestation")
        } footer: {
            Text("You'll receive a unique link to share with your witnesses.")
                .font(.footnote)
        }
    }
    
    private var canSubmit: Bool {
        !personaDID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func initiateBackgroundCheck() {
        isLoading = true
        validationError = nil
        validationResult = nil
        
        Task {
            do {
                // Simulate network request (in production, call actual API)
                try await Task.sleep(nanoseconds: 2_000_000_000)
                
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let nonce = UUID().uuidString
                
                let result: String
                switch selectedMethod {
                case .humanToPersona:
                    result = """
                    Human-to-Persona Verification Initiated
                    
                    Persona DID: \(personaDID)
                    Verification ID: \(nonce)
                    Timestamp: \(timestamp)
                    Status: Pending Biometric Match
                    
                    Next Steps:
                    1. Prepare government-issued photo ID
                    2. Ensure good lighting for photos
                    3. Complete biometric verification
                    4. Confirm GPS location
                    
                    Estimated completion: 5-10 minutes
                    """
                    
                case .documentBased:
                    result = """
                    Document Verification Request Created
                    
                    Persona DID: \(personaDID)
                    Request ID: \(nonce)
                    Timestamp: \(timestamp)
                    Status: Awaiting Document Upload
                    
                    Upload your documents via the secure portal:
                    https://verify.signator.example.com/upload/\(nonce)
                    
                    Estimated review time: 1-3 business days
                    """
                    
                case .witnessAttestation:
                    result = """
                    Witness Attestation Request Created
                    
                    Persona DID: \(personaDID)
                    Attestation ID: \(nonce)
                    Timestamp: \(timestamp)
                    Status: Pending Witness Signatures
                    
                    Share this link with your witnesses:
                    https://verify.signator.example.com/attest/\(nonce)
                    
                    Required: 2 witness signatures minimum
                    """
                }
                
                await MainActor.run {
                    isLoading = false
                    validationResult = result
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    validationError = "Failed to initiate verification: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func markAsComplete() {
        backgroundCheckRequired = true
        dismiss()
    }
}

#Preview {
    NavigationStack {
        BackgroundCheckRequestView(
            personaManager: PersonaManager(),
            backgroundCheckRequired: .constant(false)
        )
    }
}
