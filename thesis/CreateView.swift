import SwiftUI
import RichTextKit
import Core451

#if os(macOS)
import AppKit
#endif

struct CreateView: View {
    @Environment(\.undoManager) private var undoManager
    @StateObject private var richTextContext = RichTextContext()

    // Local draft page. If you want to pass a binding from the tab container,
    // change this to `@Binding var page: Page` and adjust MainAppView accordingly.
    @State private var page: Page = {
        let emptyDoc = RichDoc(version: 1, blocks: [Block(type: .paragraph, inlines: [])])
        let data = (try? RichTextCodec.encodeJSON(emptyDoc)) ?? Data()
        return Page(title: "Draft", richTextJSON: data)
    }()

    var body: some View {
        #if os(macOS)
        // Sidebars are now moved to DraftEditorView. Keep this view minimal.
        VStack(spacing: 0) {
            RichTextKit.RichTextEditor(
                text: Binding(
                    get: { page.doc.attributed },
                    set: { newValue in
                        page.doc.attributed = NSMutableAttributedString(attributedString: newValue)
                        ActivityManager.triggerIfNeeded(forPlainText: newValue.string)
                    }
                ),
                context: richTextContext
            )
            .environmentObject(richTextContext)
            .padding(8)
        }
        .environmentObject(richTextContext)
        .navigationTitle("Create")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button { richTextContext.toggleStyle(.bold) } label: { Image(systemName: "bold") }
                Button { richTextContext.toggleStyle(.italic) } label: { Image(systemName: "italic") }
                Button { richTextContext.toggleStyle(.underlined) } label: { Image(systemName: "underline") }
                Button { richTextContext.toggleStyle(.strikethrough) } label: { Image(systemName: "strikethrough") }
            }
        }
        .onChange(of: page.doc.attributed) { _ in }
        #else
        VStack(spacing: 0) {
            RichTextKit.RichTextEditor(
                text: Binding(
                    get: { page.doc.attributed },
                    set: { newValue in
                        page.doc.attributed = NSMutableAttributedString(attributedString: newValue)
                        ActivityManager.triggerIfNeeded(forPlainText: newValue.string)
                    }
                ),
                context: richTextContext
            )
            .environmentObject(richTextContext)
            .padding(8)
        }
        .environmentObject(richTextContext)
        .navigationTitle("Create")
        .toolbar(content: {
            #if canImport(UIKit) && !os(visionOS)
            ToolbarItemGroup(placement: .keyboard) {
                Button { richTextContext.toggleStyle(.bold) } label: { Image(systemName: "bold") }
                Button { richTextContext.toggleStyle(.italic) } label: { Image(systemName: "italic") }
                Button { richTextContext.toggleStyle(.underlined) } label: { Image(systemName: "underline") }
                Button { richTextContext.toggleStyle(.strikethrough) } label: { Image(systemName: "strikethrough") }
                Spacer(minLength: 16)
                Button { undoManager?.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                Button { undoManager?.redo() } label: { Image(systemName: "arrow.uturn.forward") }
            }
            #endif
        })
        .onChange(of: page.doc.attributed) { _ in }
        #endif
    }
}

// MARK: - Sidebars (moved to DraftEditorView)
// CreateLLMSuggestionsSidebar and CreateSearchResultsSidebar have been moved to DraftEditorView usage.

#Preview {
    NavigationStack {
        CreateView()
    }
}

