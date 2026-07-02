import SwiftUI
import Core451
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@available(iOS 16.0, *)
struct EditorToolbarOverlay<Content: View>: View {

    @Binding var attributedText: NSMutableAttributedString
    @Binding var selectedRange: NSRange
    @Binding var scrollProgress: CGFloat
    @Binding var caretProgress: CGFloat

    let onScrollNearEnd: () -> Void
    let onOverscrollAtTop: () -> Void
    let onOverscrollAtBottom: () -> Void

    @ViewBuilder let overlay: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            RichTextEditor(
                attributedText: Binding(get: { attributedText }, set: { attributedText = $0 }),
                selectedRange: Binding(get: { selectedRange }, set: { selectedRange = $0 }),
                scrollProgress: $scrollProgress,
                caretProgress: $caretProgress,
                onScrollNearEnd: onScrollNearEnd,
                onOverscrollAtTop: onOverscrollAtTop,
                onOverscrollAtBottom: onOverscrollAtBottom
            )
            .zIndex(0)
        }
        .safeAreaInset(edge: .bottom) {
            ZStack {
                // A barely visible material to make the inset hit-testable
                Color.clear
                    .background(Color.clear)
                HStack {
                    Spacer(minLength: 0)
                    overlay()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .allowsHitTesting(true)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
            .zIndex(1)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }
}

#if DEBUG
@available(iOS 16.0, *)
struct EditorToolbarOverlay_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var attributedText = NSMutableAttributedString(string: "Hello, world!")
        @State private var selectedRange = NSRange(location: 0, length: 0)
        @State private var scrollProgress: CGFloat = 0
        @State private var caretProgress: CGFloat = 0

        var body: some View {
            EditorToolbarOverlay(
                attributedText: $attributedText,
                selectedRange: $selectedRange,
                scrollProgress: $scrollProgress,
                caretProgress: $caretProgress,
                onScrollNearEnd: {},
                onOverscrollAtTop: {},
                onOverscrollAtBottom: {}
            ) {
                HStack(spacing: 16) {
                    Button(action: {}) {
                        Image(systemName: "bold")
                    }
                    Button(action: {}) {
                        Image(systemName: "italic")
                    }
                    Button(action: {}) {
                        Image(systemName: "underline")
                    }
                }
                .font(.title2)
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .previewLayout(.sizeThatFits)
    }
}
#endif

