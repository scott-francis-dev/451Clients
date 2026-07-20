import SwiftUI
import RichTextKit


struct PageEditorContainer: View {

    @Binding var document: RichTextDocument
    @StateObject private var richTextContext = RichTextContext()
    // @State private var isInspectorPresented = false
    @Binding var scrollProgress: CGFloat
    @Binding var caretProgress: CGFloat
    var onNearEnd: () -> Void
    var onOverscrollTop: () -> Void
    var onOverscrollBottom: () -> Void

    private var resolvedOnBold: () -> Void {
        // Implementation detail
        {}
    }
    private var resolvedOnItalic: () -> Void {
        // Implementation detail
        {}
    }
    private var resolvedOnUnderline: () -> Void {
        // Implementation detail
        {}
    }
    private var resolvedOnStrikethrough: () -> Void {
        // Implementation detail
        {}
    }

    var body: some View {
        VStack(spacing: 0) {
            // #if os(macOS)
            // RichTextFormat.Toolbar(context: richTextContext)
            // #endif
            RichTextKit.RichTextEditor(
                text: Binding(
                    get: { document.attributed },
                    set: { document.attributed = NSMutableAttributedString(attributedString: $0) }
                ),
                context: richTextContext
            )
            // Use this to just view the text:
            // RichTextViewer(document.attributed)
            // #if os(iOS)
            // RichTextKeyboardToolbar(
            //     context: context,
            //     leadingButtons: { $0 },
            //     trailingButtons: { $0 },
            //     formatSheet: { $0 }
            // )
            // #endif
        }
        // .inspector(isPresented: $isInspectorPresented) {
        //     RichTextFormat.Sidebar(context: context)
        //         #if os(macOS)
        //         .inspectorColumnWidth(min: 200, ideal: 200, max: 315)
        //         #endif
        // }
        // .toolbar {
        //     ToolbarItem(placement: .automatic) {
        //         Toggle(isOn: $isInspectorPresented) {
        //             Image.richTextFormatBrush
        //                 .resizable()
        //                 .aspectRatio(1, contentMode: .fit)
        //         }
        //     }
        // }
        .frame(minWidth: 500)
        // .focusedValue(\.richTextContext, context)
        // .toolbarRole(.automatic)
        // .richTextFormatSheetConfig(.init(colorPickers: colorPickers))
        // .richTextFormatSidebarConfig(
        //     .init(
        //         colorPickers: colorPickers,
        //         fontPicker: isMac
        //     )
        // )
        // .richTextFormatToolbarConfig(.init(colorPickers: []))
    }
}

// Extension methods commented out since RichTextKit components are disabled
// private extension PageEditorContainer{
//
//     var isMac: Bool {
//         #if os(macOS)
//         true
//         #else
//         false
//         #endif
//     }
//
//     var colorPickers: [RichTextColor] {
//         [.foreground, .background]
//     }
//
//     var formatToolbarEdge: VerticalEdge {
//         isMac ? .top : .bottom
//     }
// }

