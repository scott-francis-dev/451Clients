import SwiftUI
import CryptoKit

struct ProposedPersonaReviewView: View {
    let tokenString: String

    @State private var parsedToken: ProposedPersonaToken? = nil
    @State private var proposed: ProposedPersona? = nil
    @State private var shortCode: String = ""
    @State private var isValidating = false
    @State private var validationError: String? = nil
    @State private var canAccept = false

    @State private var isSubmitting = false
    @State private var showingPersonaCreation = false
    @State private var submitMessage: String? = nil

    @EnvironmentObject private var personaManager: PersonaManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let proposed { details(for: proposed) }

                    codeEntry

                    if let err = validationError { errorView(err) }

                    acceptDisabledHint

                    if let msg = submitMessage {
                        Text(msg).font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Review Persona")
            .sheet(isPresented: $showingPersonaCreation) {
                CreatePersonaView(personaManager: personaManager)
            }
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .task { await parseAndLoad() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Proposed Persona", systemImage: "person.crop.circle.badge.plus")
                .font(.headline)
            Text("This persona was proposed by your firm. Review the details and enter the short code from your email/text to continue.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func details(for p: ProposedPersona) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                LabeledContent("Name", value: p.name)
                if let v = p.displayName { LabeledContent("Display Name", value: v) }
                if let v = p.displayPublisher { LabeledContent("Publisher", value: v) }
                if let v = p.handle { LabeledContent("Handle", value: v) }
                if let v = p.email { LabeledContent("Email", value: v) }
                if let v = p.affiliations { LabeledContent("Affiliations", value: v) }
                if let v = p.address { LabeledContent("Address", value: v) }
                if let v = p.proposer { LabeledContent("Proposed By", value: v) }
                if let v = p.issuedAt { LabeledContent("Issued", value: v) }
            }
        }
        .padding()
        .background(Color.platformGroupedBackground)
        .cornerRadius(12)
    }

    private var codeEntry: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Short Code")
                .font(.headline)
            HStack {
                TextField("Enter code (e.g., 3D1aZ)", text: $shortCode)
                    .textFieldStyle(.roundedBorder)
                    .platformAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                Button {
                    Task { await validateCode() }
                } label: {
                    if isValidating { ProgressView() } else { Text("Verify") }
                }
                .disabled(shortCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)
            }
            Text("This code was provided in your email or text message.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.platformSecondaryGroupedBackground)
        .cornerRadius(12)
    }

    @ViewBuilder private func errorView(_ err: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text(err).font(.footnote).foregroundColor(.orange)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    private var acceptDisabledHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task {
                    guard canAccept, let token = parsedToken else { return }
                    await MainActor.run { isSubmitting = true; submitMessage = nil }
                    defer { Task { await MainActor.run { isSubmitting = false } } }

                    // Accepting signs the proposal as you, so it needs a persona whose key this
                    // device actually holds. This used to fabricate one when there was none: an
                    // ephemeral key, a made-up "did:example:" identifier, a signature sent to the
                    // server under that identifier, and a Persona stored locally whose private key
                    // was then discarded — permanently unable to sign again. Persona creation is a
                    // real flow with a server round trip and a saved key; this screen sends you
                    // there rather than approximating it.
                    guard let acceptingPersona = personaManager.activePersona() else {
                        await MainActor.run {
                            submitMessage = "Accepting signs this proposal as you, so it needs a persona whose key is on this device. Create one first — then accept, and the acceptance will carry that persona's signature."
                            showingPersonaCreation = true
                        }
                        return
                    }

                    do {
                        let acceptingDID = acceptingPersona.id
                        let privateKey = try PrivateKeyStore.loadPrivateKey(for: acceptingDID)
                        let publicKeyB64 = acceptingPersona.publicKeyBase64

                        let timestamp = ISO8601DateFormatter().string(from: Date())
                        let canonical = canonicalAcceptanceMessage(token: token, acceptingDID: acceptingDID, timestamp: timestamp)
                        let signature = try privateKey.signature(for: Data(canonical.utf8))
                        let signatureB64 = Data(signature.derRepresentation).base64EncodedString()

                        try await ProposalVerificationService.shared.submitAcceptance(
                            proposalID: token.payload.proposalID,
                            acceptanceSignature: signatureB64,
                            publicKeyBase64: publicKeyB64,
                            tokenString: tokenString,
                            tokenID: token.payload.tokenID
                        )

                        await MainActor.run { submitMessage = "✅ Persona accepted and recorded" }
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        await MainActor.run { dismiss() }
                    } catch {
                        await MainActor.run { submitMessage = "❌ " + error.localizedDescription }
                    }
                }
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Accept & Sign")
                    }
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(canAccept ? Color.blue : Color.gray)
            .cornerRadius(12)
            .disabled(!canAccept)

            Text("You can accept after verifying the short code.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func parseAndLoad() async {
        do {
            let token = try ProposalVerificationService.shared.parseToken(tokenString)
            try ProposalVerificationService.shared.basicValidate(token)
            self.parsedToken = token
            let proposal = try await ProposalVerificationService.shared.fetchProposedPersona(token: token, tokenString: tokenString)
            await MainActor.run { self.proposed = proposal }
        } catch {
            await MainActor.run { self.validationError = error.localizedDescription }
        }
    }

    private func validateCode() async {
        guard let token = parsedToken else { return }
        await MainActor.run { isValidating = true; validationError = nil }
        defer { Task { await MainActor.run { isValidating = false } } }
        do {
            let ok = try await ProposalVerificationService.shared.validateShortCode(
                proposalID: token.payload.proposalID,
                code: shortCode,
                tokenString: tokenString,
                tokenID: token.payload.tokenID
            )
            await MainActor.run {
                if ok { canAccept = true } else { validationError = "Invalid code" }
            }
        } catch {
            await MainActor.run { validationError = error.localizedDescription }
        }
    }

    private func canonicalAcceptanceMessage(token: ProposedPersonaToken, acceptingDID: String, timestamp: String) -> String {
        let p = token.payload
        let hashComponent = p.proposalHash ?? p.tokenID ?? p.proposalID
        return [acceptingDID, p.proposalID, hashComponent, timestamp].joined(separator: "|")
    }
}

#Preview {
    ProposedPersonaReviewView(tokenString: "header.payload.signature")
        .environmentObject(PersonaManager())
}
