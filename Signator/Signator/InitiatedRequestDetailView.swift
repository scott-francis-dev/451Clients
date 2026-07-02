import SwiftUI

struct InitiatedRequestDetailView: View {
    let title: String
    let contractParties: [PersonaResolvedProfile]
    let authors: [PersonaResolvedProfile]
    let accessCode: String?

    @State private var reminding = false
    @State private var remindError: String? = nil
    @State private var remindSuccess: Bool = false
    @State private var showCopyConfirmation = false

    var body: some View {
        Form {
            Section("Document") {
                Text(title)
            }
            
            // Access Code Section
            if let code = accessCode {
                Section("Access Code") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Share this code with signers to grant access:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(code)
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .textSelection(.enabled)
                            
                            Spacer()
                            
                            Button {
                                copyToClipboard(code)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: showCopyConfirmation ? "checkmark" : "doc.on.doc")
                                    Text(showCopyConfirmation ? "Copied" : "Copy")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            }
                        }
                        
                        Text("Format: XXX-XXXX (3 digits, dash, 4 digits)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(header: Text("Contract Parties")) {
                if contractParties.isEmpty {
                    Text("No contract parties").foregroundColor(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(contractParties, id: \.id) { p in
                                MentionChip(profile: p)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }

            Section(header: Text("Authors")) {
                if authors.isEmpty {
                    Text("No authors").foregroundColor(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(authors, id: \.id) { p in
                                MentionChip(profile: p)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }

            Section {
                Button(reminding ? "Sending Reminder…" : "Remind All Pending") {
                    Task { await remindAllPending() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(reminding)
            }

            if let err = remindError {
                Section { Text(err).foregroundColor(.red) }
            }
            if remindSuccess {
                Section { Text("Reminders sent").foregroundColor(.green) }
            }
        }
        .navigationTitle("Request Details")
        .inlineNavigationTitle()
#if os(iOS) || os(watchOS)
        .toolbar(.visible, for: .navigationBar)
#endif
    }
    
    private func copyToClipboard(_ text: String) {
        PlatformPasteboard.copy(text)
        showCopyConfirmation = true
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                showCopyConfirmation = false
            }
        }
    }

    // Placeholder async remind call; integrate with server when available
    private func remindAllPending() async {
        await MainActor.run { reminding = true; remindError = nil; remindSuccess = false }
        defer { Task { await MainActor.run { reminding = false } } }
        do {
            try await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run { remindSuccess = true }
        } catch {
            await MainActor.run { remindError = error.localizedDescription }
        }
    }
}

#Preview {
    NavigationStack {
        InitiatedRequestDetailView(
            title: "Example Contract.pdf",
            contractParties: [
                PersonaResolvedProfile(did: "did:example:alice", guid: nil, shortId: "ABC-1234", handle: "alice", prettyDID: "Alice", name: "Alice")
            ],
            authors: [
                PersonaResolvedProfile(did: "did:example:bob", guid: nil, shortId: "DEF-5678", handle: "bob", prettyDID: "Bob", name: "Bob")
            ],
            accessCode: "451-7892"
        )
    }
}
