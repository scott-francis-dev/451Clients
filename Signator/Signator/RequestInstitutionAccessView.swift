// RequestInstitutionAccessView.swift
// Staff member requests access to an institution (e.g., a new doctor joining a hospital system).
//
// Flow:
//  1. User selects which persona to use for the request.
//  2. User enters the institution domain (e.g., "hillsborohospital.org") and their role.
//  3. Signator POSTs the request to S451 → S451 stores it for the institution admin.
//  4. Institution admin (Bobby Sue) sees the request in InstitutionAdminView and approves it.
//  5. On approval, a Verifiable Credential arrives in Signator via APNs.

import SwiftUI

@MainActor
struct RequestInstitutionAccessView: View {

    @EnvironmentObject private var personaManager: PersonaManager
    @Environment(\.dismiss) private var dismiss

    @State private var institutionDomain = ""
    @State private var requestedRole = "Physician"
    @State private var npi = ""
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var errorMessage: String? = nil

    private var selectedPersona: Persona? { personaManager.activePersona() }

    private let roleOptions = [
        "Physician", "Nurse Practitioner", "Physician Assistant",
        "Registered Nurse", "PharmD", "Medical Assistant", "Admin Staff"
    ]

    var body: some View {
        NavigationStack {
            Form {
                // Persona being used for the request
                if let persona = selectedPersona {
                    Section("Requesting As") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(persona.name).font(.headline)
                            Text(persona.handle)
                                .font(.caption).foregroundColor(.secondary)
                            Text(persona.id)
                                .font(.caption2).foregroundColor(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Section {
                        Label("Select an active persona first.", systemImage: "person.crop.circle.badge.exclamationmark")
                            .foregroundColor(.orange)
                    }
                }

                Section {
                    TextField("Domain (e.g. hillsborohospital.org)", text: $institutionDomain)
                        .platformAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .platformKeyboardType(.url)
                } header: {
                    Text("Institution")
                } footer: {
                    Text("Enter the institution's domain — the same one used in its did:web identity.")
                        .font(.footnote)
                }

                Section("Role Request") {
                    Picker("Role", selection: $requestedRole) {
                        ForEach(roleOptions, id: \.self) { role in
                            Text(role).tag(role)
                        }
                    }

                    TextField("NPI (optional)", text: $npi)
                        .platformKeyboardType(.numberPad)
                }

                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: 80)
                } header: {
                    Text("Personal Note (optional)")
                } footer: {
                    Text("A brief note to the institution administrator explaining your request.")
                        .font(.footnote)
                }

                if let err = errorMessage {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                if submitted {
                    Section {
                        Label("Request submitted! You'll receive a credential notification when approved.", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                Section {
                    Button {
                        Task { await submitRequest() }
                    } label: {
                        if isSubmitting {
                            HStack {
                                ProgressView()
                                Text("Submitting…")
                            }
                        } else {
                            Text("Request Access")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSubmitting || submitted || selectedPersona == nil || institutionDomain.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Request Institution Access")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func submitRequest() async {
        guard let persona = selectedPersona else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let domain = institutionDomain.trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")

        do {
            try await InstitutionAPIService.requestAccess(
                subjectPersona: persona,
                institutionDomain: domain,
                requestedRole: requestedRole,
                npi: npi.trimmingCharacters(in: .whitespaces).isEmpty ? nil : npi.trimmingCharacters(in: .whitespaces),
                message: message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : message
            )
            submitted = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    RequestInstitutionAccessView()
        .environmentObject(PersonaManager())
}
