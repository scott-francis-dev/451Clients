import SwiftUI
import Combine

final class PublishingCardsViewModel: ObservableObject {
    enum Phase: String, CaseIterable, Identifiable {
        case s3Cloud
        case blockchain
        case signatureFile
        case searchIndexing
        var id: String { rawValue }
        var title: String {
            switch self {
            case .s3Cloud: return "S3 Cloud"
            case .blockchain: return "Blockchain"
            case .signatureFile: return "Signature File"
            case .searchIndexing: return "Search Indexing"
            }
        }
        var subtitle: String {
            switch self {
            case .s3Cloud: return "Documents uploaded to S3 Providers"
            case .blockchain: return "Green Blockchain: Head updated"
            case .signatureFile: return "Signature file uploaded"
            case .searchIndexing: return "Metadata indexed for search"
            }
        }
        var iconName: String {
            switch self {
            case .s3Cloud: return "cloud.fill"
            case .blockchain: return "lock.shield.fill"
            case .signatureFile: return "signature"
            case .searchIndexing: return "magnifyingglass"
            }
        }
        var gradient: [Color] {
            switch self {
            case .s3Cloud: return [Color(red: 0.07, green: 0.63, blue: 0.99), Color(red: 0.00, green: 0.35, blue: 0.86)]
            case .blockchain: return [Color.green, Color.green.opacity(0.75)]
            case .signatureFile: return [Color.orange, Color.orange.opacity(0.75)]
            case .searchIndexing: return [Color.pink, Color.pink.opacity(0.75)]
            }
        }
    }

    struct Step: Identifiable, Equatable {
        let id = UUID()
        var title: String
        var isComplete: Bool = false
        var detail: String? = nil
    }

    enum PhaseState: Equatable {
        case pending
        case inProgress(progress: Double?, steps: [Step])
        case success
        case failure(message: String?)
    }

    struct StatusCardModel: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        var state: PhaseState
        let providers: [String]
        let iconName: String
        let gradient: [Color]
    }

    @Published var visibleCards: [StatusCardModel] = []
    @Published var showCompletionCard: Bool = false

    private var completedPhases: Set<Phase> = []
    private var providersCompleted: Set<String> = []
    private var completionTimer: AnyCancellable?

    // Configure which providers count toward S3 success
    private let allProviders: Set<String> = ["Backblaze B2", "Cloudflare R2", "451 Info (MinIO)"]

    func reset() {
        visibleCards = []
        showCompletionCard = false
        completedPhases = []
        providersCompleted = []
        completionTimer?.cancel()
        completionTimer = nil
    }

    // MARK: - Incoming message handlers

    func markProviderUploadSuccess(providerName: String) {
        providersCompleted.insert(providerName)
        if providersCompleted.isSuperset(of: allProviders) {
            completePhaseIfNeeded(.s3Cloud) { phase in
                StatusCardModel(
                    title: phase.title,
                    subtitle: "Documents uploaded to S3 Providers:",
                    state: .success,
                    providers: Array(allProviders).sorted(),
                    iconName: phase.iconName,
                    gradient: phase.gradient
                )
            }
        }
    }

    func markBlockchainHeadUpdated() {
        completePhaseIfNeeded(.blockchain) { phase in
            StatusCardModel(
                title: phase.title,
                subtitle: "Head updated",
                state: .success,
                providers: [],
                iconName: phase.iconName,
                gradient: phase.gradient
            )
        }
    }

    func markSignatureFileUploaded() {
        completePhaseIfNeeded(.signatureFile) { phase in
            StatusCardModel(
                title: phase.title,
                subtitle: "Signature file uploaded",
                state: .success,
                providers: Array(allProviders).sorted(),
                iconName: phase.iconName,
                gradient: phase.gradient
            )
        }
    }

    func markSearchIndexed() {
        completePhaseIfNeeded(.searchIndexing) { phase in
            StatusCardModel(
                title: phase.title,
                subtitle: "Metadata indexed for search",
                state: .success,
                providers: [],
                iconName: phase.iconName,
                gradient: phase.gradient
            )
        }
    }

    // MARK: - Core appending logic and 3-second hold

    // MARK: - Progress helpers for step-by-step updates

    func startPhaseInProgress(_ phase: Phase, steps: [Step], initialProgress: Double? = nil, subtitle: String? = nil) {
        guard !completedPhases.contains(phase) else { return }
        let card = StatusCardModel(
            title: phase.title,
            subtitle: subtitle ?? phase.subtitle,
            state: .inProgress(progress: initialProgress, steps: steps),
            providers: [],
            iconName: phase.iconName,
            gradient: phase.gradient
        )
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            visibleCards.append(card)
        }
    }

    func updatePhaseProgress(_ phase: Phase, progress: Double?, completeStepAt index: Int? = nil, detail: String? = nil) {
        guard let i = visibleCards.firstIndex(where: { $0.title == phase.title }) else { return }
        switch visibleCards[i].state {
        case .inProgress(let oldProgress, var steps):
            if let idx = index, steps.indices.contains(idx) {
                steps[idx].isComplete = true
                if let detail { steps[idx].detail = detail }
            }
            visibleCards[i].state = .inProgress(progress: progress ?? oldProgress, steps: steps)
        default:
            break
        }
    }

    func finishPhaseSuccess(_ phase: Phase) {
        guard let i = visibleCards.firstIndex(where: { $0.title == phase.title }) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            visibleCards[i].state = .success
        }
        completedPhases.insert(phase)
        if completedPhases.count == Phase.allCases.count { startCompletionHold() }
    }

    func failPhase(_ phase: Phase, message: String? = nil) {
        guard let i = visibleCards.firstIndex(where: { $0.title == phase.title }) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            visibleCards[i].state = .failure(message: message)
        }
        completedPhases.insert(phase)
        if completedPhases.count == Phase.allCases.count { startCompletionHold() }
    }

    private func completePhaseIfNeeded(_ phase: Phase, cardBuilder: (Phase) -> StatusCardModel) {
        guard !completedPhases.contains(phase) else { return }
        completedPhases.insert(phase)
        let card = cardBuilder(phase)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            visibleCards.append(card)
        }
        if completedPhases.count == Phase.allCases.count {
            startCompletionHold()
        }
    }

    private func startCompletionHold() {
        completionTimer?.cancel()
        completionTimer = Just(())
            .delay(for: .seconds(3), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.showCompletionCard = true
            }
    }
}

