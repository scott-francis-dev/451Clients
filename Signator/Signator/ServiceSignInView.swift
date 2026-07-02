//
//  ServiceSignInView.swift
//  451Wallet
//
//  Handles the QR-code / 6-digit challenge-response sign-in flow.
//  Presented when the app opens a signator://auth?... deep link.
//

import SwiftUI
import CryptoKit

@MainActor
struct ServiceSignInView: View {
    let challenge: String
    let service: String
    let serviceURL: String

    @EnvironmentObject private var personaManager: PersonaManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPersona: Persona? = nil
    @State private var isSigning = false
    @State private var signInResult: SignInResult? = nil
    @State private var errorMessage: String? = nil

    enum SignInResult {
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: Service header
                    VStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.blue)
                        Text("Sign in to \(service.capitalized)")
                            .font(.title2).fontWeight(.bold)
                        Text(serviceURL)
                            .font(.caption).foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.top, 24)

                    // MARK: Challenge code
                    VStack(spacing: 4) {
                        Text("Code")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        Text(formattedChallenge)
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .tracking(6)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(Color.platformGray6)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)

                    // MARK: Persona picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sign in as")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal)

                        if personaManager.personas.isEmpty {
                            Text("No personas found. Create one in Signator first.")
                                .font(.subheadline).foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            ForEach(personaManager.personas) { persona in
                                Button {
                                    selectedPersona = persona
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(persona.name.isEmpty ? persona.handle : persona.name)
                                                .font(.subheadline).fontWeight(.medium)
                                                .foregroundColor(.primary)
                                            Text(persona.handle)
                                                .font(.caption).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if selectedPersona?.id == persona.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(14)
                                    .background(
                                        selectedPersona?.id == persona.id
                                            ? Color.blue.opacity(0.08)
                                            : Color.platformGray6
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(
                                                selectedPersona?.id == persona.id
                                                    ? Color.blue.opacity(0.3)
                                                    : Color.clear,
                                                lineWidth: 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }

                    // MARK: Result / action area
                    if let result = signInResult {
                        switch result {
                        case .success:
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.green)
                                Text("Signed in successfully")
                                    .font(.headline)
                                Text("Return to \(service.capitalized) in your browser.")
                                    .font(.subheadline).foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.bottom, 24)

                        case .failure(let msg):
                            VStack(spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.red)
                                Text(msg)
                                    .font(.subheadline).foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                Button("Try Again") { signInResult = nil }
                                    .buttonStyle(.bordered)
                            }
                            .padding(.bottom, 24)
                        }
                    } else {
                        VStack(spacing: 12) {
                            if let err = errorMessage {
                                Text(err)
                                    .font(.caption).foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }

                            Button {
                                Task { await performSignIn() }
                            } label: {
                                HStack {
                                    if isSigning {
                                        ProgressView().tint(.white)
                                    }
                                    Text(isSigning ? "Signing..." : "Confirm Sign In")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    selectedPersona != nil && !isSigning
                                        ? Color.blue
                                        : Color.gray.opacity(0.4)
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .disabled(selectedPersona == nil || isSigning)
                            .padding(.horizontal)

                            Button("Cancel") { dismiss() }
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Service Sign-In")
            .inlineNavigationTitle()
            .onAppear {
                // Default to active persona, fall back to first
                selectedPersona = personaManager.activePersona() ?? personaManager.personas.first
            }
        }
    }

    // MARK: - Helpers

    private var formattedChallenge: String {
        guard challenge.count == 6 else { return challenge }
        return "\(challenge.prefix(3)) \(challenge.suffix(3))"
    }

    // MARK: - Sign-in logic

    private func performSignIn() async {
        guard let persona = selectedPersona else { return }
        isSigning = true
        errorMessage = nil
        defer { isSigning = false }

        let challengeString = "signator-auth:\(challenge)"
        guard let challengeData = challengeString.data(using: .utf8) else {
            errorMessage = "Failed to encode challenge."
            return
        }

        do {
            // Sign using the unified key store (Secure Enclave first, regular key fallback)
            let signature = try SecureEnclaveKeyStore.sign(challengeData, for: persona.id)
            let signatureBase64 = signature.derRepresentation.base64EncodedString()

            // POST to the service
            guard let url = URL(string: "\(serviceURL)/api/auth/verify") else {
                errorMessage = "Invalid service URL."
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: String] = [
                "code": challenge,
                "signature": signatureBase64,
                "did": persona.id,
                "personaHandle": persona.handle,
                "publicKeyBase64": persona.publicKeyBase64,
                "name": persona.name,
            ]
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse

            // Try decoding success flag
            if let json = try? JSONDecoder().decode([String: Bool].self, from: data),
               json["success"] == true,
               http?.statusCode == 200 {
                signInResult = .success
            } else {
                let errJson = try? JSONDecoder().decode([String: String].self, from: data)
                let msg = errJson?["error"] ?? "Sign-in failed (HTTP \(http?.statusCode ?? 0))."
                signInResult = .failure(msg)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    ServiceSignInView(
        challenge: "482915",
        service: "medai",
        serviceURL: "https://medai.451.info"
    )
    .environmentObject(PersonaManager())
}
