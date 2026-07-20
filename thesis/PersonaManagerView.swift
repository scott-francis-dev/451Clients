//
//  PersonaManagerView.swift
//  451Wallet
//
//  Created by User451 on 4/25/25.
//

import Foundation
import SwiftUI

struct PersonaManagerView: View {
    @EnvironmentObject private var personaManager: PersonaManager
    @State private var showingCreatePersona = false
    
    @State private var pendingDeleteOffsets: IndexSet?
    @State private var showFirstDeleteAlert = false
    @State private var showSecondDeleteAlert = false
    
    @State private var selectedPersona: Persona?
    
    var body: some View {
        VStack {
            List {
                ForEach(personaManager.personas) { persona in
                    Button {
                        selectedPersona = persona
                    } label: {
                        VStack(alignment: .leading) {
                            Text(persona.name)
                                .font(.headline)
                            Text(persona.id)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .onDelete { offsets in
                    pendingDeleteOffsets = offsets
                    showFirstDeleteAlert = true
                }
            }
        }
        .navigationTitle("Personas")
        #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showingCreatePersona = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        // Single flow: server-backed PersonaCreationView
        .sheet(isPresented: $showingCreatePersona) {
            NavigationStack {
                PersonaCreationView()
            }
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

