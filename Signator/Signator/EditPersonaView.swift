import Foundation
import SwiftUI
import CryptoKit



struct EditPersonaView: View {
    @ObservedObject var personaManager: PersonaManager
    private let originalPersona: Persona
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var vcStore = VCStore.shared
    
   
    @State private var name: String
    @State private var email: String
    @State private var affiliations: String
    @State private var socialLinks: String
    @State private var address: String
    
    // Private fields
    @State private var givenName: String
    @State private var aliases: String
    @State private var street: String
    @State private var city: String
    @State private var stateRegion: String
    @State private var postalCode: String
    @State private var country: String
    @State private var socialSecurityNumber: String
    @State private var privateEmail: String
    
    // UI state
    @State private var errorMessage: String? = nil
    @State private var showPublishPrompt: Bool = false
    @State private var showPublishSheet: Bool = false
    @State private var showServerSettings: Bool = false
    @State private var isValidating: Bool = false
    @State private var isValidated: Bool
    @State private var isPublicPersona: Bool

    // Content to share via system share sheet
    private var shareText: String {
        let displayName = name.isEmpty ? originalPersona.name : name
        let aff = affiliations.trimmingCharacters(in: .whitespacesAndNewlines)
        let social = socialLinks.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines: [String] = []
        lines.append("Persona Info")
        lines.append("Name: \(displayName)")
        lines.append("DID: \(originalPersona.id)")
        lines.append("Short ID: \(originalPersona.shortIDPhoneStyle)")
        lines.append("Visibility: \(isPublicPersona ? "Public" : "Private")")
        lines.append("")
        lines.append("Public Key (P-256, X9.63 uncompressed, Base64):")
        lines.append(originalPersona.publicKeyBase64)
        if !aff.isEmpty { lines.append("Affiliations: \(aff)") }
        if !social.isEmpty { lines.append("Social: \(social)") }
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Server Update (Signed)
    private struct UpdateMessage: Encodable {
        let did: String
        let name: String?
        let email: String?
        let address: [String: String]?
        let backgroundValidated: Bool?
        let nonce: String
        let updatedAt: String
    }

    private struct PersonaUpdateRequest: Encodable {
        let name: String?
        let email: String?
        let address: [String: String]?
        let backgroundValidated: Bool?
        let nonce: String
        let updatedAt: String
        let signedUpdate: String
    }

    private func serverAddressDict(from privateAddress: PersonaProfile.PostalAddress?) -> [String: String]? {
        guard let address = privateAddress else { return nil }
        var dict: [String: String] = [:]
        if let street = address.street, !street.isEmpty { dict["street"] = street }
        if let city = address.city, !city.isEmpty { dict["city"] = city }
        if let state = address.state, !state.isEmpty { dict["region"] = state }
        if let postal = address.postalCode, !postal.isEmpty { dict["postalCode"] = postal }
        if let country = address.country, !country.isEmpty { dict["country"] = country }
        return dict.isEmpty ? nil : dict
    }
    
    // Percent-encode a string for use as a single URL path component (encodes '@' to %40, etc.)
    private func percentEncodePathComponent(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }
    
    // Simple local logger for diagnostics
    @inline(__always)
    private func debugLog(_ message: String) {
        print("[EditPersonaView] \(message)")
    }
    
    // Resolve to canonical DID using server search-direct endpoint
    private func resolveCanonicalDID(_ did: String) async throws -> String {
        guard let base = URL(string: ServerConfig.baseURL) else { throw URLError(.badURL) }
        guard var comps = URLComponents(url: base
            .appendingPathComponent("api")
            .appendingPathComponent("persona")
            .appendingPathComponent("search-direct"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        comps.queryItems = [URLQueryItem(name: "did", value: did)]
        guard let url = comps.url else { throw URLError(.badURL) }
        debugLog("Resolve URL: \(url.absoluteString)")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse {
            debugLog("Resolve status: \(http.statusCode)")
        }
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 404 {
            throw NSError(domain: "Resolve", code: 404, userInfo: [NSLocalizedDescriptionKey: "Persona not found on server"])
        }
        guard (200...299).contains(http.statusCode) else {
            throw NSError(domain: "Resolve", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Resolve failed: \(http.statusCode)"])
        }
        struct MinimalProfile: Decodable { let dID: String }
        struct HitsWrapper: Decodable { let hits: [MinimalProfile] }
        struct ResultsWrapper: Decodable { let results: [MinimalProfile] }

        let decoder = JSONDecoder()
        if let direct = try? decoder.decode(MinimalProfile.self, from: data) {
            debugLog("Resolved canonical DID (direct): \(direct.dID)")
            return direct.dID
        }
        if let hits = try? decoder.decode(HitsWrapper.self, from: data), let first = hits.hits.first {
            debugLog("Resolved canonical DID (hits): \(first.dID)")
            return first.dID
        }
        if let results = try? decoder.decode(ResultsWrapper.self, from: data), let first = results.results.first {
            debugLog("Resolved canonical DID (results): \(first.dID)")
            return first.dID
        }
        let bodyStr = String(data: data, encoding: .utf8) ?? "(non-utf8 response)"
        debugLog("Resolve decode failed. Body: \(bodyStr)")
        throw NSError(domain: "Resolve", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unrecognized resolve response shape"])
    }

    private func performServerUpdate(with updatedPersona: Persona) async {
        let did = updatedPersona.id

        // Resolve canonical DID so path and signed message match server expectations
        let canonicalDID: String
        do {
            canonicalDID = try await resolveCanonicalDID(did)
        } catch {
            await MainActor.run {
                let ns = error as NSError
                if ns.code == 404 {
                    self.showPublishPrompt = true
                    self.errorMessage = nil
                } else {
                    self.errorMessage = "Failed to resolve persona on server: \(error.localizedDescription)"
                }
            }
            return
        }
        let signingDID = canonicalDID
        debugLog("Using canonical DID: \(signingDID)")

        let nonce = UUID().uuidString
        let updatedAt = ISO8601DateFormatter().string(from: Date())
        
        // Build address from private data if present
        let hasAddress = !street.isEmpty || !city.isEmpty || !stateRegion.isEmpty || !postalCode.isEmpty || !country.isEmpty
        let privateAddress = hasAddress ? PersonaProfile.PostalAddress(
            street: street.isEmpty ? nil : street,
            city: city.isEmpty ? nil : city,
            state: stateRegion.isEmpty ? nil : stateRegion,
            postalCode: postalCode.isEmpty ? nil : postalCode,
            country: country.isEmpty ? nil : country
        ) : nil
        let addressDict = serverAddressDict(from: privateAddress)

        // Canonical message to sign (sorted keys)
        let message = UpdateMessage(
            did: signingDID,
            name: updatedPersona.name,
            email: updatedPersona.email,
            address: addressDict,
            backgroundValidated: nil,
            nonce: nonce,
            updatedAt: updatedAt
        )

        do {
            let canonicalEncoder = JSONEncoder()
            canonicalEncoder.outputFormatting = [.sortedKeys]
            let canonicalBytes = try canonicalEncoder.encode(message)
            if let canonicalJSON = String(data: canonicalBytes, encoding: .utf8) {
                debugLog("Canonical UpdateMessage: \(canonicalJSON)")
            }

            // Sign with persona's private key (P-256, DER-encoded ECDSA)
            let privateKey: P256.Signing.PrivateKey
            do {
                privateKey = try PrivateKeyStore.loadPrivateKey(for: signingDID)
            } catch {
                // Fallback: try original id if key was saved under base id locally
                privateKey = try PrivateKeyStore.loadPrivateKey(for: did)
            }
            let signatureDER = try privateKey.signature(for: canonicalBytes).derRepresentation
            let signatureBase64 = Data(signatureDER).base64EncodedString()
            debugLog("Signature (base64) prefix: \(signatureBase64.prefix(16))… length=\(signatureBase64.count)")

            // Build request body
            let body = PersonaUpdateRequest(
                name: updatedPersona.name,
                email: updatedPersona.email,
                address: addressDict,
                backgroundValidated: nil,
                nonce: nonce,
                updatedAt: updatedAt,
                signedUpdate: signatureBase64
            )

            // Build URL: PATCH /api/persona/:personaDID (ensure '@' and other reserved chars are encoded)
            guard let base = URL(string: ServerConfig.baseURL) else {
                await MainActor.run { self.errorMessage = "Bad server base URL." }
                return
            }
            let encodedDID = percentEncodePathComponent(signingDID)
            guard let url = URL(string: base.absoluteString + "/api/persona/" + encodedDID) else {
                await MainActor.run { self.errorMessage = "Failed to build update URL." }
                return
            }
            debugLog("PATCH URL: \(url.absoluteString)")

            var req = URLRequest(url: url)
            req.httpMethod = "PATCH"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)

            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse {
                debugLog("PATCH status: \(http.statusCode)")
            }
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let http = resp as? HTTPURLResponse
                let bodyText = String(data: data, encoding: .utf8) ?? "(non-utf8 response body)"
                let code = http?.statusCode ?? -1
                debugLog("PATCH error body: \(bodyText)")
                throw NSError(domain: "PersonaUpdate", code: code, userInfo: [NSLocalizedDescriptionKey: "Server error \(code): \(bodyText)"])
            }

            // On success, persist locally and dismiss
            await MainActor.run {
                self.personaManager.updatePersona(updatedPersona)
                if let _ = self.personaManager.personas.firstIndex(where: { $0.id == updatedPersona.id }) {
                    self.dismiss()
                } else {
                    self.errorMessage = "Updated on server, but failed to update locally."
                }
            }
        } catch {
            debugLog("Update failed: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    init(personaManager: PersonaManager, persona: Persona) {
        self.personaManager = personaManager
        self.originalPersona = persona
        _name = State(initialValue: persona.name)
        _email = State(initialValue: persona.email ?? "")
        _affiliations = State(initialValue: persona.affiliations ?? "")
        _socialLinks = State(initialValue: persona.socialLinks ?? "")
        _address = State(initialValue: persona.address ?? "")
        
        // Load private data from PrivateDataStore
        let privateData = try? PrivateDataStore.loadPrivateData(for: persona.id)
        _givenName = State(initialValue: privateData?.givenName ?? "")
        _aliases = State(initialValue: privateData?.aliases ?? "")
        _street = State(initialValue: privateData?.privateAddress?.street ?? "")
        _city = State(initialValue: privateData?.privateAddress?.city ?? "")
        _stateRegion = State(initialValue: privateData?.privateAddress?.state ?? "")
        _postalCode = State(initialValue: privateData?.privateAddress?.postalCode ?? "")
        _country = State(initialValue: privateData?.privateAddress?.country ?? "")
        _socialSecurityNumber = State(initialValue: privateData?.socialSecurityNumber ?? "")
        _privateEmail = State(initialValue: privateData?.privateEmail ?? "")
        
        // Check if persona is validated
        _isValidated = State(initialValue: persona.status == "validated")
        _isPublicPersona = State(initialValue: persona.visibility == .public)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle(isOn: $isPublicPersona) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isPublicPersona ? "Public Persona" : "Private Persona")
                                .font(.headline)
                            Text(isPublicPersona ? "Use for publishing; can be anonymous." : "Use for contracts; requires full identity and background check.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    Text("Public personas can publish books/documents without revealing identity. Private personas are not publicly visible but must provide full identity for encrypted contract signing and background checks.")
                        .font(.footnote)
                }
                
                Section {
                    TextField("Name", text: $name)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DID: \(originalPersona.id)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text("Short ID: \(originalPersona.shortIDPhoneStyle)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Persona Identity")
                } footer: {
                    Text("Your DID is always public and searchable.")
                        .font(.footnote)
                }

                Section {
                    NavigationLink {
                        DomainClaimView(persona: originalPersona)
                    } label: {
                        Label("Verify a Domain", systemImage: "server.rack")
                    }
                    NavigationLink {
                        DomainDelegationView(owner: originalPersona, personaManager: personaManager)
                    } label: {
                        Label("Delegate a Domain", systemImage: "person.badge.key")
                    }
                } header: {
                    Text("Domain Ownership")
                } footer: {
                    Text("Prove this persona controls a domain with a signed DNS record, then grant others the right to publish under it. Subdomains count — a department proves chem.example.edu and delegates to its own members.")
                        .font(.footnote)
                }

                Section {
                    TextField("Email (Optional)", text: $email)
                        .platformAutocapitalization(.never)
                        .platformKeyboardType(.emailAddress)
                        .autocorrectionDisabled(true)
                    TextField("Affiliations", text: $affiliations)
                    TextField("Social Media Links (comma-separated URLs)", text: $socialLinks)
                } header: {
                    Text("Public Information")
                } footer: {
                    Text("Public fields are visible in your persona profile and can be viewed by anyone searching for your DID.")
                        .font(.footnote)
                }
                
                Section {
                    TextField("Address", text: $address)
                } header: {
                    Text(isPublicPersona ? "Private Information (Optional)" : "Private Information (Recommended)")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("Private fields are encrypted and stored only on your device.")
                        }
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "signature")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("They are only included when you sign documents like contracts, wills, or legal agreements.")
                        }
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "shield.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("Private data is never sent to the server or made publicly accessible.")
                        }
                    }
                    .font(.footnote)
                }
                
