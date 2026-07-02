//
//  PersonaHelpView.swift
//  451Wallet
//
//  Created by User451 on 4/25/25.
//

import SwiftUI

struct PersonaHelpView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("About Personas")
                        .font(.largeTitle.bold())
                    Text("Learn how to use personas to manage multiple identities")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
                
                // What are Personas?
                HelpSection(
                    icon: "person.2.fill",
                    title: "What are Personas?",
                    description: "Personas allow you to maintain separate digital identities for different contexts. Each persona has its own unique decentralized identifier (DID) and cryptographic keys."
                )
                
                // Why use multiple personas?
                HelpSection(
                    icon: "shield.fill",
                    title: "Why Use Multiple Personas?",
                    description: "Different situations call for different levels of identity disclosure. You might use one persona for professional documents, another for personal matters, and a third for anonymous signing."
                )
                
                // How they work
                HelpSection(
                    icon: "key.fill",
                    title: "How They Work",
                    description: "Each persona has its own cryptographic key pair. When you sign a document, the signature proves that your persona approved it. The persona's public key can be shared to verify signatures."
                )
                
                // Creating personas
                HelpSection(
                    icon: "plus.circle.fill",
                    title: "Creating Personas",
                    description: "Tap the + button to create a new persona. You'll provide a name and optional details like address, affiliations, and social links. These details can be shared when proving your identity."
                )
                
                // Managing personas
                HelpSection(
                    icon: "pencil",
                    title: "Managing Personas",
                    description: "Tap any persona to edit its details. You can update the name, address, affiliations, and social links at any time. Swipe left to delete personas you no longer need."
                )
                
                // Short IDs
                HelpSection(
                    icon: "number",
                    title: "Short IDs",
                    description: "Each persona has a Short ID for easy sharing. This is a shortened version of the full DID that's easier to read and communicate over phone or in person."
                )
                
                // Security
                HelpSection(
                    icon: "lock.fill",
                    title: "Security",
                    description: "Your private keys never leave your device. All signatures are created locally. When you delete a persona, the deletion is permanent and cannot be undone."
                )
                
                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .background(Color.platformGroupedBackground.ignoresSafeArea())
        .navigationTitle("Help")
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

struct HelpSection: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.platformBackground)
        )
    }
}

#Preview {
    NavigationStack {
        PersonaHelpView()
    }
}
