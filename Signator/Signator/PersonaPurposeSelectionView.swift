//
//  PersonaPurposeSelectionView.swift
//  451Wallet
//
//  View for selecting the primary purpose of a persona
//

import SwiftUI

enum PersonaPurpose: String, CaseIterable {
    case publishing = "publishing"
    case proof = "proof"
    case legal = "legal"
    case compliance = "compliance"
    
    var title: String {
        switch self {
        case .publishing:
            return "Persona for Publishing Content"
        case .proof:
            return "I want to prove we completed some work"
        case .legal:
            return "Attorney or Agency Persona"
        case .compliance:
            return "Auditor/Compliance Representative"
        }
    }
    
    var subtitle: String {
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
    
    var systemImage: String {
        switch self {
        case .publishing:
            return "doc.text.fill"
        case .proof:
            return "checkmark"
        case .legal:
            return "briefcase.fill"
        case .compliance:
            return "checkmark.seal.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .publishing:
            return .blue
        case .proof:
            return .cyan
        case .legal:
            return .purple
        case .compliance:
            return .green
        }
    }
    
    var detailedDescription: String {
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

struct PersonaPurposeSelectionView: View {
    let isPublicPersona: Bool
    @EnvironmentObject var personaManager: PersonaManager
    @State private var selectedPurpose: PersonaPurpose?
    @State private var navigateToIdentityMethod = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("What will you use this persona for?")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Choose the option that best describes your primary use case.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Purpose options
            VStack(spacing: 12) {
                ForEach(PersonaPurpose.allCases, id: \.self) { purpose in
                    purposeTile(for: purpose)
                }
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Persona Purpose")
        .inlineNavigationTitle()
        .navigationDestination(isPresented: $navigateToIdentityMethod) {
            if let purpose = selectedPurpose {
                CredentialSelectionView(
                    isPublicPersona: isPublicPersona,
                    personaPurpose: purpose
                )
            }
        }
    }
    
    private func purposeTile(for purpose: PersonaPurpose) -> some View {
        Button {
            selectedPurpose = purpose
            navigateToIdentityMethod = true
        } label: {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: purpose.systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(
                            colors: [purpose.color, purpose.color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: purpose.color.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(purpose.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(purpose.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.platformBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.platformGray5, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Purpose Detail View (Optional - shows more info before proceeding)

struct PersonaPurposeDetailView: View {
    let purpose: PersonaPurpose
    let isPublicPersona: Bool
    @EnvironmentObject var personaManager: PersonaManager
    @State private var navigateToIdentityMethod = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Icon and title
                HStack(spacing: 16) {
                    Image(systemName: purpose.systemImage)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 72, height: 72)
                        .background(purpose.color)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: purpose.color.opacity(0.3), radius: 12, x: 0, y: 6)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(purpose.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(purpose.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
                
                // Detailed description
                VStack(alignment: .leading, spacing: 12) {
                    Text("What this means:")
                        .font(.headline)
                    
                    Text(purpose.detailedDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(Color.platformGray6)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                // Continue button
                Button {
                    navigateToIdentityMethod = true
                } label: {
                    HStack {
                        Text("Continue with \(purpose.title)")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(purpose.color)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Persona Purpose")
        .inlineNavigationTitle()
        .navigationDestination(isPresented: $navigateToIdentityMethod) {
            CredentialSelectionView(
                isPublicPersona: isPublicPersona,
                personaPurpose: purpose
            )
        }
    }
}

#Preview("Purpose Selection") {
    NavigationStack {
        PersonaPurposeSelectionView(isPublicPersona: true)
            .environmentObject(PersonaManager())
    }
}

#Preview("Purpose Detail") {
    NavigationStack {
        PersonaPurposeDetailView(
            purpose: .publishing,
            isPublicPersona: true
        )
        .environmentObject(PersonaManager())
    }
}
