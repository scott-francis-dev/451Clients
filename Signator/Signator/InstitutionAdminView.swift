// InstitutionAdminView.swift
// Institution administrator view — lets Bobby Sue review pending access requests
// and issue Verifiable Credentials to approved staff.
//
// Flow:
//  1. Admin taps "Institution Admin" in their persona detail.
//  2. View polls S451 for pending requests under the admin's institution domain.
//  3. Admin reviews each request (name, NPI, requested role, message).
//  4. Admin picks role / department / access level and taps "Grant Access".
//  5. Signator builds a W3C VC, signs it with the admin persona's Secure Enclave key,
//     posts the signed VC to S451 which anchors it to the blockchain and pushes APNs to the subject.

import SwiftUI
import CryptoKit

@MainActor
struct InstitutionAdminView: View {

    let adminPersona: Persona   // the institution admin's persona (did:web persona)

    @EnvironmentObject private var personaManager: PersonaManager
    @State private var requests: [InstitutionAccessRequest] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var selectedRequest: InstitutionAccessRequest? = nil

    private var institutionDomain: String {
        // Derive domain from the admin's handle:  bobby.sue.hillsborohospital.org → hillsborohospital.org
        let parts = adminPersona.handle.components(separatedBy: ".")
        guard parts.count >= 2 else { return adminPersona.handle }
        return parts.suffix(2).joined(separator: ".")
    }

    var body: some View {
        List {
            if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading requests…").foregroundColor(.secondary)
                }
            } else if requests.isEmpty {
                ContentUnavailableView(
                    "No Pending Requests",
                    systemImage: "person.badge.clock",
                    description: Text("Staff access requests for \(institutionDomain) will appear here.")
                )
            } else {
                Section("Pending Access Requests") {
                    ForEach(requests.filter { $0.status == "pending" }) { req in
                        RequestRow(request: req)
                            .onTapGesture { selectedRequest = req }
                    }
                }

                let approved = requests.filter { $0.status == "approved" }
                if !approved.isEmpty {
                    Section("Recently Approved") {
                        ForEach(approved) { req in
                            RequestRow(request: req)
                        }
                    }
                }
            }

            if let err = errorMessage {
                Section {
                    Label(err, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Institution Admin")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await loadRequests() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task { await loadRequests() }
        .sheet(item: $selectedRequest) { req in
            GrantAccessSheet(
                request: req,
                adminPersona: adminPersona,
                institutionDomain: institutionDomain
            ) { approved in
                if approved {
                    // Mark locally as approved while we wait for next poll
                    if let idx = requests.firstIndex(where: { $0.id == req.id }) {
                        requests[idx].status = "approved"
                    }
                }
                selectedRequest = nil
            }
            .environmentObject(personaManager)
        }
    }

    // MARK: - Load Requests

    private func loadRequests() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            requests = try await InstitutionAPIService.fetchAccessRequests(
                institutionDomain: institutionDomain,
                adminPersona: adminPersona
            )
        } catch {
            errorMessage = "Could not load requests: \(error.localizedDescription)"
        }
    }
}

// MARK: - Row

