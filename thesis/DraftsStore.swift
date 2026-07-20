import Foundation

actor DraftsStore {
    static let shared = DraftsStore()

    private let fileManager = FileManager.default

    // Directory: Documents/Drafts
    private var draftsDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("Drafts", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func url(for id: String) -> URL {
        draftsDirectory.appendingPathComponent("\(id).json")
    }

    func createNewDraft() async throws -> Book {
        var book = Book()
        // Stable file id
        book.id = UUID().uuidString
        // DID at creation time
        book.did = "did:local:\(book.id)"
        // Ensure at least one empty page
        if book.pages.isEmpty {
            let emptyDoc = RichDoc(version: 1, blocks: [
                Block(type: .paragraph, inlines: [.text(TextRun(text: ""))])
            ])
            let data = (try? RichTextCodec.encodeJSON(emptyDoc)) ?? Data()
            let page = Page(title: "Page 1", richTextJSON: data)
            book.pages = [page]
        }
        try await save(book)
        return book
    }

    func loadAllDrafts() async throws -> [Book] {
        let urls = (try? fileManager.contentsOfDirectory(at: draftsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        var books: [Book] = []
        for u in urls where u.pathExtension.lowercased() == "json" {
            if let data = try? Data(contentsOf: u),
               let book = try? JSONDecoder().decode(Book.self, from: data) {
                books.append(book)
            }
        }
        // Sort by title then id for stable display (you can change to modified date once added to Book)
        return books.sorted { (a, b) in
            let at = a.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let bt = b.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if at.isEmpty && bt.isEmpty { return a.id < b.id }
            if at.isEmpty { return false }
            if bt.isEmpty { return true }
            return at.localizedCaseInsensitiveCompare(bt) == .orderedAscending
        }
    }

    func loadDraft(id: String) async throws -> Book? {
        let u = url(for: id)
        guard fileManager.fileExists(atPath: u.path) else { return nil }
        let data = try Data(contentsOf: u)
        return try JSONDecoder().decode(Book.self, from: data)
    }

    func save(_ book: Book) async throws {
        let u = url(for: book.id)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(book)
        try data.write(to: u, options: .atomic)
        print("📦 DraftsStore.save -> wrote \(data.count) bytes to \(u.lastPathComponent)")
    }

    func delete(id: String) async throws {
        let u = url(for: id)
        if fileManager.fileExists(atPath: u.path) {
            try fileManager.removeItem(at: u)
        }
    }
}
