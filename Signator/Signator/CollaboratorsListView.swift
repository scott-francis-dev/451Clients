import SwiftUI

enum CollaboratorsListMode {
    case manage
    case pick((PersonaResolvedProfile) -> Void)
}

struct CollaboratorsListView: View {
    @ObservedObject var store: CollaboratorsStore = .shared
    let personaManager: PersonaManager
    let resolver: PersonaResolver
    let mode: CollaboratorsListMode
    let searchText: String

    @State private var recentlySelected: Set<String> = [] // lowercased DIDs briefly marked as selected
    
    // Default initializer for backward compatibility (when searchText is not provided)
    init(store: CollaboratorsStore = .shared,
         personaManager: PersonaManager,
         resolver: PersonaResolver,
         mode: CollaboratorsListMode,
         searchText: String = "") {
        self.store = store
        self.personaManager = personaManager
        self.resolver = resolver
        self.mode = mode
        self.searchText = searchText
    }
    
    // Filtered collaborators based on search text
    private var filteredCollaborators: [PersonaResolvedProfile] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return store.collaborators }
        return store.collaborators.filter { profile in
            profile.did.lowercased().contains(trimmed) ||
            profile.displayName.lowercased().contains(trimmed) ||
            (profile.name?.lowercased().contains(trimmed) ?? false) ||
            (profile.prettyDID?.lowercased().contains(trimmed) ?? false) ||
            (profile.handle?.lowercased().contains(trimmed) ?? false) ||
            (profile.shortId?.lowercased().contains(trimmed) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.collaborators.isEmpty {
                Text("Add people you work with and then quickly select them when initiating signing.  You may search for them by persona id (persona@@publishing house, or you may be given a 7 digit code to quickly find an anonymous party")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else if filteredCollaborators.isEmpty {
                // Has collaborators, but search filtered them all out
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No contacts match '\(searchText)'")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                List {
                    if case .manage = mode {
                        ForEach(filteredCollaborators, id: \.id) { p in
                            row(for: p)
                        }
                        .onDelete(perform: handleDelete)
                    } else {
                        ForEach(filteredCollaborators, id: \.id) { p in
                            row(for: p)
                        }
                    }
                }
#if canImport(UIKit)
                .listStyle(.insetGrouped)
#else
                .listStyle(.inset)
#endif
                .frame(minHeight: 120)
            }
        }
    }

    @ViewBuilder
    private func row(for p: PersonaResolvedProfile) -> some View {
        switch mode {
        case .manage:
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "person.circle")
                VStack(alignment: .leading, spacing: 2) {
                    NameAndPublisherView(
                        name: p.displayName,
                        publisher: p.publisher,
                        nameFont: .body,
                        publisherFont: .caption
                    )
                    Text(p.did).font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                Button(role: .destructive) { store.remove(did: p.did) } label: {
                    Image(systemName: "trash")
                }
            }
        case .pick(let onPick):
            Button {
                onPick(p)
                let key = p.did.lowercased()
                recentlySelected.insert(key)
                // Clear the selection highlight after 1.2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    recentlySelected.remove(key)
                }
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "person.circle")
                    VStack(alignment: .leading, spacing: 2) {
                        NameAndPublisherView(
                            name: p.displayName,
                            publisher: p.publisher,
                            nameFont: .body,
                            publisherFont: .caption
                        )
                        Text(p.did).font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    if recentlySelected.contains(p.did.lowercased()) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .background(
                recentlySelected.contains(p.did.lowercased()) ? Color.green.opacity(0.10) : Color.clear
            )
            .animation(.easeInOut(duration: 0.2), value: recentlySelected)
        }
    }

    private func handleDelete(_ offsets: IndexSet) {
        // Map filtered indices to actual DIDs and remove them
        let didsToRemove = offsets.map { filteredCollaborators[$0].did }
        for did in didsToRemove {
            store.remove(did: did)
        }
    }
}

private struct AutocapitalizationCompatibility: ViewModifier {
    func body(content: Content) -> some View {
#if canImport(UIKit)
        if #available(iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            // Use the modern modifier on supported UIKit platforms
            return content.textInputAutocapitalization(.never)
        } else {
            // Fallback for older iOS/tvOS/watchOS versions using UIKit
            return content.autocapitalization(UITextAutocapitalizationType.none)
        }
#else
        // On macOS (AppKit) these modifiers are unavailable; just return content
        return content
#endif
    }
}

private extension View {
    func autocapitalizationCompatibility() -> some View {
        self.modifier(AutocapitalizationCompatibility())
    }
}
