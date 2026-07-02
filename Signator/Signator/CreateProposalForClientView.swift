// CreateProposalForClientView.swift
// Lets an attorney / firm fill in a client's details, generate a
// proposed-persona token, and share it with the client.

import SwiftUI
import Foundation

struct CreateProposalForClientView: View {
    @EnvironmentObject private var personaManager: PersonaManager
    @Environment(\.dismiss) private var dismiss

    // ── Form fields ───────────────────────────────────────────────
    @State private var clientName        = ""
    @State private var clientDisplayName = ""
    @State private var clientDisplayPublisher = ""
    @State private var clientEmail       = ""
    @State private var clientHandle      = ""
    @State private var clientIsPublic    = true
    @State private var clientVerified    = false
    @State private var clientBackgroundCheckRequired = false
    @State private var clientBackgroundValidated = false
    @State private var clientRequestedDomain = ""
    @State private var clientRequestedDnsChallenge = ""
    @State private var clientValidatedDomains = ""
    @State private var clientAffiliations = ""
    @State private var clientSocialLinks = ""
    @State private var clientType = ""
    @State private var clientHash = ""
    @State private var clientMetadataJSON = ""

    // ── Address ───────────────────────────────────────────────
    @State private var clientStreet = ""
    @State private var clientCity = ""
    @State private var clientStateRegion = ""
    @State private var clientPostalCode = ""
    @State private var clientCountry = ""

    // ── Private data (encrypted, optional for private personas) ──
    @State private var privateGivenName = ""
    @State private var privateAliases = ""
    @State private var privateEmail = ""
    @State private var privateSSN = ""
    @State private var privateStreet = ""
    @State private var privateCity = ""
    @State private var privateStateRegion = ""
    @State private var privatePostalCode = ""
    @State private var privateCountry = ""

    // ── Submission state ──────────────────────────────────────────
    @State private var isSubmitting      = false
    @State private var generatedToken: String? = nil   // the JWS to share
    @State private var shortCode: String? = nil        // OOB code for the client
    @State private var proposalID: String? = nil       // xyz-abcd style ID
    @State private var submitError: String? = nil

