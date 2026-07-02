import Foundation

// MARK: - Escrow Provider

enum EscrowProvider: String, Codable, CaseIterable {
    case dwolla = "dwolla"
    case stripe = "stripe"
    case escrowCom = "escrow.com"

    var displayName: String {
        switch self {
        case .dwolla: return "Dwolla"
        case .stripe: return "Stripe"
        case .escrowCom: return "Escrow.com"
        }
    }
}

// MARK: - Release Condition

enum ReleaseConditionType: String, Codable {
    case oneParty = "one_party"
    case allParties = "all_parties"
    case auditor
}

struct ReleaseCondition: Codable {
    let type: ReleaseConditionType
    let signerRole: String?     // "owner" | "contractor" — for one_party
    let auditorDid: String?     // for auditor
    let auditorName: String?

    var displayText: String {
        switch type {
        case .oneParty:
            return "Released by \(signerRole ?? "one party")"
        case .allParties:
            return "All parties must sign"
        case .auditor:
            return "Auditor: \(auditorName ?? auditorDid ?? "unknown")"
        }
    }
}

// MARK: - Milestone Signature

struct MilestoneSignature: Codable, Identifiable {
    let signerDid: String
    var signerRole: String
    var signerName: String
    var required: Bool
    var signedAt: String?
    var signature: String?

    var id: String { signerDid }
    var isSigned: Bool { signedAt != nil }

    enum CodingKeys: String, CodingKey {
        case signerDid, signerRole, signerName, required, signedAt, signature
    }
}

// MARK: - Milestone Escrow

struct MilestoneEscrow: Codable {
    let provider: EscrowProvider
    var amount: Double
    var externalId: String?
    var fundedAt: String?
    var releasedAt: String?

    var isFunded: Bool { fundedAt != nil }
    var isReleased: Bool { releasedAt != nil }
}

// MARK: - Milestone Status

enum MilestoneStatus: String, Codable {
    case pending, active, signed, released, disputed

    var displayName: String { rawValue.capitalized }

    var color: String {
        switch self {
        case .pending:  return "gray"
        case .active:   return "blue"
        case .signed:   return "yellow"
        case .released: return "green"
        case .disputed: return "red"
        }
    }
}

// MARK: - Milestone

struct Milestone: Codable, Identifiable {
    let id: String
    var order: Int
    var title: String
    var description: String
    var deliverables: [String]
    var amount: Double
    var escrow: MilestoneEscrow?
    var releaseCondition: ReleaseCondition
    var signatures: [MilestoneSignature]
    var status: MilestoneStatus
    var createdAt: String
    var completedAt: String?
}

// MARK: - MilestoneSchedule

struct MilestoneSchedule: Codable {
    var version: String
    var escrowProvider: EscrowProvider?
    var milestones: [Milestone]

    var totalAmount: Double {
        milestones.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - API Responses

struct MilestoneScheduleResponse: Codable {
    let schedule: MilestoneSchedule?
}

struct MilestoneActionResponse: Codable {
    let success: Bool
    let milestoneStatus: String?
    let escrowReleased: Bool?
    let error: String?
}
