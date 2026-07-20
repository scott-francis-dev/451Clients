import SwiftUI

struct PagesPicker: View {
    @Binding var book: Book
    @Binding var selectedIndex: Int

    var onBeforeChange: () -> Void = {}
    var onAfterChange: () -> Void = {}

    @State private var editingTitleForPageID: UUID? = nil
    @Environment(\.dismiss) private var dismiss

    // A virtual extra tab at the end that creates a page when selected.
    private var addPageTabIndex: Int { book.pages.count }

    var body: some View {
        NavigationStack {
            pager
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            addPageAndSelect()
                        } label: {
                            Label("Add Page", systemImage: "plus.circle")
                        }
                    }
                }
                .navigationTitle("Pages")
        }
        .onAppear {
            // Ensure we have at least one page and a valid selection.
            if book.pages.isEmpty {
                addPageAndSelect()
            } else if selectedIndex >= book.pages.count {
                selectedIndex = max(0, book.pages.count - 1)
            }
        }
    }

    // MARK: - Pager

    private var pager: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(book.pages.enumerated()), id: \.element.id) { (idx, page) in
                PageCard(
                    index: idx,
                    page: page,
                    isEditingTitle: editingTitleForPageID == page.id,
                    titleBinding: bindingForTitle(pageID: page.id),
                    onRename: { editingTitleForPageID = page.id },
                    onEndEditing: { editingTitleForPageID = nil }
                )
                .tag(idx)
                .padding()
            }

            // Trailing "Add New Page" sentinel
            addNewPageCard
                .tag(addPageTabIndex)
        }
#if os(iOS) || os(visionOS)
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .never))
#endif
        .onChange(of: selectedIndex) { newValue in
            if newValue == addPageTabIndex {
                // Swiped onto the add tab; create a new page and select it.
                addPageAndSelect()
            } else if newValue >= 0 && newValue < book.pages.count {
                // Normal page change
                onBeforeChange()
                DispatchQueue.main.async {
                    onAfterChange()
                }
            }
        }
    }

    private var addNewPageCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.circle")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(.secondary)
            Text("New Page")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Swipe here to create a page.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            addPageAndSelect()
        }
        .padding()
    }

    // MARK: - Helpers

    private func bindingForTitle(pageID: UUID) -> Binding<String> {
        Binding<String>(
            get: {
                book.pages.first(where: { $0.id == pageID })?.title ?? ""
            },
            set: { newValue in
                if let i = book.pages.firstIndex(where: { $0.id == pageID }) {
                    book.pages[i].title = newValue
                }
            }
        )
    }

    private func addPageAndSelect() {
        let emptyDoc = RichDoc(version: 1, blocks: [
            Block(type: .paragraph, inlines: [.text(TextRun(text: ""))])
        ])
        let data = (try? RichTextCodec.encodeJSON(emptyDoc)) ?? Data()
        let newPage = Page(title: "Page \(book.pages.count + 1)", richTextJSON: data)

        book.pages.append(newPage)
        let newIndex = book.pages.count - 1

        onBeforeChange()
        selectedIndex = newIndex
        DispatchQueue.main.async {
            onAfterChange()
        }
    }
}

private struct PageCard: View {
    let index: Int
    let page: Page
    let isEditingTitle: Bool
    let titleBinding: Binding<String>

    let onRename: () -> Void
    let onEndEditing: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if isEditingTitle {
                    TextField("Title", text: titleBinding)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { onEndEditing() }
                } else {
                    Text(displayTitle())
                        .font(.title2)
                        .bold()
                        .onTapGesture { onRename() }
                }
                Spacer()
                Text("#\(index + 1)")
                    .foregroundStyle(.secondary)
            }

            // Simple preview from first non-empty text run
            Text(previewText())
                .foregroundStyle(.secondary)
                .lineLimit(6)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func displayTitle() -> String {
        page.title.isEmpty ? "Page \(index + 1)" : page.title
    }

    private func previewText() -> String {
        guard let doc = try? RichTextCodec.decodeJSON(page.richTextJSON) else { return "" }
        for block in doc.blocks {
            for inline in block.inlines {
                if case .text(let tr) = inline, !tr.text.isEmpty {
                    return tr.text
                }
            }
        }
        return ""
    }
}
