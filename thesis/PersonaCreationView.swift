// PersonaCreationView.swift
// UI for creating a new persona profile

import SwiftUI
import Combine
import Foundation
import CryptoKit
import Core451

// Client-side mirror of the server's PersonaCreationRequest
private struct ServerPersonaCreationRequest: Encodable {
    let dID: String
    let prettyDID: String
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
    let dID: String
    let prettyDID: String
    let controller: String
    var isPublic: Bool

    // Persona fields
    var name: String?
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

private func personaDisplayName(_ persona: PersonaProfileModel, handle: String) -> String {
    if let displayName = persona.displayName, !displayName.isEmpty { return displayName }
    if let name = persona.name, !name.isEmpty { return name }
    if !handle.isEmpty { return handle }
    if !persona.handle.isEmpty { return persona.handle }
    return persona.dID
}

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

struct PersonaCreationView: View {
    @State private var name = ""
    @State private var didInput = ""
    @State private var affiliations = ""
    @State private var socialLinks = ""
    @State private var street = ""
    @State private var city = ""
    @State private var stateRegion = ""
    @State private var postalCode = ""
    @State private var country = ""
    @State private var showAlert = false
    @ObservedObject private var store = PersonaStore.shared
    @State private var errorMessage: String? = nil
    @State private var createdPersona: PersonaProfileModel?
    @State private var backgroundCheckRequired = false

    @EnvironmentObject private var personaManager: PersonaManager

    var onCreate: ((PersonaProfileModel) -> Void)?

    private var normalizedDID: String {
        // Split at first '@' or ' at '
        let separators = ["@", " at "]
        var firstPart = didInput
        var secondPart = ""
        for sep in separators {
            if let range = didInput.range(of: sep, options: .caseInsensitive) {
                firstPart = String(didInput[..<range.lowerBound])
                secondPart = String(didInput[range.upperBound...])
                break
            }
        }
        func normalize(_ s: String) -> String {
            return s.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: " ", with: ".")
                .replacingOccurrences(of: "..", with: ".")
        }
        let left = normalize(firstPart).components(separatedBy: ".").prefix(6).joined(separator: ".")
        let right = normalize(secondPart).components(separatedBy: ".").prefix(6).joined(separator: ".")
        return left + (secondPart.isEmpty ? "" : "@" + right)
    }

    private var isDIDValid: Bool {
        let parts = normalizedDID.split(separator: "@")
        guard parts.count == 2 else { return false }

        // left/right dot counts
        let leftDotCount = parts[0].components(separatedBy: ".").count - 1
        let rightDotCount = parts[1].components(separatedBy: ".").count - 1
        guard leftDotCount <= 5, rightDotCount <= 5 else { return false }

        // domain checks
        let domain = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        if domain.isEmpty { return false }
        if parts[0].isEmpty { return false }

        // avoid pure TLDs
        let isNotTLD = !rootLevelTLDs.contains(where: { domain.hasSuffix($0) })
        return isNotTLD
    }

