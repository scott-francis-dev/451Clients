//
//  SignatorSignInInitiatorView.swift
//  Signator
//
//  "Sign in with Signator" Quick Action.
//  Lets users proactively initiate a sign-in to any service from within Signator —
//  either by entering a challenge code + service URL shown on the service's login page,
//  or by having the service scan/share a QR code that the user pastes here.
//
//  The primary path is via deep link (QR code scan opens ServiceSignInView directly),
//  but this view covers the case where the user is already in Signator and wants to connect.
//

import SwiftUI

@MainActor
struct SignatorSignInInitiatorView: View {

    @EnvironmentObject private var personaManager: PersonaManager
    @Environment(\.dismiss) private var dismiss

    @State private var challengeCode = ""
    @State private var showSignInFlow = false
    @State private var errorMessage: String? = nil

    // Derived: strip whitespace and uppercase the code
    private var normalizedCode: String {
        challengeCode.trimmingCharacters(in: .whitespaces).uppercased()
    }

    private var canProceed: Bool {
        normalizedCode.count == 6
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // MARK: Header
                    VStack(spacing: 10) {
                        Image(systemName: "person.badge.shield.checkmark.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.blue)
                        Text("Sign in with Signator")
                            .font(.title2).fontWeight(.bold)
                        Text("Use your Persona to authenticate with any Signator-enabled service.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 24)

                    // MARK: How it works callout
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("How to use")
                                .font(.subheadline).fontWeight(.semibold)
                            Text("On the service's login page, tap **Sign in with Signator** to see a QR code and a 6-character code. Scan the QR code with your camera — Signator opens automatically — or enter the 6-character code below.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color.blue.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal)

                    // MARK: Input fields
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Challenge Code")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        TextField("e.g. AB3X9Y", text: $challengeCode)
                            .platformAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .background(Color.platformGray6)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .onChange(of: challengeCode) { _, newValue in
                                if newValue.count > 6 {
                                    challengeCode = String(newValue.prefix(6))
                                }
                            }
                    }
                    .padding(.horizontal)

                    // MARK: Error
                    if let err = errorMessage {
                        Text(err)
                            .font(.caption).foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // MARK: Proceed button
                    Button {
                        attemptSignIn()
                    } label: {
                        Text("Proceed to Sign In")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canProceed ? Color.blue : Color.gray.opacity(0.4))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(!canProceed)
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Sign in with Signator")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            // Present ServiceSignInView as a sheet once we have a valid code + URL
            .sheet(isPresented: $showSignInFlow) {
                ServiceSignInView(
                    challenge: normalizedCode,
                    service: serviceName(from: serviceURL),
                    serviceURL: serviceURL
                )
                .environmentObject(personaManager)
            }
        }
    }

    // MARK: - Helpers

    private func attemptSignIn() {
        errorMessage = nil
        guard canProceed else { return }
        showSignInFlow = true
    }

    private var serviceURL: String { ServerConfig.baseURL }

    private func serviceName(from url: String) -> String {
        guard let host = URL(string: url)?.host else { return "service" }
        return host.components(separatedBy: ".").first ?? "service"
    }
}

// MARK: - Preview

#Preview {
    SignatorSignInInitiatorView()
        .environmentObject(PersonaManager())
}
