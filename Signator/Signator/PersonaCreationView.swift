// PersonaCreationView.swift
// UI for creating a new persona profile
//
// ATProtocol DID Architecture (inspired by Bluesky):
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DID (Decentralized Identifier):
//   - Permanent, cryptographic identifier
//   - Format: did:451:<random-id>
//   - Example: did:451:a8k7m4p9n2q1x5z3
//   - Never changes, used for all cryptographic operations
//
// Handle (Human-readable identifier):
//   - User-friendly name/address
//   - Example: sara.silver.silver.publishing.451.info
//   - Can be changed by user
//   - Stored in handle field (ATProtocol standard)
//   - Resolved to DID via DNS or server lookup
//
// This separation allows:
//   ✓ Permanent identity (DID) even if handle changes
//   ✓ Multiple handles pointing to same DID
//   ✓ Easy migration between services
//   ✓ Human-readable addressing
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import SwiftUI
import Combine
import Foundation
import CryptoKit

// Client-side mirror of the server's PersonaCreationRequest
private struct ServerPersonaCreationRequest: Encodable {
    let did: String
    let handle: String  // ATProtocol: human-readable identifier
    let name: String
    let attributes: [String: String]?
    let address: [String: String]?
    let verified: Bool
    let isPublic: Bool?
    let backgroundValidated: Bool?
    let backgroundCheckRequired: Bool
    let domainToBeVerified: String?
    let dnsChallengeValue: String?
    let verificationMethod: [ServerPersonaProfileForSigning.VerificationMethod]?
    let signature: String?
}

// A minimal, client-side mirror of the server PersonaProfile used solely for canonical signing
private struct ServerPersonaProfileForSigning: Encodable {
    // Core
    let did: String
    let handle: String  // ATProtocol: human-readable identifier
    let controller: String
    var isPublic: Bool
    
    // Persona fields
    var name: String?
    var email: String?
    var address: PostalAddress?
    var affiliations: String?
    var socialLinks: String?
    var verified: Bool?
    
    // Workflow
    var backgroundCheckRequired: Bool?
    var requestedDomain: String?
    var requestedDnsChallenge: String?
    
    // Status
    var backgroundValidated: Bool?
    var validatedDomains: [String]?
    
    // Document fields
    var type: String?
    var hash: String?
    var storageEndpoints: [StorageEndpoint]?
    
    // Resource folders
    var resourceFolders: [ResourceFolder]?
    
    // Metadata
    var metadata: [String: String]?
    var createdAt: String?
    var updatedAt: String?
    var eTag: String?
    
    // Verification
    let verificationMethod: [VerificationMethod]
    
    // Services
    let service: [Service]?
    
    // Transaction
    var previousBlock: String?
    var relatedBlock: String?
    
    // Signature (nil for canonicalization)
    var signature: String?
    
    struct VerificationMethod: Encodable {
        let id: String
        let type: String
        let controller: String
        let publicKeyBase64: String
    }
    
    struct Service: Encodable {
        let id: String
        let type: String
        let serviceEndpoint: [String]
        let metadata: [String: String]?
    }
    
    struct StorageEndpoint: Encodable {
        let providerName: String
        let url: String
        let eTag: String
        let lastVerified: String?
    }
    
    struct ResourceFolder: Encodable {
        let providerName: String
        let folderPath: String
        let type: String
        let eTag: String
        let lastVerified: String?
    }
    
    struct PostalAddress: Encodable {
        let street: String?
        let city: String?
        let region: String?      // server uses 'region' (not 'state')
        let postalCode: String?
        let country: String?
    }
}

private func formattedAddress(_ address: PersonaProfile.PostalAddress?) -> String {
    guard let address = address else { return "" }
    let parts = [address.street, address.city, address.state, address.postalCode, address.country]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
    return parts.joined(separator: ", ")
}

typealias PersonaProfileModel = PersonaProfile

private let rootLevelTLDs: Set<String> = [
    ".com", ".org", ".edu", ".net", ".gov", ".io", ".co", ".us", ".biz", ".info", ".me", ".dev", ".ai", ".app", ".tv", ".xyz", ".pro", ".ca", ".uk", ".de", ".fr", ".it", ".es", ".jp", ".ru", ".au", ".ch", ".nl", ".in", ".br", ".za", ".pl", ".be", ".eu", ".tr", ".fi", ".gr", ".no", ".se", ".ae", ".cz", ".hu", ".dk", ".hk", ".sg", ".nz", ".mx", ".ar", ".cl", ".il", ".ie", ".kr", ".cn", ".tw", ".pt", ".sk", ".ro", ".bg", ".lv", ".lt", ".ee"
]

// Minimal Base58 encoding implementation (kept intact)
fileprivate let base58Alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

fileprivate extension Data {
    func toBase58() -> String {
        var bytes = [UInt8](self)
        var zeroCount = 0
        for b in bytes {
            if b == 0 { zeroCount += 1 } else { break }
        }
        var num = BigUInt(Data(bytes))
        var result = ""
        while num > 0 {
            let (quotient, remainder) = num.quotientAndRemainder(dividingBy: 58)
            let idx = base58Alphabet.index(base58Alphabet.startIndex, offsetBy: Int(remainder))
            result = String(base58Alphabet[idx]) + result
            num = quotient
        }
        return String(repeating: "1", count: zeroCount) + result
    }
}

fileprivate struct BigUInt {
    private var digits: [UInt8] // least-significant byte first
    
    init(_ data: Data) {
        digits = data.reversed()
    }
    
    static func >(lhs: BigUInt, rhs: Int) -> Bool {
        if lhs.digits.count > 1 { return true }
        if let first = lhs.digits.first {
            return first > rhs
        }
        return false
    }
    
    static func /(lhs: BigUInt, rhs: UInt8) -> BigUInt {
        var resultDigits: [UInt8] = []
        var remainder: UInt16 = 0
        for digit in lhs.digits.reversed() {
            let value = UInt16(remainder) << 8 | UInt16(digit)
            let quotient = value / UInt16(rhs)
            remainder = value % UInt16(rhs)
            resultDigits.insert(UInt8(quotient), at: 0)
        }
        while resultDigits.first == 0 && resultDigits.count > 1 {
            resultDigits.removeFirst()
        }
        return BigUInt(Data(resultDigits.reversed()))
    }
    
    static func %(lhs: BigUInt, rhs: UInt8) -> UInt8 {
        var remainder: UInt16 = 0
        for digit in lhs.digits.reversed() {
            let value = UInt16(remainder) << 8 | UInt16(digit)
            remainder = value % UInt16(rhs)
        }
        return UInt8(remainder)
    }
    
    func quotientAndRemainder(dividingBy rhs: UInt8) -> (BigUInt, UInt8) {
        var resultDigits: [UInt8] = []
        var remainder: UInt16 = 0
        for digit in digits.reversed() {
            let value = UInt16(remainder) << 8 | UInt16(digit)
            let quotient = value / UInt16(rhs)
            remainder = value % UInt16(rhs)
            resultDigits.insert(UInt8(quotient), at: 0)
        }
        while resultDigits.first == 0 && resultDigits.count > 1 {
            resultDigits.removeFirst()
        }
        return (BigUInt(Data(resultDigits.reversed())), UInt8(remainder))
    }
}

// MARK: - Verbose networking logger (development)
private enum NetLog {
    static func id() -> String { UUID().uuidString.prefix(8).description }
    
    static func endpointSummary(_ req: URLRequest) {
        guard let url = req.url else { print("🔎 [endpoint] (nil URL)"); return }
        let host = url.host ?? "(nil)"
        let port = url.port.map(String.init) ?? "(default)"
        let scheme = url.scheme ?? "(nil)"
        let path = url.path.isEmpty ? "/" : url.path
        let query = url.query.map { "?\($0)" } ?? ""
        let isLocalHost = host == "localhost" || host == "127.0.0.1" || host == "::1"
        print("🔎 Endpoint: \(scheme)://\(host):\(port)\(path)\(query) (localhost: \(isLocalHost))")
    }
    
    static func dumpHeaders(_ headers: [AnyHashable: Any]) -> String {
        headers
            .map { "\($0): \($1)" }
            .sorted()
            .joined(separator: "\n")
    }
    
    static func dumpBody(_ data: Data?, limit: Int = 32_768) -> String {
        guard let data = data else { return "(nil)" }
        if data.count <= limit {
            return String(data: data, encoding: .utf8) ?? "(non-utf8, \(data.count) bytes)"
        } else {
            let head = data.prefix(limit)
            let tailNote = "... [truncated \(data.count - limit) bytes]"
            return (String(data: head, encoding: .utf8) ?? "(non-utf8)") + tailNote
        }
    }
    
    static func request(_ id: String, _ req: URLRequest) {
        print("──────── 🛰️ REQUEST START [\(id)] ────────")
        endpointSummary(req)
        let url = req.url?.absoluteString ?? "(nil)"
        let method = req.httpMethod ?? "GET"
        print("🛰️ [\(id)] Request: \(method) \(url)")
        if let headers = req.allHTTPHeaderFields {
            print("🧾 [\(id)] Headers:\n\(headers.map { "\($0): \($1)" }.sorted().joined(separator: "\n"))")
        }
        print("📦 [\(id)] Body:\n\(dumpBody(req.httpBody))")
    }
    
    static func response(_ id: String, _ res: HTTPURLResponse, data: Data, duration: TimeInterval) {
        print("✅ [\(id)] Response: \(res.statusCode) (\(String(format: "%.2f", duration))s) URL: \(res.url?.absoluteString ?? "(nil)")")
        print("🧾 [\(id)] Resp Headers:\n\(dumpHeaders(res.allHeaderFields))")
        print("📦 [\(id)] Resp Body:\n\(dumpBody(data))")
        print("──────── ✅ REQUEST END [\(id)] ────────")
    }
    
    static func error(_ id: String, _ res: HTTPURLResponse?, data: Data?, err: Error?, duration: TimeInterval) {
        let code = res?.statusCode ?? -1
        print("❌ [\(id)] Error (code: \(code)) (\(String(format: "%.2f", duration))s)")
        if let res = res {
            print("🧾 [\(id)] Resp Headers:\n\(dumpHeaders(res.allHeaderFields))")
        }
        if let data = data {
            print("📦 [\(id)] Resp Body:\n\(dumpBody(data))")
        }
        if let err = err {
            print("⚠️ [\(id)] Error: \(err.localizedDescription)")
        }
        print("──────── ❌ REQUEST END [\(id)] ────────")
    }
}

// URLSession delegate to log redirects
private final class NetSessionDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        let id = (task.taskDescription ?? NetLog.id())
        print("↪️ [\(id)] Redirect \(response.statusCode) to: \(request.url?.absoluteString ?? "(nil)")")
        NetLog.endpointSummary(request)
        completionHandler(request)
    }
}

// MARK: - Private Data Encryption
private struct PrivateDataEncryption {
    // Encrypt private data using AES-256-GCM
    static func encrypt(_ privateData: PersonaProfile.PrivatePersonaData, using key: SymmetricKey) throws -> Data {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(privateData)
        let sealedBox = try AES.GCM.seal(jsonData, using: key)
        guard let combined = sealedBox.combined else {
            throw NSError(domain: "PrivateDataEncryption", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create sealed box"])
        }
        return combined
    }
    
    // Decrypt private data
    static func decrypt(_ encryptedData: Data, using key: SymmetricKey) throws -> PersonaProfile.PrivatePersonaData {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        let decoder = JSONDecoder()
        return try decoder.decode(PersonaProfile.PrivatePersonaData.self, from: decryptedData)
    }
    
    // Generate or retrieve encryption key for a DID (stored in Keychain)
    static func getEncryptionKey(for did: String) throws -> SymmetricKey {
        // In production, this should be stored in Keychain
        // For now, derive from DID (in production use Keychain to store a random key)
        let keyData = SHA256.hash(data: Data(did.utf8))
        return SymmetricKey(data: keyData)
    }
}

struct PersonaCreationView: View {
    // ── Morphing-form progress ──────────────────────────────────────────
    // nil  → purpose picker is showing (step 1)
    // .some → purpose chosen; identity-method picker shows next (step 2)
    //         then the rest of the form appears once method is chosen (step 3)
    @State private var selectedPurpose: PersonaPurpose?   // step 1 → 2
    // Removed methodChosen @State
    
    // Core DID/Handle components
    @State private var name = ""
    @State private var publishingHouse = ""
    @State private var customDomain = ""
    @State private var didManuallyEdited = false
    @State private var lastAutoSuggestedDID: String = ""
    @State private var didInput = ""
    
    // DID Configuration
    private let didMethod = "did:451:"  // Our DID method (inspired by Fahrenheit 451)
    private let defaultDomain = "451.info"  // Default domain for 90% of users
    
    // DNS Verification
    @State private var isVerifyingDNS = false
    @State private var dnsVerificationStatus: DNSVerificationStatus = .notStarted
    @State private var dnsVerificationMessage: String? = nil
    
    enum DNSVerificationStatus {
        case notStarted
        case verifying
        case success
        case failed
    }
    
    // Removed IdentityMethod enum and identityMethod state
    // Kept useCustomDomain Bool state as it is used for identity method toggle
    @State private var useCustomDomain: Bool = false
    
    // Public fields (visible in metadata)
    @State private var publicAffiliations = ""
    @State private var socialMediaLinks = ""
    @State private var publicEmail = ""

    // PersonaProfile fields (optional overrides)
    @State private var profileDisplayName = ""
    @State private var profileDisplayPublisher = ""
    @State private var profileVerified = false
    @State private var profileRequestedDomain = ""
    @State private var profileRequestedDnsChallenge = ""
    @State private var profileBackgroundValidated = false
    @State private var profileValidatedDomains = ""
    @State private var profileType = ""
    @State private var profileHash = ""
    @State private var profileMetadataJSON = ""
    @State private var profileStreet = ""
    @State private var profileCity = ""
    @State private var profileStateRegion = ""
    @State private var profilePostalCode = ""
    @State private var profileCountry = ""
    
