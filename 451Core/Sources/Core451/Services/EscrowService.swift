import Foundation

// MARK: - Models

struct EscrowStatus: Codable, Identifiable {
    let id: String
    let invoiceId: String
    let projectId: String
    let amount: Double
    let status: EscrowStatusValue
    let payerUsercode: String
    let payeeUsercode: String
    let fundedAt: String?
    let releaseRequestedAt: String?
    let releasedAt: String?
    let cancelledAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case invoiceId = "invoice_id"
        case projectId = "project_id"
        case amount
        case status
        case payerUsercode = "payer_usercode"
        case payeeUsercode = "payee_usercode"
        case fundedAt = "funded_at"
        case releaseRequestedAt = "release_requested_at"
        case releasedAt = "released_at"
        case cancelledAt = "cancelled_at"
    }
}

enum EscrowStatusValue: String, Codable {
    case pending
    case funded
    case releaseRequested = "release_requested"
    case released
    case cancelled
    case refunded

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .funded: return "In Escrow"
        case .releaseRequested: return "Release Requested"
        case .released: return "Released"
        case .cancelled: return "Cancelled"
        case .refunded: return "Refunded"
        }
    }
}

struct EscrowResponse: Codable {
    let escrow: EscrowStatus?
}

struct EscrowActionResponse: Codable {
    let success: Bool
    let escrowId: String?
    let transferId: String?
    let error: String?
}

// MARK: - EscrowService

@MainActor
class EscrowService: ObservableObject {
    @Published var escrow: EscrowStatus?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var baseURL: URL { URL(string: ServerConfig.baseURL)! }

    // MARK: - Fetch Status

    func fetchEscrowStatus(invoiceId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let url = baseURL.appendingPathComponent("api/escrow/status/\(invoiceId)")
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(EscrowResponse.self, from: data)
            escrow = response.escrow
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Create / Fund Escrow

    func createEscrow(invoiceId: String, projectId: String, amount: Double, payeeUsercode: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var request = URLRequest(url: baseURL.appendingPathComponent("api/escrow/create"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "invoiceId": invoiceId,
            "projectId": projectId,
            "amount": String(amount),
            "payeeUsercode": payeeUsercode,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let result = try? JSONDecoder().decode(EscrowActionResponse.self, from: data)
            throw NSError(domain: "EscrowService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: result?.error ?? "Failed to create escrow"])
        }
        await fetchEscrowStatus(invoiceId: invoiceId)
    }

    // MARK: - Request Release (Contractor)

    func requestRelease(invoiceId: String) async throws {
        try await performAction(endpoint: "api/escrow/request-release", invoiceId: invoiceId)
    }

    // MARK: - Approve Release (Owner)

    func approveRelease(invoiceId: String) async throws {
        try await performAction(endpoint: "api/escrow/approve-release", invoiceId: invoiceId)
    }

    // MARK: - Cancel & Refund (Owner)

    func cancelEscrow(invoiceId: String) async throws {
        try await performAction(endpoint: "api/escrow/cancel", invoiceId: invoiceId)
    }

    // MARK: - Private Helper

    private func performAction(endpoint: String, invoiceId: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["invoiceId": invoiceId])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let result = try? JSONDecoder().decode(EscrowActionResponse.self, from: data)
            throw NSError(domain: "EscrowService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: result?.error ?? "Action failed"])
        }
        await fetchEscrowStatus(invoiceId: invoiceId)
    }
}
