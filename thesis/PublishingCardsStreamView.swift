import SwiftUI
import Core451

typealias StatusCardModel = PublishingCardsViewModel.StatusCardModel

struct PublishingCardsStreamView: View {
    @StateObject private var model = PublishingCardsViewModel()

    var body: some View {
        VStack(spacing: 24) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(model.visibleCards, id: \.id) { card in
                        switch card.state {
                        case .inProgress(let progress, let steps):
                            ProgressStatusCardView(
                                title: card.title,
                                subtitle: card.subtitle,
                                iconName: card.iconName,
                                gradient: card.gradient,
                                progress: progress,
                                steps: steps
                            )
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                    removal: .opacity))
                        case .success, .failure:
                            StatusCardView(model: card)
                                .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                        removal: .opacity))
                        case .pending:
                            ProgressStatusCardView(
                                title: card.title,
                                subtitle: card.subtitle,
                                iconName: card.iconName,
                                gradient: card.gradient,
                                progress: nil,
                                steps: []
                            )
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                    removal: .opacity))
                        }
                    }
                }
                .padding(.horizontal)
            }

            if model.showCompletionCard {
                StatusCardView(
                    model: StatusCardModel(
                        title: "Publishing Complete",
                        subtitle: "Your document has been published successfully.",
                        state: .success,
                        providers: [],
                        iconName: "checkmark.seal.fill",
                        gradient: [Color.blue, Color.purple]
                    )
                )
                .frame(width: 280, height: 200)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: model.showCompletionCard)
        .onAppear {
            model.reset()
        }
    }
}

struct StatusCardView: View {
    let model: StatusCardModel

    private var statusText: String {
        switch model.state {
        case .success:
            return "Success"
        case .failure:
            return "Failed"
        case .inProgress, .pending:
            return "In Progress"
        }
    }

    private var statusIconName: String {
        switch model.state {
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "xmark.octagon.fill"
        case .inProgress, .pending:
            return "hourglass"
        }
    }

    private var statusColor: Color {
        switch model.state {
        case .success:
            return .green
        case .failure:
            return .red
        case .inProgress, .pending:
            return .white.opacity(0.85)
        }
    }

    private var failureMessage: String? {
        if case .failure(let message) = model.state {
            return message
        }
        return nil
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: model.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: model.iconName)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(model.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    Image(systemName: statusIconName)
                        .foregroundStyle(statusColor)
                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 6)

                if let failureMessage, !failureMessage.isEmpty {
                    Text(failureMessage)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.top, 2)
                }

                if !model.providers.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(model.providers, id: \.self) { provider in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.white.opacity(0.9))
                                Text(provider)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.top, 6)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .frame(width: 260, height: 200)
    }
}

#Preview {
    PublishingCardsStreamView()
}
