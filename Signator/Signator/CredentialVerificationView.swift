//
//  CredentialVerificationView.swift
//  451Wallet
//
//  Handles the in-flight verification for a single CredentialItem.
//  Launched from CredentialSelectionView when the user taps "Verify".
//
//  • Email  – sends the verification email, then polls / waits for the
//             deep-link callback.  A "Check now" button is provided as a
//             manual fallback.
//  • ORCID  – launches ASWebAuthenticationSession; result arrives back
//             here via the completion handler.
//  • Bar    – fires a single network request; shows result immediately.
//  • Bond   – same as bar.
//

import SwiftUI

struct CredentialVerificationView: View {
    /// The credential being verified.  Mutated locally; the final value
    /// is handed back to the parent via `onCredentialUpdated`.
    @State private var credential: CredentialItem

    /// Called when verification completes (success *or* failure) so the
    /// parent can persist the updated status.
    let onCredentialUpdated: (CredentialItem) -> Void

    /// Drives the main async work for email / ORCID.
    @State private var verificationTask: Task<Void, Never>?

    /// Human-readable status message shown below the spinner.
    @State private var statusMessage = "Starting verification…"

    /// If non-nil, an error occurred and we show the failure UI.
    @State private var verificationError: Error?

    // ── init ─────────────────────────────────────────────────────────
    init(credential: CredentialItem, onCredentialUpdated: @escaping (CredentialItem) -> Void) {
        self._credential = State(initialValue: credential)
        self.onCredentialUpdated = onCredentialUpdated
    }

    // ── body ─────────────────────────────────────────────────────────

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // ── kind icon ────────────────────────────────────────────
            Image(systemName: credential.kind.systemImage)
                .font(.system(size: 56, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 96, height: 96)
                .background(credential.kind.color)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: credential.kind.color.opacity(0.3), radius: 12, x: 0, y: 6)

            // ── title ────────────────────────────────────────────────
            Text(credential.kind.title)
                .font(.title2)
                .fontWeight(.bold)

            // ── status area (spinner / result) ───────────────────────
            switch credential.status {
            case .pending:
                pendingView
            case .verified:
                successView
            case .unverified:
                failureView
            default:
                // Should not land here, but handle gracefully
                pendingView
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Verification")
        .inlineNavigationTitle()
        .onAppear {
            startVerification()
        }
        .onDisappear {
            verificationTask?.cancel()
        }
    }

    // ── pending ──────────────────────────────────────────────────────

