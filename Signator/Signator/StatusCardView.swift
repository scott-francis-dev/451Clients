import SwiftUI

enum CardStatus: Equatable {
    case pending
    case inProgress(Double?) // 0...1 optional progress
    case success
    case warning(String?)
    case failure(String?)
}

struct StatusCardModel: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var subtitle: String
    var status: CardStatus
    var providers: [String] = []
    var iconName: String
    var gradient: [Color]
}

struct StatusCardView: View {
    let model: StatusCardModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: model.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: model.iconName)
                    .font(.system(size: 34, weight: .semibold))
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

                if !model.providers.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(model.providers, id: \.self) { provider in
                            Text(provider)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .padding(.top, 4)
                }

                statusBadge
                    .padding(.top, 8)

                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .frame(width: 260, height: 340)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch model.status {
        case .pending:
            label(text: "Pending", color: .white.opacity(0.85))
        case .inProgress(let progress):
            if let p = progress {
                HStack(spacing: 8) {
                    ProgressView(value: p)
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                    Text("\(Int(p * 100))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
            } else {
                label(text: "In Progress", color: .white)
            }
        case .success:
            label(text: "Complete", color: .white)
        case .warning(let message):
            label(text: message ?? "Warning", color: .yellow)
        case .failure(let message):
            label(text: message ?? "Failed", color: .red)
        }
    }

    private func label(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.15), in: Capsule())
    }
}

#Preview {
    let demo = StatusCardModel(
        title: "S3 Cloud",
        subtitle: "Documents uploaded to S3 Providers:",
        status: .success,
        providers: ["Backblaze B2", "Cloudflare R2", "451 Info (MinIO)"],
        iconName: "cloud.fill",
        gradient: [Color.blue, Color.blue.opacity(0.7)]
    )
    StatusCardView(model: demo)
        .padding()
        .background(Color(white: 0.95))
}
