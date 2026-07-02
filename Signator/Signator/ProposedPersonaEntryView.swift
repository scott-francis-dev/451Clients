import SwiftUI

/// Lets the user paste or scan a proposed-persona token string,
/// then navigates into ProposedPersonaReviewView for review & acceptance.
struct ProposedPersonaEntryView: View {
    @EnvironmentObject private var personaManager: PersonaManager

    @State private var tokenInput: String = ""
    @State private var navigateToken: String? = nil
    @State private var showScanner = false
    @State private var pasteError: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // ── Header ────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Label("Accept a Proposed Persona",
                          systemImage: "person.crop.circle.badge.plus")
                        .font(.headline)
                    Text("Your firm or attorney may have proposed a persona on your behalf. Paste the token from your email or text message, or scan the QR code they provided.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // ── Token input + Scan button ─────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    Text("Proposal Token")
                        .font(.headline)

                    HStack(alignment: .top, spacing: 12) {
                        TextEditor(text: $tokenInput)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(minHeight: 80, maxHeight: 140)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(Color.platformSecondaryGroupedBackground)
                            .cornerRadius(12)
                            .onChange(of: tokenInput) { _, _ in pasteError = nil }

                        VStack(spacing: 8) {
                            // Paste from clipboard
                            Button {
                                pasteFromClipboard()
                            } label: {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            .accessibilityLabel("Paste from clipboard")

                            // QR scan
                            Button {
                                showScanner = true
                            } label: {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            .accessibilityLabel("Scan QR code")
                        }
                    }

                    if let err = pasteError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Text("The token looks like: header.payload.signature (three base64 segments separated by dots).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.platformGroupedBackground)
                .cornerRadius(16)

                // ── Continue button ───────────────────────────────
                Button {
                    let trimmed = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard trimmed.split(separator: ".").count == 3 else {
                        pasteError = "Token must contain exactly three dot-separated segments."
                        return
                    }
                    navigateToken = trimmed
                } label: {
                    Text("Review Proposal")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isTokenReady ? Color.blue : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!isTokenReady)
            }
            .padding()
        }
        .navigationTitle("Proposed Persona")
        .inlineNavigationTitle()
        // ── Navigate to the full review screen ──────────────────
        .navigationDestination(item: $navigateToken) { token in
            ProposedPersonaReviewView(tokenString: token)
                .environmentObject(personaManager)
        }
        // ── QR scanner sheet ────────────────────────────────────
        .sheet(isPresented: $showScanner) {
            NavigationStack {
                QRScannerView { scannedCode in
                    let trimmed = scannedCode.trimmingCharacters(in: .whitespacesAndNewlines)

                    // If the scanned value is a full deep-link URL, extract the token param
                    if let url = URL(string: trimmed),
                       let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                       let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
                       !token.isEmpty {
                        tokenInput = token
                    } else {
                        // Otherwise treat the raw scanned string as the token itself
                        tokenInput = trimmed
                    }
                    showScanner = false
                }
            }
        }
    }

    // ── Helpers ─────────────────────────────────────────────────
    private var isTokenReady: Bool {
        tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ".").count == 3
    }

    private func pasteFromClipboard() {
        guard let board = PlatformPasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !board.isEmpty else {
            pasteError = "Nothing on the clipboard."
            return
        }

        // If clipboard holds a full deep-link URL, extract the token param
        if let url = URL(string: board),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
           !token.isEmpty {
            tokenInput = token
        } else {
            tokenInput = board
        }
    }
}

#Preview {
    NavigationStack {
        ProposedPersonaEntryView()
            .environmentObject(PersonaManager())
    }
}
