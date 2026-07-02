//
//  PersonaManagerView.swift
//  451Wallet
//
//  Created by User451 on 4/25/25.
//

import Foundation
import SwiftUI

struct PersonaManagerView: View {
    @StateObject private var personaManager = PersonaManager()
    @State private var showingCreatePersona = false
    
    @State private var pendingDeleteOffsets: IndexSet?
    @State private var showFirstDeleteAlert = false
    @State private var showSecondDeleteAlert = false
    
    @State private var selectedPersona: Persona?
    @State private var showingHelp = false
    
    var body: some View {
        VStack (alignment: .leading, spacing: 16) {
            HStack {
                Text("My Personas (\(personaManager.personas.count))")
                    .font(.title3).bold()
                Spacer()
                Button(action: { showingHelp = true }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                Button(action: { showingCreatePersona = true }) {
                    Image(systemName: "plus")
                        .font(.title3.bold())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            // Explainer text
            VStack(alignment: .leading, spacing: 8) {
                Text("Personas allow you to maintain separate identities for different contexts.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Create multiple personas for work, personal use, or anonymous signing. Each persona has its own unique identity and can be used independently.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.08))
            )
            .padding(.horizontal, 20)
            
            List {
                ForEach(personaManager.personas) { persona in
                    Button {
                        selectedPersona = persona
                    } label: {
                        // Use the Signator Calling Card component
                        PersonaHandleDetailCard(
                            persona: persona,
                            size: .standard,
                            showDID: true,
                            showCopyButton: false
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .onDelete { offsets in
                    pendingDeleteOffsets = offsets
                    showFirstDeleteAlert = true
                }
            }
            .listStyle(.plain)
        }
        .background(Color.white.ignoresSafeArea())
        .sheet(isPresented: $showingHelp) {
            NavigationStack {
                PersonaHelpView()
            }
        }
        // Single flow: server-backed PersonaCreationView
        .sheet(isPresented: $showingCreatePersona) {
            PersonaHandleWizardView()
                .environmentObject(personaManager)
        }
        .sheet(item: $selectedPersona) { persona in
            EditPersonaView(personaManager: personaManager, persona: persona)
        }
        .alert("Are you sure you want to delete the selected persona(s)?", isPresented: $showFirstDeleteAlert) {
            Button("Cancel", role: .cancel) {
                pendingDeleteOffsets = nil
            }
            Button("Continue") {
                showSecondDeleteAlert = true
            }
        }
        .alert("This action is permanent and cannot be undone.", isPresented: $showSecondDeleteAlert) {
            Button("Cancel", role: .cancel) {
                pendingDeleteOffsets = nil
            }
            Button("Delete", role: .destructive) {
                if let offsets = pendingDeleteOffsets {
                    deletePersona(at: offsets)
                }
                pendingDeleteOffsets = nil
            }
        }
    }
    
    private func deletePersona(at offsets: IndexSet) {
        offsets.forEach { index in
            let persona = personaManager.personas[index]
            personaManager.deletePersona(persona)
        }
    }
}

