import SwiftUI

struct IdentityMethodSelectionView: View {
    let isPublicPersona: Bool
    let personaPurpose: PersonaPurpose
    @EnvironmentObject var personaManager: PersonaManager
    @State private var navigateToCreate = false
    @State private var selectedUseCustomDomain: Bool = false
    @State private var selectedOneTimeSigning: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Show purpose context
            HStack(spacing: 12) {
                Image(systemName: personaPurpose.systemImage)
                    .font(.system(size: 20))
                    .foregroundColor(personaPurpose.color)
                    .frame(width: 36, height: 36)
                    .background(personaPurpose.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Creating persona for:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(personaPurpose.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color.platformGray6)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            Text("How will your persona identify itself?")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.top, 8)
            Text("Choose one of the options below. You can go back at any time.")
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                methodTile(
                    title: "I have my own domain",
                    subtitle: "Use a domain you own (DNS verification)",
                    systemImage: "globe",
                    color: .blue
                ) {
                    selectedUseCustomDomain = true
                    navigateToCreate = true
                }

                methodTile(
                    title: "I don't have a domain; start a Publishing House",
                    subtitle: "We'll help you use a publishing house handle",
                    systemImage: "building.2.crop.circle",
                    color: .green
                ) {
                    selectedUseCustomDomain = false
                    navigateToCreate = true
                }

                if !isPublicPersona {
                    methodTile(
                        title: "One time signing ceremony",
                        subtitle: "Document execution (no domain)",
                        systemImage: "doc.badge.plus",
                        color: .orange
                    ) {
                        selectedUseCustomDomain = false
                        selectedOneTimeSigning = true
                        navigateToCreate = true
                    }
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .navigationDestination(isPresented: $navigateToCreate) {
            PersonaCreationView(
                personaManager: personaManager,
                onCreate: { created in
                    // created is of type PersonaProfileModel (aka PersonaProfile)
                    // Continue navigation or handle post-create actions here as needed
                },
                initialIsPublicPersona: isPublicPersona,
                initialUseCustomDomain: selectedUseCustomDomain
            )
        }
        .padding()
        .navigationTitle("Identity Method")
        .inlineNavigationTitle()
    }

    private func methodTile(title: String, subtitle: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
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
        IdentityMethodSelectionView(
            isPublicPersona: true,
            personaPurpose: .publishing
        )
        .environmentObject(PersonaManager())
    }
}
