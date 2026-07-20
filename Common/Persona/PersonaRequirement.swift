//
//  PersonaRequirement.swift
//  Core451
//
//  Soft-gate primitive: run an action only once a persona exists. When the
//  gate is triggered and no persona is available, the app's own
//  persona-creation view is presented; the action proceeds once creation
//  succeeds. The app injects its creation view so Core451 stays UI-agnostic.
//

import SwiftUI

public extension View {
    /// Gate `onSatisfied` on the existence of a persona.
    ///
    /// Set `isActive` to `true` to request the action. If a persona already
    /// exists, `onSatisfied` runs immediately. Otherwise `createPersona` is
    /// presented as a sheet; when creation completes (signaled by the manager),
    /// `onSatisfied` runs. If the user dismisses creation without finishing,
    /// the request is cancelled.
    func requiresPersona<CreateView: View>(
        _ manager: PersonaManager,
        isActive: Binding<Bool>,
        onSatisfied: @escaping () -> Void,
        @ViewBuilder createPersona: @escaping () -> CreateView
    ) -> some View {
        modifier(
            RequiresPersonaModifier(
                manager: manager,
                isActive: isActive,
                onSatisfied: onSatisfied,
                createPersona: createPersona
            )
        )
    }
}

private struct RequiresPersonaModifier<CreateView: View>: ViewModifier {
    @ObservedObject var manager: PersonaManager
    @Binding var isActive: Bool
    let onSatisfied: () -> Void
    let createPersona: () -> CreateView

    @State private var showCreation = false

    private var hasPersona: Bool {
        manager.activePersona() != nil || !manager.personas.isEmpty
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: isActive) { active in
                guard active else { return }
                if hasPersona {
                    satisfy()
                } else {
                    showCreation = true
                }
            }
            // PersonaCreationView signals completion by setting this flag
            // instead of self-dismissing; close the injected sheet in response.
            .onChange(of: manager.dismissCreationFlow) { shouldDismiss in
                if shouldDismiss {
                    manager.dismissCreationFlow = false
                    showCreation = false
                }
            }
            .sheet(isPresented: $showCreation, onDismiss: handleCreationDismiss) {
                createPersona()
            }
    }

    /// Evaluated whenever the creation sheet closes, for any reason.
    private func handleCreationDismiss() {
        guard isActive else { return }
        if hasPersona {
            satisfy()
        } else {
            // User cancelled without creating a persona.
            isActive = false
        }
    }

    private func satisfy() {
        isActive = false
        onSatisfied()
    }
}
