import SwiftUI

struct ProgressStatusCardView: View {
    let title: String
    let subtitle: String
    let iconName: String
    let gradient: [Color]
    let progress: Double? // 0...1
    let steps: [PublishingCardsViewModel.Step]

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let p = progress {
                    HStack(spacing: 8) {
                        ProgressView(value: p)
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                        Text("\(Int(p * 100))%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 6)
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Working…")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 6)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(steps) { step in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: step.isComplete ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(step.isComplete ? .green : .white.opacity(0.7))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.white)
                                if let detail = step.detail, !detail.isEmpty {
                                    Text(detail)
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.top, 6)

                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .frame(width: 260, height: 340)
    }
}

#Preview {
    let steps = [
        PublishingCardsViewModel.Step(title: "Preparing document…", isComplete: true),
        PublishingCardsViewModel.Step(title: "Document loaded", isComplete: true, detail: "932,770 bytes"),
        PublishingCardsViewModel.Step(title: "Embedding PDF metadata…", isComplete: true),
        PublishingCardsViewModel.Step(title: "Validating persona credentials…", isComplete: false)
    ]
    return ProgressStatusCardView(
        title: "S3 Cloud",
        subtitle: "Uploading to S3 providers",
        iconName: "cloud.fill",
        gradient: [Color.blue, Color.blue.opacity(0.8)],
        progress: 0.6,
        steps: steps
    )
    .padding()
    .background(Color.primary.opacity(0.05))
}