    // ── Share-sheet trigger ───────────────────────────────────────
    @State private var showShareSheet    = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // ── Header ──────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Label("Propose a Persona for a Client",
                          systemImage: "person.crop.circle.badge.plus")
                        .font(.headline)
                    Text("Fill in the client's details below. A signed proposal token and a short verification code will be generated. Share both with your client — they will use them to review and accept the persona.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // ── Core Identity ───────────────────────────────
                VStack(alignment: .leading, spacing: 16) {
                    field(title: "Full Name *", placeholder: "e.g. Jane Smith", binding: $clientName)
                    field(title: "Display Name", placeholder: "e.g. Jane", binding: $clientDisplayName)
                    VStack(alignment: .leading, spacing: 8) {
                        field(
                            title: "Publishing House (Optional)",
                            placeholder: "e.g. sue.smith.of.orr.ohio",
                            binding: $clientDisplayPublisher
                        )

                        Text("Leave blank if unknown. We often use a hometown format like: sue.smith.of.orr.ohio. If they represent a company, use that instead (e.g. sue.smith.the.origami.company).")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("Use hometown format") {
                            if let suggestion = suggestedPublisherFromHometown() {
                                clientDisplayPublisher = suggestion
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(suggestedPublisherFromHometown() == nil)
                    }
                    field(title: "Email", placeholder: "jane@example.com", binding: $clientEmail)
                    field(title: "Handle", placeholder: "jane.smith", binding: $clientHandle)
                    Toggle("Public Persona", isOn: $clientIsPublic)
                    Toggle("Verified", isOn: $clientVerified)
                    Toggle("Background Check Required", isOn: $clientBackgroundCheckRequired)
                }
                .padding()
                .background(Color.platformGroupedBackground)
                .cornerRadius(16)

                // ── Address ────────────────────────────────────
                VStack(alignment: .leading, spacing: 16) {
                    field(title: "Street", placeholder: "123 Main St", binding: $clientStreet)
                    field(title: "City", placeholder: "City", binding: $clientCity)
                    field(title: "State / Region", placeholder: "State", binding: $clientStateRegion)
                    field(title: "Postal Code", placeholder: "00000", binding: $clientPostalCode)
                    field(title: "Country", placeholder: "Country", binding: $clientCountry)
                }
                .padding()
                .background(Color.platformGroupedBackground)
                .cornerRadius(16)

                // ── Public Details ─────────────────────────────
                VStack(alignment: .leading, spacing: 16) {
                    field(title: "Affiliations", placeholder: "e.g. Acme Corp", binding: $clientAffiliations)
                    field(title: "Social Links", placeholder: "e.g. https://example.com", binding: $clientSocialLinks)
                }
                .padding()
                .background(Color.platformGroupedBackground)
                .cornerRadius(16)

                // ── Verification & Domains ─────────────────────
                VStack(alignment: .leading, spacing: 16) {
                    field(title: "Requested Domain", placeholder: "e.g. example.com", binding: $clientRequestedDomain)
                    field(title: "Requested DNS Challenge", placeholder: "dns-challenge", binding: $clientRequestedDnsChallenge)
                    Toggle("Background Validated", isOn: $clientBackgroundValidated)
                    field(title: "Validated Domains", placeholder: "comma,separated,domains", binding: $clientValidatedDomains)
                }
                .padding()
                .background(Color.platformGroupedBackground)
                .cornerRadius(16)

                // ── Additional Fields ──────────────────────────
                VStack(alignment: .leading, spacing: 16) {
                    field(title: "Type", placeholder: "e.g. author", binding: $clientType)
                    field(title: "Hash", placeholder: "e.g. sha256:...", binding: $clientHash)
                    field(
                        title: "Metadata (JSON)",
                        placeholder: "{\"key\":\"value\"}",
                        binding: $clientMetadataJSON,
                        axis: .vertical,
                        lineLimit: 2...6
                    )
                }
                .padding()
                .background(Color.platformGroupedBackground)
                .cornerRadius(16)

                // ── Private Data (optional) ────────────────────
                if !clientIsPublic {
                    VStack(alignment: .leading, spacing: 16) {
                        field(title: "Given Name", placeholder: "Given name", binding: $privateGivenName)
                        field(title: "Aliases", placeholder: "Aliases", binding: $privateAliases)
                        field(title: "Private Email", placeholder: "private@example.com", binding: $privateEmail)
                        field(title: "Social Security Number", placeholder: "XXX-XX-XXXX", binding: $privateSSN)
                        field(title: "Private Street", placeholder: "123 Main St", binding: $privateStreet)
                        field(title: "Private City", placeholder: "City", binding: $privateCity)
                        field(title: "Private State / Region", placeholder: "State", binding: $privateStateRegion)
                        field(title: "Private Postal Code", placeholder: "00000", binding: $privatePostalCode)
                        field(title: "Private Country", placeholder: "Country", binding: $privateCountry)
                    }
                    .padding()
                    .background(Color.platformGroupedBackground)
                    .cornerRadius(16)
                }

                // ── Submit button ───────────────────────────────
                if generatedToken == nil {
                    Button {
                        Task { await createProposal() }
                    } label: {
                        HStack {
                            if isSubmitting { ProgressView().tint(.white) }
                            Text(isSubmitting ? "Creating…" : "Create Proposal")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isNameFilled ? Color.gray : Color.gray.opacity(0.4))
                        .cornerRadius(12)
                    }
                    .disabled(!isNameFilled || isSubmitting)
                }

                // ── Error banner ────────────────────────────────
                if let err = submitError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                        Text(err).font(.footnote).foregroundColor(.red)
                    }
                    .padding(10)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }

                // ── Success / share section ─────────────────────
                if let token = generatedToken {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Proposal Created", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)

                        // ── Proposal ID ───────────────────────
                        if let pid = proposalID {
                            infoRow(
                                label: "Proposal ID",
                                value: pid,
                                icon: "number.square.fill",
                                iconColor: .indigo
                            )
                        }

                        // ── Short verification code ───────────
                        if let code = shortCode {
                            infoRow(
                                label: "Short Verification Code",
                                value: code,
                                icon: "key.fill",
                                iconColor: .orange,
                                caption: "Send this code to your client separately (e.g. via SMS). They will need it to accept the proposal."
                            )
                        }

                        // Token preview (truncated)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Proposal Token")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(token)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }

                        // Action buttons
                        HStack(spacing: 12) {
                            // Copy token
                            Button {
                                PlatformPasteboard.copy(token)
                            } label: {
                                Label("Copy Token", systemImage: "doc.on.clipboard")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }

                            // Share via sheet
                            Button {
                                showShareSheet = true
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                        }

                        // Reset / create another
                        Button {
                            reset()
                        } label: {
                            Text("Create Another")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color.platformGroupedBackground)
                    .cornerRadius(16)

                    // Share-sheet
                    .sheet(isPresented: $showShareSheet) {
                        ShareLink(item: token) {
                            Label("Share Proposal Token", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                Spacer(minLength: 24)
            }
            .padding()
        }
        .navigationTitle("Propose Persona for Client")
        .inlineNavigationTitle()
    }

    // ── Helpers ───────────────────────────────────────────────────
    private var isNameFilled: Bool {
        !clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func suggestedPublisherFromHometown() -> String? {
        let name = dotSlug(clientName)
        let city = dotSlug(clientCity)
        let state = dotSlug(clientStateRegion)
        guard !name.isEmpty, !city.isEmpty, !state.isEmpty else { return nil }
        return "\(name).of.\(city).\(state)"
    }

    private func dotSlug(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics
        var words: [String] = []
        var current = ""

        for scalar in input.lowercased().unicodeScalars {
            if allowed.contains(scalar) {
                current.append(Character(scalar))
            } else if !current.isEmpty {
                words.append(current)
                current = ""
            }
        }

        if !current.isEmpty {
            words.append(current)
        }

        return words.joined(separator: ".")
    }

    @ViewBuilder
    private func field(
        title: String,
        placeholder: String,
        binding: Binding<String>,
        axis: Axis = .horizontal,
        lineLimit: ClosedRange<Int>? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let lineLimit {
                TextField(placeholder, text: binding, axis: axis)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled(true)
                    .platformAutocapitalization(.never)
                    .lineLimit(lineLimit)
            } else {
                TextField(placeholder, text: binding, axis: axis)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled(true)
                    .platformAutocapitalization(.never)
            }
        }
    }

    /// A single labelled value row with an optional copy button and caption.
    @ViewBuilder
    private func infoRow(
        label: String,
        value: String,
        icon: String,
        iconColor: Color,
        caption: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                Text(label)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 8) {
                Text(value)
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)

                // Copy-to-clipboard button
                Button {
                    PlatformPasteboard.copy(value)
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let cap = caption {
                Text(cap)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.platformSecondaryGroupedBackground)
        .cornerRadius(12)
    }

    private func reset() {
        clientName        = ""
        clientDisplayName = ""
        clientDisplayPublisher = ""
        clientEmail       = ""
        clientHandle      = ""
        clientIsPublic    = true
        clientVerified    = false
        clientBackgroundCheckRequired = false
        clientBackgroundValidated = false
        clientRequestedDomain = ""
        clientRequestedDnsChallenge = ""
        clientValidatedDomains = ""
        clientAffiliations = ""
        clientSocialLinks = ""
        clientType = ""
        clientHash = ""
        clientMetadataJSON = ""
        clientStreet = ""
        clientCity = ""
        clientStateRegion = ""
        clientPostalCode = ""
        clientCountry = ""
        privateGivenName = ""
        privateAliases = ""
        privateEmail = ""
        privateSSN = ""
        privateStreet = ""
        privateCity = ""
        privateStateRegion = ""
        privatePostalCode = ""
        privateCountry = ""
        generatedToken    = nil
        shortCode         = nil
        proposalID        = nil
        submitError       = nil
    }

    // ── Server call ───────────────────────────────────────────────
    private func createProposal() async {
        await MainActor.run { isSubmitting = true; submitError = nil }
        defer { Task { await MainActor.run { isSubmitting = false } } }

        do {
            let metadata = try parseMetadataJSON(clientMetadataJSON)
            let address = buildAddress(
                street: clientStreet,
                city: clientCity,
                stateRegion: clientStateRegion,
                postalCode: clientPostalCode,
                country: clientCountry
            )
            let privateAddress = buildAddress(
                street: privateStreet,
                city: privateCity,
                stateRegion: privateStateRegion,
                postalCode: privatePostalCode,
                country: privateCountry
            )
            let privateData = buildPrivateData(
                givenName: privateGivenName,
                aliases: privateAliases,
                privateEmail: privateEmail,
                socialSecurityNumber: privateSSN,
                address: privateAddress
            )

            let result = try await ProposalCreationService.shared.createProposal(
                name: clientName.trimmingCharacters(in: .whitespacesAndNewlines),
                displayName: nilIfEmpty(clientDisplayName),
                displayPublisher: nilIfEmpty(clientDisplayPublisher),
                email: nilIfEmpty(clientEmail),
                handle: nilIfEmpty(clientHandle),
                isPublic: clientIsPublic,
                verified: clientVerified,
                backgroundCheckRequired: clientBackgroundCheckRequired,
                backgroundValidated: clientBackgroundValidated,
                requestedDomain: nilIfEmpty(clientRequestedDomain),
                requestedDnsChallenge: nilIfEmpty(clientRequestedDnsChallenge),
                validatedDomains: parseCommaSeparated(clientValidatedDomains),
                affiliations: nilIfEmpty(clientAffiliations),
                socialLinks: nilIfEmpty(clientSocialLinks),
                address: address,
                type: nilIfEmpty(clientType),
                hash: nilIfEmpty(clientHash),
                metadata: metadata,
                privateData: privateData,
                proposerPersonaID: personaManager.activePersona()?.id
            )
            await MainActor.run {
                generatedToken = result.token
                shortCode      = result.shortCode
                proposalID     = result.proposalID
            }
        } catch {
            await MainActor.run { submitError = error.localizedDescription }
        }
    }

    private func nilIfEmpty(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private func parseMetadataJSON(_ input: String) throws -> [String: String]? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let data = Data(trimmed.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dict = object as? [String: Any] else {
            throw NSError(domain: "ProposalMetadata", code: 0, userInfo: [NSLocalizedDescriptionKey: "Metadata must be a JSON object."])
        }
        var output: [String: String] = [:]
        for (key, value) in dict {
            if let stringValue = value as? String {
                output[key] = stringValue
            } else {
                output[key] = String(describing: value)
            }
        }
        return output.isEmpty ? nil : output
    }

    private func parseCommaSeparated(_ input: String) -> [String]? {
        let values = input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return values.isEmpty ? nil : values
    }

    private func buildAddress(
        street: String,
        city: String,
        stateRegion: String,
        postalCode: String,
        country: String
    ) -> ProposalCreationService.Address? {
        let hasAny = [street, city, stateRegion, postalCode, country]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard hasAny else { return nil }
        return ProposalCreationService.Address(
            street: nilIfEmpty(street),
            city: nilIfEmpty(city),
            state: nilIfEmpty(stateRegion),
            postalCode: nilIfEmpty(postalCode),
            country: nilIfEmpty(country)
        )
    }

    private func buildPrivateData(
        givenName: String,
        aliases: String,
        privateEmail: String,
        socialSecurityNumber: String,
        address: ProposalCreationService.Address?
    ) -> ProposalCreationService.PrivateData? {
        let hasAny = [
            givenName,
            aliases,
            privateEmail,
            socialSecurityNumber
        ].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } || address != nil
        guard hasAny else { return nil }
        return ProposalCreationService.PrivateData(
            givenName: nilIfEmpty(givenName),
            aliases: nilIfEmpty(aliases),
            privateEmail: nilIfEmpty(privateEmail),
            socialSecurityNumber: nilIfEmpty(socialSecurityNumber),
            privateAddress: address
        )
    }
}

// MARK: - ProposalCreationService

/// Stub service for the server-side proposal-creation endpoint.
/// Replace the body of `createProposal` with a real network call once
/// the backend is ready.
final class ProposalCreationService {
    static let shared = ProposalCreationService()
    private init() {}

    struct Address: Codable, Hashable {
        let street: String?
        let city: String?
        let state: String?
        let postalCode: String?
        let country: String?
    }

    struct PrivateData: Codable, Hashable {
        let givenName: String?
        let aliases: String?
        let privateEmail: String?
        let socialSecurityNumber: String?
        let privateAddress: Address?
    }

    struct ProposalResult {
        let proposalID: String   // human-friendly ID  (e.g. "x7k-3mN2")
        let token:      String   // signed JWS to hand to the client
        let shortCode:  String   // OOB verification code
    }

    private struct PersonaPayload: Encodable {
        let name: String
        let displayName: String?
        let displayPublisher: String?
        let email: String?
        let handle: String?
        let isPublic: Bool
        let verified: Bool
        let backgroundCheckRequired: Bool
        let backgroundValidated: Bool
        let requestedDomain: String?
        let requestedDnsChallenge: String?
        let validatedDomains: [String]?
        let affiliations: String?
        let socialLinks: String?
        let address: Address?
        let type: String?
        let hash: String?
        let metadata: [String: String]?
        let privateData: PrivateData?
        let proposerPersonaID: String?
    }

    private struct ProposalCreateRequest: Encodable {
        let persona: PersonaPayload
    }

    private struct ProposalCreateResponse: Decodable {
        let proposalID: String?
        let token: String?
        let shortCode: String?
        let expiresAt: String?
    }

    /// POST /api/proposals
    func createProposal(
        name:              String,
        displayName:       String?,
        displayPublisher:  String?,
        email:             String?,
        handle:            String?,
        isPublic:          Bool,
        verified:          Bool,
        backgroundCheckRequired: Bool,
        backgroundValidated: Bool,
        requestedDomain:   String?,
        requestedDnsChallenge: String?,
        validatedDomains:  [String]?,
        affiliations:      String?,
        socialLinks:       String?,
        address:           Address?,
        type:              String?,
        hash:              String?,
        metadata:          [String: String]?,
        privateData:       PrivateData?,
        proposerPersonaID: String?
    ) async throws -> ProposalResult {
        let requestID = RequestIDGenerator.generate()
        guard let url = URL(string: ServerConfig.baseURL + "/api/proposals") else {
            ClientLogger.error(component: LogComponent.proposedPersona, "Invalid server URL", requestID: requestID)
            throw NSError(domain: "ProposalCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server URL"])
        }

        let persona = PersonaPayload(
            name: name,
            displayName: displayName,
            displayPublisher: displayPublisher,
            email: email,
            handle: handle,
            isPublic: isPublic,
            verified: verified,
            backgroundCheckRequired: backgroundCheckRequired,
            backgroundValidated: backgroundValidated,
            requestedDomain: requestedDomain,
            requestedDnsChallenge: requestedDnsChallenge,
            validatedDomains: validatedDomains,
            affiliations: affiliations,
            socialLinks: socialLinks,
            address: address,
            type: type,
            hash: hash,
            metadata: metadata,
            privateData: privateData,
            proposerPersonaID: proposerPersonaID
        )

        let requestBody = ProposalCreateRequest(persona: persona)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        ClientLogger.info(component: LogComponent.proposedPersona, "POST /api/proposals", requestID: requestID)
        ClientLogger.debug(component: LogComponent.proposedPersona, "Request URL: \(url.absoluteString)", requestID: requestID)
        if let body = request.httpBody, let bodyPreview = String(data: body, encoding: .utf8) {
            ClientLogger.debug(component: LogComponent.proposedPersona, "Request body bytes: \(body.count)", requestID: requestID)
            ClientLogger.debug(component: LogComponent.proposedPersona, "Request body preview: \(bodyPreview.prefix(400))", requestID: requestID)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            ClientLogger.error(component: LogComponent.proposedPersona, "Network error: \(error.localizedDescription)", requestID: requestID)
            throw NSError(domain: "ProposalCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error: \(error.localizedDescription)"])
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            ClientLogger.error(component: LogComponent.proposedPersona, "Invalid HTTP response", requestID: requestID)
            throw NSError(domain: "ProposalCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
        }

        ClientLogger.info(component: LogComponent.proposedPersona, "Response status: \(httpResponse.statusCode)", requestID: requestID)

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            ClientLogger.error(component: LogComponent.proposedPersona, "HTTP \(httpResponse.statusCode): \(bodyString.prefix(400))", requestID: requestID)
            throw NSError(domain: "ProposalCreation", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(bodyString)"])
        }

        do {
            let decoded = try JSONDecoder().decode(ProposalCreateResponse.self, from: data)
            guard let proposalID = decoded.proposalID,
                  let token = decoded.token,
                  let shortCode = decoded.shortCode else {
                ClientLogger.error(component: LogComponent.proposedPersona, "Unexpected response payload", requestID: requestID)
                throw NSError(domain: "ProposalCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected response from server"])
            }

            if let expiresAt = decoded.expiresAt {
                ClientLogger.info(component: LogComponent.proposedPersona, "Proposal expires at \(expiresAt)", requestID: requestID)
            }

            ClientLogger.info(component: LogComponent.proposedPersona, "Proposal created: \(proposalID)", requestID: requestID)

            return ProposalResult(
                proposalID: proposalID,
                token: token,
                shortCode: shortCode
            )
        } catch {
            let bodyString = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            ClientLogger.error(component: LogComponent.proposedPersona, "Decode error: \(error.localizedDescription)", requestID: requestID)
            ClientLogger.error(component: LogComponent.proposedPersona, "Response body: \(bodyString.prefix(400))", requestID: requestID)
            throw error
        }
    }

}

#Preview {
    NavigationStack {
        CreateProposalForClientView()
            .environmentObject(PersonaManager())
    }
}
