//
//  CredentialVerificationService.swift
//  451Wallet
//
//  Orchestrates every credential-verification flow the app supports.
//
//  Email verification  – generates a nonce, calls the server to dispatch
//                         the verification email, then exposes a method
//                         the deep-link handler can call to confirm it.
//  ORCID OAuth         – opens the ORCID authorize URL in an ASWebAuth
//                         session; on callback parses the authorization
//                         code, exchanges it for a token, and fetches the
//                         ORCID iD.
//  Bar license         – submits state + bar-number to an external
//                         verification endpoint; receives back a
//                         Verified-Credential JWT on success.
//  Bonding / insurance – same pattern as bar license but against an
//                         insurance-verification endpoint.
//
//  The service is deliberately stateless on its own; callers hold the
//  `CredentialItem` and mutate it based on the results returned here.
//

import Foundation
import AuthenticationServices
import CryptoKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Errors

enum CredentialVerificationError: Error, LocalizedError {
    case networkFailure(Error)
    case invalidResponse(String)
    case oauthCancelled
    case oauthFailed(String)
    case verificationDenied
    case alreadyVerified
    case unknownKind

    var errorDescription: String? {
        switch self {
        case .networkFailure(let e):    return "Network error: \(e.localizedDescription)"
        case .invalidResponse(let msg): return "Invalid response: \(msg)"
        case .oauthCancelled:           return "OAuth verification was cancelled."
        case .oauthFailed(let msg):     return "OAuth failed: \(msg)"
        case .verificationDenied:       return "Verification was denied by the authority."
        case .alreadyVerified:          return "This credential is already verified."
        case .unknownKind:              return "Unrecognised credential type."
        }
    }
}

// MARK: - CredentialVerificationService

/// Singleton façade – all verification logic lives here so views stay thin.
final class CredentialVerificationService {
    static let shared = CredentialVerificationService()
    private init() {}

    // ─────────────────────────────────────────────
    // MARK: – Email Verification
    // ─────────────────────────────────────────────

    /// Generate a cryptographically random nonce.
    static func generateNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Calls the backend to send a verification email containing a
    /// deep-link URL of the form:
    ///   signator://verify-email?nonce=<nonce>&email=<email>
    ///
    /// The backend is the one that actually sends the email; we only
    /// tell it what nonce to embed.
    ///
    /// Returns the nonce that was sent (caller stores it in the
    /// CredentialItem for later comparison).
    func sendVerificationEmail(to email: String) async throws -> String {
        let nonce = CredentialVerificationService.generateNonce()

        // TODO: replace with your real API endpoint.
        // For now we POST to the server's credential-verification route.
        guard let url = URL(string: "https://api.451.info/credentials/email-verification") else {
            throw CredentialVerificationError.invalidResponse("Bad server URL")
        }

        let payload: [String: String] = [
            "email": email,
            "nonce": nonce,
            "scheme": "signator"          // tells the server which deep-link scheme to embed
        ]
        let body = try JSONEncoder().encode(payload)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "unknown"
            throw CredentialVerificationError.invalidResponse(msg)
        }

