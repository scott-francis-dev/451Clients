import Foundation

enum ProposalVerificationError: Error, LocalizedError {
    case invalidToken
    case expired
    case notYetValid
    case badIssuer
    case badSubject
    case signatureNotVerified
    case networkFailure(String)

    var errorDescription: String? {
        switch self {
        case .invalidToken: return "Invalid token"
        case .expired: return "Token has expired"
        case .notYetValid: return "Token not yet valid"
        case .badIssuer: return "Unrecognised issuer"
        case .badSubject: return "Unexpected token subject"
        case .signatureNotVerified: return "Signature verification failed"
        case .networkFailure(let msg): return msg
        }
    }
}

/// Minimal scaffold that will later:
///  - Verify JWT/JWS signature using a law firm public key (kid lookup)
///  - Resolve proposal details by ID
///  - Validate short code with server
///  - Submit acceptance to server
final class ProposalVerificationService {
    static let shared = ProposalVerificationService()
    private init() {}

    // MARK: - Token Parsing

    /// Parses a compact JWS/JWT string of the form header.payload.signature (all base64url)
    /// and returns a structured token with decoded JSON for header + payload.
    func parseToken(_ token: String) throws -> ProposedPersonaToken {
        let parts = token.split(separator: ".").map(String.init)
        guard parts.count == 3 else { throw ProposalVerificationError.invalidToken }
        let headerB64 = parts[0]
        let payloadB64 = parts[1]
        let sigB64     = parts[2]

        func decodeB64URLJSON<T: Decodable>(_ b64: String, as type: T.Type) throws -> T {
            var s = b64.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            let pad = 4 - (s.count % 4)
            if pad < 4 { s.append(String(repeating: "=", count: pad)) }
            guard let data = Data(base64Encoded: s) else { throw ProposalVerificationError.invalidToken }
            return try JSONDecoder().decode(T.self, from: data)
        }

        let header = try decodeB64URLJSON(headerB64, as: [String: String].self)
        let payload = try decodeB64URLJSON(payloadB64, as: ProposedPersonaTokenPayload.self)
        return ProposedPersonaToken(headerJSON: header, payload: payload, signatureBase64URL: sigB64)
    }

    /// Performs basic checks (exp, sub, iss). Signature verification is TODO.
    func basicValidate(_ token: ProposedPersonaToken, expectedIssuerPrefix: String = "did:") throws {
        guard token.payload.sub == "proposed-persona" else { throw ProposalVerificationError.badSubject }
        guard token.payload.iss.hasPrefix(expectedIssuerPrefix) else { throw ProposalVerificationError.badIssuer }
        let now = Int(Date().timeIntervalSince1970)
        if token.payload.exp <= now { throw ProposalVerificationError.expired }
        if token.payload.iat > now + 300 { throw ProposalVerificationError.notYetValid }
        // TODO: Verify JWS signature using header.kid to fetch the law firm's public key.
        // throw ProposalVerificationError.signatureNotVerified if verification fails.
    }

    // MARK: - Server Integration

    /// Resolves a ProposedPersona by token. Fetches server payload using the lookup token.
    func fetchProposedPersona(token: ProposedPersonaToken, tokenString: String) async throws -> ProposedPersona {
        let requestID = RequestIDGenerator.generate()
        let encodedToken = tokenString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tokenString
        let path = "/api/proposals/\(token.payload.proposalID)"
        ClientLogger.info(component: LogComponent.proposedPersona, "GET \(path)", requestID: requestID)
        let responseData = try await rawRequest(
            path: path,
            method: .GET,
            queryItems: [URLQueryItem(name: "token", value: encodedToken)],
            requestID: requestID
        )
        return try decodeProposedPersona(from: responseData, fallbackProposalID: token.payload.proposalID, issuer: token.payload.iss, requestID: requestID)
    }

    /// Validates the short code for a proposal.
    func validateShortCode(proposalID: String, code: String, tokenString: String, tokenID: String?) async throws -> Bool {
        let requestID = RequestIDGenerator.generate()
        let path = "/api/proposals/\(proposalID)/verify"
        ClientLogger.info(component: LogComponent.proposedPersona, "POST \(path)", requestID: requestID)
        let body = VerifyRequest(code: code, token: tokenString, tokenID: tokenID)
        let response: VerifyResponse = try await jsonRequest(path: path, method: .POST, body: body, requestID: requestID)
        if let ok = response.ok { return ok }
        if let success = response.success { return success }
        if let valid = response.valid { return valid }
        return false
    }

    /// Submits acceptance.
    func submitAcceptance(
        proposalID: String,
        acceptanceSignature: String,
        publicKeyBase64: String,
        tokenString: String,
        tokenID: String?
    ) async throws {
        let requestID = RequestIDGenerator.generate()
        let path = "/api/proposals/\(proposalID)/accept"
        ClientLogger.info(component: LogComponent.proposedPersona, "POST \(path)", requestID: requestID)
        let body = AcceptRequest(
            token: tokenString,
            tokenID: tokenID,
            acceptanceSignature: acceptanceSignature,
            publicKeyBase64: publicKeyBase64
        )
        let _: EmptyResponse = try await jsonRequest(path: path, method: .POST, body: body, requestID: requestID)
    }

    // MARK: - Networking

    private enum HTTPMethod: String {
        case GET, POST
    }

    private struct EmptyResponse: Decodable { }

