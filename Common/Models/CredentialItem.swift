//
//  CredentialItem.swift
//  451Wallet
//
//  Domain model for persona credentials.
//  Each credential type carries its own metadata; status tracks where
//  in the verification pipeline it sits.
//

import Foundation
import SwiftUI

// MARK: - Credential Status

/// Lifecycle of a single credential on the device.
enum CredentialStatus: String, Codable, Equatable, CaseIterable {
    /// User has not yet started verification.
    case notStarted
    /// Verification is in-flight (email sent, OAuth browser open, etc.).
    case pending
    /// The credential has been cryptographically confirmed.
    case verified
    /// Verification was attempted but failed or was rejected.
    case unverified
    /// The credential was once valid but has since expired.
    case expired
}

// MARK: - Credential Kind

/// The set of credential types the app currently understands.
/// New credential kinds can be added here; `CredentialSelectionView`
/// uses `relevantCredentials(for:)` to decide which ones to surface
/// for a given `PersonaPurpose`.
enum CredentialKind: String, Codable, Equatable, CaseIterable {
    // --- Publishing / Academic ---
    case emailVerification   // Institutional or personal e-mail ownership
    case orcid               // ORCID iD (OAuth-verified)

    // --- Legal ---
    case barLicense          // State bar admission (Verified Credential)

    // --- Compliance / Auditing ---
    case bondingInsurance    // Professional bond / E&O insurance status

    // MARK: - Display helpers

    var title: String {
        switch self {
        case .emailVerification: return "Email Verification"
        case .orcid:             return "ORCID iD"
        case .barLicense:        return "Bar License"
        case .bondingInsurance:  return "Bonding / Insurance"
        }
    }

    var subtitle: String {
        switch self {
        case .emailVerification:
            return "Prove ownership of an institutional or personal email address"
        case .orcid:
            return "Link and verify your ORCID iD via the official OAuth flow"
        case .barLicense:
            return "Associate a state bar admission record with this persona"
        case .bondingInsurance:
            return "Attach your professional bond or errors-&-omissions policy"
        }
    }

    var systemImage: String {
        switch self {
        case .emailVerification: return "envelope.fill"
        case .orcid:             return "person.badge.star.fill"
        case .barLicense:        return "building.columns.fill"
        case .bondingInsurance:  return "shield.fill"
        }
    }

    var color: Color {
        switch self {
        case .emailVerification: return .blue
        case .orcid:             return .teal
        case .barLicense:        return .indigo
        case .bondingInsurance:  return .orange
        }
    }

    /// Which purposes expose this credential kind.
    var applicablePurposes: [PersonaPurpose] {
        switch self {
        case .emailVerification: return [.publishing, .legal, .compliance]
        case .orcid:             return [.publishing]
        case .barLicense:        return [.legal]
        case .bondingInsurance:  return [.compliance]
        }
    }
}

// MARK: - CredentialItem

/// A single credential attached (or to-be-attached) to a persona.
/// This is the unit that travels through the creation flow and is
/// eventually persisted alongside the `Persona`.
struct CredentialItem: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: CredentialKind
    var status: CredentialStatus

    // --- Kind-specific payload fields (all optional; only the relevant
    //     ones are populated for a given kind) ---

    /// The email address being verified (emailVerification)
    var email: String?
    /// The nonce token embedded in the verification URL (emailVerification)
    var nonce: String?
    /// The ORCID iD string, e.g. "0000-0002-1825-0097" (orcid)
    var orcidID: String?
    /// The state abbreviation for bar lookup, e.g. "CA" (barLicense)
    var barState: String?
    /// The bar number entered by the user (barLicense)
    var barNumber: String?
    /// A Verified-Credential JWT issued by a bar-verification authority (barLicense)
    var barCredentialJWT: String?
    /// The policy / certificate number (bondingInsurance)
    var policyNumber: String?
    /// The issuing authority name (bondingInsurance)
    var issuerName: String?
    /// A Verified-Credential JWT for bonding/insurance (bondingInsurance)
    var bondingCredentialJWT: String?

    // MARK: - Convenience initializers

    init(kind: CredentialKind, status: CredentialStatus = .notStarted) {
        self.id = UUID()
        self.kind = kind
        self.status = status
    }
}

// MARK: - Purpose → Credential mapping

extension CredentialKind {
    /// Returns the credential kinds that are relevant for a given purpose,
    /// in display order.
    static func relevantCredentials(for purpose: PersonaPurpose) -> [CredentialKind] {
        allCases.filter { $0.applicablePurposes.contains(purpose) }
    }
}
