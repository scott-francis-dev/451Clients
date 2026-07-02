import SwiftUI

struct PersonaEditView: View {
    @ObservedObject var personaManager: PersonaManager
    let persona: Persona
    var onSave: (Persona) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var handle: String
    @State private var email: String
    @State private var affiliations: String
    @State private var socialLinks: String
    @State private var visibilityIsPublic: Bool

    init(personaManager: PersonaManager, persona: Persona, onSave: @escaping (Persona) -> Void) {
        self.personaManager = personaManager
        self.persona = persona
        self.onSave = onSave
        _name = State(initialValue: persona.name)
        _handle = State(initialValue: persona.handle)
        _email = State(initialValue: persona.email ?? "")
        _affiliations = State(initialValue: persona.affiliations ?? "")
        _socialLinks = State(initialValue: persona.socialLinks ?? "")
        _visibilityIsPublic = State(initialValue: persona.visibility == .public)
    }

    var body: some View {
        Form {
            Section {
                TextField("Display Name", text: $name, prompt: Text("Scott Francis"))
                
                TextField("Handle (ATProtocol)", text: $handle, prompt: Text("scott-francis.451-project.451.info"))
                    .platformAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(.system(.body, design: .monospaced))
            } header: {
                Text("Identity")
            } footer: {
                Text("Handle is your human-readable ATProtocol identifier, constructed from your name and publishing house")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Section {
                TextField("Public Email", text: $email)
                    .platformAutocapitalization(.never)
                    .platformKeyboardType(.emailAddress)
                    .autocorrectionDisabled(true)
                TextField("Affiliations", text: $affiliations)
                TextField("Social Links", text: $socialLinks)
            } header: {
                Text("Public Info")
            }
            Section {
                Toggle(isOn: $visibilityIsPublic) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(visibilityIsPublic ? "Public Persona" : "Private Persona")
                            .font(.headline)
                        Text(visibilityIsPublic ? "Visible for publishing." : "Hidden; used for private signing.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Visibility")
            }
        }
        .navigationTitle("Edit Persona")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
    }

    private func save() {
        var updated = persona
        updated.name = name
        updated.handle = handle
        updated.email = email.isEmpty ? nil : email
        updated.affiliations = affiliations.isEmpty ? nil : affiliations
        updated.socialLinks = socialLinks.isEmpty ? nil : socialLinks
        updated.visibility = visibilityIsPublic ? .public : .private
        onSave(updated)
        dismiss()
    }
}