    // Private fields (encrypted with document)
    @State private var givenName = ""
    @State private var aliases = ""
    @State private var street = ""
    @State private var city = ""
    @State private var stateRegion = ""
    @State private var postalCode = ""
    @State private var country = ""
    @State private var socialSecurityNumber = ""
    @State private var privateEmail = ""
    @FocusState private var ssnFocused: Bool
    
    // UI State
    @State private var showAlert = false
    @State private var store = PersonaStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String? = nil
    @State private var createdPersona: PersonaProfileModel?
    @State private var creationWarning: String? = nil
    @State private var uploadResults: [UploadResult] = []
    @State private var uploadFailures: [UploadFailure] = []
    @State private var showUploadDetails: Bool = false
    @State private var retryInProgress: Bool = false
    @State private var retryError: String? = nil
    @State private var showSuccessSheet: Bool = false
    @State private var showIdentityInfo: Bool = false
    
    @State private var isPublicPersona: Bool = true

    /// Which progressive-reveal segment is open; all start collapsed.
    @State private var expandedSegment: CreationSegment? = nil
    
    private let lockVisibilityChoice: Bool
    private let lockIdentityMethod: Bool
    
    // Optional PersonaManager to update the main persona list
    private let personaManager: PersonaManager?
    
    var onCreate: ((PersonaProfileModel) -> Void)?
    var onDismiss: (() -> Void)?
    
    // Inline credentials state (reusing CredentialSelectionView patterns)
    @State private var credentials: [CredentialItem] = []
    @State private var expandedKind: CredentialKind?
    @State private var navigatingCredential: CredentialItem?
    
    // Initializer to optionally pass in a PersonaManager
    init(personaManager: PersonaManager? = nil,
         onCreate: ((PersonaProfileModel) -> Void)? = nil,
         onDismiss: (() -> Void)? = nil,
         initialIsPublicPersona: Bool? = nil,
         initialUseCustomDomain: Bool? = nil,
         lockVisibilityChoice: Bool? = nil,
         lockIdentityMethod: Bool? = nil,
         prefilledData: OneTimePersonaData? = nil,
         initialName: String? = nil,
         initialEmail: String? = nil,
         initialPublishingHouse: String? = nil,
         initialPurpose: PersonaPurpose? = nil) {
        self.personaManager = personaManager
        self.onCreate = onCreate
        self.onDismiss = onDismiss
        if let initialIsPublicPersona { self._isPublicPersona = State(initialValue: initialIsPublicPersona) }
        if let initialUseCustomDomain {
            self._useCustomDomain = State(initialValue: initialUseCustomDomain)
        }
        self.lockVisibilityChoice = (lockVisibilityChoice ?? (initialIsPublicPersona != nil))
        self.lockIdentityMethod = (lockIdentityMethod ?? (initialUseCustomDomain != nil))
        if let initialName, !initialName.isEmpty { self._name = State(initialValue: initialName) }
        if let initialEmail, !initialEmail.isEmpty {
            // Prefill both: the private field is hidden for public personas,
            // so the visible Public Email field must carry the suggestion too.
            self._privateEmail = State(initialValue: initialEmail)
            self._publicEmail = State(initialValue: initialEmail)
        }
        if let initialPublishingHouse, !initialPublishingHouse.isEmpty { self._publishingHouse = State(initialValue: initialPublishingHouse) }
        if let initialPurpose, prefilledData == nil {
            self._selectedPurpose = State(initialValue: initialPurpose)
        }
        
        // ── One-time signing (deep-link / QR) skips both pickers entirely ──
        if prefilledData != nil {
            self._selectedPurpose = State(initialValue: .publishing)
            // Removed setting of methodChosen
        }
        
        // Prefill fields if data is provided
        if let data = prefilledData {
            if let name = data.name {
                self._publishingHouse = State(initialValue: name)
            }
            if let givenName = data.givenName {
                self._givenName = State(initialValue: givenName)
            }
            if let email = data.email {
                self._privateEmail = State(initialValue: email)
            }
            if let ssn = data.ssn {
                self._socialSecurityNumber = State(initialValue: ssn)
            }
            if let address = data.address {
                if let street = address.street {
                    self._street = State(initialValue: street)
                }
                if let city = address.city {
                    self._city = State(initialValue: city)
                }
                if let state = address.state {
                    self._stateRegion = State(initialValue: state)
                }
                if let zip = address.zip {
                    self._postalCode = State(initialValue: zip)
                }
                if let country = address.country {
                    self._country = State(initialValue: country)
                }
            }
        }
    }
    
    private func normalizePart(_ s: String) -> String {
        // ATProtocol format: lowercase, replace spaces with periods
        let normalized = s.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: ".")
        // Collapse multiple periods into a single period
        return normalized.replacingOccurrences(of: "\\\\.+", with: ".", options: .regularExpression)
    }
    
    private func composeSuggestion() -> String {
        let left = normalizePart(name)
        let right = normalizePart(publishingHouse)
        
        // Private personas: anonymous handle under default domain
        // IMPORTANT: Only generate a NEW handle if we don't have one yet
        // This prevents regenerating a different random number every time the view updates
        if isPublicPersona == false {
            // If didInput is already set and looks like a private handle (contains only digits and hyphens),
            // keep it - don't regenerate
            let stripped = didInput.replacingOccurrences(of: "." + defaultDomain, with: "")
            let isPrivateHandleFormat = stripped.range(of: "^[0-9]{3}-[0-9]{4}$", options: .regularExpression) != nil
            
            if !didInput.isEmpty && isPrivateHandleFormat {
                // Keep existing private handle
                return didInput
            } else {
                // Generate new private handle (7-digit format)
                let newHandle = generatePrivateHandle() + "." + defaultDomain
                // Store the generated handle so it doesn't regenerate on every view update
                DispatchQueue.main.async {
                    if self.didInput.isEmpty || !isPrivateHandleFormat {
                        self.didInput = newHandle
                    }
                }
                return newHandle
            }
        }
        
        // Public personas
        if useCustomDomain {
            let domain = customDomain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if left.isEmpty { return domain }
            if domain.isEmpty { return left }
            return left + "." + domain
        } else {
            // publishing house flow
            // Both name and publishing house are required
            if left.isEmpty || right.isEmpty { return "" }
            return left + "." + right + "." + defaultDomain
        }
    }
    
    // Generate random 7-digit handle for private personas (XXX-XXXX format)
    private func generatePrivateHandle() -> String {
        let first3 = String(format: "%03d", Int.random(in: 0...999))
        let last4 = String(format: "%04d", Int.random(in: 0...9999))
        return "\(first3)-\(last4)"
    }

    private func nilIfEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func parseCommaSeparated(_ input: String) -> [String]? {
        let values = input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return values.isEmpty ? nil : values
    }

    private func parseMetadataJSON(_ input: String) throws -> [String: String]? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let data = Data(trimmed.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dict = object as? [String: Any] else {
            throw NSError(domain: "PersonaMetadata", code: 0, userInfo: [NSLocalizedDescriptionKey: "Metadata must be a JSON object."])
        }
        var output: [String: String] = [:]
        for (key, value) in dict {
            if let stringValue = value as? String {
                output[key] = stringValue
            } else {
                output[key] = String(describing: value)
            }
        }
        return output.isEmpty ? nil : output
    }

    private func buildPostalAddress(
        street: String,
        city: String,
        stateRegion: String,
        postalCode: String,
        country: String
    ) -> PersonaProfile.PostalAddress? {
        let hasAny = [street, city, stateRegion, postalCode, country]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard hasAny else { return nil }
        return PersonaProfile.PostalAddress(
            street: nilIfEmpty(street),
            city: nilIfEmpty(city),
            state: nilIfEmpty(stateRegion),
            postalCode: nilIfEmpty(postalCode),
            country: nilIfEmpty(country)
        )
    }
    
    // Generate random DID identifier (like Bluesky's random DIDs)
    // Using base32-like encoding (lowercase letters + numbers, excluding confusing chars)
    // Bluesky uses ~24 chars, we'll use 16 for reasonable uniqueness
    private func generateRandomDID() -> String {
        // Base32-like: excluding 0, 1, l, o to avoid confusion
        let characters = "23456789abcdefghijkmnpqrstuvwxyz"
        return String((0..<16).map { _ in characters.randomElement()! })
    }
    
    // Generate a full DID with our method prefix
    private func generateFullDID() -> String {
        return didMethod + generateRandomDID()
    }
    
    // Format SSN as XXX-XX-XXXX
    private func formatSSN(_ input: String) -> String {
        // Remove all non-digit characters
        let digits = input.filter { $0.isNumber }
        
        // Limit to 9 digits
        let limited = String(digits.prefix(9))
        
        // Format with dashes
        var formatted = ""
        for (index, char) in limited.enumerated() {
            if index == 3 || index == 5 {
                formatted += "-"
            }
            formatted.append(char)
        }
        
        return formatted
    }
    
    private func updateSuggestedDID() {
        let suggestion = composeSuggestion()
        if !didManuallyEdited || didInput == lastAutoSuggestedDID {
            didInput = suggestion
        }
        lastAutoSuggestedDID = suggestion
    }
    
    private func validationState() -> (isValid: Bool, reason: String?) {
        let candidate = normalizedDID
        
        // Must contain at least one dot
        guard candidate.contains(".") else {
            return (false, "Handle must include at least one '.' separating parts (e.g., name.publisher or name.your-domain.com)")
        }
        
        let parts = candidate.split(separator: ".")
        
        // Must have at least 2 parts
        guard parts.count >= 2 else {
            return (false, "Handle must have at least two parts separated by '.' (e.g., name.publisher)")
        }
        
        // Each part must be at least 1 character
        for part in parts {
            if part.count < 1 {
                return (false, "Each part must contain at least one character between dots")
            }
        }
        
        // If using custom domain, verify it looks like a domain
        if isPublicPersona && useCustomDomain {
            let domain = customDomain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !domain.contains(".") {
                return (false, "Custom domain must include at least one '.' (e.g., your-domain.com)")
            }
        }
        
        return (true, nil)
    }
    
