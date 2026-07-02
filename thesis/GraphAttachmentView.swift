import SwiftUI
import Core451

struct GraphAttachmentView: View {
    let objectId: String

    @State private var value: Double = 0.5

    var body: some View {
        VStack(spacing: 8) {
            Text("Graph • \(objectId)")
                .font(.caption)
                .padding(4)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            GeometryReader { geo in
                Path { p in
                    let w = geo.size.width
                    let h = geo.size.height
                    p.move(to: CGPoint(x: 0, y: h * (1 - value)))
                    p.addLine(to: CGPoint(x: w, y: h * value))
                }
                .stroke(Color.accentColor, lineWidth: 2)
            }
            .frame(width: 160, height: 80)
            Slider(value: $value, in: 0...1)
                .frame(width: 160)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 1))
    }
}