private struct RequestRow: View {
    let request: InstitutionAccessRequest

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.subjectName)
                    .font(.headline)
                Text(request.subjectHandle)
                    .font(.caption).foregroundColor(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Label(request.requestedRole, systemImage: "briefcase")
                        .font(.caption2)
                    if let npi = request.npi {
                        Text("NPI \(npi)")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if request.status == "pending" {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: String {
        switch request.status {
        case "approved": return "checkmark.seal.fill"
        case "rejected": return "xmark.seal.fill"
        default: return "clock.badge"
        }
    }

    private var statusColor: Color {
        switch request.status {
        case "approved": return .green
        case "rejected": return .red
        default: return .orange
        }
    }
}

// MARK: - Grant Access Sheet

private struct GrantAccessSheet: View {

    let request: InstitutionAccessRequest
    let adminPersona: Persona
    let institutionDomain: String
    let onDone: (Bool) -> Void

    @State private var role: String
    @State private var department: String
    @State private var accessLevel: String = "provider"
    @State private var validYears: Int = 1
    @State private var isIssuing = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    private let accessLevels = ["viewer", "provider", "admin"]
    private let roleOptions = ["Physician", "Nurse Practitioner", "Physician Assistant",
                               "Registered Nurse", "PharmD", "Medical Assistant", "Admin Staff"]

    init(
        request: InstitutionAccessRequest,
        adminPersona: Persona,
        institutionDomain: String,
        onDone: @escaping (Bool) -> Void
    ) {
        self.request = request
        self.adminPersona = adminPersona
        self.institutionDomain = institutionDomain
        self.onDone = onDone
        _role = State(initialValue: request.requestedRole)
        _department = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            Form {
                // Request summary
                Section("Access Request") {
                    LabeledContent("Name", value: request.subjectName)
                    LabeledContent("Handle", value: request.subjectHandle)
                    if let npi = request.npi {
                        LabeledContent("NPI", value: npi)
                    }
                    if let msg = request.message, !msg.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Message").font(.caption).foregroundColor(.secondary)
                            Text(msg).font(.body)
                        }
                    }
                }

                // Credential details
                Section("Credential to Issue") {
                    Picker("Role", selection: $role) {
                        ForEach(roleOptions, id: \.self) { r in
                            Text(r).tag(r)
                        }
                    }

                    TextField("Department", text: $department)
                        .autocorrectionDisabled()

                    Picker("Access Level", selection: $accessLevel) {
                        ForEach(accessLevels, id: \.self) { lvl in
                            Text(lvl.capitalized).tag(lvl)
                        }
                    }

                    Stepper("Valid for \(validYears) year\(validYears == 1 ? "" : "s")",
                            value: $validYears, in: 1...5)
                }

                // Issuer info
                Section("Issuer") {
                    LabeledContent("Institution", value: institutionDomain)
                    LabeledContent("Your DID", value: adminPersona.id)
                        .font(.caption)
                }

                if let err = errorMessage {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                if let ok = successMessage {
                    Section {
                        Label(ok, systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                Section {
                    Button {
                        Task { await issueVC() }
                    } label: {
                        if isIssuing {
                            HStack {
                                ProgressView()
                                Text("Signing & Issuing…")
                            }
                        } else {
                            Text("Grant Access")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isIssuing || successMessage != nil)
                }
            }
            .navigationTitle("Grant Access")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone(false) }
                }
            }
        }
    }

    // MARK: - Issue VC

    private func issueVC() async {
        isIssuing = true
        errorMessage = nil
        defer { isIssuing = false }

        do {
            // Build unsigned VC
            let issuerDID = "did:web:\(institutionDomain)"
            let verificationMethod = "\(issuerDID)#key-1"
            // Institution display name: capitalize each word of the domain stem
            let institutionName = institutionDomain
                .components(separatedBy: ".").first?
                .split(separator: "-").map { $0.capitalized }.joined(separator: " ") ?? institutionDomain

            let vc = VerifiableCredential.make(
                issuerDID: issuerDID,
                subjectDID: request.subjectDID,
                subjectHandle: request.subjectHandle,
                role: role,
                department: department.isEmpty ? nil : department,
                accessLevel: accessLevel,
                institution: institutionName,
                institutionDomain: institutionDomain,
                npi: request.npi,
                validForYears: validYears
            )

            // Load the admin's P256 private key
            let privateKey = try PrivateKeyStore.loadPrivateKey(for: adminPersona.id)

            // Sign the VC
            let signedVC = try vc.signed(using: privateKey, verificationMethod: verificationMethod)

            // Post to S451 (anchors to blockchain, pushes APNs to subject)
            try await InstitutionAPIService.issueVC(signedVC, adminPersona: adminPersona)

            successMessage = "Credential issued! \(request.subjectName) will receive a notification."
            // Brief delay so the user sees the success message, then dismiss
            try await Task.sleep(nanoseconds: 2_000_000_000)
            onDone(true)
        } catch {
            errorMessage = "Failed to issue credential: \(error.localizedDescription)"
        }
    }
}

// MARK: - Institution API Service

enum InstitutionAPIService {

    // MARK: Fetch Pending Requests

    /// Fetches pending access requests for the admin's institution domain.
    /// Sends a signed request so S451 can verify the caller is an admin.
    static func fetchAccessRequests(
        institutionDomain: String,
        adminPersona: Persona
    ) async throws -> [InstitutionAccessRequest] {
        let baseURL = ServerConfig.baseURL
        guard let url = URL(string: "\(baseURL)/api/institution/requests/\(institutionDomain)") else {
            throw URLError(.badURL)
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let message = "admin-list|\(institutionDomain)|\(adminPersona.id)|\(timestamp)"
        let sigB64: String
        do {
            let key = try PrivateKeyStore.loadPrivateKey(for: adminPersona.id)
            let sig = try key.signature(for: SHA256.hash(data: Data(message.utf8)))
            sigB64 = Data(sig.derRepresentation).base64EncodedString()
        } catch {
            throw error
        }

        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(adminPersona.id, forHTTPHeaderField: "X-Admin-DID")
        req.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
        req.setValue(sigB64, forHTTPHeaderField: "X-Signature")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "InstitutionAPI", code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: body])
        }
        return try JSONDecoder().decode([InstitutionAccessRequest].self, from: data)
    }

    // MARK: Issue VC

    /// Posts a signed Verifiable Credential to S451.
    /// S451 anchors the VC hash to the blockchain and sends APNs to the subject.
    static func issueVC(_ vc: VerifiableCredential, adminPersona: Persona) async throws {
        let baseURL = ServerConfig.baseURL
        guard let url = URL(string: "\(baseURL)/api/vc/issue") else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(adminPersona.id, forHTTPHeaderField: "X-Issuer-DID")
        req.httpBody = try JSONEncoder().encode(vc)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "InstitutionAPI", code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: body])
        }
    }

    // MARK: Request Access (staff side)

    /// Staff member submits an access request to an institution.
    static func requestAccess(
        subjectPersona: Persona,
        institutionDomain: String,
        requestedRole: String,
        npi: String?,
        message: String?
    ) async throws {
        let baseURL = ServerConfig.baseURL
        guard let url = URL(string: "\(baseURL)/api/institution/request") else {
            throw URLError(.badURL)
        }

        struct RequestBody: Encodable {
            let subjectDID: String
            let subjectName: String
            let subjectHandle: String
            let subjectPublicKeyBase64: String
            let npi: String?
            let requestedRole: String
            let institutionDomain: String
            let message: String?
        }

        let body = RequestBody(
            subjectDID: subjectPersona.id,
            subjectName: subjectPersona.name,
            subjectHandle: subjectPersona.handle,
            subjectPublicKeyBase64: subjectPersona.publicKeyBase64,
            npi: npi,
            requestedRole: requestedRole,
            institutionDomain: institutionDomain,
            message: message
        )

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "InstitutionAPI", code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: body])
        }
    }
}

// MARK: - Preview

#Preview {
    let persona = Persona(
        id: "did:web:hillsborohospital.org",
        controller: "did:web:hillsborohospital.org",
        name: "Bobby Sue McLennan",
        handle: "bobby.sue.mclennan.hillsborohospital.org",
        publicKeyBase64: "",
        createdAt: ISO8601DateFormatter().string(from: Date())
    )
    NavigationStack {
        InstitutionAdminView(adminPersona: persona)
            .environmentObject(PersonaManager())
    }
}