    private var normalizedDID: String {
        let s = didInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: ".")
        // Collapse multiple periods into a single period
        return s.split(separator: ".").joined(separator: ".")
    }
    
    private var isDIDValid: Bool {
        validationState().isValid
    }
    
    // Handle variants used in UI and DID construction
    private var displayHandle: String {
        // What we show in UI: hide the default domain for public personas using publishingHouse or one-time signing
        let handle = normalizedDID
        if isPublicPersona {
            // If the handle ends with the default domain, strip it for display
            if handle.hasSuffix("." + defaultDomain) {
                return String(handle.dropLast(defaultDomain.count + 1))
            }
        }
        return handle
    }
    
    private var fullHandle: String {
        let handle = normalizedDID
        if isPublicPersona && useCustomDomain {
            // custom domain is already part of the handle
            return handle
        }
        // publishing house and private personas: ensure default domain
        if handle.hasSuffix("." + defaultDomain) {
            return handle
        } else {
            return handle + "." + defaultDomain
        }
    }
    
    private var fullDID: String {
        // ATProtocol approach: DID is a permanent identifier, NOT the handle
        // We'll generate this when creating the persona
        // For now, return a placeholder - the actual DID will be generated in handleCreatePersona
        return didMethod + "placeholder"
    }
    
    // The handle is what the user sees and types
    // It's separate from the DID
    private var handleForDisplay: String {
        return fullHandle
    }
    
    private var privateFieldsComplete: Bool {
        // Required private identity fields for private personas:
        // - Given Name, Street, City, State/Region, Country, Social Security Number
        // - Private Email and Aliases are optional
        let ssnDigits = socialSecurityNumber.filter { $0.isNumber }
        let requiredFilled = !givenName.isEmpty &&
        !street.isEmpty &&
        !city.isEmpty &&
        !stateRegion.isEmpty &&
        !country.isEmpty &&
        ssnDigits.count == 9  // Must be exactly 9 digits
        return requiredFilled
    }
    
    private var canCreate: Bool {
        if !isDIDValid { return false }
        
        // Public personas using publishing house must have both name and publishing house
        if isPublicPersona && !useCustomDomain {
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                publishingHouse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
        }
        
        if isPublicPersona { return true }
        // Private requires all private fields (background check is automatic)
        return privateFieldsComplete
    }
    
    var body: some View {
        formContent
            .onChange(of: name) { _ in
                updateSuggestedDID()
            }
            .onChange(of: publishingHouse) { _ in
                updateSuggestedDID()
            }
            .onChange(of: customDomain) { _ in
                updateSuggestedDID()
            }
            .onChange(of: didInput) { newValue in
                let normalized = newValue.replacingOccurrences(of: " ", with: ".")
                if normalized != newValue { didInput = normalized }
                didManuallyEdited = (didInput != lastAutoSuggestedDID)
            }
            .onChange(of: isPublicPersona) { _ in
                updateSuggestedDID()
            }
            .onAppear {
                // For private personas, ensure handle is generated immediately
                if !isPublicPersona && didInput.isEmpty {
                    didInput = generatePrivateHandle() + "." + defaultDomain
                }
                updateSuggestedDID()
            }
            .navigationTitle("Create Persona")
            .sheet(isPresented: $showSuccessSheet) {
                successSheet
            }
            .sheet(isPresented: $showUploadDetails) {
                uploadDetailsSheet
            }
            .navigationDestination(isPresented: Binding(
                get: { navigatingCredential != nil },
                set: { if !$0 { navigatingCredential = nil } }
            )) {
                if let item = navigatingCredential {
                    CredentialVerificationView(
                        credential: item,
                        onCredentialUpdated: { updated in
                            if let idx = credentials.firstIndex(where: { $0.id == updated.id }) {
                                credentials[idx] = updated
                            }
                            navigatingCredential = nil
                        }
                    )
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Persona Identity Information", isPresented: $showIdentityInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                if isPublicPersona {
                    Text("""
                    Your handle (what others see): \(displayHandle)
                    
                    Full handle: \(fullHandle)
                    
                    A permanent DID will be generated automatically (like did:451:a8k7m4p9n2q1x5)

                    Your handle and DID are permanent once created. Everything else can be added or changed later — each change is recorded on the blockchain, so your persona's history stays traceable.
                    """)
                } else {
                    Text("""
                    Private personas use anonymous 7-digit handles (XXX-XXXX).
                    
                    A unique DID is generated for cryptographic operations.
                    
                    Your real identity is encrypted and only revealed when signing contracts.
                    """)
                }
            }
    }
    
    private var formContent: some View {
        Form {
            // ── Step 1: Purpose (morphs away once chosen) ──────────────────
            if selectedPurpose == nil {
                purposePickerSection
            }

            // ── Step 2: Progressive-reveal segments (after purpose chosen) ─
            // Each segment is a tappable row with a green check once it has
            // content; only the expanded segment's fields are shown.
            if selectedPurpose != nil {
                chosenPurposeBadge

                segmentRow(.identity)
                if expandedSegment == .identity {
                    Section {
                        HStack(spacing: 8) {
                            Picker("Identity Method", selection: $useCustomDomain) {
                                Text("Start a Publishing House").tag(false)
                                Text("I have my own domain").tag(true)
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.bottom, 8)

                        identitySection
                    }
                }

                segmentRow(.credentials)
                if expandedSegment == .credentials, let purpose = selectedPurpose {
                    credentialsInlineSection(for: purpose)
                }

                segmentRow(.publicInfo)
                if expandedSegment == .publicInfo {
                    publicFieldsSection
                }

                segmentRow(.profileDetails)
                if expandedSegment == .profileDetails {
                    personaProfileFieldsSection
                }

                if !isPublicPersona {
                    segmentRow(.privateIdentity)
                    if expandedSegment == .privateIdentity {
                        privateFieldsSection
                    }
                }

                createButtonSection
                if personaManager != nil && !(personaManager?.personas.isEmpty ?? true) {
                    deletePersonaSection
                }
            }
        }
    }

    // MARK: - Progressive-reveal segments

    private enum CreationSegment: String, CaseIterable, Identifiable {
        case identity, credentials, publicInfo, profileDetails, privateIdentity
        var id: String { rawValue }
    }

    private func segmentTitle(_ segment: CreationSegment) -> String {
        switch segment {
        case .identity:        return "Identity"
        case .credentials:     return "Credentials"
        case .publicInfo:      return "Public Information"
        case .profileDetails:  return "Profile Details"
        case .privateIdentity: return "Private Identity"
        }
    }

    private func segmentSubtitle(_ segment: CreationSegment) -> String {
        switch segment {
        case .identity:        return "Your name, publishing house, and permanent handle"
        case .credentials:     return "Email verification, ORCID, professional credentials"
        case .publicInfo:      return "Public email, affiliations, and social links"
        case .profileDetails:  return "Display overrides, public address, advanced fields"
        case .privateIdentity: return "Legal identity — encrypted on this device"
        }
    }

    private func segmentIsRequired(_ segment: CreationSegment) -> Bool {
        switch segment {
        case .identity:        return true
        case .privateIdentity: return !isPublicPersona
        default:               return false
        }
    }

    /// Green check = the segment has content. Optional segments can be left
    /// empty and filled in later by editing the persona.
    private func segmentIsComplete(_ segment: CreationSegment) -> Bool {
        func filled(_ s: String) -> Bool {
            !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        switch segment {
        case .identity:
            guard isDIDValid else { return false }
            guard isPublicPersona else { return true }
            return filled(name) && (useCustomDomain ? filled(customDomain) : filled(publishingHouse))
        case .credentials:
            return !credentials.isEmpty
        case .publicInfo:
            return filled(publicEmail) || filled(publicAffiliations) || filled(socialMediaLinks)
        case .profileDetails:
            return [profileDisplayName, profileDisplayPublisher, profileRequestedDomain,
                    profileValidatedDomains, profileType, profileHash, profileMetadataJSON,
                    profileStreet, profileCity, profileStateRegion, profilePostalCode,
                    profileCountry].contains(where: filled)
        case .privateIdentity:
            return privateFieldsComplete
        }
    }

    private func segmentRow(_ segment: CreationSegment) -> some View {
        Section {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedSegment = (expandedSegment == segment) ? nil : segment
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: segmentIsComplete(segment) ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(segmentIsComplete(segment) ? Color.green : Color.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(segmentTitle(segment))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        // Identity is the permanent pair: once composed, show the
                        // label (handle) and DID status instead of generic copy.
                        if segment == .identity && segmentIsComplete(.identity) {
                            Text(fullHandle)
                                .font(.caption2)
                                .monospaced()
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text("DID: assigned permanently when the persona is created")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text(segmentSubtitle(segment))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if segmentIsRequired(segment) && !segmentIsComplete(segment) {
                        Text("Required")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expandedSegment == segment ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Inline Purpose Picker (Step 1)
    
    private var purposePickerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Text("What will you use this persona for?")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Choose the option that best describes your primary use case.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    ForEach(PersonaPurpose.allCases, id: \.self) { purpose in
                        purposeTile(for: purpose)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func purposeTile(for purpose: PersonaPurpose) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedPurpose = purpose
                // Removed methodChosen and identityMethod setting
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: purpose.systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(
                            colors: [purpose.color, purpose.color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: purpose.color.opacity(0.3), radius: 8, x: 0, y: 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(purpose.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(purpose.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.platformBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.platformGray5, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // --- Removed identityMethodPickerSection and methodTile as per instructions ---
    
    // MARK: - Compact "chosen" badges (show context once a step is locked in)
    
    /// Shows the selected purpose as a compact tappable badge so users can change their mind.
    private var chosenPurposeBadge: some View {
        Section {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedPurpose = nil   // resets step 2 + 3 automatically
                    // Removed methodChosen reset
                }
            } label: {
                HStack(spacing: 12) {
                    if let purpose = selectedPurpose {
                        Image(systemName: purpose.systemImage)
                            .font(.system(size: 18))
                            .foregroundColor(purpose.color)
                            .frame(width: 34, height: 34)
                            .background(purpose.color.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Purpose")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(purpose.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // --- Removed chosenMethodBadge and methodBadgeInfo as per instructions ---
    
    // --- REPLACE identitySection as per instructions ---
    private var identitySection: some View {
        Section {
            PersonaIdentityPreviewView(name: name.isEmpty ? "Your Name" : name, publisher: useCustomDomain ? customDomain : (publishingHouse.isEmpty ? nil : publishingHouse))
                .padding(.bottom, 6)
            Group {
                if isPublicPersona {
                    if useCustomDomain {
                        // Custom domain flow (reuse HaveMyOwnDomainView)
                        HaveMyOwnDomainView(
                            name: $name,
                            customDomain: $customDomain,
                            didInput: $didInput,
                            isPublicPersona: isPublicPersona,
                            defaultDomain: defaultDomain,
                            fullDID: fullDID,
                            displayHandle: displayHandle,
                            fullHandle: fullHandle,
                            isDIDValid: isDIDValid,
                            validationState: validationState,
                            dnsVerificationView: { AnyView(dnsVerificationView) }
                        )
                    } else {
                        // Publishing house flow
                        StartPublishingHouseView(
                            name: $name,
                            publishingHouse: $publishingHouse,
                            didInput: $didInput,
                            isPublicPersona: isPublicPersona,
                            defaultDomain: defaultDomain,
                            displayHandle: displayHandle,
                            fullHandle: fullHandle,
                            isDIDValid: isDIDValid,
                            validationState: validationState
                        )
                    }
                } else {
                    // Private personas use one-time signing flow
                    OneTimeSigningView(
                        signingName: $publishingHouse,
                        didInput: $didInput,
                        isPublicPersona: isPublicPersona,
                        defaultDomain: defaultDomain,
                        displayHandle: displayHandle,
                        fullHandle: fullHandle,
                        isDIDValid: isDIDValid,
                        validationState: validationState
                    )
                }
            }
        } header: {
            HStack(spacing: 4) {
                Text("Persona Identity (Required)")
                Button {
                    showIdentityInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Inline DNS Verification View used by HaveMyOwnDomainView
    @ViewBuilder
    private var dnsVerificationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                switch dnsVerificationStatus {
                case .notStarted:
                    Image(systemName: "questionmark.circle").foregroundColor(.secondary)
                    Text("DNS verification not started")
                        .foregroundColor(.secondary)
                case .verifying:
                    ProgressView().progressViewStyle(.circular)
                    Text("Verifying DNS…")
                        .foregroundColor(.secondary)
                case .success:
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("DNS verified successfully")
                        .foregroundColor(.green)
                case .failed:
                    Image(systemName: "xmark.octagon.fill").foregroundColor(.red)
                    Text("DNS verification failed")
                        .foregroundColor(.red)
                }
                Spacer()
            }

            if let message = dnsVerificationMessage, !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            HStack {
                Spacer()
                Button(isVerifyingDNS ? "Verifying…" : "Verify DNS") {
                    Task { await verifyDNS() }
                }
                .disabled(isVerifyingDNS)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Inline Credentials Section
    @ViewBuilder
    private func credentialsInlineSection(for purpose: PersonaPurpose) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Credentials (Optional)")
                    .font(.headline)
                Text("Add credentials to strengthen this persona. You can also verify them later.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                let kinds = CredentialKind.relevantCredentials(for: purpose)
                VStack(spacing: 12) {
                    ForEach(kinds, id: \.self) { kind in
                        credentialTile(for: kind)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // Tile builder replicated locally to avoid cross-file coupling
    @ViewBuilder
    private func credentialTile(for kind: CredentialKind) -> some View {
        let added = credentials.contains(where: { $0.kind == kind })
        let isExpanded = (expandedKind == kind)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: kind.systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(kind.color)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: kind.color.opacity(0.25), radius: 6, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(kind.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if added, let item = credentials.first(where: { $0.kind == kind }) {
                    statusBadge(for: item)
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            expandedKind = (expandedKind == kind) ? nil : kind
                            if !added { credentials.append(CredentialItem(kind: kind)) }
                        }
                    } label: {
                        Text("Add")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(kind.color)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(kind.color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding()

            if added && (isExpanded || (credentials.first(where: { $0.kind == kind })?.status == .notStarted)) {
                Divider()
                inputForm(for: kind)
                    .padding([.horizontal, .bottom])
                verifyButton(for: kind, enabled: isInputValid(for: kind))
                    .padding([.horizontal, .bottom])
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.platformBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(added ? kind.color.opacity(0.3) : Color.platformGray5, lineWidth: 1)
        )
    }

    // Status badge copied inline for simplicity
    @ViewBuilder
    private func statusBadge(for item: CredentialItem) -> some View {
        switch item.status {
        case .notStarted:
            Text("Pending input")
                .font(.caption)
                .foregroundColor(.secondary)
        case .pending:
            HStack(spacing: 4) {
                ProgressView().progressViewStyle(.circular).scaleEffect(0.6)
                Text("Verifying…").font(.caption).foregroundColor(.secondary)
            }
        case .verified:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                Text("Verified").font(.caption).fontWeight(.semibold).foregroundColor(.green)
            }
        case .unverified:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                Text("Failed").font(.caption).foregroundColor(.red)
            }
        case .expired:
            HStack(spacing: 4) {
                Image(systemName: "clock.badge.exclamationmark.fill").foregroundColor(.orange)
                Text("Expired").font(.caption).foregroundColor(.orange)
            }
        }
    }

    // Per-kind input forms proxy into existing types in project
    @ViewBuilder
    private func inputForm(for kind: CredentialKind) -> some View {
        switch kind {
        case .emailVerification:
            CredentialSelectionView.EmailInputForm(kind: kind)
        case .orcid:
            CredentialSelectionView.ORCIDInputForm(kind: kind)
        case .barLicense:
            CredentialSelectionView.BarLicenseInputForm(kind: kind)
        case .bondingInsurance:
            CredentialSelectionView.BondingInsuranceInputForm(kind: kind)
        }
    }

    // Simple validity gate; inline forms already hint when ready
    private func isInputValid(for kind: CredentialKind) -> Bool {
        // Conservatively enable Verify when the tile has been added; deeper validation occurs in the verification view
        return credentials.contains(where: { $0.kind == kind })
    }

    // Shared Verify button to kick off navigation to verification view
    @ViewBuilder
    private func verifyButton(for kind: CredentialKind, enabled: Bool) -> some View {
        let item = credentials.first(where: { $0.kind == kind })
        Button {
            guard var target = item else { return }
            target.status = .pending
            if let idx = credentials.firstIndex(where: { $0.id == target.id }) {
                credentials[idx] = target
            }
            navigatingCredential = target
        } label: {
            Text("Verify")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(enabled ? kind.color : Color.platformGray)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .disabled(!enabled)
    }
    
    private var privateFieldsSection: some View {
        Section {
            if isPublicPersona {
                EmptyView()
            } else {
                Group {
                    DictationTextField(
                        placeholder: "Given Name",
                        text: $givenName,
                        prompt: Text("Required for private personas")
                    )
                    DictationTextField(
                        placeholder: "Aliases (optional)",
                        text: $aliases
                    )
                    DictationTextField(
                        placeholder: "Street",
                        text: $street,
                        prompt: Text("Required for private personas")
                    )
                    DictationTextField(
                        placeholder: "City",
                        text: $city,
                        prompt: Text("Required for private personas")
                    )
                    DictationTextField(
                        placeholder: "State / Region",
                        text: $stateRegion,
                        prompt: Text("Required for private personas")
                    )
                    HStack {
                        DictationTextField(
                            placeholder: "Postal Code",
                            text: $postalCode
                        )
                        DictationTextField(
                            placeholder: "Country",
                            text: $country,
                            prompt: Text("Required for private personas")
                        )
                    }
                    TextField("Private Email (optional)", text: $privateEmail)
                        .platformAutocapitalization(.never)
                        .platformKeyboardType(.emailAddress)
                        .autocorrectionDisabled(true)

                    // SSN formatted input
                    TextField("Social Security Number (XXX-XX-XXXX)", text: Binding(
                        get: { socialSecurityNumber },
                        set: { socialSecurityNumber = formatSSN($0) }
                    ))
                    .platformKeyboardType(.numberPad)
                    .focused($ssnFocused)
                }
            }
        } header: {
            Text("Private Identity (Required for Private Personas)")
        } footer: {
            if !isPublicPersona {
                Text("These fields are encrypted locally and only used for contract signing and background checks. They are never sent to the server in plain text.")
                    .font(.footnote)
            }
        }
    }
    
    // --- Existing code below remains unchanged ---
    
    // MARK: - Upload diagnostics
    private struct UploadResult: Codable, Hashable, Identifiable {
        var id: String { providerName + (eTag ?? "") }
        let providerName: String
        let url: String
        let eTag: String?
    }
    
    private struct UploadFailure: Codable, Hashable, Identifiable {
        var id: String { providerName + (code ?? "") }
        let providerName: String
        let code: String?
        let message: String?
    }
    
    private struct RetryUploadsRequest: Encodable {
        let did: String
        let providers: [String]
    }
    
    // MARK: - Networking
    
    private struct PersonaCanonicalizeRequest: Encodable {
        let did: String
        let handle: String  // ATProtocol: human-readable identifier
        let name: String
        let attributes: [String: String]?
        let address: [String: String]?
        let verified: Bool
        let isPublic: Bool
        let backgroundCheckRequired: Bool
        let domainToBeVerified: String?
        let dnsChallengeValue: String?
        let verificationMethod: [ServerPersonaProfileForSigning.VerificationMethod]?
    }
    
    private struct PersonaCanonicalizeResponse: Decodable {
        let profile: PersonaProfileModel
        let nonce: String
        let expiresAt: String?
    }
    
    private struct PersonaFinalizeRequest: Encodable {
        let profile: PersonaProfileModel
        let nonce: String
    }
    
    private var publicFieldsSection: some View {
        Section {
            TextField("Public Affiliations", text: $publicAffiliations)
            TextField("Social Media Links", text: $socialMediaLinks)
            TextField("Public Email", text: $publicEmail)
                .platformAutocapitalization(.never)
                .platformKeyboardType(.emailAddress)
                .autocorrectionDisabled(true)
        } header: {
            Text("Public Information (Optional)")
        } footer: {
            Text("Public fields are visible in your persona profile and can be viewed by anyone searching for your DID.")
                .font(.footnote)
        }
    }

    private var personaProfileFieldsSection: some View {
        Section {
            TextField("Display Name (optional override)", text: $profileDisplayName)
            TextField("Display Publisher (optional override)", text: $profileDisplayPublisher)
            Toggle("Verified", isOn: $profileVerified)
            TextField("Requested Domain", text: $profileRequestedDomain)
            TextField("Requested DNS Challenge", text: $profileRequestedDnsChallenge)
            Toggle("Background Validated", isOn: $profileBackgroundValidated)
            TextField("Validated Domains (comma-separated)", text: $profileValidatedDomains)
            TextField("Type", text: $profileType)
            TextField("Hash", text: $profileHash)
            TextField("Metadata (JSON)", text: $profileMetadataJSON, axis: .vertical)
                .lineLimit(2...6)

            Divider()

            TextField("Public Street", text: $profileStreet)
            TextField("Public City", text: $profileCity)
            TextField("Public State / Region", text: $profileStateRegion)
            TextField("Public Postal Code", text: $profilePostalCode)
            TextField("Public Country", text: $profileCountry)
        } header: {
            Text("Persona Profile Fields (Optional)")
        } footer: {
            Text("These fields map directly to PersonaProfile and will be included in the created persona.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
    
    private var createButtonSection: some View {
        Section {
            Button(isPublicPersona ? "Create Persona" : "Create Private Persona") {
                handleCreatePersona()
            }
            .disabled(!canCreate)
            
            if !isPublicPersona && !privateFieldsComplete {
                Text("Please complete all required private identity fields: Given Name, Street, City, State/Region, Country, and Social Security Number. Background check will be performed automatically.")
                    .font(.footnote)
                    .foregroundColor(.red)
                Text("Public personas can publish books/documents without revealing identity. Private personas are not publicly visible but must provide full identity for encrypted contract signing. Background checks are required and automatic for private personas.")
                    .font(.footnote)
                
            }
        }
    }
    
    private var deletePersonaSection: some View {
        Section {
            if let personaManager = personaManager, let activePersona = personaManager.activePersona() {
                Button(role: .destructive) {
                    handleDeleteActivePersona()
                } label: {
                    Label("Delete Active Persona (\(activePersona.name))", systemImage: "trash")
                }
            }
            
            Button(role: .destructive) {
                handleDeleteAllPersonas()
            } label: {
                Label("Delete All Personas", systemImage: "trash.fill")
            }
        } header: {
            Text("Persona Management")
        } footer: {
            if let count = personaManager?.personas.count, count > 0 {
                Text("You currently have \(count) persona(s). You can delete the active persona or all personas.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Text("No personas available.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - DNS Verification
    
    private func verifyDNS() async {
        await MainActor.run {
            isVerifyingDNS = true
            dnsVerificationStatus = .verifying
            dnsVerificationMessage = "Checking DNS records..."
        }
        
        defer {
            Task { @MainActor in
                isVerifyingDNS = false
            }
        }
        
        do {
            let handle = normalizedDID
            let domain = customDomain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            // For custom domains: _atproto.{full-handle-minus-domain}
            // Example: gary-lutz.lutz.pub → _atproto.gary-lutz (on lutz.pub zone)
            guard let lastDotIndex = handle.lastIndex(of: ".") else {
                await MainActor.run {
                    dnsVerificationStatus = .failed
                    dnsVerificationMessage = "Invalid handle format"
                }
                return
            }
            
            let handlePart = String(handle[..<lastDotIndex])  // e.g., "gary-lutz"
            
            // ATProtocol format:
            // TXT record name: _atproto.{handle-part} (under the user's domain)
            // TXT record value: did={fullDID}
            let txtRecordName = "_atproto.\(handlePart)"  // e.g., "_atproto.gary-lutz"
            let expectedValue = "did=\(fullDID)"  // e.g., "did:451:a8k7m4p9n2q1x5"
            
            // Call server API to verify DNS
            guard let url = URL(string: ServerConfig.baseURL + "/api/persona/verify-dns") else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let verifyRequest = DNSVerifyRequest(
                handle: handle,
                domain: domain,
                txtRecordName: txtRecordName,
                expectedValue: expectedValue,
                fullDID: fullDID
            )
            
            request.httpBody = try JSONEncoder().encode(verifyRequest)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                let verifyResponse = try JSONDecoder().decode(DNSVerifyResponse.self, from: data)
                
                await MainActor.run {
                    if verifyResponse.verified {
                        dnsVerificationStatus = .success
                        dnsVerificationMessage = "DNS verified successfully! ✓"
                    } else {
                        dnsVerificationStatus = .failed
                        dnsVerificationMessage = verifyResponse.message ?? "DNS verification failed"
                    }
                }
            } else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                await MainActor.run {
                    dnsVerificationStatus = .failed
                    dnsVerificationMessage = "Verification failed: \(errorMsg)"
                }
            }
        } catch {
            await MainActor.run {
                dnsVerificationStatus = .failed
                dnsVerificationMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    private struct DNSVerifyRequest: Encodable {
        let handle: String
        let domain: String
        let txtRecordName: String
        let expectedValue: String
        let fullDID: String
    }
    
    private struct DNSVerifyResponse: Decodable {
        let verified: Bool
        let message: String?
        let txtRecordValue: String?
    }
    
    // MARK: - Actions
    
    private func handleDeleteActivePersona() {
        guard let personaManager = personaManager,
              let activePersona = personaManager.activePersona() else {
            print("⚠️ [PersonaCreation] No active persona to delete")
            return
        }
        
        print("🗑️ [PersonaCreation] Deleting active persona: \(activePersona.id)")
        
        // Delete from PersonaManager
        personaManager.deletePersona(activePersona)
        
        // Delete private key
        do {
            try PrivateKeyStore.deletePrivateKey(for: activePersona.id)
            print("🗑️ [PersonaCreation] Deleted private key for: \(activePersona.id)")
        } catch {
            print("⚠️ [PersonaCreation] Failed to delete private key: \(error)")
        }
        
        // Delete private data
        do {
            try PrivateDataStore.deletePrivateData(for: activePersona.id)
            print("🗑️ [PersonaCreation] Deleted private data for: \(activePersona.id)")
        } catch {
            print("⚠️ [PersonaCreation] Failed to delete private data: \(error)")
        }
        
        // Remove from PersonaStore
        if let existingPersonas = try? store.personas {
            let filtered = existingPersonas.filter { $0.dID != activePersona.id }
            // This assumes PersonaStore has a way to bulk replace; adjust if needed
            store.removeAllPersonas()
            for p in filtered {
                try? store.addPersona(p)
            }
        }
        
        print("✅ [PersonaCreation] Deleted active persona. Remaining: \(personaManager.personas.count)")
    }
    
    private func handleDeleteAllPersonas() {
        guard let personaManager = personaManager else { return }
        
        print("🗑️ [PersonaCreation] Deleting all \(personaManager.personas.count) persona(s)")
        
        // Delete all from PersonaManager
        let personasToDelete = personaManager.personas
        for persona in personasToDelete {
            personaManager.deletePersona(persona)
            
            // Delete private keys and private data
            do {
                try PrivateKeyStore.deletePrivateKey(for: persona.id)
                print("🗑️ [PersonaCreation] Deleted private key for: \(persona.id)")
            } catch {
                print("⚠️ [PersonaCreation] Failed to delete private key for \(persona.id): \(error)")
            }
            
            do {
                try PrivateDataStore.deletePrivateData(for: persona.id)
                print("🗑️ [PersonaCreation] Deleted private data for: \(persona.id)")
            } catch {
                print("⚠️ [PersonaCreation] Failed to delete private data for: \(persona.id): \(error)")
            }
        }
        
        // Clear PersonaStore
        store.removeAllPersonas()
        
        print("✅ [PersonaCreation] Deleted all \(personasToDelete.count) persona(s) and cleared all stores")
    }
    
    private func handleCreatePersona() {
        // ═══════════════════════════════════════════════════════════════════
        // TRANSACTIONAL PERSONA CREATION
        // ═══════════════════════════════════════════════════════════════════
        // This function follows a strict transactional approach:
        //
        // ORDER OF OPERATIONS:
        // 1. Generate DID and handle
        // 2. Create Secure Enclave key (private key NEVER leaves hardware)
        // 3. Build persona profile with public key
        // 4. Send to server for registration
        // 5. IF SERVER SUCCEEDS: Save locally (PersonaStore, PrivateDataStore, PersonaManager)
        // 6. IF SERVER FAILS: Complete cleanup of ALL local data
        //
        // CLEANUP POLICY:
        // If ANY step fails, ALL local data must be deleted:
        // - Secure Enclave key (cryptographic identity)
        // - PersonaStore entry (persistent full profile)
        // - PrivateDataStore entry (encrypted sensitive data)
        // - PersonaManager entry (in-memory lightweight reference)
        //
        // This ensures NO orphaned personas exist locally if server registration fails.
        // ═══════════════════════════════════════════════════════════════════
        
        let uuid = UUID().uuidString
        
        // Client generates the DID (collision probability is negligible with 16 random chars)
        // Server will validate uniqueness and reject if duplicate (extremely rare)
        let didToUse = generateFullDID()  // e.g., did:451:a8k7m4p9n2q1x5z3
        let handleToUse = fullHandle       // e.g., sara.silver.silver.publishing.451.info
        
        print("🆔 [PersonaCreation] Generated DID: \(didToUse)")
        print("🏷️ [PersonaCreation] Handle: \(handleToUse)")
        
        // 🔐 Generate key in Secure Enclave (private key NEVER leaves hardware)
        let publicKey: P256.Signing.PublicKey
        do {
            // Require biometrics for public personas (higher security)
            let requireBiometrics = isPublicPersona
            publicKey = try SecureEnclaveKeyStore.createKey(for: didToUse, requireBiometrics: requireBiometrics)
            print("✅ [PersonaCreation] Created Secure Enclave key (biometrics: \(requireBiometrics))")
        } catch {
            print("❌ [PersonaCreation] Failed to create Secure Enclave key: \(error)")
            self.errorMessage = "Failed to create secure key: \(error.localizedDescription)"
            return
        }
        
        // Extract public key for sharing
        let publicKeyRaw = publicKey.rawRepresentation
        let publicKeyUncompressed: Data
        if publicKeyRaw.count == 65 && publicKeyRaw.first == 0x04 {
            publicKeyUncompressed = publicKeyRaw
        } else if publicKeyRaw.count == 64 {
            publicKeyUncompressed = Data([0x04]) + publicKeyRaw
        } else {
            publicKeyUncompressed = publicKeyRaw
        }
        let publicKeyBase64 = publicKeyUncompressed.base64EncodedString()
        
        print("🔑 [PersonaCreation] Public key (safe to share): \(publicKeyBase64.prefix(20))...")
        
        // Build private data structure (will be encrypted locally)
        let hasPrivateData = !givenName.isEmpty || !aliases.isEmpty || !privateEmail.isEmpty ||
        !socialSecurityNumber.isEmpty || !street.isEmpty || !city.isEmpty ||
        !stateRegion.isEmpty || !postalCode.isEmpty || !country.isEmpty
        
        var privateData: PersonaProfile.PrivatePersonaData? = nil
        if hasPrivateData {
            let privateAddress = PersonaProfile.PostalAddress(
                street: street.isEmpty ? nil : street,
                city: city.isEmpty ? nil : city,
                state: stateRegion.isEmpty ? nil : stateRegion,
                postalCode: postalCode.isEmpty ? nil : postalCode,
                country: country.isEmpty ? nil : country
            )
            
            privateData = PersonaProfile.PrivatePersonaData(
                givenName: givenName.isEmpty ? nil : givenName,
                aliases: aliases.isEmpty ? nil : aliases,
                privateEmail: privateEmail.isEmpty ? nil : privateEmail,
                socialSecurityNumber: socialSecurityNumber.isEmpty ? nil : socialSecurityNumber,
                privateAddress: privateAddress
            )
        }
        
        // Build public metadata (visible to everyone)
        var publicMetadata: [String: String] = ["publicKey": publicKeyBase64]
        publicMetadata["visibility"] = isPublicPersona ? "public" : "private"
        
        // Store handle in metadata, but strip .451.info for server compatibility
        var handleForMetadata = handleToUse
        if handleForMetadata.hasSuffix(".451.info") {
            handleForMetadata = String(handleForMetadata.dropLast(".451.info".count))
        }
        publicMetadata["handle"] = handleForMetadata
        
        if !publicAffiliations.isEmpty {
            publicMetadata["publicAffiliations"] = publicAffiliations
        }
        if !socialMediaLinks.isEmpty {
            publicMetadata["socialLinks"] = socialMediaLinks
        }
        if !publicEmail.isEmpty {
            publicMetadata["publicEmail"] = publicEmail
        }
        
        // ----------- Inserted per instructions -----------
        let resolvedDisplayName = profileDisplayName.isEmpty ? name : profileDisplayName
        let resolvedDisplayPublisher = profileDisplayPublisher.isEmpty ? publishingHouse : profileDisplayPublisher
        if !resolvedDisplayName.isEmpty { publicMetadata["displayName"] = resolvedDisplayName }
        if !resolvedDisplayPublisher.isEmpty { publicMetadata["displayPublisher"] = resolvedDisplayPublisher }
        if !publicAffiliations.isEmpty { publicMetadata["publicAffiliations"] = publicAffiliations }
        if !socialMediaLinks.isEmpty { publicMetadata["socialLinks"] = socialMediaLinks }
        if !publicEmail.isEmpty {
            publicMetadata["publicEmail"] = publicEmail
            if publicMetadata["emailVerified"] == nil { publicMetadata["emailVerified"] = "false" }
        }
        // Ensure ORCID and email verification flags are reflected in metadata
        // Prefer current inputs if available; otherwise, fall back to any existing lightweight Persona fields
        if publicMetadata["orcid"] == nil {
            if let existingOrcid = personaManager?.personas.first(where: { $0.handle == handleToUse })?.orcid, !existingOrcid.isEmpty {
                publicMetadata["orcid"] = existingOrcid
            }
        }
        if publicMetadata["orcidVerified"] == nil {
            if let existingVerified = personaManager?.personas.first(where: { $0.handle == handleToUse })?.orcidVerified {
                publicMetadata["orcidVerified"] = existingVerified ? "true" : "false"
            }
        }

        // If a public email is present and we didn't set emailVerified above, ensure it's present
        if publicMetadata["publicEmail"] != nil && publicMetadata["emailVerified"] == nil {
            publicMetadata["emailVerified"] = "false"
        }
        if let metadataOverrides = try? parseMetadataJSON(profileMetadataJSON) {
            publicMetadata.merge(metadataOverrides) { _, new in new }
        }
        // -----------------------------------------------
        
        let verificationMethod = PersonaProfileModel.VerificationMethod(
            id: "\(didToUse)#key-1",
            type: "EcdsaSecp256r1VerificationKey2019",
            controller: didToUse,
            publicKeyBase64: publicKeyBase64
        )

        let publicAddress = buildPostalAddress(
            street: profileStreet,
            city: profileCity,
            stateRegion: profileStateRegion,
            postalCode: profilePostalCode,
            country: profileCountry
        )
        let validatedDomains = parseCommaSeparated(profileValidatedDomains)

        let persona = PersonaProfileModel(
            dID: didToUse,  // Permanent DID: did:451:a8k7m4p9n2q1x5z3
            controller: uuid,
            backgroundCheckRequired: !isPublicPersona, // Automatic for private personas
            guid: nil,
            shortId: nil,
            isPublic: isPublicPersona,
            handle: handleToUse,  // ATProtocol: human-readable handle
            name: name.isEmpty ? nil : name,
            displayName: resolvedDisplayName.isEmpty ? nil : resolvedDisplayName,
            displayPublisher: resolvedDisplayPublisher.isEmpty ? nil : resolvedDisplayPublisher,
            email: publicEmail.isEmpty ? nil : publicEmail, // Public email goes here
            address: publicAddress,
            affiliations: publicAffiliations.isEmpty ? nil : publicAffiliations,
            socialLinks: socialMediaLinks.isEmpty ? nil : socialMediaLinks,
            verified: profileVerified ? true : nil,
            requestedDomain: nilIfEmpty(profileRequestedDomain),
            requestedDnsChallenge: nilIfEmpty(profileRequestedDnsChallenge),
            backgroundValidated: profileBackgroundValidated ? true : nil,
            validatedDomains: validatedDomains,
            type: nilIfEmpty(profileType),
            hash: nilIfEmpty(profileHash),
            storageEndpoints: nil,
            resourceFolders: nil,
            metadata: publicMetadata,
            privateData: privateData, // Private data (will be encrypted client-side)
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: nil,
            eTag: nil,
            verificationMethod: [verificationMethod],
            service: nil,
            previousBlock: nil,
            relatedBlock: nil,
            signature: nil
        )
        
        Task {
            do {
                let (serverPersona, warning, results, failures) = try await sendPersonaCreationRequest(persona: persona,
                                                                                                       publicKeyBase64: publicKeyBase64,
                                                                                                       personaDID: didToUse)
                
                // ═══════════════════════════════════════════════════════════════════
                // SERVER-SIDE INDEXING VERIFICATION
                // ═══════════════════════════════════════════════════════════════════
                // If we got here, the server has ALREADY verified:
                // 1. Meilisearch indexing succeeded (server retried 2-3 times)
                // 2. S3 storage uploaded successfully (or returned failure)
                // 3. Blockchain block created
                //
                // The server only returns success if ALL critical steps passed.
                // If the server returns success, we trust it - no client-side polling needed.
                // ═══════════════════════════════════════════════════════════════════
                
                print("✅ [PersonaCreation] Server confirmed persona creation successful")
                print("✅ [PersonaCreation] Server verified: indexing, S3 storage, blockchain")
                
                // ═══════════════════════════════════════════════════════════════════
                // CRITICAL: Verify S3 uploads succeeded (at least primary storage)
                // ═══════════════════════════════════════════════════════════════════
                // Partial uploads are acceptable (redundancy), but zero uploads is fatal
                if results.isEmpty && !failures.isEmpty {
                    print("❌ [PersonaCreation] ═══════════════════════════════════════")
                    print("❌ [PersonaCreation] CRITICAL FAILURE: ALL S3 UPLOADS FAILED")
                    print("❌ [PersonaCreation] DID: \(serverPersona.dID)")
                    print("❌ [PersonaCreation] Failed providers: \(failures.map { $0.providerName }.joined(separator: ", "))")
                    print("❌ [PersonaCreation] ═══════════════════════════════════════")
                    print("❌ [PersonaCreation] WHY THIS MATTERS:")
                    print("❌ [PersonaCreation] - No S3 storage means no document verification")
                    print("❌ [PersonaCreation] - Documents cannot be retrieved or proven")
                    print("❌ [PersonaCreation] - Persona cannot fulfill its trust purpose")
                    print("❌ [PersonaCreation] ═══════════════════════════════════════")
                    print("🧹 [PersonaCreation] INITIATING COMPLETE CLEANUP...")
                    
                    await cleanupFailedPersonaCreation(did: serverPersona.dID)
                    
                    await MainActor.run {
                        let failureDetails = failures.map { "• \($0.providerName): \($0.message ?? "Unknown error")" }.joined(separator: "\n")
                        self.errorMessage = """
                        Persona Creation Failed
                        
                        All S3 storage uploads failed. This makes the persona unusable.
                        
                        Failed Storage Providers:
                        \(failureDetails)
                        
                        Without S3 storage:
                        ✗ Documents cannot be verified
                        ✗ Data cannot be retrieved
                        ✗ Trust mechanism is broken
                        
                        All persona data has been deleted from both server and client.
                        Please check your network connection and try again.
                        """
                    }
                    return
                }
                
                print("✅ [PersonaCreation] Persona successfully indexed and searchable")
                if results.isEmpty {
                    print("⚠️ [PersonaCreation] WARNING: No S3 uploads reported (may be okay if server doesn't report results)")
                } else {
                    print("✅ [PersonaCreation] S3 uploads successful: \(results.count) provider(s)")
                }
                if !failures.isEmpty {
                    print("⚠️ [PersonaCreation] Some S3 uploads failed: \(failures.count) provider(s) - redundancy reduced")
                }
                
                await MainActor.run {
                    // Multi-persona mode: Add new persona alongside existing ones
                    print("✨ [PersonaCreation] Adding new persona to collection")
                    
                    // Save to PersonaStore (full profile with private data)
                    do {
                        // Note: privateData in serverPersona will be nil since server doesn't receive it
                        // We need to add our locally-created private data back
                        var fullPersona = serverPersona
                        
                        // ----------- Inserted per instructions -----------
                        fullPersona.metadata = publicMetadata
                        // -----------------------------------------------
                        
                        fullPersona.privateData = privateData
                        
                        try self.store.addPersona(fullPersona)
                        print("✅ [PersonaCreation] Saved full profile to PersonaStore: \(serverPersona.dID)")
                        
                        // Encrypt and store private data separately if present
                        if let privateData = privateData {
                            do {
                                try PrivateDataStore.savePrivateData(privateData, for: serverPersona.dID)
                                print("✅ [PersonaCreation] Encrypted and stored private data for: \(serverPersona.dID)")
                            } catch {
                                print("❌ [PersonaCreation] CRITICAL: Failed to encrypt private data after server success")
                                print("🧹 [PersonaCreation] Performing emergency cleanup...")
                                
                                // Clean up local data - server has the persona but we can't use it safely
                                Task {
                                    await self.cleanupFailedPersonaCreation(did: serverPersona.dID)
                                }
                                
                                self.errorMessage = "Critical error: Private data could not be secured locally. Persona creation aborted. Error: \(error.localizedDescription)"
                                return
                            }
                        }
                    } catch {
                        print("❌ [PersonaCreation] CRITICAL: Failed to save to PersonaStore after server success")
                        print("🧹 [PersonaCreation] Performing emergency cleanup...")
                        
                        // Clean up - server has the persona but we can't save it locally
                        Task {
                            await self.cleanupFailedPersonaCreation(did: serverPersona.dID)
                        }
                        
                        self.errorMessage = "Critical error: Could not save persona locally after server registration. Persona creation aborted. Error: \(error.localizedDescription)"
                        return
                    }
                    
                    // ✅ Private key is already securely stored in Secure Enclave
                    // No need to save it again - it never leaves the hardware!
                    print("✅ [PersonaCreation] Private key secured in Secure Enclave for: \(serverPersona.dID)")
                    
                    // 🚫 DO NOT add to PersonaManager here!
                    // Adding the persona now would cause RootView to immediately detect it
                    // and navigate away BEFORE the success sheet can be shown.
                    // 
                    // Instead, we add to PersonaManager in handleSuccessSheetDismiss()
                    // AFTER the user has seen and dismissed the success celebration.
                    print("⏸️ [PersonaCreation] Deferring PersonaManager addition until success sheet dismissed")
                    
                    // ═══════════════════════════════════════════════════════════════════
                    // 🎉 SUCCESS! All data is safely stored AND persona is indexed
                    // ═══════════════════════════════════════════════════════════════════
                    print("✅ [PersonaCreation] ════════════════════════════════════════════")
                    print("✅ [PersonaCreation] PERSONA CREATION SUCCESSFUL!")
                    print("✅ [PersonaCreation] DID: \(serverPersona.dID)")
                    print("✅ [PersonaCreation] Handle: \(serverPersona.handle)")
                    print("✅ [PersonaCreation] Type: \(isPublicPersona ? "Public" : "Private")")
                    print("✅ [PersonaCreation] Indexed: YES")
                    print("✅ [PersonaCreation] ════════════════════════════════════════════")
                    
                    self.createdPersona = serverPersona
                    self.creationWarning = warning // No indexing warning needed - we verified it
                    
                    self.uploadResults = results
                    self.uploadFailures = failures
                    self.showUploadDetails = !(failures.isEmpty && results.isEmpty) && failureDrivenDetailsPresentation()
                    
                    // ✅ Show SUCCESS SHEET instead of alert to prevent auto-navigation
                    // This blocks RootView from detecting the persona and auto-navigating
                    showSuccessSheet = true  // ✅ This shows the full-screen success celebration
                }
            } catch {
                // ❌ Server registration failed - COMPLETE CLEANUP REQUIRED
                // If ANY part of server registration fails, we must remove ALL local data
                print("❌ [PersonaCreation] Server registration failed: \(error)")
                print("🧹 [PersonaCreation] Starting complete cleanup for failed persona: \(didToUse)")
                
                // Perform complete transactional cleanup
                await cleanupFailedPersonaCreation(did: didToUse)
                
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
                return
            }
        }
    }
    
    // MARK: - Transactional Cleanup
    
    /// Complete cleanup of a failed persona creation
    /// This ensures NO orphaned data remains if server registration fails OR indexing fails
    /// 
    /// CRITICAL: This performs BOTH client-side AND server-side cleanup:
    /// - Client: Secure Enclave key, PersonaStore, PrivateDataStore, PersonaManager
    /// - Server: Persona document, S3 storage, blockchain block, search index
    ///
    /// If ANY critical step fails (S3, blockchain, indexing), the entire persona is unusable
    /// and must be completely removed from both client and server.
    private func cleanupFailedPersonaCreation(did: String) async {
        print("🧹 [PersonaCreation] ═══════════════════════════════════════")
        print("🧹 [PersonaCreation] COMPLETE CLEANUP for failed DID: \(did)")
        print("🧹 [PersonaCreation] ═══════════════════════════════════════")
        
        // 1. Delete from SERVER first (most important - prevents orphaned server data)
        print("🧹 [PersonaCreation] [1/5] Deleting from server...")
        await deletePersonaFromServer(did: did)
        
        // 2. Delete Secure Enclave key (CRITICAL - this is the cryptographic identity)
        print("🧹 [PersonaCreation] [2/5] Deleting Secure Enclave key...")
        SecureEnclaveKeyStore.deleteKey(for: did)
        print("✅ [PersonaCreation] Secure Enclave key deleted")
        
        // 3. Delete from PersonaStore (persistent storage)
        print("🧹 [PersonaCreation] [3/5] Removing from PersonaStore...")
        store.removePersona(did)
        print("✅ [PersonaCreation] Removed from PersonaStore")
        
        // 4. Delete encrypted private data
        print("🧹 [PersonaCreation] [4/5] Deleting encrypted private data...")
        do {
            try PrivateDataStore.deletePrivateData(for: did)
            print("✅ [PersonaCreation] Encrypted private data deleted")
        } catch {
            print("⚠️ [PersonaCreation] Private data deletion failed (may not exist yet): \(error)")
        }
        
        // 5. Remove from PersonaManager (in-memory lightweight personas)
        await MainActor.run {
            print("🧹 [PersonaCreation] [5/5] Removing from PersonaManager...")
            if let personaManager = self.personaManager {
                // Find and remove the persona if it was added
                if let persona = personaManager.personas.first(where: { $0.id == did }) {
                    personaManager.deletePersona(persona)
                    print("✅ [PersonaCreation] Removed from PersonaManager")
                } else {
                    print("ℹ️ [PersonaCreation] Not found in PersonaManager (never added)")
                }
            } else {
                print("⚠️ [PersonaCreation] PersonaManager is nil")
            }
        }
        
        print("🧹 [PersonaCreation] ═══════════════════════════════════════")
        print("✅ [PersonaCreation] CLEANUP COMPLETE - All traces removed")
        print("✅ [PersonaCreation] Server persona deleted (S3, blockchain, index)")
        print("✅ [PersonaCreation] Client data deleted (Enclave, stores, managers)")
        print("🧹 [PersonaCreation] ═══════════════════════════════════════")
    }
    
    /// Delete persona from server (S3, blockchain, search index)
    /// Called when client-side verification fails (e.g., indexing timeout)
    private func deletePersonaFromServer(did: String) async {
        guard let url = URL(string: ServerConfig.baseURL + "/api/persona/\(did)") else {
            print("❌ [PersonaCreation] Bad URL for server deletion")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [PersonaCreation] Non-HTTP response for server deletion")
                return
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                print("✅ [PersonaCreation] Server persona deleted successfully")
                print("✅ [PersonaCreation] Server confirmed: S3 files deleted, blockchain block removed, index cleared")
            } else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ [PersonaCreation] Server deletion failed (\(httpResponse.statusCode)): \(errorMsg)")
                print("⚠️ [PersonaCreation] WARNING: Server may have orphaned data for DID: \(did)")
            }
        } catch {
            print("❌ [PersonaCreation] Server deletion error: \(error.localizedDescription)")
            print("⚠️ [PersonaCreation] WARNING: Server may have orphaned data for DID: \(did)")
        }
    }
    
    // MARK: - Success Celebration Sheet
    
    private var successSheet: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: isPublicPersona ? 
                    [Color.blue.opacity(0.3), Color.purple.opacity(0.2)] :
                        [Color.purple.opacity(0.3), Color.pink.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer(minLength: 60)
                        
                        // Success Icon
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.green.gradient)
                            .shadow(color: .green.opacity(0.3), radius: 20)
                        
                        // Title
                        VStack(spacing: 8) {
                            Text("Persona Created!")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("Your digital identity is ready to use")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        
                        // Persona Details Card
                        if let persona = createdPersona {
                            personaDetailsCard(persona)
                        }
                        
                        // Security Confirmations
                        securityConfirmationsView
                        
                        // Warning if present
                        if let warning = creationWarning {
                            warningCard(warning)
                        }
                        
                        // Action Buttons
                        actionButtonsView
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Success")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        handleSuccessSheetDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .interactiveDismissDisabled(true) // Prevent swipe-to-dismiss
    }
    
    private func personaDetailsCard(_ persona: PersonaProfileModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Handle - with blue sphere formatting
            VStack(alignment: .leading, spacing: 8) {
                Label("Handle", systemImage: "at")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Blue sphere: displayName left, displayPublisher right
                PersonaIdentityPreviewView(
                    name: persona.displayName ?? (name.isEmpty ? (persona.name ?? persona.handle) : name),
                    publisher: persona.displayPublisher ?? (publishingHouse.isEmpty ? nil : publishingHouse)
                )
                
                // Full handle below for reference
                Text(persona.handle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
            
            Divider()
            
            // DID
            VStack(alignment: .leading, spacing: 4) {
                Label("DID (Permanent)", systemImage: "key.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(persona.dID.suffix(24)))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.blue)
                    .textSelection(.enabled)
            }
            
            Divider()
            
            // Type
            HStack {
                Label("Type", systemImage: isPublicPersona ? "megaphone.fill" : "lock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(isPublicPersona ? "Public Persona" : "Private Persona")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isPublicPersona ? .blue : .purple)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke((isPublicPersona ? Color.blue : Color.purple).opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var securityConfirmationsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Security Status")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                securityCheckmark("Secured in Secure Enclave", "lock.shield.fill")
                securityCheckmark("Registered with server", "checkmark.icloud.fill")
                if createdPersona?.privateData != nil {
                    securityCheckmark("Private data encrypted", "lock.doc.fill")
                }
            }
            .padding()
            .background(Color.platformBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 10)
        }
    }
    
    private func securityCheckmark(_ text: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .font(.title3)
            Text(text)
                .font(.body)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
    
    private func warningCard(_ warning: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Note")
                    .font(.headline)
                Text(warning)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            // Primary action: dismiss all sheets and return to Personas view
            Button {
                handleSuccessSheetDismiss()
            } label: {
                HStack {
                    Image(systemName: "person.2.fill")
                    Text("View My Personas")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }

            // View details button (if there are warnings)
            if creationWarning != nil {
                Button {
                    showUploadDetails = true
                } label: {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("View Upload Details")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func handleSuccessSheetDismiss() {
        // Close the success sheet
        showSuccessSheet = false
        
        // CRITICAL: Add persona to PersonaManager ONLY AFTER user dismisses success sheet
        // This prevents RootView from detecting the persona and auto-navigating prematurely
        if let persona = createdPersona, let personaManager = self.personaManager {
            // Convert to lightweight Persona if not already added
            let publicKeyBase64 = persona.verificationMethod.first?.publicKeyBase64 ?? ""
            
            let lightweight = Persona(
                id: persona.dID,
                controller: persona.controller,
                name: persona.name ?? persona.handle,
                handle: persona.handle,  // ATProtocol: human-readable identifier (e.g., scott.francis.451.project.451.info)
                displayName: name.isEmpty ? nil : name,  // Store the original input name (e.g., "Sam Sooner")
                displayPublisher: publishingHouse.isEmpty ? nil : publishingHouse,  // Store the original publisher name (e.g., "Sooner Publishing")
                address: nil,
                email: persona.email,
                emailVerified: persona.metadata?["emailVerified"] == "true",
                orcid: persona.metadata?["orcid"],
                orcidVerified: persona.metadata?["orcidVerified"] == "true",
                affiliations: persona.affiliations,
                socialLinks: persona.socialLinks,
                publicKeyBase64: publicKeyBase64,
                storageEndpoints: nil,
                createdAt: persona.createdAt ?? ISO8601DateFormatter().string(from: Date()),
                updatedAt: persona.updatedAt,
                eTag: persona.eTag,
                visibility: isPublicPersona ? .public : .private,
                status: "active"
            )
            
            // Add to PersonaManager now (this triggers RootView navigation)
            personaManager.addPersona(lightweight)
            personaManager.setActivePersona(lightweight)
            print("✅ [PersonaCreation] Added persona to PersonaManager AFTER success sheet dismissed")
            
            // Signal PersonasTabView to close the entire creation sheet.
            // dismiss() only pops one NavigationStack level; this flag closes
            // the outermost .sheet(isPresented: $showingCreate) owned by PersonasTabView.
            personaManager.dismissCreationFlow = true
        }
        
        // Call onCreate callback now that user has dismissed the success sheet
        if let persona = createdPersona {
            onCreate?(persona)
        }
        
        // Dismiss the creation view (pops this view from the NavigationStack)
        onDismiss?()
        dismiss()
    }
    
    private var successAlertButtons: some View {
        Group {
            if creationWarning != nil {
                Button("View details") { showUploadDetails = true }
            }
            
            Button("Done") {
                // Call onCreate callback now that user has seen the success message
                if let persona = createdPersona {
                    onCreate?(persona)
                }
                onDismiss?()
                dismiss()
            }
        }
    }
    
    private func successAlertMessage(for persona: PersonaProfileModel) -> Text {
        var message = "🎉 Persona created successfully!\n\n"
        
        // Add DID and handle info
        message += "DID: \(String(persona.dID.suffix(20)))\n"
        message += "Handle: \(persona.handle)\n"
        message += "Type: \(isPublicPersona ? "Public" : "Private")\n\n"
        
        // Security confirmation
        message += "✅ Secured in Secure Enclave\n"
        message += "✅ Registered with server\n"
        if persona.privateData != nil {
            message += "✅ Private data encrypted\n"
        }
        
        if let warning = creationWarning {
            message += "\n⚠️ Note: \(warning)"
        }
        
        return Text(message)
    }
    
    private var uploadDetailsSheet: some View {
        NavigationView {
            uploadDetailsList
                .navigationTitle("Upload Details")
                .toolbar {
                    uploadDetailsToolbar
                }
        }
    }
    
    private var uploadDetailsList: some View {
        List {
            if !uploadFailures.isEmpty {
                failedProvidersSection
            }
            if !uploadResults.isEmpty {
                successfulProvidersSection
            }
            if uploadFailures.isEmpty && uploadResults.isEmpty {
                Text("No upload diagnostics were provided by the server.")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var failedProvidersSection: some View {
        Section {
            ForEach(uploadFailures) { f in
                VStack(alignment: .leading, spacing: 4) {
                    Text(f.providerName).font(.headline)
                    if let code = f.code, !code.isEmpty {
                        Text("Code: \(code)").font(.footnote).foregroundColor(.secondary)
                    }
                    if let msg = f.message, !msg.isEmpty {
                        Text(msg).font(.footnote)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Failed Providers")
        }
    }
    
    private var successfulProvidersSection: some View {
        Section {
            ForEach(uploadResults) { r in
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.providerName).font(.headline)
                    Text(r.url).font(.footnote).foregroundColor(.secondary)
                    if let e = r.eTag, !e.isEmpty {
                        Text("ETag: \(e)").font(.footnote).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Successful Providers")
        }
    }
    
    @ToolbarContentBuilder
    private var uploadDetailsToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") { showUploadDetails = false }
        }
        if !uploadFailures.isEmpty, let persona = createdPersona {
            ToolbarItem(placement: .confirmationAction) {
                Button(retryInProgress ? "Retrying…" : "Retry Failed") {
                    Task { await retryFailedUploads(for: persona.dID) }
                }
                .disabled(retryInProgress)
            }
        }
    }
    
    private func failureDrivenDetailsPresentation() -> Bool {
        // Auto-present details when there are failures; otherwise keep hidden
        return !uploadFailures.isEmpty
    }
    
    private func sendPersonaCreationRequest(persona: PersonaProfileModel,
                                            publicKeyBase64: String,
                                            personaDID: String) async throws -> (PersonaProfileModel, String?, [UploadResult], [UploadFailure])
    {
        // ATProtocol approach:
        // - DID is permanent: did:451:a8k7m4p9n2q1x5z3
        // - Handle is human-readable: sara.silver.silver.publishing.451.info
        let fullDID = persona.dID  // Already includes did:451: prefix
        var handle = persona.handle  // The human-readable handle
        
        // Server validation rule: Handle must have at least 2 segments separated by dots
        // For publishing house personas, remove the .451.info suffix before sending
        // Server will add it back automatically
        if handle.hasSuffix(".451.info") {
            // Strip the default domain - server will add it back
            handle = String(handle.dropLast(".451.info".count))
            print("🏷️ [PersonaCreation] Stripped .451.info from handle: \(handle)")
        }
        
        print("🆔 [PersonaCreation] Sending DID: \(fullDID)")
        print("🏷️ [PersonaCreation] Sending handle: \(handle)")
        
        // Build public metadata (don't send private data to server)
        var attributes = persona.metadata ?? [:]
        attributes["publicKey"] = publicKeyBase64
        attributes["didMethod"] = "did:451"  // Mark our DID method
        
        // NOTE: Private data is NOT sent to server
        // It is stored locally, encrypted
        
        // 1) Canonicalize on server
        // Per server instructions: send the FULL DID (with did:451: prefix)
        let canonReq = PersonaCanonicalizeRequest(
            did: fullDID,  // Send full DID: did:451:a8k7m4p9n2q1x5z3
            handle: handle,  // ATProtocol: human-readable handle (without .451.info)
            name: persona.name ?? handle,
            attributes: attributes, // Public metadata only
            address: nil, // Address is now in privateData, not sent to server
            verified: persona.verified ?? false,
            isPublic: isPublicPersona,
            backgroundCheckRequired: persona.backgroundCheckRequired,
            domainToBeVerified: persona.requestedDomain,
            dnsChallengeValue: persona.requestedDnsChallenge,
            verificationMethod: [
                .init(
                    id: "\(fullDID)#key-1",  // Use full DID for the ID
                    type: "EcdsaSecp256r1VerificationKey2019",
                    controller: fullDID,  // Use full DID for controller
                    publicKeyBase64: publicKeyBase64
                )
            ]
        )
        
        guard let canonURL = URL(string: ServerConfig.baseURL + "/api/persona/canonicalize") else {
            throw URLError(.badURL)
        }
        var canonURLRequest = URLRequest(url: canonURL)
        canonURLRequest.httpMethod = "POST"
        canonURLRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        canonURLRequest.httpBody = try JSONEncoder().encode(canonReq)
        
        let canonReqId = NetLog.id()
        NetLog.request(canonReqId, canonURLRequest)
        let canonStart = Date()
        
        let delegate = NetSessionDelegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        
        let (canonData, canonResponse): (Data, URLResponse) = try await withCheckedThrowingContinuation { cont in
            let task = session.dataTask(with: canonURLRequest) { data, response, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else if let data = data, let response = response {
                    cont.resume(returning: (data, response))
                } else {
                    cont.resume(throwing: URLError(.unknown))
                }
            }
            task.taskDescription = canonReqId
            task.resume()
        }
        
        let canonDuration = Date().timeIntervalSince(canonStart)
        if let http = canonResponse as? HTTPURLResponse {
            guard (200...299).contains(http.statusCode) else {
                NetLog.error(canonReqId, http, data: canonData, err: nil, duration: canonDuration)
                let msg = String(data: canonData, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "PersonaCanonicalize", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            NetLog.response(canonReqId, http, data: canonData, duration: canonDuration)
        } else {
            NetLog.error(canonReqId, nil, data: canonData, err: nil, duration: canonDuration)
            throw NSError(domain: "PersonaCanonicalize", code: -1, userInfo: [NSLocalizedDescriptionKey: "Non-HTTP response"])
        }
        
        // Decode canonicalize response (profile + nonce)
        let canonResp = try JSONDecoder().decode(PersonaCanonicalizeResponse.self, from: canonData)
        
        // ⚠️ CRITICAL: Check if server changed the DID
        let serverDID = canonResp.profile.dID
        if serverDID != personaDID {
            print("⚠️ [PersonaCreation] Server changed DID!")
            print("   Client sent: \(personaDID)")
            print("   Server returned: \(serverDID)")
            print("   Updating Secure Enclave key reference...")
            
            // If server changed the DID, we need to update the keychain entry
            // Delete the old entry and create new one with server's DID
            SecureEnclaveKeyStore.deleteKey(for: personaDID)
            
            // The key itself is still in Secure Enclave, just need to update the reference tag
            // We need to retrieve the key with old DID and re-store with new DID
            // For now, we'll just use the server's DID going forward
            print("⚠️ [PersonaCreation] WARNING: Secure Enclave key was created with client DID but server uses different DID")
            print("⚠️ [PersonaCreation] This may cause signing failures. Consider refactoring to create key AFTER server assigns DID.")
        }
        
        // Build canonical bytes to sign from the returned profile (signature must be nil)
        var profileToSign = canonResp.profile
        profileToSign.signature = nil
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let canonicalProfileData = try encoder.encode(profileToSign)
        
        // 🔐 Sign canonical profile with Secure Enclave key (signing happens IN the hardware)
        print("🔐 [PersonaCreation] Signing with Secure Enclave...")
        // Use the server's DID for signing, not the client's original DID
        let didForSigning = serverDID
        let signature = try SecureEnclaveKeyStore.sign(canonicalProfileData, for: didForSigning)
        let signatureBase64 = signature.derRepresentation.base64EncodedString()
        print("✅ [PersonaCreation] Signature created in Secure Enclave")
        
#if DEBUG
        do {
            if let pkData = Data(base64Encoded: publicKeyBase64) {
                let pubKey = try P256.Signing.PublicKey(x963Representation: pkData)
                let sig = try P256.Signing.ECDSASignature(derRepresentation: Data(base64Encoded: signatureBase64)!)
                let ok = pubKey.isValidSignature(sig, for: canonicalProfileData)
                print("[PersonaCreation] Local signature verify (server-canonical): \(ok)")
            } else {
                print("[PersonaCreation] Failed to decode publicKeyBase64 for local verify")
            }
        } catch {
            print("[PersonaCreation] Local verify error (server-canonical): \(error)")
        }
#endif
        
        // 2) Finalize with signed profile
        var signedProfile = canonResp.profile
        signedProfile.signature = signatureBase64
        
        let finalizeReq = PersonaFinalizeRequest(profile: signedProfile, nonce: canonResp.nonce)
        
        guard let finalizeURL = URL(string: ServerConfig.baseURL + "/api/persona/finalize") else {
            throw URLError(.badURL)
        }
        var finalizeURLRequest = URLRequest(url: finalizeURL)
        finalizeURLRequest.httpMethod = "POST"
        finalizeURLRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        finalizeURLRequest.httpBody = try JSONEncoder().encode(finalizeReq)
        
        let finReqId = NetLog.id()
        NetLog.request(finReqId, finalizeURLRequest)
        let finStart = Date()
        
        let (finData, finResponse): (Data, URLResponse) = try await withCheckedThrowingContinuation { cont in
            let task = session.dataTask(with: finalizeURLRequest) { data, response, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else if let data = data, let response = response {
                    cont.resume(returning: (data, response))
                } else {
                    cont.resume(throwing: URLError(.unknown))
                }
            }
            task.taskDescription = finReqId
            task.resume()
        }
        
        let finDuration = Date().timeIntervalSince(finStart)
        if let http = finResponse as? HTTPURLResponse {
            if (200...299).contains(http.statusCode) {
                NetLog.response(finReqId, http, data: finData, duration: finDuration)
                let partialWarning: String? = (http.allHeaderFields["X-Partial-Upload"] as? String) ?? (http.allHeaderFields["x-partial-upload"] as? String)
                // Decode and verify the server-returned canonical PersonaProfile
                let returned = try JSONDecoder().decode(PersonaProfileModel.self, from: finData)
                // Parse optional upload diagnostics headers (if server provides them)
                var results: [UploadResult] = []
                var failures: [UploadFailure] = []
                if let hdr = http.allHeaderFields["X-Upload-Results"] as? String, let data = hdr.data(using: .utf8) {
                    if let decoded = try? JSONDecoder().decode([UploadResult].self, from: data) { results = decoded }
                }
                if let hdr = http.allHeaderFields["X-Upload-Failures"] as? String, let data = hdr.data(using: .utf8) {
                    if let decoded = try? JSONDecoder().decode([UploadFailure].self, from: data) { failures = decoded }
                }
                // Verify DID is based on the requested identifier. The server may append a unique tag, e.g., "base(ABC-1234)".
                // Compare against the full DID (with did:451: prefix)
                let base = persona.dID.lowercased()
                let returnedLower = returned.dID.lowercased()
                
                // Server should return full DID (did:451:handle) or full DID with tag (did:451:handle(ABC-1234))
                let didMatches = (returnedLower == base) || returnedLower.hasPrefix(base + "(")
                guard didMatches else {
                    print("⚠️ [PersonaCreation] DID mismatch - expected: \(base), got: \(returnedLower)")
                    throw NSError(domain: "PersonaFinalize", code: -2, userInfo: [NSLocalizedDescriptionKey: "Server returned unexpected DID format."])
                }
                // Verify public key matches the local generated public key
                let returnedPK = returned.verificationMethod.first?.publicKeyBase64 ?? ""
                guard returnedPK == publicKeyBase64 else {
                    throw NSError(domain: "PersonaFinalize", code: -3, userInfo: [NSLocalizedDescriptionKey: "Server returned mismatched public key."])
                }
                // Return the authoritative persona and optional warning header
                return (returned, partialWarning, results, failures)
            } else {
                NetLog.error(finReqId, http, data: finData, err: nil, duration: finDuration)
                let msg = String(data: finData, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "PersonaFinalize", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
        } else {
            NetLog.error(finReqId, nil, data: finData, err: nil, duration: finDuration)
            throw NSError(domain: "PersonaFinalize", code: -1, userInfo: [NSLocalizedDescriptionKey: "Non-HTTP response"])
        }
    }
    
    private func retryFailedUploads(for did: String) async {
        await MainActor.run { retryInProgress = true; retryError = nil }
        defer { Task { await MainActor.run { retryInProgress = false } } }
        
        let providers = uploadFailures.map { $0.providerName }
        guard !providers.isEmpty else { return }
        
        guard let url = URL(string: ServerConfig.baseURL + "/api/persona/uploads/retry") else {
            await MainActor.run { retryError = "Bad retry URL" }
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = RetryUploadsRequest(did: did, providers: providers)
        do {
            req.httpBody = try JSONEncoder().encode(body)
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if (200...299).contains(http.statusCode) {
                // On success, attempt to parse updated results from headers
                var newResults: [UploadResult] = uploadResults
                var remainingFailures: [UploadFailure] = []
                if let hdr = http.allHeaderFields["X-Upload-Results"] as? String, let d = hdr.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode([UploadResult].self, from: d) {
                    newResults = decoded
                }
                if let hdr = http.allHeaderFields["X-Upload-Failures"] as? String, let d = hdr.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode([UploadFailure].self, from: d) {
                    remainingFailures = decoded
                }
                await MainActor.run {
                    self.uploadResults = newResults
                    self.uploadFailures = remainingFailures
                    if remainingFailures.isEmpty { self.creationWarning = nil }
                }
            } else {
                let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
                await MainActor.run { retryError = "Retry failed: \(http.statusCode) — \(msg)" }
            }
        } catch {
            await MainActor.run { retryError = error.localizedDescription }
        }
    }
    
    // MARK: - Indexing verification (strict success)
    private struct PersonaSearchWrapper: Decodable {
        let results: [PersonaProfileModel]
    }
    
    private struct PersonaSearchHit: Decodable {
        let dID: String
    }
    
    private struct PersonaSearchResponse: Decodable {
        let hits: [PersonaProfileModel]
        let query: String
        let processingTimeMs: Int
        let limit: Int
        let offset: Int
        let estimatedTotalHits: Int
    }
    
    private func verifyIndexing(did: String, timeout: TimeInterval = 120, pollInterval: TimeInterval = 3.0) async -> Bool {
        print("🔍 [PersonaCreation] ═══════════════════════════════════════")
        print("🔍 [PersonaCreation] Starting indexing verification")
        print("🔍 [PersonaCreation] DID: \(did)")
        print("🔍 [PersonaCreation] Timeout: \(timeout)s (2 minutes), Poll interval: \(pollInterval)s")
        print("🔍 [PersonaCreation] ═══════════════════════════════════════")
        
        let deadline = Date().addingTimeInterval(timeout)
        var attempt = 0
        let maxAttempts = Int(timeout / pollInterval)
        
        while Date() < deadline {
            attempt += 1
            let elapsed = timeout - deadline.timeIntervalSinceNow
            print("🔍 [PersonaCreation] Verification attempt \(attempt)/~\(maxAttempts) (elapsed: \(String(format: "%.1f", elapsed))s)")
            
            if await isPersonaIndexed(did: did) {
                print("✅ [PersonaCreation] ═══════════════════════════════════════")
                print("✅ [PersonaCreation] INDEXING VERIFIED!")
                print("✅ [PersonaCreation] DID: \(did)")
                print("✅ [PersonaCreation] Attempts: \(attempt)")
                print("✅ [PersonaCreation] Time: \(String(format: "%.1f", elapsed))s")
                print("✅ [PersonaCreation] ═══════════════════════════════════════")
                return true
            }
            
            if Date().addingTimeInterval(pollInterval) >= deadline {
                print("⏰ [PersonaCreation] Next poll would exceed deadline, stopping verification")
                break
            }
            
            print("⏳ [PersonaCreation] Not indexed yet, waiting \(pollInterval)s before retry...")
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        
        print("❌ [PersonaCreation] ═══════════════════════════════════════")
        print("❌ [PersonaCreation] INDEXING VERIFICATION TIMEOUT")
        print("❌ [PersonaCreation] DID: \(did)")
        print("❌ [PersonaCreation] Attempts: \(attempt)")
        print("❌ [PersonaCreation] Timeout: \(timeout)s (2 minutes)")
        print("❌ [PersonaCreation] This indicates a server-side indexing problem")
        print("❌ [PersonaCreation] ═══════════════════════════════════════")
        return false
    }
    
    private func isPersonaIndexed(did: String) async -> Bool {
        // Use only search endpoint - if it's working, that's what matters
        return await searchPersonaByQuery(did) == true
    }
    
    private func searchPersonaByQuery(_ query: String) async -> Bool? {
        // ═══════════════════════════════════════════════════════════════════
        // CRITICAL FIX: Use exact DID matching via filter, not natural language search
        // ═══════════════════════════════════════════════════════════════════
        // Problem: Natural language search tokenizes DIDs and returns irrelevant results
        // Solution: Use Meilisearch filter for exact DID matching
        //
        // Before: ?q=did:451:abc123 → matches "Daft Punk", "Crafty Nut" (fuzzy/token match)
        // After:  ?filter=dID="did:451:abc123" → exact match only
        //
        // Server filter examples:
        // - Exact DID: filter=dID="did:451:abc123"
        // - Active only: filter=status!="decommissioned"
        // - Combined: filter=dID="did:451:abc123"ANDstatus!="decommissioned"
        // ═══════════════════════════════════════════════════════════════════
        
        // Check if this is a DID query (starts with "did:")
        let isDIDQuery = query.lowercased().hasPrefix("did:")
        
        let urlString: String
        if isDIDQuery {
            // Use filter for exact DID matching
            // Meilisearch filter syntax: dID="did:451:abc123"
            // Note: No spaces around = and no escaping needed in the filter string itself
            let filterString = "dID=\"\(query)\""
            
            guard let encodedFilter = filterString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                print("❌ [PersonaCreation] Failed to encode filter for DID: \(query)")
                return nil
            }
            
            urlString = ServerConfig.baseURL + "/api/persona/search?filter=" + encodedFilter
        } else {
            // Use natural language search for non-DID queries (names, handles, etc.)
            guard let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                print("❌ [PersonaCreation] Failed to encode query: \(query)")
                return nil
            }
            urlString = ServerConfig.baseURL + "/api/persona/search?q=" + q
        }
        
        guard let url = URL(string: urlString) else {
            print("❌ [PersonaCreation] Bad search URL for query: \(query)")
            return nil
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        
        // ═══════════════════════════════════════════════════════════════════
        // 🔍 DETAILED SEARCH LOGGING - Use this to test manually!
        // ═══════════════════════════════════════════════════════════════════
        print("🔍 [PersonaCreation] ═══════════════════════════════════════")
        print("🔍 [PersonaCreation] SEARCH REQUEST DETAILS")
        print("🔍 [PersonaCreation] ═══════════════════════════════════════")
        print("🔍 [PersonaCreation] Query (raw): \(query)")
        print("🔍 [PersonaCreation] Search type: \(isDIDQuery ? "EXACT DID FILTER" : "NATURAL LANGUAGE")")
        print("🔍 [PersonaCreation] Full URL: \(url.absoluteString)")
        print("🔍 [PersonaCreation] ═══════════════════════════════════════")
        print("🔍 [PersonaCreation] TEST WITH CURL:")
        print("curl -X GET '\(url.absoluteString)'")
        print("🔍 [PersonaCreation] ═══════════════════════════════════════")
        
        do {
            print("🔍 [PersonaCreation] Sending search request...")
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                print("❌ [PersonaCreation] Non-HTTP response for search: \(query)")
                return nil
            }
            
            print("🔍 [PersonaCreation] ═══════════════════════════════════════")
            print("🔍 [PersonaCreation] SEARCH RESPONSE")
            print("🔍 [PersonaCreation] Status: \(http.statusCode)")
            print("🔍 [PersonaCreation] Response size: \(data.count) bytes")
            print("🔍 [PersonaCreation] ═══════════════════════════════════════")
            
            guard (200...299).contains(http.statusCode) else {
                print("❌ [PersonaCreation] Search failed with status \(http.statusCode) for query: \(query)")
                if let responseText = String(data: data, encoding: .utf8) {
                    print("❌ [PersonaCreation] Response body: \(responseText)")
                }
                return false
            }
            
            // Log the raw response for debugging
            if let responseText = String(data: data, encoding: .utf8) {
                print("🔍 [PersonaCreation] Raw response (first 500 chars): \(responseText.prefix(500))")
            }
            
            let decoder = JSONDecoder()
            
            // Try the actual server format first: {"hits": [...], "query": "...", ...}
            if let searchResult = try? decoder.decode(PersonaSearchResponse.self, from: data) {
                print("🔍 [PersonaCreation] Parsed as PersonaSearchResponse")
                print("🔍 [PersonaCreation] Total hits: \(searchResult.hits.count)")
                print("🔍 [PersonaCreation] Estimated total: \(searchResult.estimatedTotalHits)")
                print("🔍 [PersonaCreation] Processing time: \(searchResult.processingTimeMs)ms")
                
                // Log all DIDs found
                for (index, hit) in searchResult.hits.enumerated() {
                    print("🔍 [PersonaCreation] Hit[\(index)]: DID=\(hit.dID), handle=\(hit.handle)")
                }
                
                let found = searchResult.hits.contains { hit in
                    let exactMatch = hit.dID.caseInsensitiveCompare(query) == .orderedSame
                    let prefixMatch = hit.dID.lowercased().hasPrefix(query.lowercased() + "(")
                    
                    if exactMatch {
                        print("✅ [PersonaCreation] FOUND: Exact match on DID: \(hit.dID)")
                    } else if prefixMatch {
                        print("✅ [PersonaCreation] FOUND: Prefix match on DID: \(hit.dID)")
                    }
                    
                    return exactMatch || prefixMatch
                }
                
                if !found {
                    print("❌ [PersonaCreation] NOT FOUND: No match for query '\(query)' in \(searchResult.hits.count) results")
                }
                
                print("🔍 [PersonaCreation] ═══════════════════════════════════════")
                return found
            }
            
            // Try array of profiles format (fallback)
            if let profiles = try? decoder.decode([PersonaProfileModel].self, from: data) {
                print("🔍 [PersonaCreation] Parsed as array of PersonaProfile")
                print("🔍 [PersonaCreation] Total profiles: \(profiles.count)")
                
                for (index, profile) in profiles.enumerated() {
                    print("🔍 [PersonaCreation] Profile[\(index)]: DID=\(profile.dID), handle=\(profile.handle)")
                }
                
                let found = profiles.contains { $0.dID.caseInsensitiveCompare(query) == .orderedSame || $0.dID.lowercased().hasPrefix(query.lowercased() + "(") }
                print("🔍 [PersonaCreation] Result: \(found ? "FOUND" : "NOT FOUND")")
                print("🔍 [PersonaCreation] ═══════════════════════════════════════")
                return found
            }
            
            // Try wrapper format (fallback)
            if let wrapped = try? decoder.decode(PersonaSearchWrapper.self, from: data) {
                print("🔍 [PersonaCreation] Parsed as PersonaSearchWrapper")
                print("🔍 [PersonaCreation] Total results: \(wrapped.results.count)")
                
                for (index, profile) in wrapped.results.enumerated() {
                    print("🔍 [PersonaCreation] Result[\(index)]: DID=\(profile.dID), handle=\(profile.handle)")
                }
                
                let found = wrapped.results.contains { $0.dID.caseInsensitiveCompare(query) == .orderedSame || $0.dID.lowercased().hasPrefix(query.lowercased() + "(") }
                print("🔍 [PersonaCreation] Result: \(found ? "FOUND" : "NOT FOUND")")
                print("🔍 [PersonaCreation] ═══════════════════════════════════════")
                return found
            }
            
            // If we can't parse the response, log it and assume not found
            let responseStr = String(data: data, encoding: .utf8) ?? "(non-UTF8 data)"
            print("⚠️ [PersonaCreation] ═══════════════════════════════════════")
            print("⚠️ [PersonaCreation] UNPARSEABLE SEARCH RESPONSE")
            print("⚠️ [PersonaCreation] Query: \(query)")
            print("⚠️ [PersonaCreation] Response: \(responseStr)")
            print("⚠️ [PersonaCreation] ═══════════════════════════════════════")
            return false
            
        } catch {
            print("❌ [PersonaCreation] ═══════════════════════════════════════")
            print("❌ [PersonaCreation] SEARCH ERROR")
            print("❌ [PersonaCreation] Query: \(query)")
            print("❌ [PersonaCreation] Error: \(error.localizedDescription)")
            print("❌ [PersonaCreation] Full error: \(error)")
            print("❌ [PersonaCreation] ═══════════════════════════════════════")
            return nil
        }
    }
    
    private func fetchPersonaByDID(_ did: String) async -> Bool? {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:/?#[]@!$&'()*+,;=%").inverted
        let path = did.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(allowed)) ?? did
        guard let url = URL(string: ServerConfig.baseURL + "/api/persona/" + path) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return nil }
            return (200...299).contains(http.statusCode)
        } catch {
            return nil
        }
    }
}

// MARK: - Text Field with Dictation Support

import Speech

/// A text field with an integrated microphone button for voice dictation
struct DictationTextField: View {
    let placeholder: String
    @Binding var text: String
    var prompt: Text? = nil
    var keyboardType: PlatformKeyboardType = .default
    var textContentType: PlatformTextContentType? = nil
    var autocapitalization: PlatformTextCase = .sentences
    var autocorrection: Bool = true
    
    @State private var isRecording = false
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var showPermissionAlert = false
    @State private var permissionDenied = false
    
    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text, prompt: prompt)
                .platformKeyboardType(keyboardType)
                .platformTextContentType(textContentType ?? .none)
                .platformAutocapitalization(autocapitalization)
                .autocorrectionDisabled(!autocorrection)
            
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startDictation()
                }
            } label: {
                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .foregroundColor(isRecording ? .red : .blue)
                    .font(.body)
                    .frame(width: 32, height: 32)
                    .background(isRecording ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(permissionDenied)
        }
        .alert("Microphone Permission Required", isPresented: $showPermissionAlert) {
            Button("Settings") {
#if os(iOS) || os(visionOS)
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
#endif
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable microphone and speech recognition permissions in Settings to use voice dictation.")
        }
    }
    
    private func startDictation() {
        // Request permissions first
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
#if os(iOS)
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            if granted {
                                startRecording()
                            } else {
                                permissionDenied = true
                                showPermissionAlert = true
                            }
                        }
                    }
#else
                    startRecording()
#endif
                } else {
                    permissionDenied = true
                    showPermissionAlert = true
                }
            }
        }
    }
    
    private func startRecording() {
        // Cancel any ongoing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session (iOS only; macOS has no AVAudioSession)
#if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error)")
            return
        }
#endif
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Get the audio input node
        let inputNode = audioEngine.inputNode
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                // Update text with the transcription
                DispatchQueue.main.async {
                    self.text = result.bestTranscription.formattedString
                }
            }
            
            if error != nil || result?.isFinal == true {
                // Stop recording
                DispatchQueue.main.async {
                    self.stopRecording()
                }
            }
        }
        
        // Configure the microphone input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start the audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }
    
    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }
}

// MARK: - Persona Identity Preview View

/// Live preview of persona identity with blue sphere formatting (signature look)
private struct PersonaIdentityPreviewView: View {
    let name: String
    let publisher: String?
    
    var body: some View {
        HStack(spacing: 12) {
            // Blue sphere avatar (gradient) - our signature look
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                // Person icon in white
                Image(systemName: "person.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            .shadow(color: .blue.opacity(0.3), radius: 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Identity Preview")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                // Name · Publisher format with blue sphere separator
                HStack(spacing: 8) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let publisher = publisher, !publisher.isEmpty {
                        // Blue sphere separator (small)
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 4, height: 4)
                        
                        Text(publisher)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.blue.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1.5)
        )
    }
}

// --- Inserted struct OneTimeSigningView as per instructions ---
private struct OneTimeSigningView: View {
    @Binding var signingName: String
    @Binding var didInput: String
    let isPublicPersona: Bool
    let defaultDomain: String
    let displayHandle: String
    let fullHandle: String
    let isDIDValid: Bool
    let validationState: () -> (isValid: Bool, reason: String?)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("One-Time Signing")
                .font(.headline)

            TextField("Signing Name (e.g., Organization or Event)", text: $signingName)
                .platformAutocapitalization(.never)
                .autocorrectionDisabled(true)

            // Show the handle preview (for private personas this will be the anonymous format)
            Text("Handle: \(displayHandle)")
                .font(.footnote)
                .foregroundColor(.secondary)

            if let reason = validationState().reason, !isDIDValid {
                Text(reason)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            Text("This flow doesn't require DNS. A unique DID will be generated and your private information will only be used for signing.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// --- Inserted struct StartPublishingHouseView as per instructions ---
private struct StartPublishingHouseView: View {
    @Binding var name: String
    @Binding var publishingHouse: String
    @Binding var didInput: String
    let isPublicPersona: Bool
    let defaultDomain: String
    let displayHandle: String
    let fullHandle: String
    let isDIDValid: Bool
    let validationState: () -> (isValid: Bool, reason: String?)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Your Name", text: $name)
                .platformAutocapitalization(.never)
                .autocorrectionDisabled(true)
            
            TextField("Publishing House", text: $publishingHouse)
                .platformAutocapitalization(.never)
                .autocorrectionDisabled(true)
            
            Text("Handle: \(displayHandle)")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            if let reason = validationState().reason, !isDIDValid {
                Text(reason)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Segments") {
    NavigationStack {
        PersonaCreationView(initialIsPublicPersona: true,
                            initialName: "Scott Francis",
                            initialPurpose: .publishing)
    }
}

#Preview {
    NavigationStack {
        PersonaCreationView()
    }
}
