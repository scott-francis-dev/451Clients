import SwiftUI
import CryptoKit

/// Example view demonstrating the new multi-party document signing workflow
/// Shows how to:
/// 1. Upload a document (creates PROOF entry)
/// 2. Collect signatures from multiple parties with roles (creates SIGN entries)
/// 3. Finalize the document (creates ATTEST entry)
/// 4. View signature status and audit trail

struct MultiPartySigningView: View {
    @State private var documentData: Data?
    @State private var documentName: String = ""
    @State private var authorDID: String = ""
    @State private var showFilePicker = false
    
    // Workflow state
    @State private var uploadResponse: DocumentSigningService.UploadResponse?
    @State private var signatureEntries: [SignatureEntry] = []
    @State private var isFinalized = false
    @State private var attestEntryID: String?
    
    // UI state
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showSignatureStatus = false
    @State private var showAuditTrail = false
    @State private var signatureStatus: DocumentSigningService.SignatureStatus?
    @State private var auditTrail: DocumentSigningService.AuditTrail?
    
    // Signers to add
    @State private var newSignerDID: String = ""
    @State private var selectedRole: DocumentSigningService.SignerRole = .contractParty
    
    struct SignatureEntry: Identifiable {
        let id = UUID()
        let did: String
        let role: DocumentSigningService.SignerRole
        let ledgerEntryID: String
        let timestamp: String
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Step 1: Upload Document
                uploadSection
                
                // Step 2: Add Signatures
                if uploadResponse != nil {
                    signaturesSection
                }
                
                // Step 3: Finalize
                if !signatureEntries.isEmpty && !isFinalized {
                    finalizeSection
                }
                
                // Status & Audit Trail
                if uploadResponse != nil {
                    statusSection
                }
                
