import SwiftUI

struct Document: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let isSigned: Bool
}
struct DocumentRow: View {
    let document: Document
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .frame(width: 40, height: 50)
                .overlay(Image(systemName: "doc.fill")
                            .foregroundColor(.white))

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                Text(document.subtitle)
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.horizontal)
    }
}
