import SwiftUI

struct PersonaListView: View {
    @ObservedObject var personaManager: PersonaManager
    @State private var showingCreate = false
    @State private var showCreatePersonaForClient = false
    @State private var showAcceptProposedPersona = false
    @State private var editTarget: Persona? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Proposed Personas")
                            .font(.headline)
                        Text("Send a proposed persona to a client or accept one they sent you.")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        Button {
                            showCreatePersonaForClient = true
                        } label: {
                            Label("Propose Persona for Client", systemImage: "person.crop.circle.badge.checkmark")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            showAcceptProposedPersona = true
                        } label: {
                            Label("Accept Proposed Persona", systemImage: "person.crop.circle.badge.plus")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }

                if personaManager.personas.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No personas yet")
                                .font(.headline)
                            Text("Create a persona to start publishing or sign privately.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }
                }
                Section {
                    ForEach(personaManager.personas, id: \.id) { persona in
                        HStack(spacing: 12) {
                            // Active indicator
                            Image(systemName: isActive(persona) ? "person.crop.circle.fill" : "person.crop.circle")
                                .foregroundColor(isActive(persona) ? .blue : .secondary)
                                .font(.title3)
                            
                            // Use the Signator Calling Card component
                            PersonaHandleDetailCard(
                                persona: persona,
                                size: .compact,
                                showDID: false,
                                showCopyButton: false
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if isActive(persona) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }

                            Menu {
                                Button {
                                    personaManager.setActivePersona(persona)
                                } label: {
                                    Label("Set Active", systemImage: "checkmark.circle")
                                }
                                Button {
                                    editTarget = persona
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    personaManager.deletePersona(persona)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            personaManager.setActivePersona(persona)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let persona = personaManager.personas[index]
                            personaManager.deletePersona(persona)
                        }
                    }
                } header: {
                    Text("Personas")
                }
            }
            .navigationTitle("Personas")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingCreate = true
                        } label: {
                            Label("New Persona", systemImage: "person.crop.circle.badge.plus")
                        }
                        Button {
                            showCreatePersonaForClient = true
                        } label: {
                            Label("Propose Persona for Client", systemImage: "person.crop.circle.badge.checkmark")
                        }
                        Button {
                            showAcceptProposedPersona = true
                        } label: {
                            Label("Accept Proposed Persona", systemImage: "person.crop.circle.badge.plus")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    NavigationLink(destination: PersonaDebugView(personaManager: personaManager)) {
                        Label("Debug", systemImage: "ladybug")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingCreate) {
                PersonaHandleWizardView()
                    .environmentObject(personaManager)
            }
            .sheet(item: $editTarget, onDismiss: { editTarget = nil }) { persona in
                NavigationStack {
                    PersonaEditView(personaManager: personaManager, persona: persona) { updated in
                        personaManager.updatePersona(updated)
                    }
                }
            }
            .sheet(isPresented: $showCreatePersonaForClient) {
                NavigationStack {
                    CreateProposalForClientView()
                        .environmentObject(personaManager)
                }
            }
            .sheet(isPresented: $showAcceptProposedPersona) {
                NavigationStack {
                    ProposedPersonaEntryView()
                        .environmentObject(personaManager)
                }
            }
        }
    }

    private func isActive(_ persona: Persona) -> Bool {
        return personaManager.activePersona()?.id == persona.id
    }

    private func displayName(for persona: Persona) -> String {
        if !persona.name.isEmpty { return persona.name }
        return persona.id
    }
}

#Preview {
    let manager = PersonaManager()
    return PersonaListView(personaManager: manager)
}

// MARK: - PersonaManager minimal API expectations
// The project should provide these methods. If not, implement stubs to match your app's data flow.
// extension PersonaManager {
//     func updatePersona(_ persona: Persona) { /* update in-memory list and persist */ }
// }
