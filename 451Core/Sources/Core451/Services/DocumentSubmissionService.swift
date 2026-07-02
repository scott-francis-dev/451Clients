import Foundation
import CryptoKit

// MARK: - Helper Types (moved to file scope)

/// Percent-encode a single path component, encoding '@' as well
private func encodePathComponent(_ component: String) -> String {
    var allowed = CharacterSet.urlPathAllowed
    // Remove '@' from allowed characters to force encoding
    allowed.remove(charactersIn: "@")
    return component.addingPercentEncoding(withAllowedCharacters: allowed) ?? component
}

/// Validate a client-provided document identifier (DID/GUID) using a conservative character set and length bounds.
/// Allowed characters: [A-Za-z0-9._-]
/// Length: 3...200
private func isSafeDocumentIdentifier(_ s: String) -> Bool {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    guard (3...200).contains(trimmed.count) else { return false }
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")
    return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
}

/// Strict UUID v4 format validator (lowercase hex, hyphens at 8-4-4-4-12, version=4, variant=8|9|a|b)
private func isUUIDv4(_ s: String) -> Bool {
    let pattern = "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
    return s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
}

private enum HTTPMethod: String {
    case GET, POST, PUT, PATCH
}

private struct HTTPError: LocalizedError {
    let statusCode: Int
    let url: URL
    let data: Data?

    var errorDescription: String? {
        var message = "HTTP \(statusCode) error for URL: \(url.absoluteString)"
        if let data = data, let bodyString = String(data: data, encoding: .utf8) {
            message += "\nResponse body: \(bodyString)"
        }
        return message
    }
}

// MARK: - Helper Functions

private func debugLog(_ items: Any...) {
    #if DEBUG
    print("[submitSignedDocumentFlow]", items.map { "\($0)" }.joined(separator: " "))
    #endif
}

/// Performs a JSON request with optional JSON body and returns decoded result.
private func jsonRequest<ResponseBody: Decodable>(
    url: URL,
    method: HTTPMethod,
    requestBody: (any Encodable)? = nil
) async throws -> ResponseBody {
    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue

    if let body = requestBody {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw NSError(domain: "submitSignedDocumentFlow", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request body: \(error.localizedDescription)"])
        }

        let previewBody = String(data: request.httpBody!, encoding: .utf8) ?? "<binary>"
        debugLog("Request:", method.rawValue, url.absoluteString, "Body preview:", previewBody.prefix(300))
    } else {
        debugLog("Request:", method.rawValue, url.absoluteString, "No body")
    }

    let (data, response): (Data, URLResponse)
    do {
        (data, response) = try await URLSession.shared.data(for: request)
    } catch {
        throw NSError(domain: "submitSignedDocumentFlow", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error: \(error.localizedDescription)"])
    }

    guard let httpResponse = response as? HTTPURLResponse else {
        throw NSError(domain: "submitSignedDocumentFlow", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
    }

    debugLog("Response:", httpResponse.statusCode, url.absoluteString)

    guard (200..<300).contains(httpResponse.statusCode) else {
        throw HTTPError(statusCode: httpResponse.statusCode, url: url, data: data)
    }

    do {
        return try JSONDecoder().decode(ResponseBody.self, from: data)
    } catch {
        let responseString = String(data: data, encoding: .utf8) ?? "<unable to decode response as UTF-8>"
        debugLog("JSON decode error for response:", responseString)
        throw NSError(domain: "submitSignedDocumentFlow", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode JSON response: \(error.localizedDescription)\nResponse was: \(responseString)"])
    }
}

/// Performs a request with raw body data.
private func rawRequest(
    url: URL,
    method: HTTPMethod,
    body: Data,
    contentType: String
) async throws {
    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    request.setValue(contentType, forHTTPHeaderField: "Content-Type")
    request.httpBody = body

    debugLog("Request:", method.rawValue, url.absoluteString, "Body size:", body.count, "Content-Type:", contentType)

    let (data, response): (Data, URLResponse)
    do {
        (data, response) = try await URLSession.shared.data(for: request)
    } catch {
        throw NSError(domain: "submitSignedDocumentFlow", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error: \(error.localizedDescription)"])
    }

    guard let httpResponse = response as? HTTPURLResponse else {
        throw NSError(domain: "submitSignedDocumentFlow", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
    }

    debugLog("Response:", httpResponse.statusCode, url.absoluteString)

    guard (200..<300).contains(httpResponse.statusCode) else {
        throw HTTPError(statusCode: httpResponse.statusCode, url: url, data: data)
    }
}

private extension UInt8 {
    var isWhitespaceByte: Bool { self == 0x20 || self == 0x0A || self == 0x0D || self == 0x09 }
}

private struct EmptyResponse: Decodable { }

/// Legacy function maintained for backward compatibility
/// ⚠️ DEPRECATED: Use DocumentSigningService.completeSigningWorkflow() for new code
/// This function now internally uses the new multi-party signing workflow
@available(*, deprecated, message: "Use DocumentSigningService.completeSigningWorkflow() for the new ledger-based workflow")
public func submitSignedDocumentFlow(
    documentData: Data,
    privateKey: P256.Signing.PrivateKey,
    personaDid: String,
    personaPublicKey: String,
    isPublic: Bool,
    documentId: String,
    originalFilename: String?
) async throws {
    debugLog("⚠️ Using legacy submitSignedDocumentFlow - consider migrating to DocumentSigningService")
    
    // Use new workflow under the hood
    let (docId, _) = try await DocumentSigningService.completeSigningWorkflow(
        documentData: documentData,
        originalFilename: originalFilename,
    )
    
    debugLog("✅ Document submitted via legacy API: \(docId)")
}

/// New function that supports the complete multi-party signing workflow
/// This is the recommended approach for new code
public func submitSignedDocumentFlowV2(
    documentData: Data,
    privateKey: P256.Signing.PrivateKey,
    personaDid: String,
    personaPublicKey: String,
    isPublic: Bool,
    documentId: String,
    originalFilename: String?
) async throws -> (documentId: String, attestEntryID: String) {
    return try await DocumentSigningService.completeSigningWorkflow(
        documentData: documentData,
        originalFilename: originalFilename,
    )
}