    var body: some View {
        Form {
            // 1) DID first
            Section(header: Text("Persona DID")) {
                TextField("Enter DID (e.g. Scott Francis @ Francis Publishing)", text: $didInput)
                    .autocorrectionDisabled(true)
                HStack {
                    Text("Normalized:")
                    Spacer()
                    Text(normalizedDID)
                        .foregroundColor(.secondary)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            // 2) Name
            Section(header: Text("Basic Info")) {
                TextField("Name", text: $name)
            }
            // 3) Address
            Section(header: Text("Postal Address (Optional)")) {
                TextField("Street", text: $street)
                TextField("City", text: $city)
                TextField("State/Region", text: $stateRegion)
                TextField("Postal Code", text: $postalCode)
                TextField("Country", text: $country)
            }
            // 4) Affiliations & Social
            Section(header: Text("Affiliations & Social")) {
                TextField("Affiliations", text: $affiliations)
                TextField("Social Links", text: $socialLinks)
            }
            // 5) Background Toggle
            Section {
                Toggle("Background Check Required", isOn: $backgroundCheckRequired)
            }
            // 6) Create Button
            Section {
                Button("Create Persona") {
                    createPersona()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isDIDValid)
            }
        }
        .navigationTitle("Create Persona")
        .alert("Persona Created", isPresented: $showAlert, presenting: createdPersona) { _ in
            Button("OK", role: .cancel) {}
        } message: { persona in
            Text("Persona \(persona.name ?? "") created successfully.")
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Actions

    private func createPersona() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedName.isEmpty ? normalizedDID : trimmedName

        let uuid = UUID().uuidString
        let privateKey = P256.Signing.PrivateKey()
        let publicKeyRaw = privateKey.publicKey.rawRepresentation
        let publicKeyUncompressed: Data
        if publicKeyRaw.count == 65 && publicKeyRaw.first == 0x04 {
            publicKeyUncompressed = publicKeyRaw
        } else if publicKeyRaw.count == 64 {
            publicKeyUncompressed = Data([0x04]) + publicKeyRaw
        } else {
            publicKeyUncompressed = publicKeyRaw
        }
        let publicKeyBase64 = publicKeyUncompressed.base64EncodedString()
        try? PrivateKeyStore.savePrivateKey(privateKey, for: normalizedDID)

        let hasAnyAddress = !(street.isEmpty && city.isEmpty && stateRegion.isEmpty && postalCode.isEmpty && country.isEmpty)
        let addressObj = hasAnyAddress ? PersonaProfile.PostalAddress(
            street: street.isEmpty ? nil : street,
            city: city.isEmpty ? nil : city,
            state: stateRegion.isEmpty ? nil : stateRegion,
            postalCode: postalCode.isEmpty ? nil : postalCode,
            country: country.isEmpty ? nil : country
        ) : nil

        let verificationMethod = PersonaProfileModel.VerificationMethod(
            id: "\(normalizedDID)#key-1",
            type: "EcdsaSecp256r1VerificationKey2019",
            controller: normalizedDID,
            publicKeyBase64: publicKeyBase64
        )

        let persona = PersonaProfileModel(
            dID: normalizedDID,
            controller: uuid,
            backgroundCheckRequired: backgroundCheckRequired,
            guid: nil,
            shortId: nil,
            isPublic: nil,
            handle: normalizedDID,
            name: trimmedName.isEmpty ? nil : trimmedName,
            displayName: displayName,
            displayPublisher: nil,
            email: nil,
            address: addressObj,
            affiliations: affiliations.isEmpty ? nil : affiliations,
            socialLinks: socialLinks.isEmpty ? nil : socialLinks,
            verified: false,
            requestedDomain: nil,
            requestedDnsChallenge: nil,
            backgroundValidated: nil,
            validatedDomains: nil,
            type: nil,
            hash: nil,
            storageEndpoints: nil,
            resourceFolders: nil,
            metadata: ["publicKey": publicKeyBase64],
            privateData: nil,
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
                try await sendPersonaCreationRequest(persona: persona,
                                                     publicKeyBase64: publicKeyBase64,
                                                     privateKey: privateKey)
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
                return
            }
            await MainActor.run {
                // Persist to PersonaStore only after server success
                do {
                    try self.store.addPersona(persona)
                } catch {
                    self.errorMessage = "Saved to server but failed to save locally: \(error.localizedDescription)"
                    return
                }

                // Reflect in PersonaManager list (local, lightweight model)
                let lightweight = Persona(
                    id: persona.dID,
                    controller: persona.dID,
                    name: personaDisplayName(persona, handle: persona.handle),
                    handle: persona.handle,
                    address: formattedAddress(persona.address),
                    affiliations: persona.affiliations,
                    socialLinks: persona.socialLinks,
                    publicKeyBase64: publicKeyBase64,
                    storageEndpoints: nil,
                    createdAt: persona.createdAt ?? ISO8601DateFormatter().string(from: Date()),
                    updatedAt: nil,
                    eTag: nil,
                    status: "active"
                )
                self.personaManager.addPersona(lightweight)

                self.createdPersona = persona
                onCreate?(persona)
                showAlert = true
            }
        }
    }

    // MARK: - Networking

    private func sendPersonaCreationRequest(persona: PersonaProfileModel,
                                            publicKeyBase64: String,
                                            privateKey: P256.Signing.PrivateKey) async throws {
        // 1) Build the server-shaped profile for signing (match server PersonaProfile)
        let signingAddress = ServerPersonaProfileForSigning.PostalAddress(
            street: persona.address?.street,
            city: persona.address?.city,
            region: persona.address?.state,
            postalCode: persona.address?.postalCode,
            country: persona.address?.country
        )

        let signingProfile = ServerPersonaProfileForSigning(
            dID: persona.dID,
            prettyDID: personaDisplayName(persona, handle: persona.handle),
            controller: persona.dID,
            isPublic: false,
            name: persona.name,
            address: (persona.address == nil) ? nil : signingAddress,
            affiliations: persona.affiliations,
            socialLinks: persona.socialLinks,
            verified: persona.verified,
            backgroundCheckRequired: persona.backgroundCheckRequired,
            requestedDomain: persona.requestedDomain,
            requestedDnsChallenge: persona.requestedDnsChallenge,
            backgroundValidated: nil,
            validatedDomains: nil,
            type: nil,
            hash: nil,
            storageEndpoints: nil,
            resourceFolders: nil,
            metadata: nil,
            createdAt: nil,
            updatedAt: nil,
            eTag: nil,
            verificationMethod: [
                .init(
                    id: "\(persona.dID)#key-1",
                    type: "EcdsaSecp256r1VerificationKey2019",
                    controller: persona.dID,
                    publicKeyBase64: publicKeyBase64
                )
            ],
            service: [],
            previousBlock: nil,
            relatedBlock: nil,
            signature: nil
        )

        // 2) Canonical encode with sortedKeys and signature=nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let canonicalData = try encoder.encode(signingProfile)

        // 3) Sign with P-256; DER Base64
        let signatureDER = try privateKey.signature(for: canonicalData).derRepresentation
        let signatureBase64 = signatureDER.base64EncodedString()

        // 4) Build server PersonaCreationRequest body
        var addressDict: [String: String]? = nil
        if persona.address != nil {
            addressDict = [
                "street": persona.address?.street ?? "",
                "city": persona.address?.city ?? "",
                "region": persona.address?.state ?? "",
                "postalCode": persona.address?.postalCode ?? "",
                "country": persona.address?.country ?? ""
            ]
        }

        let requestBody = ServerPersonaCreationRequest(
            dID: persona.dID.lowercased(),
            prettyDID: personaDisplayName(persona, handle: persona.handle),
            name: persona.name ?? personaDisplayName(persona, handle: persona.handle),
            attributes: ["publicKey": publicKeyBase64],
            address: addressDict,
            verified: persona.verified ?? false,
            isPublic: false,
            backgroundValidated: nil,
            backgroundCheckRequired: persona.backgroundCheckRequired,
            domainToBeVerified: persona.requestedDomain,
            dnsChallengeValue: persona.requestedDnsChallenge,
            verificationMethod: [
                .init(
                    id: "\(persona.dID)#key-1",
                    type: "EcdsaSecp256r1VerificationKey2019",
                    controller: persona.dID,
                    publicKeyBase64: publicKeyBase64
                )
            ],
            signature: signatureBase64
        )

        // 5) Send to server
        guard let url = URL(string: ServerConfig.baseURL + "/api/persona") else {
            throw URLError(.badURL)
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)

        // Verbose logging
        let reqId = NetLog.id()
        NetLog.request(reqId, urlRequest)
        let start = Date()

        // Use custom session to log redirects
        let delegate = NetSessionDelegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        // Bridge dataTask to async/await
        let (data, response): (Data, URLResponse) = try await withCheckedThrowingContinuation { cont in
            let task = session.dataTask(with: urlRequest) { data, response, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else if let data = data, let response = response {
                    cont.resume(returning: (data, response))
                } else {
                    cont.resume(throwing: URLError(.unknown))
                }
            }
            task.taskDescription = reqId
            task.resume()
        }

        let duration = Date().timeIntervalSince(start)
        if let httpResponse = response as? HTTPURLResponse {
            if (200...299).contains(httpResponse.statusCode) {
                NetLog.response(reqId, httpResponse, data: data, duration: duration)
                // Optionally: decode returned PersonaProfile and return it to merge/save.
                // For now, we only confirm success and persist the client persona.
            } else {
                NetLog.error(reqId, httpResponse, data: data, err: nil, duration: duration)
                let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "PersonaCreation", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
        } else {
            NetLog.error(reqId, nil, data: data, err: nil, duration: duration)
            throw NSError(domain: "PersonaCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Non-HTTP response"])
        }
    }
}

#Preview {
    NavigationStack {
        PersonaCreationView()
    }
    .environmentObject(PersonaManager())
}