    @ViewBuilder
    private var pendingView: some View {
        switch credential.kind {
        case .emailVerification:
            emailPendingView
        case .orcid:
            orcidPendingView
        default:
            // Bar + bonding are fire-and-forget; if we're still pending
            // it means the network call is in flight.
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.4)
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    // email: show "check your inbox" + a manual retry button
    @ViewBuilder
    private var emailPendingView: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.open.fill")
                .font(.system(size: 40))
                .foregroundColor(credential.kind.color)

            Text("Verification email sent")
                .font(.headline)

            Text("Open your email and tap the verification link. It will bring you back to this app automatically.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Manual "I already tapped the link" check
            Button("I've tapped the link — check now") {
                recheckEmail()
            }
            .font(.subheadline)
            .foregroundColor(credential.kind.color)

            // Resend
            Button("Resend email") {
                resendEmail()
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    // ORCID: the browser is open (or about to be); just wait.
    @ViewBuilder
    private var orcidPendingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
            Text("Waiting for ORCID authorization…")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("An ORCID sign-in page should appear shortly. Authorize this app there and you will be returned here.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    // ── success ──────────────────────────────────────────────────────

    @ViewBuilder
    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Verified!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.green)

            // Show the verified value depending on kind
            Text(verifiedSummary)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button("Done") {
                onCredentialUpdated(credential)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(credential.kind.color)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    private var verifiedSummary: String {
        switch credential.kind {
        case .emailVerification:
            return "Email \(credential.email ?? "—") has been verified."
        case .orcid:
            return "ORCID iD \(credential.orcidID ?? "—") is now linked."
        case .barLicense:
            return "Bar admission (\(credential.barState ?? "—") #\(credential.barNumber ?? "—")) confirmed."
        case .bondingInsurance:
            return "Policy \(credential.policyNumber ?? "—") issued by \(credential.issuerName ?? "—") is active."
        }
    }

    // ── failure ──────────────────────────────────────────────────────

    @ViewBuilder
    private var failureView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundColor(.red)

            Text("Verification failed")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.red)

            Text(verificationError?.localizedDescription ?? "An unknown error occurred.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button("Try again") {
                credential.status = .pending
                verificationError = nil
                startVerification()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(credential.kind.color)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 24)
        }
    }

    // ── verification orchestration ───────────────────────────────────

    private func startVerification() {
        verificationTask?.cancel()
        verificationTask = Task { [self] in
            do {
                switch credential.kind {
                case .emailVerification:
                    try await runEmailVerification()
                case .orcid:
                    try await runORCIDVerification()
                case .barLicense:
                    try await runBarVerification()
                case .bondingInsurance:
                    try await runBondingVerification()
                }
            } catch {
                await MainActor.run {
                    verificationError = error
                    credential.status = .unverified
                }
            }
        }
    }

    // ── Email ────────────────────────────────────────────────────────

    @MainActor
    private func runEmailVerification() async throws {
        statusMessage = "Sending verification email…"
        let nonce = try await CredentialVerificationService.shared
            .sendVerificationEmail(to: credential.email ?? "")
        credential.nonce = nonce
        statusMessage = "Email sent — waiting for you to tap the link…"
        // We now sit here until the user taps the link (handled by
        // `recheckEmail()`) or the view disappears.
    }

    /// Called when the user taps "I've tapped the link — check now".
    private func recheckEmail() {
        Task {
            do {
                let confirmed = try await CredentialVerificationService.shared
                    .confirmEmailVerification(
                        nonce: credential.nonce ?? "",
                        email: credential.email ?? ""
                    )
                await MainActor.run {
                    if confirmed {
                        credential.status = .verified
                    } else {
                        statusMessage = "Not yet confirmed. Please check your inbox and try again."
                    }
                }
            } catch {
                await MainActor.run {
                    verificationError = error
                    credential.status = .unverified
                }
            }
        }
    }

    private func resendEmail() {
        Task {
            do {
                let nonce = try await CredentialVerificationService.shared
                    .sendVerificationEmail(to: credential.email ?? "")
                await MainActor.run {
                    credential.nonce = nonce
                    statusMessage = "Email resent — waiting for you to tap the link…"
                }
            } catch {
                await MainActor.run {
                    verificationError = error
                    credential.status = .unverified
                }
            }
        }
    }

    // ── ORCID ────────────────────────────────────────────────────────

    @MainActor
    private func runORCIDVerification() async throws {
        statusMessage = "Opening ORCID authorization…"
        let orcidID = try await CredentialVerificationService.shared.authenticateORCID()
        credential.orcidID = orcidID
        credential.status  = .verified
    }

    // ── Bar ──────────────────────────────────────────────────────────

    @MainActor
    private func runBarVerification() async throws {
        statusMessage = "Contacting bar verification authority…"
        let jwt = try await CredentialVerificationService.shared
            .verifyBarLicense(state: credential.barState ?? "", barNumber: credential.barNumber ?? "")
        credential.barCredentialJWT = jwt
        credential.status           = .verified
    }

    // ── Bonding ──────────────────────────────────────────────────────

    @MainActor
    private func runBondingVerification() async throws {
        statusMessage = "Contacting bonding authority…"
        let jwt = try await CredentialVerificationService.shared
            .verifyBondingInsurance(policyNumber: credential.policyNumber ?? "", issuerName: credential.issuerName ?? "")
        credential.bondingCredentialJWT = jwt
        credential.status               = .verified
    }
}

// MARK: - Preview

#Preview("Email – Pending") {
    NavigationStack {
        CredentialVerificationView(
            credential: {
                var item = CredentialItem(kind: .emailVerification, status: .pending)
                item.email = "user@university.edu"
                item.nonce = "abc123"
                return item
            }(),
            onCredentialUpdated: { _ in }
        )
    }
}

#Preview("ORCID – Verified") {
    NavigationStack {
        CredentialVerificationView(
            credential: {
                var item = CredentialItem(kind: .orcid, status: .verified)
                item.orcidID = "0000-0002-1825-0097"
                return item
            }(),
            onCredentialUpdated: { _ in }
        )
    }
}

#Preview("Bar – Failed") {
    NavigationStack {
        CredentialVerificationView(
            credential: CredentialItem(kind: .barLicense, status: .unverified),
            onCredentialUpdated: { _ in }
        )
    }
}
