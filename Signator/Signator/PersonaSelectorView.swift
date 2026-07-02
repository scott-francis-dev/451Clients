//
//  PersonaSelectorView.swift
//  451Wallet
//
//  Created by User451 on 4/25/25.
//


import SwiftUI

struct PersonaSelectorView: View {
    @ObservedObject var personaManager: PersonaManager
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List {
                ForEach(personaManager.personas) { persona in
                    Button(action: {
                        personaManager.setActivePersona(persona)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(persona.name).font(.headline)
                                Text(persona.id).font(.caption).foregroundColor(.gray)
                            }
                            Spacer()
                            if personaManager.activePersonaId == persona.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Persona")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
