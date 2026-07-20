import Foundation
import SwiftUI



struct EditPersonaView: View {
    @ObservedObject var personaManager: PersonaManager
    private let originalPersona: Persona
    @Environment(\.dismiss) var dismiss
    
   
    @State private var name: String
    @State private var address: String
    @State private var affiliations: String
    @State private var socialLinks: String
    @State private var errorMessage: String? = nil
    
    init(personaManager: PersonaManager, persona: Persona) {
        self.personaManager = personaManager
        self.originalPersona = persona
        _name = State(initialValue: persona.name)
        _address = State(initialValue: persona.address ?? "")
        _affiliations = State(initialValue: persona.affiliations ?? "")
        _socialLinks = State(initialValue: persona.socialLinks ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Name")) {
                    TextField("Name", text: $name)
                }
                Section(header: Text("Address")) {
                    TextField("Address", text: $address)
                }
                Section(header: Text("Affiliations")) {
                    TextField("Affiliations", text: $affiliations)
                }
                Section(header: Text("Social Media Links")) {
                    TextField("Social Media Links (comma-separated URLs)", text: $socialLinks)
                }
                Section {
                    Button("Save Changes") {
                        saveChanges()
                    }
                }
            }
            .navigationTitle("Edit Persona")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func saveChanges() {
        var updatedPersona = originalPersona
        updatedPersona.name = name
        updatedPersona.address = address.isEmpty ? nil : address
        updatedPersona.affiliations = affiliations.isEmpty ? nil : affiliations
        updatedPersona.socialLinks = socialLinks.isEmpty ? nil : socialLinks

        personaManager.updatePersona(updatedPersona)
        if let _ = personaManager.personas.firstIndex(where: { $0.id == updatedPersona.id }) {
            dismiss()
        } else {
            errorMessage = "Failed to find persona for updating."
        }
    }
}

