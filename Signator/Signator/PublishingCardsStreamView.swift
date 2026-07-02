import SwiftUI

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
                        case .success:
                            StatusCardView(
                                model: StatusCardModel(
                                    title: card.title,
                                    subtitle: card.subtitle,
                                    status: .success,
                                    providers: card.providers,
                                    iconName: card.iconName,
                                    gradient: card.gradient
                                )
                            )
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                    removal: .opacity))
                        case .failure(let message):
                            StatusCardView(
                                model: StatusCardModel(
                                    title: card.title,
                                    subtitle: card.subtitle,
                                    status: .failure(message),
                                    providers: card.providers,
                                    iconName: card.iconName,
                                    gradient: card.gradient
                                )
                            )
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
                        status: .success,
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

#Preview {
    PublishingCardsStreamView()
}
