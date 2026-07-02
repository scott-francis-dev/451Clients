//
//  WelcomeOnboardingView.swift
//  Signator
//
//  Welcome screen that provides two onboarding paths:
//  1. Quick one-time document signing (temporary persona)
//  2. Full persona creation for long-term use
//

import SwiftUI

struct WelcomeOnboardingView: View {
    @ObservedObject var personaManager: PersonaManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showQuickSignFlow = false
    @State private var showFullPersonaCreation = false
    @State private var showAcceptProposal = false
    @State private var navigateToMainFlow = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // App icon and title
            VStack(spacing: 16) {
                Image(systemName: "signature")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Welcome to Signator")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your secure digital signature platform")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Two-path selection
            VStack(spacing: 20) {
                // Primary: One-time signing
                Button {
                    showQuickSignFlow = true
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("I am here for a one-time document(s) signing")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                
                                Text("Quick setup for signing right now")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                
                // Secondary: Long-term persona
                Button {
                    showFullPersonaCreation = true
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.title2)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("I want to create long-term persona(s)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                
                                Text("Full setup with verified identity")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(Color.platformSecondaryGroupedBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Discreet link: accept a proposed persona token
                Button {
                    showAcceptProposal = true
                } label: {
                    Text("I have a persona token to accept")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .underline()
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Footer info
            VStack(spacing: 8) {
                Text("Both options are secure and private")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("You can always create additional personas later")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showQuickSignFlow) {
            NavigationStack {
                PersonaCreationView(
                    personaManager: personaManager,
                    onCreate: { _ in
                        showQuickSignFlow = false
                        dismiss()
                    },
                    initialIsPublicPersona: false,
                    initialUseCustomDomain: false,
                    lockVisibilityChoice: true,
                    lockIdentityMethod: true
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showQuickSignFlow = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showFullPersonaCreation) {
            NavigationStack {
                PublicOrPrivateSelectionView(personaManager: personaManager)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showFullPersonaCreation = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showAcceptProposal) {
            NavigationStack {
                ProposedPersonaEntryView()
                    .environmentObject(personaManager)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showAcceptProposal = false
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    WelcomeOnboardingView(personaManager: PersonaManager())
}
