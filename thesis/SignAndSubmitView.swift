//
//  SignAndSubmitView.swift
//  451Wallet
//
//  Created by User451 on 4/25/25.
//
//  Document upload and submission flow.
//

import SwiftUI

// MARK: - Sign and Submit View
//
// Modern implementation that uploads documents to the server.
// Server handles all signing logic server-side via DocumentSigningService.
//
// Usage Examples:
//   - Basic: SignAndSubmitView(documentData: data, originalFilename: "doc.pdf")
//   - Auto-submit: SignAndSubmitView(documentData: data, originalFilename: nil, autoSubmit: true)
//   - With callback: 
//       SignAndSubmitView(documentData: data, originalFilename: "doc.pdf") { result in
//           switch result {
//           case .success(let submission):
//               print("Success! Access code: \(submission.accessCode ?? "none")")
//           case .failure(let error):
//               print("Failed: \(error)")
//           }
//       }

struct SignAndSubmitView: View {
    // MARK: - Required Properties
    
    /// The raw document data to upload
    let documentData: Data
    
    /// Optional filename (e.g., "Contract.pdf")
    let originalFilename: String?
    
    // MARK: - Optional Configuration
    
    /// If true, automatically starts submission when view appears
    var autoSubmit: Bool = false
    
    /// Called when submission completes (success or failure)
    var onCompletion: ((Result<SubmissionResult, Error>) -> Void)? = nil
    
    // MARK: - State
    
    @State private var isSubmitting = false
    @State private var submissionResult: Result<SubmissionResult, Error>? = nil
    @State private var progressMessage: String = ""
    @State private var uploadProgress: Double = 0.0
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Types
    
    struct SubmissionResult {
        let documentId: String
        let accessCode: String?
        let ledgerProofEntryID: String?
        let documentURL: String?
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 24) {
            switch submissionResult {
            case .none:
                // Initial state or submitting
                if isSubmitting {
                    submittingView
                } else {
                    initialView
                }
                
            case .success(let result):
                successView(result: result)
                
            case .failure(let error):
                failureView(error: error)
            }
        }
        .padding()
        .onAppear {
            if autoSubmit {
                Task {
                    await submitDocument()
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var initialView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.arrow.up")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Ready to Submit")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let filename = originalFilename {
                Text(filename)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text("\(ByteCountFormatter.string(fromByteCount: Int64(documentData.count), countStyle: .file))")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            Button {
                Task {
                    await submitDocument()
                }
            } label: {
                Label("Submit Document", systemImage: "arrow.up.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
    
    private var submittingView: some View {
        VStack(spacing: 16) {
            ProgressView(value: uploadProgress) {
                Text("Submitting Document")
                    .font(.headline)
            }
            .progressViewStyle(.linear)
            
            if !progressMessage.isEmpty {
                Text(progressMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private func successView(result: SubmissionResult) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("Document Submitted Successfully")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                if let accessCode = result.accessCode {
                    HStack {
                        Text("Access Code:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(accessCode)
                            .fontWeight(.semibold)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                
                HStack {
                    Text("Document ID:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(result.documentId.prefix(12) + "...")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                if let proofID = result.ledgerProofEntryID {
                    HStack {
                        Text("Proof Entry:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(proofID.prefix(12) + "...")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(12)
            
            Button("Done") {
                onCompletion?(.success(result))
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
    
    private func failureView(error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text("Submission Failed")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(12)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCompletion?(.failure(error))
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Try Again") {
                    Task {
                        await submitDocument()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
    }
    
    // MARK: - Submission Logic
    
    private func submitDocument() async {
        isSubmitting = true
        submissionResult = nil
        progressMessage = "Preparing document..."
        uploadProgress = 0.1
        
        do {
            print("🚀 [SignAndSubmit] Starting document upload")
            print("   File size: \(documentData.count) bytes")
            if let filename = originalFilename {
                print("   Filename: \(filename)")
            }
            
            progressMessage = "Uploading to server..."
            uploadProgress = 0.3
            
            // Use the modern DocumentSigningService API
            // Server handles all signing logic server-side
            let uploadResponse = try await DocumentSigningService.uploadDocument(
                documentData: documentData,
                originalFilename: originalFilename
            )
            
            progressMessage = "Processing complete"
            uploadProgress = 1.0
            
            let result = SubmissionResult(
                documentId: uploadResponse.documentId,
                accessCode: uploadResponse.accessCode,
                ledgerProofEntryID: uploadResponse.ledgerProofEntryID,
                documentURL: uploadResponse.documentURL
            )
            
            print("✅ [SignAndSubmit] Document uploaded successfully")
            print("   Document ID: \(uploadResponse.documentId)")
            if let code = uploadResponse.accessCode {
                print("   Access Code: \(code)")
            }
            if let proofID = uploadResponse.ledgerProofEntryID {
                print("   Proof Entry: \(proofID)")
            }
            
            submissionResult = .success(result)
            
            // Notify completion handler
            onCompletion?(.success(result))
            
        } catch {
            print("❌ [SignAndSubmit] Upload failed: \(error)")
            submissionResult = .failure(error)
        }
        
        isSubmitting = false
    }
}

// MARK: - Preview

#Preview("Basic Usage") {
    SignAndSubmitView(
        documentData: Data("Sample document content".utf8),
        originalFilename: "Sample.txt"
    )
}

#Preview("Auto Submit") {
    SignAndSubmitView(
        documentData: Data("Sample document content".utf8),
        originalFilename: "Contract.pdf",
        autoSubmit: true
    )
}
