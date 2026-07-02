import SwiftUI

private let appTopHeaderDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter
}()

struct AppTopHeader<Trailing: View>: View {
    let trailing: () -> Trailing

    init(@ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("WALLET")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .kerning(2)
                    .textCase(.uppercase)
                Text(appTopHeaderDateFormatter.string(from: Date()))
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            trailing()
                .font(.headline)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}
