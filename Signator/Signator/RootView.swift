// RootView.swift
// Manages splash-to-main transition and welcome flow

import SwiftUI
import AuthenticationServices

struct RootView: View {
    @StateObject private var personaManager = PersonaManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showIntro = true
    @State private var hasCheckedPersona = false
    @State private var deepLinkPersonaData: OneTimePersonaData?

    var body: some View {
        if showIntro {
            IntroView {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showIntro = false
                    hasCheckedPersona = true
                }
            }
        } else if #available(iOS 26.0, *) {
            // Video onboarding is bypassed for now (draft placeholder videos) —
            // the video action-card direction will replace it. Go straight to the app.
            // Persona creation is deferred to the point of need (when signing/pushing),
            // not required up front. Users enter the app straight away; the sign/push
            // actions present persona creation on demand via Common's `.requiresPersona`.
            MainTabView()
                .environmentObject(personaManager)
        } else {
            Text("This app requires iOS 26.0 or later.")
        }
    }
}

// MARK: - One-Time Persona Data Structure
struct OneTimePersonaData: Codable {
    let name: String?
    let givenName: String?
    let address: Address?
    let email: String?
    let ssn: String?
    let documentID: String?
    let requestID: String?
    
    struct Address: Codable {
        let street: String?
        let city: String?
        let state: String?
        let zip: String?
        let country: String?
    }
}

// MARK: - Welcome Flow View
struct WelcomeFlowView: View {
    @ObservedObject var personaManager: PersonaManager
    @Binding var deepLinkPersonaData: OneTimePersonaData?
    @State private var showCreatePersona = false
    @State private var showOneTimeSigning = false
    @State private var showQRScanner = false
    @State private var showServerSettings = false
    @State private var incomingProposedPersonaToken: String? = nil
    
