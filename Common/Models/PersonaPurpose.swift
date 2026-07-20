import Foundation

public enum PersonaPurpose: String, CaseIterable, Codable, Sendable {
    case publishing = "publishing"
    case proof = "proof"
    case legal = "legal"
    case compliance = "compliance"

    public var title: String {
        switch self {
        case .publishing: return "Persona for Publishing Content"
        case .proof:      return "I want to prove we completed some work"
        case .legal:      return "Attorney or Agency Persona"
        case .compliance: return "Auditor/Compliance Representative"
        }
    }

    public var subtitle: String {
        switch self {
        case .publishing:
            return "A persona for creating content (academic, articles, books), sign documents, and establish your digital identity"
        case .proof:
            return "We have completed some work, or an obligation, and I will use this persona to document completion"
        case .legal:
            return "I am creating documents for others.  Represent clients, execute legal documents, and maintain professional credentials"
        case .compliance:
            return "Audit transactions, verify compliance, and provide oversight"
        }
    }

    public var systemImage: String {
        switch self {
        case .publishing: return "doc.text.fill"
        case .proof:      return "checkmark"
        case .legal:      return "briefcase.fill"
        case .compliance: return "checkmark.seal.fill"
        }
    }

    public var detailedDescription: String {
        switch self {
        case .publishing:
            return """
            Perfect for authors, content creators, and individuals who want to:
            • Sign and publish documents
            • Establish verifiable authorship
            • Build a trusted digital identity
            • Collaborate with others on documents
            """
        case .proof:
            return """
            Designed for jobsite crews, forepeople who need to:
            • Proof work completed
            • Demostrate milestone completion
            • Show that materials have been delivered
            """
        case .legal:
            return """
            Designed for attorneys, legal professionals, and agencies who need to:
            • Execute legal documents on behalf of clients
            • Maintain professional credentials and licensure
            • Represent multiple parties in transactions
            • Ensure compliance with legal requirements
            """
        case .compliance:
            return """
            Built for auditors, compliance officers, and oversight professionals who:
            • Verify and audit document chains
            • Ensure regulatory compliance
            • Provide independent verification
            • Maintain audit trails and records
            """
        }
    }
}
