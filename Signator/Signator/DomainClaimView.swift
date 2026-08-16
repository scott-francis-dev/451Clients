// DomainClaimView.swift
// Signator
//
// Proves that an existing persona controls an internet domain, via a signed
// nonce published as a DNS TXT record.
//
// This runs *after* the persona is created, and it has to: the server issues the
// nonce against the persona's on-chain public key, so there is nothing to sign
// with — and no key for the server to check against — until the creation block
// exists. The pre-creation wizard therefore only collects the domain; proof
// happens here.
//
// Flow: claim (server issues nonce) → sign nonce with the persona key →
//       user publishes the signature as TXT → verify (server reads it back).

import SwiftUI
import CryptoKit

// MARK: - Wire Types

/// Mirrors the server's `DomainClaimStartRequest` / `DomainClaimStartResponse`.
private struct DomainClaimStartRequest: Encodable {
    let personaDID: String
    let domain: String
}

private struct DomainClaimStartResponse: Decodable {
    let claimId: String
    let nonce: String
    let recordName: String
    let recordType: String
    let instructions: String
    let expiresAt: String
}

private struct DomainClaimVerifyRequest: Encodable {
    let claimId: String
}

private struct DomainClaimVerifyResponse: Decodable {
    let status: String
    let domain: String
    let personaDID: String
    let blockRef: String
    let resolvers: [String]
}

/// Both Vapor's `ErrorMiddleware` and this server's `APIErrorMiddleware` emit
/// `reason`, so one shape covers every failure the routes can produce.
private struct ServerError: Decodable {
    let reason: String
}

// MARK: - View

struct DomainClaimView: View {
    /// The persona doing the claiming. Must already exist on-chain — the server
    /// reads its public key from the creation block.
    let persona: Persona
    /// Prefilled from the creation wizard when it collected one.
    var initialDomain: String = ""
    /// Called once the domain is verified, so a caller mid-flow can move on.
    var onVerified: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var domainInput: String = ""
    @State private var phase: Phase = .collecting
    @State private var claim: DomainClaimStartResponse?
    /// The DER signature over the nonce, base64 — this is the TXT record's value.
    @State private var recordValue: String = ""
    @State private var errorMessage: String?
    @State private var copied: String?

    private enum Phase: Equatable {
        case collecting     // entering the domain
        case claiming       // POST /domain/claim in flight
        case awaitingRecord // record shown; waiting for the user to publish it
        case verifying      // POST /domain/verify in flight
        case verified
    }

    private var domain: String {
        domainInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var domainLooksValid: Bool {
        domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
            && !domain.contains("@") && !domain.contains(" ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if phase == .collecting || phase == .claiming {
                    domainField
                    startButton
                }

                if let claim, phase != .collecting, phase != .claiming {
                    recordInstructions(for: claim)
                }

                if phase == .verified {
                    verifiedBanner
                } else if let errorMessage {
                    Label(errorMessage, systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
        }
        .navigationTitle("Verify Domain")
        .inlineNavigationTitle()
        .onAppear {
            if domainInput.isEmpty { domainInput = initialDomain }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Prove you own this domain.")
                .font(.title2).fontWeight(.bold)
            Text("You'll publish a DNS record signed by \(persona.name). Only someone holding this persona's key can produce it.")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }

    private var domainField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Domain")
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(.secondary).textCase(.uppercase)

            TextField("e.g. mycompany.com", text: $domainInput)
                .textFieldStyle(.plain)
                .font(.title3)
                .padding()
                .background(Color.platformGray6)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .autocorrectionDisabled()
                .platformAutocapitalization(.never)
                .platformKeyboardType(.url)
                .disabled(phase == .claiming)
        }
    }

    private var startButton: some View {
        Button {
            Task { await startClaim() }
        } label: {
            HStack {
                if phase == .claiming { ProgressView().tint(.white) }
                Text(phase == .claiming ? "Requesting challenge…" : "Continue")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.indigo)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(!domainLooksValid || phase == .claiming)
    }

    private func recordInstructions(for claim: DomainClaimStartResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "server.rack").foregroundColor(.indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add this TXT record")
                        .font(.headline)
                    Text("At your DNS provider, for \(claim.recordName.replacingOccurrences(of: "_451-challenge.", with: ""))")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                copyableRow(label: "Host", value: claim.recordName)
                dnsRow(label: "Type", value: claim.recordType)
                copyableRow(label: "Value", value: recordValue)
                dnsRow(label: "TTL", value: "300")
            }
            .padding(12)
            .background(Color.platformGray6)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.indigo.opacity(0.2), lineWidth: 1)
            )

