import SwiftUI
import CryptoKit

// MARK: - Enhanced Document Signing with Real-Time SSE Progress Tracking

/// Example view showing how to integrate real-time server-side progress tracking
/// Uses Server-Sent Events (SSE) to stream progress updates from the Vapor backend
/// 
/// Features:
/// - Real-time progress updates via SSE streaming
/// - Automatic reconnection if connection drops
/// - Fallback to polling if SSE unavailable
/// - Detailed progress logging
/// - Production-ready error handling
struct EnhancedDocumentSigningView: View {
    typealias SigningStep = DocumentSigningService.SigningStep
    
    let documentData: Data
    let authorDID: String
    let authorPrivateKey: P256.Signing.PrivateKey
    let authorPublicKey: String
    let filename: String?
    let onComplete: ((String, String) -> Void)? // Called with (documentId, attestId)
    let onDismiss: (() -> Void)?
    
    @State private var isSubmitting = false
    @State private var currentStep: SigningStep = .preparing
    @State private var progressValue: Double = 0.0
    @State private var progressMessage: String = ""
    @State private var progressLog: [ProgressLogEntry] = []
    @State private var errorMessage: String?
    @State private var completedDocumentId: String?
    @State private var completedAttestId: String?
    @State private var sseClient: ProductionSSEClient?
    @State private var taskId: String?
    @Environment(\.dismiss) private var dismiss
    
