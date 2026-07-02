import Foundation

/// A signer selected for a multi-party document signing workflow.
/// Pairs a DID with the role that person will play in the document.
public struct SignerSelection: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let did: String
    public var role: DocumentSigningService.SignerRole

    public init(did: String, role: DocumentSigningService.SignerRole) {
        self.did = did
        self.role = role
    }
}