    // Handle scanned QR code or deep link
    private func handleQRCode(_ code: String) {
        print("📷 Processing code: \(code)")
        
        // Check if it's a URL (deep link or QR code with URL)
        if let url = URL(string: code) {
            handleDeepLink(url)
        } else {
            // Try to parse as JSON
            if let data = code.data(using: .utf8),
               let personaData = try? JSONDecoder().decode(OneTimePersonaData.self, from: data) {
                // Store the persona data and show the one-time signing view
                deepLinkPersonaData = personaData
                showOneTimeSigning = true
            } else {
                print("⚠️ Unable to parse QR code data")
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        print("🔗 Processing deep link: \(url)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "signator" else {
            print("⚠️ Invalid deep link format — missing scheme")
            return
        }

        // ── Route dispatch ─────────────────────────────────────────
        switch components.host {

        // ── Email verification callback ──────────────────────────
        case "verify-email":
            handleEmailVerificationCallback(components)
            return

        // ── ORCID OAuth callback ─────────────────────────────────
        // (ASWebAuthenticationSession handles this automatically via
        //  its callbackURLScheme, but we log it here for debugging.)
        case "orcid-callback":
            print("🔗 ORCID callback received — ASWebAuthenticationSession will process this.")
            return

        // ── Persona deep link (existing flow) ────────────────────
        case "persona":
            break   // fall through to the existing persona-parsing logic below

        case "proposed-persona":
            if let token = components.queryItems?.first(where: { $0.name == "token" })?.value, !token.isEmpty {
                incomingProposedPersonaToken = token
            } else {
                print("⚠️ proposed-persona deep link missing token")
            }
            return

        default:
            print("⚠️ Unrecognised deep link host: \(components.host ?? "nil")")
            return
        }

        // ── Existing persona deep-link parsing (host == "persona") ─
        var personaData = OneTimePersonaData(
            name: nil,
            givenName: nil,
            address: nil,
            email: nil,
            ssn: nil,
            documentID: nil,
            requestID: nil
        )
        
        var addressComponents: [String: String] = [:]
        
        components.queryItems?.forEach { item in
            switch item.name {
            case "name": personaData = OneTimePersonaData(name: item.value, givenName: personaData.givenName, address: personaData.address, email: personaData.email, ssn: personaData.ssn, documentID: personaData.documentID, requestID: personaData.requestID)
            case "givenName": personaData = OneTimePersonaData(name: personaData.name, givenName: item.value, address: personaData.address, email: personaData.email, ssn: personaData.ssn, documentID: personaData.documentID, requestID: personaData.requestID)
            case "email": personaData = OneTimePersonaData(name: personaData.name, givenName: personaData.givenName, address: personaData.address, email: item.value, ssn: personaData.ssn, documentID: personaData.documentID, requestID: personaData.requestID)
            case "ssn": personaData = OneTimePersonaData(name: personaData.name, givenName: personaData.givenName, address: personaData.address, email: personaData.email, ssn: item.value, documentID: personaData.documentID, requestID: personaData.requestID)
            case "documentID": personaData = OneTimePersonaData(name: personaData.name, givenName: personaData.givenName, address: personaData.address, email: personaData.email, ssn: personaData.ssn, documentID: item.value, requestID: personaData.requestID)
            case "requestID": personaData = OneTimePersonaData(name: personaData.name, givenName: personaData.givenName, address: personaData.address, email: personaData.email, ssn: personaData.ssn, documentID: personaData.documentID, requestID: item.value)
            case "street": addressComponents["street"] = item.value
            case "city": addressComponents["city"] = item.value
            case "state": addressComponents["state"] = item.value
            case "zip": addressComponents["zip"] = item.value
            case "country": addressComponents["country"] = item.value
            default: break
            }
        }
        
        // Build address if components exist
        if !addressComponents.isEmpty {
            let address = OneTimePersonaData.Address(
                street: addressComponents["street"],
                city: addressComponents["city"],
                state: addressComponents["state"],
                zip: addressComponents["zip"],
                country: addressComponents["country"]
            )
            personaData = OneTimePersonaData(
                name: personaData.name,
                givenName: personaData.givenName,
                address: address,
                email: personaData.email,
                ssn: personaData.ssn,
                documentID: personaData.documentID,
                requestID: personaData.requestID
            )
        }
        
        // Store and navigate
        deepLinkPersonaData = personaData
        showOneTimeSigning = true
    }
    
    // ── Email verification deep-link callback ─────────────────────
    /// Called when the user taps the `signator://verify-email?nonce=…&email=…`
    /// link inside their email.  We don't need to do anything UI-side here;
    /// `CredentialVerificationView` will poll via "Check now".  But we do
    /// forward the nonce to the service so it can be confirmed server-side
    /// immediately — that way the poll that's already sitting in the
    /// verification view will succeed on its next check.
    private func handleEmailVerificationCallback(_ components: URLComponents) {
        guard let nonce = components.queryItems?.first(where: { $0.name == "nonce" })?.value,
              let email = components.queryItems?.first(where: { $0.name == "email" })?.value else {
            print("⚠️ Email verification callback missing nonce or email")
            return
        }
        print("📧 Email verification callback received — nonce: \(nonce), email: \(email)")

        // Fire-and-forget confirmation to the server so it marks the
        // nonce as used.  CredentialVerificationView's "Check now" button
        // will independently re-confirm and flip the status to .verified.
        Task {
            do {
                let confirmed = try await CredentialVerificationService.shared
                    .confirmEmailVerification(nonce: nonce, email: email)
                print("📧 Server confirmation result: \(confirmed)")
            } catch {
                print("⚠️ Email verification confirmation failed: \(error.localizedDescription)")
            }
        }
    }
    
    // ── Sign in with Apple handler ─────────────────────────────────
    @State private var showAppleSignInError = false
    @State private var appleSignInErrorMessage = ""
    
    private func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                print("⚠️ Failed to get Apple ID credential")
                appleSignInErrorMessage = "Failed to get Apple ID credential."
                showAppleSignInError = true
                return
            }
            
            // Apple only provides name/email on the first authorization —
            // persist them so persona creation can prefill now and later.
            AppleIDPrefill.remember(appleIDCredential)

            print("🍎 Creating persona from Apple Sign In: \(AppleIDPrefill.name ?? "no name provided")")

            // Navigate to persona creation with pre-filled name/email
            // The PersonaCreationView will handle the actual key generation and server registration
            showCreatePersona = true
            
        case .failure(let error):
            let nsError = error as NSError
            
            // Error 1000 = user canceled or not signed in
            if nsError.code == 1000 {
                print("ℹ️ Sign in with Apple was canceled or no Apple ID is signed in")
                appleSignInErrorMessage = "To use Sign in with Apple, please sign in to your Apple ID in Settings first."
            } else if nsError.code == 1001 {
                // Error 1001 = unknown error
                print("⚠️ Sign in with Apple unknown error")
                appleSignInErrorMessage = "An unknown error occurred. Please try again."
            } else {
                print("❌ Sign in with Apple failed: \(error.localizedDescription)")
                appleSignInErrorMessage = "Sign in failed: \(error.localizedDescription)"
            }
            
            showAppleSignInError = true
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Text("Welcome to Signator")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("Have you been given a Link, QR Code, or a numerical code from your Attorney, or Agent.")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                VStack(spacing: 12) {
                    Button {
                        showOneTimeSigning = true
                    } label: {
                        Text("Yes")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        showCreatePersona = true
                    } label: {
                        Text("No, create a persistent persona")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .background(Color.platformGroupedBackground.ignoresSafeArea())
            // Very subtle gear button in lower-right corner
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showServerSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(0.4)
                        .padding(8)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
                .accessibilityLabel("Server Settings")
            }
            .navigationDestination(isPresented: $showCreatePersona) {
                PersonaCreationView(
                    personaManager: personaManager,
                    initialIsPublicPersona: true,
                    initialName: AppleIDPrefill.craftedName,
                    initialEmail: AppleIDPrefill.email,
                    initialPublishingHouse: AppleIDPrefill.craftedPublishingHouse,
                    initialPurpose: .publishing
                )
            }
            .navigationDestination(isPresented: $showOneTimeSigning) {
                AccessCodeEntryView(
                    initialAccessCode: deepLinkPersonaData?.requestID,
                    prefilledPersona: deepLinkPersonaData
                )
            }
            .navigationDestination(item: $incomingProposedPersonaToken) { token in
                ProposedPersonaReviewView(tokenString: token)
            }
            .sheet(isPresented: $showQRScanner) {
                NavigationStack {
                    QRScannerView { scannedCode in
                        handleQRCode(scannedCode)
                    }
                }
            }
            .sheet(isPresented: $showServerSettings) {
                NavigationStack {
                    ServerSettingsView()
                }
            }
            .alert("Sign In Failed", isPresented: $showAppleSignInError) {
                Button("OK", role: .cancel) { }
                Button("Open Settings") {
                    if let url = URL(string: "App-prefs:") {
                        PlatformURLOpener.open(url)
                    }
                }
            } message: {
                Text(appleSignInErrorMessage)
            }
        }
        .environmentObject(personaManager)
    }
}
