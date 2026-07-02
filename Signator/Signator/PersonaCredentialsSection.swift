//
//  PersonaCredentialsSection.swift
//  Signator
//
//  Created on 1/31/26.
//
//  Reusable section for adding optional credentials (ORCID, email) to personas
//  Integrates with PersonaCreationView
//

import SwiftUI

/// Section for optional persona credentials (ORCID and email verification)
struct PersonaCredentialsSection: View {
    @Binding var email: String
    @Binding var emailVerified: Bool
    @Binding var orcid: String
    @Binding var orcidVerified: Bool
    
    let personaDID: String
    
    @State private var showCredentialsInfo: Bool = false
    
    var body: some View {
        Section {
            VStack(spacing: 20) {
                // Email verification
                EmailVerificationField(
                    email: $email,
                    isVerified: $emailVerified,
                    onSendVerification: { email in
                        // Send verification email via your backend
                        return await EmailVerificationService.shared.sendVerification(
                            to: email,
                            for: personaDID
                        )
                    }
                )
                
                // ORCID input
                OrcidInputField(
                    orcid: $orcid,
                    isVerified: $orcidVerified,
                    onVerify: { orcid in
                        // Verify ORCID with ORCID API
                        return await OrcidVerificationService.shared.verify(orcid)
                    }
                )
            }
        } header: {
            HStack(spacing: 4) {
                Text("Optional Credentials")
                Button {
                    showCredentialsInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        } footer: {
            Text("Adding verified credentials increases trust in your persona. Both are optional and can be added later.")
                .font(.footnote)
        }
        .sheet(isPresented: $showCredentialsInfo) {
            CredentialsInfoSheet()
        }
    }
}

/// Information sheet explaining credentials
struct CredentialsInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Email section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "envelope.badge.shield.half.filled")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text("Email Verification")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Text("Adding a verified email address:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Increases credibility of your persona", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Label("Enables account recovery options", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Label("Allows others to contact you securely", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        .font(.subheadline)
                        
                        Text("Verification Process:")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        Text("1. Enter your email address\n2. Click 'Send Verification Email'\n3. Check your inbox for verification link\n4. Click the link to verify\n\nYou can create your persona before verification completes.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // ORCID section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "graduationcap.circle.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                            Text("ORCID Identifier")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Text("What is ORCID?")
                            .font(.headline)
                        
                        Text("ORCID (Open Researcher and Contributor ID) is a unique identifier for researchers and academics. It connects you to your research outputs and activities.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Who should add ORCID?")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Academic researchers", systemImage: "person.fill")
                            Label("Scientists and scholars", systemImage: "person.fill")
                            Label("Grant recipients", systemImage: "person.fill")
                            Label("Anyone with published research", systemImage: "person.fill")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        
                        Text("Most users don't need an ORCID. Only add one if you have an existing ORCID identifier from your research institution.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        
                        Text("Format: 0000-0002-1825-0097")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    
                    Divider()
                    
                    // Privacy note
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.purple)
                            Text("Privacy & Control")
                                .font(.headline)
                        }
                        
                        Text("You control what information is visible in your persona. Email and ORCID are optional and can be kept private or shared selectively based on your needs.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Optional Credentials")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Credentials Section") {
    Form {
        PersonaCredentialsSection(
            email: .constant(""),
            emailVerified: .constant(false),
            orcid: .constant(""),
            orcidVerified: .constant(false),
            personaDID: "did:451:a4a360afd06844da8d939131f3dd2631"
        )
    }
}

#Preview("With Data") {
    Form {
        PersonaCredentialsSection(
            email: .constant("jane.wu@wisc.edu"),
            emailVerified: .constant(true),
            orcid: .constant("0000-0002-1825-0097"),
            orcidVerified: .constant(true),
            personaDID: "did:451:a4a360afd06844da8d939131f3dd2631"
        )
    }
}

#Preview("Info Sheet") {
    CredentialsInfoSheet()
}