            Text("The value is a signature over a one-time challenge, so it is safe to publish — and it only works for this persona.")
                .font(.caption).foregroundColor(.secondary)

            if let expires = friendlyExpiry(claim.expiresAt) {
                Label("Challenge expires \(expires). After that, start again.", systemImage: "clock")
                    .font(.caption).foregroundColor(.secondary)
            }

            if phase != .verified {
                Button {
                    Task { await verifyClaim() }
                } label: {
                    HStack {
                        if phase == .verifying { ProgressView().tint(.white) }
                        Text(phase == .verifying ? "Checking DNS…" : "I've Added the Record — Verify")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(phase == .verifying)

                Text("DNS changes usually appear within minutes, but can take longer to propagate.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color.indigo.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var verifiedBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Domain verified", systemImage: "checkmark.seal.fill")
                .font(.headline).foregroundColor(.green)
            Text("\(domain) is now recorded on-chain as controlled by \(persona.name).")
                .font(.caption).foregroundColor(.secondary)

            Button {
                onVerified?()
                dismiss()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Row helpers

    private func dnsRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func copyableRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                PlatformPasteboard.copy(value)
                copied = label
            } label: {
                Image(systemName: copied == label ? "checkmark" : "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(copied == label ? .green : .indigo)
        }
    }

    // MARK: - Networking

    private func startClaim() async {
        errorMessage = nil
        phase = .claiming

        do {
            let response: DomainClaimStartResponse = try await post(
                path: "/api/persona/domain/claim",
                body: DomainClaimStartRequest(personaDID: persona.id, domain: domain)
            )

            // The TXT value is a signature over the nonce, not the nonce itself.
            // P-256 ECDSA, DER, base64 — matching the server's verifier.
            let signature = try SecureEnclaveKeyStore.sign(Data(response.nonce.utf8), for: persona.id)

            await MainActor.run {
                claim = response
                recordValue = signature.derRepresentation.base64EncodedString()
                phase = .awaitingRecord
            }
        } catch {
            await MainActor.run {
                errorMessage = message(for: error)
                phase = .collecting
            }
        }
    }

    private func verifyClaim() async {
        guard let claim else { return }
        errorMessage = nil
        phase = .verifying

        do {
            let _: DomainClaimVerifyResponse = try await post(
                path: "/api/persona/domain/verify",
                body: DomainClaimVerifyRequest(claimId: claim.claimId)
            )
            await MainActor.run { phase = .verified }
        } catch {
            await MainActor.run {
                errorMessage = message(for: error)
                // Stay on the record screen: the usual cause is DNS that has not
                // propagated yet, and the same record is still the right one.
                phase = .awaitingRecord
            }
        }
    }

    private func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body
    ) async throws -> Response {
        guard let url = URL(string: ServerConfig.baseURL + path) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            let reason = (try? JSONDecoder().decode(ServerError.self, from: data))?.reason
            throw DomainClaimError.server(reason ?? "Request failed (\(http.statusCode)).")
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private enum DomainClaimError: LocalizedError {
        case server(String)
        var errorDescription: String? {
            switch self {
            case .server(let reason): return reason
            }
        }
    }

    private func message(for error: Error) -> String {
        if let claimError = error as? DomainClaimError {
            return claimError.localizedDescription
        }
        if error is URLError {
            return "Could not reach the verification server."
        }
        // Signing failures land here — most often the key is gone or the user
        // dismissed the biometric prompt.
        return "Could not sign the challenge with this persona's key. \(error.localizedDescription)"
    }

    private func friendlyExpiry(_ iso: String) -> String? {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "at \(formatter.string(from: date))"
    }
}
