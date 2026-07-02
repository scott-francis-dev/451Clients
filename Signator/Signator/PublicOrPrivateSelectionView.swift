//
//  PublicOrPrivateSelectionView.swift
//  451Wallet
//
//  View for selecting whether a persona should be public or private
//

import SwiftUI

struct PublicOrPrivateSelectionView: View {
    @ObservedObject var personaManager: PersonaManager
    @State private var selectedIsPublic: Bool?
    @State private var navigateToPurpose = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Will this persona be public or private?")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("This determines how others can discover and interact with your persona.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Public option
            Button {
                selectedIsPublic = true
                navigateToPurpose = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "globe")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Public Persona")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Discoverable by others, listed in directories, and verifiable by anyone.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .background(Color.platformBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.platformGray4, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Private option
            Button {
                selectedIsPublic = false
                navigateToPurpose = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Private Persona")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Not listed publicly. Share your identity only with specific people via codes.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .background(Color.platformBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.platformGray4, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Info footer
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("You can change this later in persona settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.bottom, 16)
        }
        .padding()
        .navigationTitle("Persona Visibility")
        .inlineNavigationTitle()
        .navigationDestination(isPresented: $navigateToPurpose) {
            if let isPublic = selectedIsPublic {
                PersonaPurposeSelectionView(isPublicPersona: isPublic)
                    .environmentObject(personaManager)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PublicOrPrivateSelectionView(personaManager: PersonaManager())
    }
}