                Section {
                    Button("Save Changes") {
                        saveChanges()
                    }
                }
                
                // Verifiable Credentials wallet
                let vcs = vcStore.credentials(for: originalPersona.id)
                if !vcs.isEmpty {
                    Section {
                        ForEach(vcs) { vc in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Label(vc.credentialSubject.role, systemImage: "checkmark.seal.fill")
                                        .font(.subheadline).fontWeight(.medium)
                                    Spacer()
                                    if vc.isExpired {
                                        Text("Expired").font(.caption2).foregroundColor(.red)
                                    } else {
                                        Text("Valid").font(.caption2).foregroundColor(.green)
                                    }
                                }
                                Text(vc.credentialSubject.institution)
                                    .font(.caption).foregroundColor(.secondary)
                                if let dept = vc.credentialSubject.department {
                                    Text(dept).font(.caption2).foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("Verifiable Credentials")
                    } footer: {
                        Text("Credentials issued to this persona by verified institutions.")
                            .font(.footnote)
                    }
                }

                // Institution Admin panel — visible only for did:web personas
                if originalPersona.id.hasPrefix("did:web:") {
                    Section {
                        NavigationLink {
                            InstitutionAdminView(adminPersona: originalPersona)
                                .environmentObject(personaManager)
                        } label: {
                            Label("Institution Admin", systemImage: "building.2.crop.circle")
                        }
                    } header: {
                        Text("Institution")
                    } footer: {
                        Text("Review staff access requests and issue Verifiable Credentials to approved members.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        deletePersona()
                    } label: {
                        Label("Delete Persona", systemImage: "trash")
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("This will permanently delete your persona from local storage, PersonaManager, and all associated keys. This action cannot be undone.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Persona")
            .onAppear { vcStore.loadForPersona(originalPersona.id) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                #if DEBUG
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showServerSettings = true
                    } label: {
                        Label("Server Settings", systemImage: "server.rack")
                    }
                }
                #endif
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share Persona")
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Persona not on server", isPresented: $showPublishPrompt) {
                Button("Cancel", role: .cancel) { showPublishPrompt = false }
                Button("Publish…") { showPublishSheet = true }
            } message: {
                Text("This persona is not published to the server yet. Would you like to publish it now?")
            }
            .sheet(isPresented: $showPublishSheet) {
                NavigationStack {
                    PersonaCreationView(personaManager: personaManager, onDismiss: { showPublishSheet = false })
                        .navigationTitle("Publish Persona")
                }
            }
            .sheet(isPresented: $showServerSettings) {
                NavigationStack {
                    ServerSettingsView()
                }
            }
        }
    }
    
