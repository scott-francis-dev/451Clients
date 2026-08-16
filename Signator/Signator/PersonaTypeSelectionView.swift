import SwiftUI

struct PersonaTypeSelectionView: View {
    @EnvironmentObject var personaManager: PersonaManager
    @State private var navigateToIdentity = false
    @State private var selectedIsPublic: Bool = true
    @State private var navigateToProposal = false

    var initialName: String = ""
    var initialPublishingHouse: String = ""
    /// Domain named in the handle wizard. Carried as a request only — proof happens
    /// after creation, in DomainClaimView.
    var initialRequestedDomain: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("You can create multiple personas.")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Some for publishing your creations to the world and other personas for signing contracts and executing private work.")
                    .foregroundColor(.secondary)

                VStack(spacing: 12) {
                    personaTile(
                        title: "Create a Public Persona",
                        subtitle: "For publishing your creations with digital signatures",
                        systemImage: "megaphone.fill",
                        color: .blue
                    ) {
                        selectedIsPublic = true
                        navigateToIdentity = true
                    }

                    personaTile(
                        title: "Create a Private Persona",
                        subtitle: "For signing one or more documents (contracts)",
                        systemImage: "lock.doc.fill",
                        color: .purple
                    ) {
                        selectedIsPublic = false
                        navigateToIdentity = true
                    }

                    Button {
                        navigateToProposal = true
                    } label: {
                        Text("Create Persona for Client")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding()
            .navigationTitle("New Persona")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        // Dismiss the sheet by toggling the presentation state.
                        // PersonaManager.dismissCreationFlow is already wired
                        // in PersonasTabView; reuse it here.
                        personaManager.dismissCreationFlow = true
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToIdentity) {
                PersonaCreationView(
                    personaManager: personaManager,
                    initialIsPublicPersona: selectedIsPublic,
                    initialName: initialName,
                    initialPublishingHouse: initialPublishingHouse,
                    initialRequestedDomain: initialRequestedDomain
                )
                .environmentObject(personaManager)
            }
            .navigationDestination(isPresented: $navigateToProposal) {
                ProposedPersonaEntryView()
                    .environmentObject(personaManager)
            }
        }
    }

    private func personaTile(title: String, subtitle: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.platformGray6)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        PersonaTypeSelectionView()
            .environmentObject(PersonaManager())
    }
}


