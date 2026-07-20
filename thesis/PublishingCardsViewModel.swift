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

    // MARK: - Simulated publish sequence

    /// Drives the four publishing phases with staged progress for demo/UI use.
    ///
    /// TODO: Replace these staged calls with real publishing-service events
    /// (S3 uploads, blockchain head update, signature upload, search indexing).
    func runSimulatedPublish() {
        reset()

        let providerSteps = [
            Step(title: "Backblaze B2"),
            Step(title: "Cloudflare R2"),
            Step(title: "451 Info (MinIO)")
        ]

        schedule(0.1) { self.startPhaseInProgress(.s3Cloud, steps: providerSteps, initialProgress: 0.05) }
        schedule(0.6) { self.updatePhaseProgress(.s3Cloud, progress: 0.33, completeStepAt: 0) }
        schedule(1.1) { self.updatePhaseProgress(.s3Cloud, progress: 0.66, completeStepAt: 1) }
        schedule(1.6) { self.updatePhaseProgress(.s3Cloud, progress: 1.0, completeStepAt: 2) }
        schedule(1.8) { self.finishPhaseSuccess(.s3Cloud) }

        schedule(1.9) { self.startPhaseInProgress(.blockchain, steps: [Step(title: "Compute head"), Step(title: "Commit head")], initialProgress: 0.25) }
        schedule(2.5) { self.updatePhaseProgress(.blockchain, progress: 1.0, completeStepAt: 0, detail: "Head committed") }
        schedule(2.7) { self.finishPhaseSuccess(.blockchain) }

        schedule(2.8) { self.startPhaseInProgress(.signatureFile, steps: [Step(title: "Sign document"), Step(title: "Upload signature")], initialProgress: 0.25) }
        schedule(3.4) { self.updatePhaseProgress(.signatureFile, progress: 1.0, completeStepAt: 1) }
        schedule(3.6) { self.finishPhaseSuccess(.signatureFile) }

        schedule(3.7) { self.startPhaseInProgress(.searchIndexing, steps: [Step(title: "Index metadata")], initialProgress: 0.4) }
        schedule(4.3) { self.updatePhaseProgress(.searchIndexing, progress: 1.0, completeStepAt: 0) }
        schedule(4.5) { self.finishPhaseSuccess(.searchIndexing) }
    }

    private func schedule(_ delay: TimeInterval, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}

