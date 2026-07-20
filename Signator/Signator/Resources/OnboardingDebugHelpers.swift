//
//  OnboardingDebugHelpers.swift
//  Signator
//
//  Debug utilities for testing onboarding flow
//  Only include in DEBUG builds
//

#if DEBUG
import SwiftUI

/// Debug view to reset onboarding state for testing
struct OnboardingDebugView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Onboarding Status")
                        Spacer()
                        Text(hasCompletedOnboarding ? "Completed" : "Not Completed")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Current State")
                }
                
                Section {
                    Button("Reset Onboarding") {
                        hasCompletedOnboarding = false
                    }
                    .foregroundColor(.red)
                    
                    Button("Mark as Completed") {
                        hasCompletedOnboarding = true
                    }
                    .foregroundColor(.blue)
                } header: {
                    Text("Actions")
                } footer: {
                    Text("Reset onboarding to see the walkthrough screens again. You'll need to restart the app for changes to take effect.")
                        .font(.caption)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Testing Tips")
                            .font(.headline)
                        
                        Text("• Reset onboarding to test first-run experience")
                        Text("• After reset, kill and relaunch the app")
                        Text("• Use Xcode launch arguments: -hasCompletedOnboarding NO")
                        Text("• Check that videos are in the bundle")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                } header: {
                    Text("Help")
                }
            }
            .navigationTitle("Onboarding Debug")
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

/// Extension to add debug button to Settings (if you have a settings view)
extension View {
    func withOnboardingDebugButton() -> some View {
        self.toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // Present OnboardingDebugView
                } label: {
                    Image(systemName: "ladybug")
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingDebugView()
}

#endif