                // Results
                if isFinalized {
                    resultsSection
                }
            }
            .navigationTitle("Multi-Party Signing")
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showSignatureStatus) {
                signatureStatusSheet
            }
            .sheet(isPresented: $showAuditTrail) {
                auditTrailSheet
            }
        }
    }
    
    // MARK: - Upload Section
    
    private var uploadSection: some View {
        Section(header: Text("1. Upload Document")) {
            if uploadResponse == nil {
                TextField("Author DID", text: $authorDID)
                    .platformTextContentType(.none)
                    .platformAutocapitalization(.never)
                
                if let data = documentData {
                    HStack {
                        Image(systemName: "doc")
                        VStack(alignment: .leading) {
                            Text(documentName)
                                .font(.subheadline)
                            Text("\(data.count) bytes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Clear") {
                            documentData = nil
                            documentName = ""
                        }
                    }
                } else {
                    Button("Select Document") {
                        showFilePicker = true
                    }
                }
                
                Button("Upload Document") {
                    Task { await performUpload() }
                }
                .disabled(documentData == nil || authorDID.isEmpty || isProcessing)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Document Uploaded", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Document ID: \(uploadResponse!.documentId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Proof Entry: \(uploadResponse!.ledgerProofEntryID)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Signatures Section
    
    private var signaturesSection: some View {
        Section(header: Text("2. Add Signatures")) {
            if !isFinalized {
                TextField("Signer DID", text: $newSignerDID)
                    .platformTextContentType(.none)
                    .platformAutocapitalization(.never)
                
                Picker("Role", selection: $selectedRole) {
                    Text("Author").tag(DocumentSigningService.SignerRole.author)
                    Text("Contract Party").tag(DocumentSigningService.SignerRole.contractParty)
                    Text("Witness").tag(DocumentSigningService.SignerRole.witness)
                    Text("Notary").tag(DocumentSigningService.SignerRole.notary)
                    Text("Reviewer").tag(DocumentSigningService.SignerRole.reviewer)
                }
                
                Button("Add Signature") {
                    Task { await addSignature() }
                }
                .disabled(newSignerDID.isEmpty || isProcessing)
            }
            
            ForEach(signatureEntries) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "signature")
                            .foregroundColor(.blue)
                        
                        // Use the Signator Calling Card component
                        PersonaHandleCard(
                            handle: entry.did,
                            isPublic: true,
                            size: .compact,
                            showCopyButton: false
                        )
                        
                        Spacer()
                        Text(entry.role.rawValue.capitalized)
                            .font(.caption)
                            .padding(4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    Text("Entry ID: \(entry.ledgerEntryID)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Finalize Section
    
    private var finalizeSection: some View {
        Section(header: Text("3. Finalize Document")) {
            Button("Finalize Document") {
                Task { await performFinalize() }
            }
            .disabled(isProcessing)
            
            Text("This will create an ATTEST ledger entry and complete the signing workflow.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        Section(header: Text("Document Status")) {
            Button("View Signature Status") {
                Task { await loadSignatureStatus() }
            }
            
            Button("View Audit Trail") {
                Task { await loadAuditTrail() }
            }
        }
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        Section(header: Text("✅ Document Finalized")) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Document successfully finalized", systemImage: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.headline)
                
                if let attestID = attestEntryID {
                    Text("Attest Entry ID: \(attestID)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("Total Signatures: \(signatureEntries.count)")
                    .font(.subheadline)
                
                ForEach(DocumentSigningService.SignerRole.allCases, id: \.self) { role in
                    let count = signatureEntries.filter { $0.role == role }.count
                    if count > 0 {
                        HStack {
                            Text(role.rawValue.capitalized + ":")
                            Spacer()
                            Text("\(count)")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }
    
    // MARK: - Signature Status Sheet
    
    private var signatureStatusSheet: some View {
        NavigationView {
            List {
                if let status = signatureStatus {
                    Section(header: Text("Summary")) {
                        HStack {
                            Text("Document ID")
                            Spacer()
                            Text(status.documentId)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Total Signatures")
                            Spacer()
                            Text("\(status.totalSignatures)")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section(header: Text("By Role")) {
                        ForEach(Array(status.signaturesByRole.keys.sorted()), id: \.self) { role in
                            HStack {
                                Text(role.capitalized)
                                Spacer()
                                Text("\(status.signaturesByRole[role] ?? 0)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Section(header: Text("Signers")) {
                        ForEach(status.signers, id: \.ledgerEntryID) { signer in
                            VStack(alignment: .leading, spacing: 8) {
                                // Use the Signator Calling Card component
                                PersonaHandleCard(
                                    handle: signer.did,
                                    isPublic: true,
                                    size: .compact,
                                    showCopyButton: false
                                )
                                
                                HStack {
                                    Text(signer.role.capitalized)
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                    Text(signer.timestamp)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    Text("Loading...")
                }
            }
            .navigationTitle("Signature Status")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showSignatureStatus = false }
                }
            }
        }
    }
    
    // MARK: - Audit Trail Sheet
    
    private var auditTrailSheet: some View {
        NavigationView {
            List {
                if let audit = auditTrail {
                    Section(header: Text("Document ID")) {
                        Text(audit.documentId)
                            .font(.caption)
                    }
                    
                    Section(header: Text("Ledger Entries (\(audit.entries.count))")) {
                        ForEach(audit.entries, id: \.id) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    entryTypeIcon(entry.type)
                                    Text(entry.type)
                                        .font(.headline)
                                    Spacer()
                                    Text(entry.timestamp)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("Issuer: \(entry.issuer)")
                                    .font(.caption)
                                
                                if let role = entry.role {
                                    Text("Role: \(role)")
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                
                                Text("Entry ID: \(entry.id)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                if let prevID = entry.previousEntryID {
                                    Text("Previous: \(prevID)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    Text("Loading...")
                }
            }
            .navigationTitle("Audit Trail")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showAuditTrail = false }
                }
            }
        }
    }
    
    private func entryTypeIcon(_ type: String) -> some View {
        Group {
            switch type {
            case "PROOF":
                Image(systemName: "doc.badge.gearshape")
                    .foregroundColor(.purple)
            case "SIGN":
                Image(systemName: "signature")
                    .foregroundColor(.blue)
            case "ATTEST":
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
            default:
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Actions
    
    private func performUpload() async {
        guard let data = documentData else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let response = try await DocumentSigningService.uploadDocument(
                documentData: data,
                originalFilename: documentName
            )
            
            await MainActor.run {
                self.uploadResponse = response
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Upload failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func addSignature() async {
        guard let uploadResp = uploadResponse else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // In a real app, you would load the actual private key for this DID
            // For demo purposes, we'll generate a temporary key
            let privateKey = P256.Signing.PrivateKey()
            let publicKey = privateKey.publicKey.rawRepresentation.base64EncodedString()
            
            guard let data = documentData else {
                throw DocumentSigningError.invalidDocumentId
            }
            let documentHash = Data(SHA256.hash(data: data))
            
            // Determine the previous entry ID (either proof or last signature)
            let previousID = signatureEntries.last?.ledgerEntryID ?? uploadResp.ledgerProofEntryID
            
            let response = try await DocumentSigningService.addSignature(
                documentId: uploadResp.documentId,
                signerDID: newSignerDID,
                signerPublicKey: publicKey,
                documentHash: documentHash,
                privateKey: privateKey,
                role: selectedRole,
                previousEntryID: previousID
            )
            
            await MainActor.run {
                self.signatureEntries.append(SignatureEntry(
                    did: newSignerDID,
                    role: selectedRole,
                    ledgerEntryID: response.ledgerEntryID,
                    timestamp: response.timestamp ?? ISO8601DateFormatter().string(from: Date())
                ))
                self.newSignerDID = ""
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Signature failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func performFinalize() async {
        guard let uploadResp = uploadResponse else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let entryIDs = signatureEntries.map { $0.ledgerEntryID }
            
            let response = try await DocumentSigningService.finalizeDocument(
                documentId: uploadResp.documentId,
                finalizedBy: authorDID,
                signatureEntryIDs: entryIDs
            )
            
            await MainActor.run {
                self.isFinalized = true
                self.attestEntryID = response.ledgerAttestEntryID
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Finalization failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadSignatureStatus() async {
        guard let uploadResp = uploadResponse else { return }
        
        do {
            let status = try await DocumentSigningService.getSignatureStatus(
                documentId: uploadResp.documentId
            )
            
            await MainActor.run {
                self.signatureStatus = status
                self.showSignatureStatus = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load status: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadAuditTrail() async {
        guard let uploadResp = uploadResponse else { return }
        
        do {
            let audit = try await DocumentSigningService.getAuditTrail(
                documentId: uploadResp.documentId
            )
            
            await MainActor.run {
                self.auditTrail = audit
                self.showAuditTrail = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load audit trail: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - SignerRole Extension

extension DocumentSigningService.SignerRole: CaseIterable {
    public static var allCases: [DocumentSigningService.SignerRole] {
        [.author, .contractParty, .witness, .notary, .reviewer]
    }
}

// MARK: - Preview

#Preview {
    MultiPartySigningView()
}