        return nonce
    }

    /// Called by the deep-link handler when the user taps the verification
    /// link in their email.  Confirms with the server that the nonce is
    /// valid and hasn't expired.
    ///
    /// Returns `true` when the server accepts the nonce.
    func confirmEmailVerification(nonce: String, email: String) async throws -> Bool {
        guard let url = URL(string: "https://api.451.info/credentials/email-verification/confirm") else {
            throw CredentialVerificationError.invalidResponse("Bad server URL")
        }

        let payload: [String: String] = ["nonce": nonce, "email": email]
        let body = try JSONEncoder().encode(payload)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "unknown"
            throw CredentialVerificationError.invalidResponse(msg)
        }

        // Server returns { "confirmed": true } on success
        let result = try JSONDecoder().decode([String: Bool].self, from: data)
        return result["confirmed"] ?? false
    }

    // ─────────────────────────────────────────────
    // MARK: – ORCID OAuth
    // ─────────────────────────────────────────────
    // ORCID sandbox: https://sandbox.orcid.org
    // ORCID production: https://orcid.org
    // Switch the base URL here when moving to production.

    private static let orcidBaseURL = "https://sandbox.orcid.org"   // ← flip to https://orcid.org for prod
    private static let orcidClientID = "YOUR_ORCID_CLIENT_ID"       // register at https://orcid.org/developer-tools
    private static let orcidClientSecret = "YOUR_ORCID_CLIENT_SECRET"
    private static let orcidRedirectURI = "signator://orcid-callback"

    /// Opens an `ASWebAuthenticationSession` that takes the user through
    /// the ORCID OAuth 2.0 authorization-code flow.  Returns the ORCID iD
    /// string on success (e.g. "0000-0002-1825-0097").
    @MainActor
    @available(iOS 12.0, macOS 10.15, *)
    func authenticateORCID() async throws -> String {
        let authURL = buildORCIDAuthURL()

        let orcidID: String = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "signator"
            ) { [self] (callbackURL: URL?, authError: Error?) in
                // ── error branch ──────────────────────────────────────
                if let authError = authError {
                    let mapped: CredentialVerificationError
                    if let sessionError = authError as? ASWebAuthenticationSessionError,
                       sessionError.code == .canceledLogin {
                        mapped = .oauthCancelled
                    } else {
                        mapped = .oauthFailed(authError.localizedDescription)
                    }
                    continuation.resume(throwing: mapped)
                    return
                }

                // ── success branch ────────────────────────────────────
                guard let callback = callbackURL else {
                    continuation.resume(throwing: CredentialVerificationError.oauthFailed("No callback URL"))
                    return
                }

                // The callback looks like:
                //   signator://orcid-callback?code=<authCode>&state=<state>
                guard let components = URLComponents(url: callback, resolvingAgainstBaseURL: false),
                      let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
                      let code = codeItem.value else {
                    continuation.resume(throwing: CredentialVerificationError.oauthFailed("Missing auth code in callback"))
                    return
                }

                // Exchange code → token → ORCID iD (network calls, so kick to a Task)
                Task {
                    do {
                        let orcid = try await self.exchangeORCIDCode(code)
                        continuation.resume(returning: orcid)
                    } catch let exchangeError {
                        continuation.resume(throwing: exchangeError)
                    }
                }
            }

            session.presentationContextProvider = ORCIDAWebAuthPresentationContext.shared
            if #available(iOS 13.0, macOS 10.15, *) {
                session.prefersEphemeralWebBrowserSession = true
            }
            session.start()
        }

        return orcidID
    }

    // MARK: - ORCID helpers (private)

    private func buildORCIDAuthURL() -> URL {
        var components = URLComponents(string: "\(CredentialVerificationService.orcidBaseURL)/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id",     value: CredentialVerificationService.orcidClientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri",  value: CredentialVerificationService.orcidRedirectURI),
            URLQueryItem(name: "scope",         value: "/read-limited"),   // minimal scope
            URLQueryItem(name: "state",         value: "orcid_verify")
        ]
        return components.url!
    }

    /// Exchanges an authorization code for an access token, then fetches
    /// the ORCID iD from the `/v3.0/<orcid>/` endpoint.
    private func exchangeORCIDCode(_ code: String) async throws -> String {
        // 1) Token exchange
        guard let tokenURL = URL(string: "\(CredentialVerificationService.orcidBaseURL)/oauth/token") else {
            throw CredentialVerificationError.invalidResponse("Bad ORCID token URL")
        }

        let tokenParams: [String: String] = [
            "grant_type":   "authorization_code",
            "code":         code,
            "client_id":    CredentialVerificationService.orcidClientID,
            "client_secret": CredentialVerificationService.orcidClientSecret,
            "redirect_uri": CredentialVerificationService.orcidRedirectURI
        ]
        let tokenBody = tokenParams.map { "\($0.key)=\(URLQueryItem(name: $0.key, value: $0.value).value!)" }
                                   .joined(separator: "&")

        var tokenRequest = URLRequest(url: tokenURL)
        tokenRequest.httpMethod = "POST"
        tokenRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        tokenRequest.httpBody = tokenBody.data(using: .utf8)

        let (tokenData, tokenResponse) = try await URLSession.shared.data(for: tokenRequest)
        guard let tokenHTTP = tokenResponse as? HTTPURLResponse, (200...299).contains(tokenHTTP.statusCode) else {
            let msg = String(data: tokenData, encoding: .utf8) ?? "unknown"
            throw CredentialVerificationError.oauthFailed("Token exchange failed: \(msg)")
        }

        // ORCID returns the ORCID iD in the token response itself (non-standard but documented)
        let tokenJSON = try JSONDecoder().decode([String: String].self, from: tokenData)
        guard let orcidID = tokenJSON["orcid"] else {
            throw CredentialVerificationError.invalidResponse("No ORCID iD in token response")
        }

        return orcidID
    }

    // ─────────────────────────────────────────────
    // MARK: – Bar License Verification
    // ─────────────────────────────────────────────
    // This calls an external Verified-Credential issuer.
    // The issuer returns a VC JWT that we store on the credential.
    // In production this will be a real bar-verification authority;
    // for now the endpoint is a placeholder.

    /// Submits a bar number + state and returns a Verified-Credential JWT
    /// from the issuing authority on success.
    func verifyBarLicense(state: String, barNumber: String) async throws -> String {
        guard let url = URL(string: "https://api.451.info/credentials/bar-verification") else {
            throw CredentialVerificationError.invalidResponse("Bad server URL")
        }

        let payload: [String: String] = [
            "state":     state,
            "barNumber": barNumber
        ]
        let body = try JSONEncoder().encode(payload)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "unknown"
            throw CredentialVerificationError.invalidResponse("Bar verification failed: \(msg)")
        }

        // Response: { "credentialJWT": "<vc-jwt>" }
        let result = try JSONDecoder().decode([String: String].self, from: data)
        guard let jwt = result["credentialJWT"] else {
            throw CredentialVerificationError.invalidResponse("No credential JWT in response")
        }
        return jwt
    }

    // ─────────────────────────────────────────────
    // MARK: – Bonding / Insurance Verification
    // ─────────────────────────────────────────────

    /// Submits an insurance policy number + issuer name and returns a
    /// Verified-Credential JWT on success.
    func verifyBondingInsurance(policyNumber: String, issuerName: String) async throws -> String {
        guard let url = URL(string: "https://api.451.info/credentials/bonding-verification") else {
            throw CredentialVerificationError.invalidResponse("Bad server URL")
        }

        let payload: [String: String] = [
            "policyNumber": policyNumber,
            "issuerName":   issuerName
        ]
        let body = try JSONEncoder().encode(payload)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "unknown"
            throw CredentialVerificationError.invalidResponse("Bonding verification failed: \(msg)")
        }

        let result = try JSONDecoder().decode([String: String].self, from: data)
        guard let jwt = result["credentialJWT"] else {
            throw CredentialVerificationError.invalidResponse("No credential JWT in response")
        }
        return jwt
    }
}

// MARK: - ASWebAuthenticationSession presentation context

#if canImport(UIKit)

@available(iOS 12.0, *)
final class ORCIDAWebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = ORCIDAWebAuthPresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Prefer the key window from the first active UIWindowScene.
        // Falls back to a fresh UIWindow (which is valid as a presentation anchor).
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) as? UIWindowScene
        else {
            return UIWindow()
        }
        return scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first ?? UIWindow()
    }
}

#elseif canImport(AppKit)

@available(macOS 10.15, *)
final class ORCIDAWebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = ORCIDAWebAuthPresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // On macOS the presentation anchor is an NSWindow.
        // Return the key window if available; otherwise create a new one.
        return NSApplication.shared.keyWindow ?? NSWindow()
    }
}

#endif

