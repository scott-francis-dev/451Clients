// DomainDelegationView.swift
// Signator
//
// Grants another persona the right to publish under a domain this persona owns.
//
// This is the mechanism behind departmental delegation. A university's central IT
// proves `psu.edu`; a department proves its own subdomain `chem.psu.edu` through the
// ordinary claim flow (DomainClaimView — subdomains are just domains to the server);
// the department then grants each of its members publishing rights here.
//
// Delegation is deliberately ONE level deep: the server accepts a delegation as
// authorization to publish, but not as authorization to re-delegate. A grantee cannot
// pass the domain on. Departments therefore own their own subdomain rather than
// receiving a grant from the top.
//
// What the grant asserts is carried in `label`, which is inside the signed message —
// so "enrolled-grad-2026" is as tamper-evident as the grant itself. It says the owner
// vouches that this persona belongs to the domain, not that it endorses what they publish.

import SwiftUI
import CryptoKit

// MARK: - Wire Types

/// Mirrors the server's `DomainDelegateRequest`.
private struct DomainDelegateRequest: Encodable {
    let ownerDID: String
    let domain: String
    let granteeDID: String
    let label: String?
    let issuedAt: String
    let expiresAt: String?
    let ownerSignature: String
}

private struct DomainDelegateResponse: Decodable {
    let status: String
    let domain: String
    let granteeDID: String
    let blockRef: String
}

private struct ServerError: Decodable {
    let reason: String
}

// MARK: - View

struct DomainDelegationView: View {
    /// The persona issuing the grant. Must already have proven the domain.
    let owner: Persona
    /// Needed by PersonaResolver to look a grantee up by handle.
    @ObservedObject var personaManager: PersonaManager

    @Environment(\.dismiss) private var dismiss

    @State private var provenDomains: [String] = []
    @State private var loadingDomains = true
    @State private var selectedDomain: String = ""

    @State private var granteeInput: String = ""
    @State private var resolvedGrantee: PersonaResolvedProfile?
    @State private var resolving = false

