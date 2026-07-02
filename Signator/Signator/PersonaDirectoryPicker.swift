import SwiftUI

struct PersonaDirectoryPicker: View {
    @ObservedObject var personaManager: PersonaManager
    let resolver: PersonaResolver
    let title: String
    let onPick: (PersonaResolvedProfile) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var results: [PersonaResolvedProfile] = []
    @State private var isSearching = false
    @State private var recent: [PersonaResolvedProfile] = []
    
    private enum VisibilityFilter: String, CaseIterable { case publicOnly = "Public", all = "All" }
    @State private var visibility: VisibilityFilter = .publicOnly

    @State private var searchError: String? = nil
    @State private var searchTask: Task<Void, Never>? = nil

    private let recentsKey = "recent_persona_picks_v1"
    
    private func looksLikeShortCode(_ s: String) -> Bool {
        let dashless = s.replacingOccurrences(of: "-", with: "").uppercased()
        guard dashless.count == 7 else { return false }
        let hexSet = CharacterSet(charactersIn: "0123456789ABCDEF")
        return dashless.unicodeScalars.allSatisfy { hexSet.contains($0) }
    }

    private func isLikelyResolvable(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("did:") { return true }
        if looksLikeShortCode(trimmed) { return true }
        if let at = trimmed.firstIndex(of: "@") {
            let left = trimmed[..<at]
            let right = trimmed[trimmed.index(after: at)...]
            return left.count >= 3 && right.count >= 3
        }
        return false
    }

    var body: some View {
        NavigationStack {
            List {
                if !personaManager.personas.isEmpty {
                    Section("My Personas") {
                        ForEach(personaManager.personas, id: \.id) { p in
                            Button {
                                let profile = PersonaResolvedProfile(
                                    did: p.id,
                                    guid: nil,
                                    shortId: p.shortIDPhoneStyle,
                                    handle: p.handle,
                                    prettyDID: p.name,
                                    name: p.name
                                )
                                pick(profile)
                            } label: {
                                // Use the Signator Calling Card component
                                PersonaHandleDetailCard(
                                    persona: p,
                                    size: .compact,
                                    showDID: false,
                                    showCopyButton: false
                                )
                            }
                        }
                    }
                }

                if !recent.isEmpty {
                    Section {
                        ForEach(recent, id: \.id) { r in
                            HStack(spacing: 12) {
                                Button { pick(r) } label: {
                                    // Use the Signator Calling Card component
                                    PersonaHandleCard(
                                        handle: r.handle ?? r.did,
                                        isPublic: true,
                                        size: .compact,
                                        showCopyButton: false
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                                
                                Button(role: .destructive) {
                                    removeRecent(r)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .onDelete(perform: deleteRecent)
                    } header: {
                        HStack {
                            Text("Recent")
                            Spacer()
                            Button("Clear All") {
                                clearAllRecent()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }
                }

                Section("Search") {
                    HStack {
                        TextField("Search by @handle, DID, or short code (ABC-1234)", text: $query)
                            .platformAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        if isSearching { ProgressView().scaleEffect(0.8) }
                    }
                    Picker("Visibility", selection: $visibility) {
                        Text("Public").tag(VisibilityFilter.publicOnly)
                        Text("All").tag(VisibilityFilter.all)
                    }
                    .pickerStyle(.segmented)
                    
                    if isSearching {
                        Text("Searching…").foregroundColor(.secondary)
                    }

                    if !results.isEmpty {
                        ForEach(results, id: \.id) { r in
                            Button { pick(r) } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    if !r.displayName.isEmpty {
                                        Text(r.displayName)
                                            .font(.headline)
                                    }
                                    
                                    // Use the Signator Calling Card component
                                    PersonaHandleCard(
                                        handle: r.handle ?? r.did,
                                        isPublic: true,
                                        size: .compact,
                                        showCopyButton: false
                                    )
                                }
                            }
                        }
                    } else if let err = searchError, !isSearching, !query.isEmpty {
                        Text(err).foregroundColor(.red)
                    } else if !query.isEmpty && !isSearching {
                        Text("No results").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear(perform: loadRecents)
            .onChange(of: query) { _ in
                searchTask?.cancel()
                let current = query
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if Task.isCancelled { return }
                    await performSearch()
                }
            }
            .onChange(of: visibility) { _ in
                searchTask?.cancel()
                searchTask = Task {
                    await performSearch()
                }
            }
        }
    }

    private func performSearch() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Enforce a small minimum to reduce server load
        guard !q.isEmpty, q.count >= 2 else {
            await MainActor.run { results = []; searchError = nil }
            return
        }
        await MainActor.run { isSearching = true; searchError = nil; results = [] }
        defer { Task { await MainActor.run { isSearching = false } } }
        do {
            // Try exact resolve first (with short-code support) only if likely resolvable
            if isLikelyResolvable(q), let resolved = try? await resolver.resolveStringWithShortCodeSupport(q) {
                await MainActor.run { results = [resolved] }
            }
            // Then broader search
            let hits = try await resolver.searchWithParams(query: q, limit: 20, offset: nil, publicOnly: (visibility == .publicOnly), waitForIndexing: nil)
            await MainActor.run {
                let existing = Set(results.map { $0.did.lowercased() })
                results.append(contentsOf: hits.filter { !existing.contains($0.did.lowercased()) })
            }
        } catch {
            await MainActor.run {
                results = []
                searchError = error.localizedDescription
            }
        }
    }

    private func pick(_ profile: PersonaResolvedProfile) {
        saveRecent(profile)
        onPick(profile)
        dismiss()
    }

    private func loadRecents() {
        if let data = UserDefaults.standard.data(forKey: recentsKey),
           let decoded = try? JSONDecoder().decode([PersonaResolvedProfile].self, from: data) {
            self.recent = decoded
        }
    }

    private func saveRecent(_ p: PersonaResolvedProfile) {
        var current = recent
        current.removeAll { $0.did.caseInsensitiveCompare(p.did) == .orderedSame }
        current.insert(p, at: 0)
        if current.count > 12 { current = Array(current.prefix(12)) }
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: recentsKey)
        }
        recent = current
    }
    
    private func removeRecent(_ profile: PersonaResolvedProfile) {
        recent.removeAll { $0.did.caseInsensitiveCompare(profile.did) == .orderedSame }
        if let data = try? JSONEncoder().encode(recent) {
            UserDefaults.standard.set(data, forKey: recentsKey)
        }
    }
    
    private func deleteRecent(at offsets: IndexSet) {
        recent.remove(atOffsets: offsets)
        if let data = try? JSONEncoder().encode(recent) {
            UserDefaults.standard.set(data, forKey: recentsKey)
        }
    }
    
    private func clearAllRecent() {
        recent.removeAll()
        UserDefaults.standard.removeObject(forKey: recentsKey)
    }
}