    private func jsonRequest<Response: Decodable, Body: Encodable>(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: Body,
        requestID: String
    ) async throws -> Response {
        let data = try await rawRequest(path: path, method: method, queryItems: queryItems, body: body, requestID: requestID)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            let bodyString = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            ClientLogger.error(component: LogComponent.proposedPersona, "Decode error: \(error.localizedDescription)", requestID: requestID)
            ClientLogger.error(component: LogComponent.proposedPersona, "Response body: \(bodyString.prefix(400))", requestID: requestID)
            throw error
        }
    }

    private func rawRequest(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        requestID: String
    ) async throws -> Data {
        guard var components = URLComponents(string: ServerConfig.baseURL + path) else {
            ClientLogger.error(component: LogComponent.proposedPersona, "Invalid base URL", requestID: requestID)
            throw ProposalVerificationError.networkFailure("Invalid base URL")
        }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else {
            ClientLogger.error(component: LogComponent.proposedPersona, "Invalid URL components", requestID: requestID)
            throw ProposalVerificationError.networkFailure("Invalid URL components")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        ClientLogger.debug(component: LogComponent.proposedPersona, "Request URL: \(url.absoluteString)", requestID: requestID)
        if let body = request.httpBody {
            ClientLogger.debug(component: LogComponent.proposedPersona, "Request body bytes: \(body.count)", requestID: requestID)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            ClientLogger.error(component: LogComponent.proposedPersona, "Network error: \(error.localizedDescription)", requestID: requestID)
            throw ProposalVerificationError.networkFailure("Network error: \(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            ClientLogger.error(component: LogComponent.proposedPersona, "Invalid HTTP response", requestID: requestID)
            throw ProposalVerificationError.networkFailure("Invalid HTTP response")
        }

        ClientLogger.info(component: LogComponent.proposedPersona, "Response status: \(httpResponse.statusCode)", requestID: requestID)

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            ClientLogger.error(component: LogComponent.proposedPersona, "HTTP \(httpResponse.statusCode): \(bodyString.prefix(400))", requestID: requestID)
            throw ProposalVerificationError.networkFailure("HTTP \(httpResponse.statusCode): \(bodyString)")
        }

        return data
    }

    // MARK: - Response Decoding

    private struct ProposedPersonaPayload: Decodable {
        let id: String?
        let proposalID: String?
        let name: String?
        let handle: String?
        let displayName: String?
        let displayPublisher: String?
        let address: String?
        let email: String?
        let affiliations: String?
        let proposer: String?
        let issuedAt: String?
    }

    private struct ProposedPersonaWrapper: Decodable {
        let proposal: ProposedPersonaPayload?
        let persona: ProposedPersonaPayload?
        let proposedPersona: ProposedPersonaPayload?
        let data: ProposedPersonaPayload?
    }

    private struct VerifyRequest: Encodable {
        let code: String
        let token: String
        let tokenID: String?
    }

    private struct VerifyResponse: Decodable {
        let ok: Bool?
        let success: Bool?
        let valid: Bool?
    }

    private struct AcceptRequest: Encodable {
        let token: String
        let tokenID: String?
        let acceptanceSignature: String
        let publicKeyBase64: String
    }

    private func decodeProposedPersona(
        from data: Data,
        fallbackProposalID: String,
        issuer: String,
        requestID: String
    ) throws -> ProposedPersona {
        if let direct = try? JSONDecoder().decode(ProposedPersonaPayload.self, from: data) {
            return buildProposedPersona(from: direct, fallbackProposalID: fallbackProposalID, issuer: issuer)
        }

        do {
            let wrapper = try JSONDecoder().decode(ProposedPersonaWrapper.self, from: data)
            let payload = wrapper.proposal ?? wrapper.persona ?? wrapper.proposedPersona ?? wrapper.data
            guard let payload else {
                ClientLogger.error(component: LogComponent.proposedPersona, "Proposal response missing persona payload", requestID: requestID)
                throw ProposalVerificationError.networkFailure("Proposal response missing persona payload")
            }
            return buildProposedPersona(from: payload, fallbackProposalID: fallbackProposalID, issuer: issuer)
        } catch {
            let bodyString = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            ClientLogger.error(component: LogComponent.proposedPersona, "Decode error: \(error.localizedDescription)", requestID: requestID)
            ClientLogger.error(component: LogComponent.proposedPersona, "Response body: \(bodyString.prefix(400))", requestID: requestID)
            throw error
        }
    }

    private func buildProposedPersona(
        from payload: ProposedPersonaPayload,
        fallbackProposalID: String,
        issuer: String
    ) -> ProposedPersona {
        let resolvedID = payload.id ?? payload.proposalID ?? fallbackProposalID
        let resolvedName = payload.name ?? "Proposed Client"
        return ProposedPersona(
            id: resolvedID,
            name: resolvedName,
            handle: payload.handle,
            displayName: payload.displayName,
            displayPublisher: payload.displayPublisher,
            address: payload.address,
            email: payload.email,
            affiliations: payload.affiliations,
            proposer: payload.proposer ?? issuer,
            issuedAt: payload.issuedAt
        )
    }

    // MARK: - Helpers

    private func tokenIssuerHint(from id: String) -> String { "did:example:lawfirm" }
}

private struct AnyEncodable: Encodable {
    private let encoder: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        self.encoder = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try self.encoder(encoder)
    }
}