    struct ProgressLogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let step: SigningStep
        let message: String
        let documentId: String?
        let entryId: String?
    }
    
    // Clean up on disappear
    func cleanup() {
        sseClient?.disconnect()
        sseClient = nil
    }
    
    var body: some View {
        ZStack {
            // Background blur for modal effect
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // Main content card
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Document Signing")
                            .font(.title2)
                            .bold()
                        
                        Text(filename ?? "Unknown Document")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Close button (only if complete or error)
                    if completedDocumentId != nil || errorMessage != nil {
                        Button {
                            if let docId = completedDocumentId, let attestId = completedAttestId {
                                onComplete?(docId, attestId)
                            }
                            onDismiss?()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.platformBackground)
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Document Info Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Size: \(ByteCountFormatter.string(fromByteCount: Int64(documentData.count), countStyle: .file))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Author: \(authorDID)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                // Status Badge
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(progressValue >= 1.0 ? Color.green : (errorMessage != nil ? Color.red : Color.orange))
                                        .frame(width: 8, height: 8)
                                    
                                    Text(progressValue >= 1.0 ? "Complete" : (errorMessage != nil ? "Failed" : "Processing"))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            // Show task ID when available
                            if let taskId = taskId {
                                HStack(spacing: 4) {
                                    Image(systemName: "number")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("Task ID:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(taskId)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .lineLimit(1)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .padding()
                        .background(Color.platformSecondaryBackground)
                        .cornerRadius(12)
                        
                        // Main Progress Display
                        if isSubmitting || completedDocumentId != nil || errorMessage != nil {
                            VStack(spacing: 20) {
                                // Large Progress Ring or Checkmark
                                ZStack {
                                    if progressValue >= 1.0 {
                                        // Success animation
                                        Circle()
                                            .fill(Color.green.opacity(0.1))
                                            .frame(width: 120, height: 120)
                                        
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 80))
                                            .foregroundColor(.green)
                                    } else if errorMessage != nil {
                                        // Error state
                                        Circle()
                                            .fill(Color.red.opacity(0.1))
                                            .frame(width: 120, height: 120)
                                        
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 80))
                                            .foregroundColor(.red)
                                    } else {
                                        // Active progress
                                        Circle()
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                                            .frame(width: 120, height: 120)
                                        
                                        Circle()
                                            .trim(from: 0, to: progressValue)
                                            .stroke(
                                                Color.blue,
                                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                            )
                                            .frame(width: 120, height: 120)
                                            .rotationEffect(.degrees(-90))
                                            .animation(.easeInOut(duration: 0.3), value: progressValue)
                                        
                                        Text("\(Int(progressValue * 100))%")
                                            .font(.title)
                                            .bold()
                                    }
                                }
                                .padding(.top, 20)
                                
                                // Current Step Info
                                VStack(spacing: 8) {
                                    HStack(spacing: 8) {
                                        if progressValue < 1.0 && errorMessage == nil {
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                                .scaleEffect(0.8)
                                        }
                                        
                                        Text(currentStep.rawValue)
                                            .font(.title3)
                                            .bold()
                                    }
                                    
                                    if !progressMessage.isEmpty {
                                        Text(progressMessage)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                    }
                                }
                                
                                // Linear Progress Bar
                                VStack(spacing: 8) {
                                    ProgressView(value: progressValue, total: 1.0)
                                        .progressViewStyle(.linear)
                                        .tint(progressValue >= 1.0 ? .green : .blue)
                                        .frame(height: 8)
                                    
                                    HStack {
                                        Text("Progress")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(Int(progressValue * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .bold()
                                    }
                                }
                                .padding(.horizontal)
                                
                                // Completion Details
                                if let docId = completedDocumentId, let attestId = completedAttestId {
                                    VStack(spacing: 16) {
                                        Divider()
                                        
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                Image(systemName: "checkmark.seal.fill")
                                                    .foregroundColor(.green)
                                                    .font(.title3)
                                                Text("Successfully Signed!")
                                                    .font(.headline)
                                                    .foregroundColor(.green)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 8) {
                                                HStack {
                                                    Text("Document ID:")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                    Text(docId)
                                                        .font(.caption)
                                                        .foregroundColor(.blue)
                                                        .textSelection(.enabled)
                                                }
                                                
                                                HStack {
                                                    Text("Attestation:")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                    Text(attestId)
                                                        .font(.caption)
                                                        .foregroundColor(.blue)
                                                        .textSelection(.enabled)
                                                }
                                            }
                                        }
                                        .padding()
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(12)
                                    }
                                }
                                
                                // Error Display
                                if let error = errorMessage {
                                    VStack(spacing: 12) {
                                        Divider()
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .foregroundColor(.red)
                                                Text("Signing Failed")
                                                    .font(.headline)
                                                    .foregroundColor(.red)
                                            }
                                            
                                            Text(error)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(12)
                                        
                                        Button("Dismiss") {
                                            onDismiss?()
                                            dismiss()
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.platformBackground)
                            .cornerRadius(12)
                        }
                        
                        // Detailed Progress Log (collapsible)
                        if !progressLog.isEmpty {
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(progressLog) { entry in
                                        HStack(alignment: .top, spacing: 12) {
                                            stepIcon(entry.step)
                                                .frame(width: 24)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(entry.step.rawValue)
                                                    .font(.caption)
                                                    .bold()
                                                
                                                Text(entry.message)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                
                                                if let docId = entry.documentId {
                                                    Text("📄 \(docId)")
                                                        .font(.caption2)
                                                        .foregroundColor(.blue)
                                                }
                                                
                                                if let entryId = entry.entryId {
                                                    Text("🔗 \(entryId)")
                                                        .font(.caption2)
                                                        .foregroundColor(.purple)
                                                }
                                                
                                                Text(formatTime(entry.timestamp))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding(10)
                                        .background(Color(.tertiarySystemBackground))
                                        .cornerRadius(8)
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "list.bullet.clipboard")
                                        .foregroundColor(.blue)
                                    Text("Activity Log (\(progressLog.count) events)")
                                        .font(.subheadline)
                                        .bold()
                                    Spacer()
                                }
                            }
                            .padding()
                            .background(Color.platformSecondaryBackground)
                            .cornerRadius(12)
                        }
                        
                        // Action Button at Bottom
                        if completedDocumentId != nil {
                            Button {
                                if let docId = completedDocumentId, let attestId = completedAttestId {
                                    onComplete?(docId, attestId)
                                }
                                onDismiss?()
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Done")
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        } else if errorMessage != nil {
                            Button {
                                onDismiss?()
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.left")
                                    Text("Go Back")
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color.platformGroupedBackground)
            }
            .frame(maxWidth: 600)
            .frame(maxHeight: .infinity)
            .background(Color.platformBackground)
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 20)
            .padding(.vertical, 40)
        }
        .onAppear {
            // Auto-start signing when view appears
            if !isSubmitting && completedDocumentId == nil && errorMessage == nil {
                Task {
                    await submitDocument()
                }
            }
        }
        .onDisappear {
            cleanup()
        }
    }
    
    @ViewBuilder
    private func stepIcon(_ step: SigningStep) -> some View {
        switch step {
        case .preparing:
            Image(systemName: "doc.badge.gearshape")
                .foregroundColor(.orange)
        case .uploading, .uploadingToS3:
            Image(systemName: "arrow.up.circle.fill")
                .foregroundColor(.blue)
        case .creatingProof:
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(.purple)
        case .creatingMetadata:
            Image(systemName: "info.circle.fill")
                .foregroundColor(.teal)
        case .signingDocument:
            Image(systemName: "signature")
                .foregroundColor(.indigo)
        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        @unknown default:
            Image(systemName: "questionmark.circle")
                .foregroundColor(.gray)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func submitDocument() async {
        isSubmitting = true
        errorMessage = nil
        progressLog.removeAll()
        completedDocumentId = nil
        completedAttestId = nil
        taskId = nil
        
        // Disconnect any existing SSE client
        sseClient?.disconnect()
        sseClient = nil
        
        do {
            // Step 1: Calculate document hash
            let documentHash = SHA256.hash(data: documentData)
            let hashString = documentHash.compactMap { String(format: "%02x", $0) }.joined()
            
            // Step 2: Determine file type from filename
            let fileType = filename?.components(separatedBy: ".").last ?? "bin"
            
            // Step 3: Build participants array
            let participants: [[String: String]] = [
                [
                    "did": authorDID,
                    "publicKey": authorPublicKey
                ]
            ]
            
            // Step 4: Upload with SSE progress tracking
            print("🚀 Starting document upload with real-time SSE progress")
            print("   Server: \(ServerConfiguration.current.baseURL)")
            print("   Document: \(filename ?? "unknown") (\(documentData.count) bytes)")
            print("   Hash: \(hashString)")
            print("   Author: \(authorDID)")
            
            let result = try await ProductionSSEClient.uploadDocumentWithProgress(
                baseURL: ServerConfiguration.current.baseURL,
                documentData: documentData,
                documentHash: hashString,
                fileType: fileType,
                authorDID: authorDID,
                participants: participants,
                metadata: [:],
                originalFilename: filename,
                onProgress: { progressStep in
                    Task { @MainActor in
                        // Map server step to UI step
                        let (uiStep, scaledProgress, description) = ServerProgressMapper.mapServerStep(
                            progressStep.step,
                            serverProgress: progressStep.progress
                        )
                        
                        // Use server message if available, otherwise use mapped description
                        let displayMessage = progressStep.message.isEmpty ? description : progressStep.message
                        
                        // Update UI state
                        self.currentStep = uiStep
                        self.progressValue = scaledProgress
                        self.progressMessage = displayMessage
                        
                        // Add to log
                        let timestamp: Date
                        if let timestampString = progressStep.timestamp {
                            // Parse ISO8601 timestamp string to Date
                            let formatter = ISO8601DateFormatter()
                            timestamp = formatter.date(from: timestampString) ?? Date()
                        } else {
                            timestamp = Date()
                        }
                        
                        let logEntry = ProgressLogEntry(
                            timestamp: timestamp,
                            step: uiStep,
                            message: displayMessage,
                            documentId: progressStep.documentId,
                            entryId: progressStep.entryId
                        )
                        self.progressLog.append(logEntry)
                        
                        // Console logging for debugging
                        print("📊 [\(Int(scaledProgress * 100))%] \(uiStep.rawValue)")
                        print("   Server: \(progressStep.step)")
                        print("   \(displayMessage)")
                        if let docId = progressStep.documentId {
                            print("   📄 Document ID: \(docId)")
                        }
                        if let entryId = progressStep.entryId {
                            print("   🔗 Entry ID: \(entryId)")
                        }
                    }
                },
                onComplete: { completion in
                    Task { @MainActor in
                        self.completedDocumentId = completion.documentId
                        self.completedAttestId = completion.attestId
                        self.isSubmitting = false
                        self.currentStep = .complete
                        self.progressValue = 1.0
                        self.progressMessage = "Document signed successfully!"
                        
                        print("✅ Document signing complete!")
                        if let docId = completion.documentId {
                            print("   Document ID: \(docId)")
                        }
                        if let attestId = completion.attestId {
                            print("   Attest Entry: \(attestId)")
                        }
                        if let index = completion.ledgerIndex {
                            print("   Ledger Index: \(index)")
                        }
                        
                        // Disconnect SSE client
                        self.sseClient?.disconnect()
                        self.sseClient = nil
                    }
                },
                onError: { error in
                    Task { @MainActor in
                        self.errorMessage = error.message
                        self.isSubmitting = false
                        
                        print("❌ Document signing failed: \(error.message)")
                        if let details = error.details {
                            print("   Details: \(details)")
                        }
                        
                        // Disconnect SSE client
                        self.sseClient?.disconnect()
                        self.sseClient = nil
                    }
                }
            )
            
            // Store task ID and draft ID for reference
            await MainActor.run {
                self.taskId = result.taskId
                print("📋 Task ID: \(result.taskId)")
                print("📄 Draft ID: \(result.draftId)")
                print("📄 Document ID: \(result.documentId)")
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isSubmitting = false
                
                print("❌ Document signing failed: \(error.localizedDescription)")
                
                // Disconnect SSE client
                self.sseClient?.disconnect()
                self.sseClient = nil
            }
        }
    }
}

// MARK: - Preview

#Preview("Enhanced Document Signing") {
    // Generate dummy data for preview
    let dummyData = "Sample document content for signing".data(using: .utf8)!
    let dummyKey = P256.Signing.PrivateKey()
    let dummyPublicKey = dummyKey.publicKey.rawRepresentation.base64EncodedString()
    
    return EnhancedDocumentSigningView(
        documentData: dummyData,
        authorDID: "alice@example.did",
        authorPrivateKey: dummyKey,
        authorPublicKey: dummyPublicKey,
        filename: "contract.pdf",
        onComplete: { docId, attestId in
            print("✅ Completed: \(docId)")
        },
        onDismiss: {
            print("👋 Dismissed")
        }
    )
}

// MARK: - Real-Time Progress Architecture

/**
 ## How Real-Time SSE Progress Works
 
 This implementation uses Server-Sent Events (SSE) for real-time progress updates:
 
 ### Architecture Flow:

*/

