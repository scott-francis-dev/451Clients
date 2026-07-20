import SwiftUI

struct MetadataView: View {
    let book: Book
    let page: Page

    var body: some View {
        NavigationStack {
            Form {
                Section("Book") {
                    LabeledContent("Title", value: book.title.isEmpty ? "Untitled Book" : book.title)
                    LabeledContent("Author", value: book.author.isEmpty ? "—" : book.author)
                    LabeledContent("Language", value: book.language.isEmpty ? "—" : book.language)
                    LabeledContent("Identifier", value: book.identifier.isEmpty ? "—" : book.identifier)
                }
                Section("Page") {
                    LabeledContent("Title", value: page.title.isEmpty ? "Untitled Page" : page.title)
                    LabeledContent("Created", value: dateString(page.created))
                    LabeledContent("Modified", value: dateString(page.modified))
                    LabeledContent("Attachments", value: "\(page.attachments.count)")
                }
            }
            .navigationTitle("Metadata")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private func dateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }
}

#Preview {
    let book = Book()
    let page = Page(title: "Sample Page")
    return MetadataView(book: book, page: page)
}
