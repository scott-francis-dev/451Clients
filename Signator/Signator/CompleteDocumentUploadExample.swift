//
//  CompleteDocumentUploadExample.swift
//  451Wallet
//
//  Created by User451 on 1/23/26.
//
//  Complete example showing how to upload a document with full metadata
//

import SwiftUI

/// Example view showing complete document upload workflow with metadata
struct CompleteDocumentUploadExample: View {
    @State private var documentData: Data?
    @State private var originalFilename: String?
    @State private var metadataForm = DocumentMetadataForm()
    @State private var selectedSigners: [SignerSelection] = []
    
    @State private var showMetadataEditor = false
    @State private var showSignerPicker = false
    @State private var isUploading = false
    @State private var uploadSuccess: Bool?
    @State private var uploadedDocumentId: String?
    @State private var errorMessage: String?
    
    @State private var progressMessage = ""
    @State private var progressValue: Double = 0.0
    
    var body: some View {
        NavigationStack {
            Form {
                // Document Section
                Section("Document") {
                    if let filename = originalFilename {
                        HStack {
                            Image(systemName: "doc.fill")
                            Text(filename)
                            Spacer()
                            Button("Change") {
                                // Show file picker
                            }
                        }
                    } else {
                        Button {
                            // Show file picker
                        } label: {
                            Label("Select Document", systemImage: "doc.badge.plus")
                        }
                    }
                }
                
                // Metadata Section
                Section {
                    if metadataForm.title.isEmpty {
                        Button {
                            showMetadataEditor = true
                        } label: {
                            Label("Add Metadata (Required)", systemImage: "doc.text")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(metadataForm.title)
                                .font(.headline)
                            if !metadataForm.author.isEmpty {
                                Text("Author: \(metadataForm.author)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if !metadataForm.type.isEmpty {
                                Text("Type: \(metadataForm.type)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button {
                            showMetadataEditor = true
                        } label: {
                            Label("Edit Metadata", systemImage: "pencil")
                        }
                    }
                } header: {
                    Text("Metadata")
                } footer: {
                    Text("Title is required. Add more details to help others find your document.")
                }
                
                // Signers Section
                Section("Signers (Optional)") {
                    if selectedSigners.isEmpty {
                        Button {
                            showSignerPicker = true
                        } label: {
                            Label("Add Signers", systemImage: "person.2.badge.plus")
                        }
                    } else {
                        ForEach(selectedSigners) { signer in
                            HStack {
                                Image(systemName: "person.circle.fill")
                                VStack(alignment: .leading) {
                                    Text(signer.did)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Text(signer.role.rawValue.capitalized)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Button {
                            showSignerPicker = true
                        } label: {
                            Label("Edit Signers", systemImage: "pencil")
                        }
                    }
                }
                
                // Upload Section
                Section {
                    if isUploading {
                        VStack(spacing: 8) {
                            ProgressView(value: progressValue)
                            Text(progressMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if let success = uploadSuccess {
                        if success {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Upload Successful!", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                if let docId = uploadedDocumentId {
                                    Text("Document ID: \(docId)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Upload Failed", systemImage: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                if let error = errorMessage {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Button("Try Again") {
                                    uploadSuccess = nil
                                }
                            }
                        }
                    } else {
                        Button {
                            Task {
                                await uploadDocument()
                            }
                        } label: {
                            Label("Upload Document", systemImage: "arrow.up.circle.fill")
                        }
                        .disabled(documentData == nil || metadataForm.title.isEmpty)
                    }
                }
            }
            .navigationTitle("Upload Document")
            .sheet(isPresented: $showMetadataEditor) {
                NavigationStack {
                    DocumentMetadataEditor(metadata: $metadataForm)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showMetadataEditor = false
                                }
                                .disabled(metadataForm.title.isEmpty)
                            }
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    showMetadataEditor = false
                                }
                            }
                        }
                }
            }
            .signerPickerSheet(isPresented: $showSignerPicker, selectedSigners: $selectedSigners)
        }
    }
    
    func uploadDocument() async {
        guard let documentData = documentData else { return }
        
        isUploading = true
        uploadSuccess = nil
        errorMessage = nil
        
        do {
            // Build metadata
            var metadata: DocumentMetadata451 = metadataForm.toMetadata()
            
            // Add file information
            if let filename = originalFilename {
                metadata.fileExtension = (filename as NSString).pathExtension
            }
            
            // Add signers if any
            if !selectedSigners.isEmpty {
                metadata.signers = DocumentMetadata451.from(signers: selectedSigners)
            }
            
            // Upload with progress tracking
            let (documentId, _, _) = try await DocumentSigningService.completeSigningWorkflowWithSSEProgress(
                documentData: documentData,
                originalFilename: originalFilename,
                metadata: metadata,
                onProgress: { update in
                    Task { @MainActor in
                        progressValue = update.progress
                        progressMessage = update.message
                    }
                },
                onServerProgress: { serverUpdate in
                    Task { @MainActor in
                        progressValue = serverUpdate.progress
                        progressMessage = serverUpdate.message
                    }
                }
            )
            
            uploadedDocumentId = documentId
            uploadSuccess = true
            
        } catch {
            errorMessage = error.localizedDescription
            uploadSuccess = false
        }
        
        isUploading = false
    }
}

// MARK: - Simple Upload Helper

/// Simple helper function for uploading documents with metadata
/// Use this when you already have the document data and metadata ready
func uploadDocumentToServer(
    documentData: Data,
    filename: String?,
    title: String,
    author: String? = nil,
    documentType: String? = nil,
    description: String? = nil,
    signers: [SignerSelection]? = nil
) async throws -> String {
    
    // Build metadata
    var metadata = DocumentMetadata451(
        title: title,
        description: description, author: author,
        type: documentType
    )
    
    // Add file extension
    if let filename = filename {
        metadata.fileExtension = (filename as NSString).pathExtension
    }
    
    // Add signers
    if let signers = signers {
        metadata.signers = DocumentMetadata451.from(signers: signers)
    }
    
    // Upload
    let (documentId, _) = try await DocumentSigningService.completeSigningWorkflow(
        documentData: documentData,
        originalFilename: filename,
        metadata: metadata
    )
    
    return documentId
}

// MARK: - Usage Examples

/*
 
 // Example 1: Simple upload with minimal metadata
 let documentId = try await uploadDocumentToServer(
     documentData: myPDFData,
     filename: "contract.pdf",
     title: "Employment Contract",
     author: "John Doe",
     documentType: "contract"
 )
 
 // Example 2: Upload with signers
 let signers = [
     SignerSelection(did: "did:example:alice", role: .author),
     SignerSelection(did: "did:example:bob", role: .contractParty),
     SignerSelection(did: "did:example:witness", role: .witness)
 ]
 
 let documentId = try await uploadDocumentToServer(
     documentData: myPDFData,
     filename: "agreement.pdf",
     title: "Partnership Agreement",
     author: "Alice Smith",
     documentType: "agreement",
     description: "Partnership agreement between Alice and Bob for new venture",
     signers: signers
 )
 
 // Example 3: Full workflow with progress tracking
 let metadata = DocumentMetadata451(
     title: "Research Paper",
     subtitle: "AI in Healthcare",
     description: "Comprehensive study of AI applications in modern healthcare",
     author: "Dr. Jane Smith",
     subject: "AI, Healthcare, Machine Learning",
     type: "article",
     language: "English"
 )
 
 metadata.doi = "10.1234/example.doi"
 metadata.publicationDate = ISO8601DateFormatter().string(from: Date())
 
 let (documentId, attestEntryID, accessCode) = try await DocumentSigningService.completeSigningWorkflowWithSSEProgress(
     documentData: paperData,
     originalFilename: "research-paper.pdf",
     metadata: metadata,
     onProgress: { update in
         print("Progress: \(update.progress * 100)% - \(update.message)")
     },
     onServerProgress: { serverUpdate in
         print("Server: \(serverUpdate.progress * 100)% - \(serverUpdate.message)")
     }
 )
 
 print("Document ID: \(documentId)")
 print("Attest Entry: \(attestEntryID)")
 if let code = accessCode {
     print("Access Code: \(code)")
 }
 
 */