    @State private var label: String = ""
    @State private var setsExpiry: Bool = true
    @State private var expiryDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 180)

    @State private var issuing = false
    @State private var issued: DomainDelegateResponse?
    @State private var errorMessage: String?

    /// A short controlled vocabulary. Free text is allowed, but grants only mean
    /// something to a reader if issuers broadly agree on the words.
    private let suggestedLabels = ["enrolled", "faculty", "staff", "affiliate"]

    private var granteeDID: String? {
        if let resolvedGrantee { return resolvedGrantee.did }
        let trimmed = granteeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("did:") ? trimmed : nil
    }

    private var canIssue: Bool {
        !selectedDomain.isEmpty && granteeDID != nil && granteeDID != owner.id && !issuing
    }

    var body: some View {
        Form {
            if let issued {
                issuedSection(issued)
            } else {
                domainSection
                granteeSection
                labelSection
                expirySection
                issueSection
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Delegate Domain")
        .inlineNavigationTitle()
        .task { await loadProvenDomains() }
    }

    // MARK: - Sections

    private var domainSection: some View {
        Section {
            if loadingDomains {
                HStack { ProgressView(); Text("Checking proven domains…").foregroundColor(.secondary) }
            } else if provenDomains.isEmpty {
                Label("This persona has not proven any domain yet.", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundColor(.orange)
                Text("Prove one first under Verify a Domain — including a subdomain like chem.example.edu, which is what a department would own.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Picker("Domain", selection: $selectedDomain) {
                    ForEach(provenDomains, id: \.self) { Text($0).tag($0) }
                }
            }
        } header: {
            Text("Grant Under")
        } footer: {
            Text("Only domains this persona has proven can be delegated.")
                .font(.footnote)
        }
    }

    private var granteeSection: some View {
        Section {
            TextField("DID or handle", text: $granteeInput)
                .autocorrectionDisabled()
                .platformAutocapitalization(.never)
                .onChange(of: granteeInput) { _, _ in resolvedGrantee = nil }

            if resolving {
                HStack { ProgressView(); Text("Resolving…").foregroundColor(.secondary) }
            } else if let resolvedGrantee {
                VStack(alignment: .leading, spacing: 2) {
                    Label(resolvedGrantee.displayName, systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(resolvedGrantee.did)
                        .font(.caption2).foregroundColor(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
            } else if !granteeInput.isEmpty && granteeDID == nil {
                Button("Look Up") { Task { await resolveGrantee() } }
            }

            if granteeDID == owner.id {
                Label("A persona cannot delegate to itself.", systemImage: "xmark.circle")
                    .font(.footnote).foregroundColor(.red)
            }
        } header: {
            Text("Grant To")
        } footer: {
            Text("The grantee must already exist. A granted persona may publish under the domain, but cannot pass the grant on.")
                .font(.footnote)
        }
    }

    private var labelSection: some View {
        Section {
            TextField("e.g. enrolled-grad-2026", text: $label)
                .autocorrectionDisabled()
                .platformAutocapitalization(.never)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestedLabels, id: \.self) { suggestion in
                        Button(suggestion) { label = suggestion }
                            .font(.caption)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.indigo.opacity(0.12))
                            .foregroundColor(.indigo)
                            .clipShape(Capsule())
                            .buttonStyle(.plain)
                    }
                }
            }
        } header: {
            Text("What This Grant Says")
        } footer: {
            Text("Signed along with the grant, so it cannot be altered afterwards. Leave blank for an unrestricted grant.")
                .font(.footnote)
        }
    }

    private var expirySection: some View {
        Section {
            Toggle("Expires", isOn: $setsExpiry)
            if setsExpiry {
                DatePicker("Expiry", selection: $expiryDate, in: Date()..., displayedComponents: .date)
            }
        } header: {
            Text("Term")
        } footer: {
            Text(setsExpiry
                 ? "The grant lapses on its own. Issuing per term avoids ever having to revoke a departure."
                 : "A grant with no expiry stays valid until the block is superseded.")
                .font(.footnote)
        }
    }

    private var issueSection: some View {
        Section {
            Button {
                Task { await issueDelegation() }
            } label: {
                HStack {
                    if issuing { ProgressView() }
                    Text(issuing ? "Signing and issuing…" : "Issue Grant")
                        .fontWeight(.semibold)
                }
            }
            .disabled(!canIssue)
        }
    }

    private func issuedSection(_ result: DomainDelegateResponse) -> some View {
        Section {
            Label("Grant issued", systemImage: "checkmark.seal.fill")
                .font(.headline).foregroundColor(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(result.granteeDID) may now publish under \(result.domain).")
                    .font(.caption)
                Text("Block \(result.blockRef)")
                    .font(.caption2).foregroundColor(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Button("Issue Another") {
                issued = nil
                granteeInput = ""
                resolvedGrantee = nil
            }
            Button("Done") { dismiss() }
        }
    }

    // MARK: - Data

    /// Proven domains come from two on-chain places, matching what the server accepts
    /// as ownership: the creation block's `validatedDomains`, and any later
    /// `domainOwnershipAttestation` blocks. Both are filed under this persona's DID.
    private func loadProvenDomains() async {
        defer { Task { @MainActor in loadingDomains = false } }

        guard let encoded = owner.id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: ServerConfig.baseURL + "/api/blocks?signator=" + encoded) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let blocks = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }

            var found: [String] = []
            for block in blocks {
                guard let payload = block["data"] as? [String: Any] else { continue }
                let type = payload["type"] as? String
                let body = payload["payload"] as? [String: Any]

                if type == "persona", let domains = body?["validatedDomains"] as? [String] {
                    found.append(contentsOf: domains)
                }
                if type == "domainOwnershipAttestation",
                   let domain = body?["domain"] as? String,
                   (body?["personaDID"] as? String) == owner.id {
                    found.append(domain)
                }
            }

            var seen = Set<String>()
            let unique = found.filter { seen.insert($0).inserted }
            await MainActor.run {
                provenDomains = unique
                if selectedDomain.isEmpty { selectedDomain = unique.first ?? "" }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Could not load this persona's proven domains."
            }
        }
    }

    private func resolveGrantee() async {
        let input = granteeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        await MainActor.run { resolving = true; errorMessage = nil }
        defer { Task { @MainActor in resolving = false } }

        let resolver = PersonaResolver(baseURLString: ServerConfig.baseURL, personaManager: personaManager)
        do {
            let profile = try await resolver.resolveString(input)
            await MainActor.run { resolvedGrantee = profile }
        } catch {
            await MainActor.run { errorMessage = "No persona found for \"\(input)\"." }
        }
    }

    private func issueDelegation() async {
        guard let granteeDID else { return }
        await MainActor.run { issuing = true; errorMessage = nil }
        defer { Task { @MainActor in issuing = false } }

        let iso = ISO8601DateFormatter()
        let issuedAt = iso.string(from: Date())
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveLabel: String? = trimmedLabel.isEmpty ? nil : trimmedLabel
        let expiresAt: String? = setsExpiry ? iso.string(from: expiryDate) : nil

        // Must match the server's DomainDelegationData.canonicalInput exactly.
        // Omitted values sign as literals: no label is "ANY", no expiry is "NEVER".
        // The expiry is inside the signature so a grant's term cannot be altered in flight.
        let message = "451-DOMAIN-DELEGATION-V2:\(selectedDomain):\(granteeDID):\(effectiveLabel ?? "ANY"):\(issuedAt):\(expiresAt ?? "NEVER")"

        do {
            let signature = try SecureEnclaveKeyStore.sign(Data(message.utf8), for: owner.id)
            let body = DomainDelegateRequest(
                ownerDID: owner.id,
                domain: selectedDomain,
                granteeDID: granteeDID,
                label: effectiveLabel,
                issuedAt: issuedAt,
                expiresAt: expiresAt,
                ownerSignature: signature.derRepresentation.base64EncodedString()
            )

            guard let url = URL(string: ServerConfig.baseURL + "/api/persona/domain/delegate") else {
                throw URLError(.badURL)
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard (200...299).contains(http.statusCode) else {
                let reason = (try? JSONDecoder().decode(ServerError.self, from: data))?.reason
                await MainActor.run { errorMessage = reason ?? "Grant failed (\(http.statusCode))." }
                return
            }

            let result = try JSONDecoder().decode(DomainDelegateResponse.self, from: data)
            await MainActor.run { issued = result }
        } catch let urlError as URLError {
            _ = urlError
            await MainActor.run { errorMessage = "Could not reach the server." }
        } catch {
            await MainActor.run {
                errorMessage = "Could not sign the grant with this persona's key. \(error.localizedDescription)"
            }
        }
    }
}