    private func saveChanges() {
        var updatedPersona = originalPersona
        updatedPersona.name = name
        updatedPersona.email = email.isEmpty ? nil : email
        updatedPersona.address = address.isEmpty ? nil : address
        updatedPersona.affiliations = affiliations.isEmpty ? nil : affiliations
        updatedPersona.socialLinks = socialLinks.isEmpty ? nil : socialLinks
        updatedPersona.visibility = isPublicPersona ? .public : .private

        if !isPublicPersona {
            let hasSomePrivate = !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if !hasSomePrivate {
                self.errorMessage = "Private personas should include private identity details. You can continue, but some workflows may require additional information."
            }
        }

        // Call the signed server update; on success we persist locally and dismiss inside the async function
        Task {
            await performServerUpdate(with: updatedPersona)
        }
    }
    
    private func deletePersona() {
        let personaToDelete = originalPersona
        
        // Delete from PersonaManager
        personaManager.deletePersona(personaToDelete)
        print("🗑️ [EditPersona] Deleted persona from PersonaManager: \(personaToDelete.id)")
        
        // Delete private key if it exists
        do {
            try PrivateKeyStore.deletePrivateKey(for: personaToDelete.id)
            print("🗑️ [EditPersona] Deleted private key for: \(personaToDelete.id)")
        } catch {
            print("⚠️ [EditPersona] Failed to delete private key for \(personaToDelete.id): \(error)")
        }
        
        // Delete private data if it exists
        do {
            try PrivateDataStore.deletePrivateData(for: personaToDelete.id)
            print("🗑️ [EditPersona] Deleted private data for: \(personaToDelete.id)")
        } catch {
            print("⚠️ [EditPersona] Failed to delete private data for \(personaToDelete.id): \(error)")
        }
        
        // Delete from PersonaStore
        PersonaStore.shared.removePersona(personaToDelete.id)
        print("🗑️ [EditPersona] Deleted persona from PersonaStore: \(personaToDelete.id)")
        
        // Dismiss the view
        dismiss()
    }
}

