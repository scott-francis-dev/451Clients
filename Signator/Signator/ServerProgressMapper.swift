import Foundation

/// Maps server-side progress steps to client-side signing workflow steps
/// This bridges the gap between backend operations and UI presentation
@available(iOS 13.0, macOS 10.15, *)
public struct ServerProgressMapper {
    
    /// Maps server step names to UI steps with progress scaling
    public static func mapServerStep(_ serverStep: String, serverProgress: Double) -> (step: DocumentSigningService.SigningStep, progress: Double, description: String) {
        
        switch serverStep {
        // Early preparation (0% - 10%)
        case "extracting_metadata":
            return (
                .preparing,
                scaleProgress(serverProgress, from: 0.0...0.1, to: 0.0...0.1),
                "Analyzing document properties and metadata"
            )
            
        case "metadata_identified":
            return (
                .creatingMetadata,
                scaleProgress(serverProgress, from: 0.1...0.2, to: 0.1...0.15),
                "Document type and properties identified"
            )
            
        // S3 Upload phase (15% - 50%)
        case "s3_upload_backblaze":
            return (
                .uploadingToS3,
                scaleProgress(serverProgress, from: 0.2...0.35, to: 0.15...0.30),
                "Uploading to Backblaze B2 storage"
            )
            
        case "s3_upload_minio":
            return (
                .uploadingToS3,
                scaleProgress(serverProgress, from: 0.35...0.45, to: 0.30...0.45),
                "Uploading to Minio storage"
            )
            
        case "s3_upload_complete":
            return (
                .uploadingToS3,
                scaleProgress(serverProgress, from: 0.45...0.6, to: 0.45...0.50),
                "Cloud storage upload complete"
            )
            
        // Hash and signature (50% - 65%)
        case "hash_computed":
            return (
                .signingDocument,
                scaleProgress(serverProgress, from: 0.6...0.65, to: 0.50...0.55),
                "Computing SHA-256 document hash"
            )
            
        case "signature_saved":
            return (
                .creatingSignEntry,
                scaleProgress(serverProgress, from: 0.65...0.7, to: 0.55...0.65),
                "Creating and saving signature file"
            )
            
        // Blockchain operations (65% - 90%)
        case "creating_proof_entry":
            return (
                .creatingProof,
                scaleProgress(serverProgress, from: 0.7...0.75, to: 0.65...0.75),
                "Building PROOF entry for ledger"
            )
            
        case "signing_proof_entry":
            return (
                .creatingProof,
                scaleProgress(serverProgress, from: 0.75...0.85, to: 0.75...0.80),
                "Cryptographically signing blockchain entry"
            )
            
        case "storing_blockchain_entry":
            return (
                .creatingProof,
                scaleProgress(serverProgress, from: 0.85...0.95, to: 0.80...0.90),
                "Writing entry to distributed ledger"
            )
            
        // Finalization (90% - 100%)
        case "finalizing":
            return (
                .signingDocument,
                scaleProgress(serverProgress, from: 0.95...1.0, to: 0.90...0.95),
                "Completing document registration"
            )
            
        case "indexing_complete":
            return (
                .complete,
                scaleProgress(serverProgress, from: 0.95...1.0, to: 0.95...1.0),
                "Adding document to search index"
            )
            
        // Fallback - use generic mapping based on server progress
        default:
            let (step, progress) = mapProgressToStep(serverProgress)
            return (step, progress, "Processing document")
        }
    }
    
    /// Fallback mapping based purely on progress percentage
    private static func mapProgressToStep(_ progress: Double) -> (step: DocumentSigningService.SigningStep, progress: Double) {
        switch progress {
        case 0.0..<0.15:
            return (.preparing, progress)
        case 0.15..<0.50:
            return (.uploadingToS3, progress)
        case 0.50..<0.65:
            return (.signingDocument, progress)
        case 0.65..<0.75:
            return (.creatingProof, progress)
        case 0.75..<0.90:
            return (.creatingProof, progress)
        case 0.90..<1.0:
            return (.signingDocument, progress)
        default:
            return (.complete, 1.0)
        }
    }
    
    /// Scales progress from one range to another
    /// Example: scaleProgress(0.25, from: 0.2...0.4, to: 0.0...1.0) = 0.25
    private static func scaleProgress(_ value: Double, from sourceRange: ClosedRange<Double>, to targetRange: ClosedRange<Double>) -> Double {
        let sourceSpan = sourceRange.upperBound - sourceRange.lowerBound
        let targetSpan = targetRange.upperBound - targetRange.lowerBound
        
        guard sourceSpan > 0 else { return targetRange.lowerBound }
        
        let normalizedValue = (value - sourceRange.lowerBound) / sourceSpan
        let clampedValue = min(max(normalizedValue, 0.0), 1.0)
        
        return targetRange.lowerBound + (clampedValue * targetSpan)
    }
}

// MARK: - Supporting Types

/// Progress step from server
public struct ProgressStep: Codable {
    public let step: String
    public let message: String
    public let progress: Double  // 0.0 to 1.0
    public let timestamp: String?  // ISO8601 string from server
    public let documentId: String?
    public let entryId: String?
    public let details: [String: String]?  // Provider info, indices, etc.
    
    // Computed property to convert timestamp string to Date
    public var timestampDate: Date? {
        guard let timestamp = timestamp else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: timestamp)
    }
    
    public init(step: String, message: String, progress: Double, timestamp: String? = nil, documentId: String? = nil, entryId: String? = nil, details: [String: String]? = nil) {
        self.step = step
        self.message = message
        self.progress = progress
        self.timestamp = timestamp
        self.documentId = documentId
        self.entryId = entryId
        self.details = details
    }
}

/// Completion event from server
public struct CompletionEvent: Codable {
    public let documentId: String?
    public let attestId: String?
    public let ledgerIndex: Int?
    public let success: Bool
    public let message: String?
    
    public init(documentId: String?, attestId: String?, ledgerIndex: Int? = nil, success: Bool, message: String?) {
        self.documentId = documentId
        self.attestId = attestId
        self.ledgerIndex = ledgerIndex
        self.success = success
        self.message = message
    }
}

/// Error event from server
public struct ErrorEvent: Codable {
    public let code: String
    public let message: String
    public let details: String?
    
    public init(code: String, message: String, details: String? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }
}

