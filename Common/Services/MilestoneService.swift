import Foundation

@MainActor
class MilestoneService: ObservableObject {
    @Published var schedule: MilestoneSchedule?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var baseURL: URL { URL(string: ServerConfig.baseURL)! }
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - Fetch

    func fetchSchedule(projectId: String) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let url = baseURL.appendingPathComponent("api/milestones/\(projectId)")
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try decoder.decode(MilestoneScheduleResponse.self, from: data)
            schedule = response.schedule
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign Milestone

    func signMilestone(projectId: String, milestoneId: String, signerDid: String, signerName: String, signature: String) async throws {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }

        var request = URLRequest(url: baseURL.appendingPathComponent("api/milestones/\(projectId)/sign/\(milestoneId)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "signerDid": signerDid,
            "signerName": signerName,
            "signature": signature,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let result = try? decoder.decode(MilestoneActionResponse.self, from: data)
            throw NSError(domain: "MilestoneService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: result?.error ?? "Sign failed"])
        }
        await fetchSchedule(projectId: projectId)
    }

    // MARK: - Fund Escrow

    func fundMilestoneEscrow(projectId: String, milestoneId: String) async throws {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }

        var request = URLRequest(url: baseURL.appendingPathComponent("api/milestones/\(projectId)/fund/\(milestoneId)"))
        request.httpMethod = "POST"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let result = try? decoder.decode(MilestoneActionResponse.self, from: data)
            throw NSError(domain: "MilestoneService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: result?.error ?? "Fund failed"])
        }
        await fetchSchedule(projectId: projectId)
    }
}
