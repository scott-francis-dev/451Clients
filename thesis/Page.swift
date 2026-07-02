import Foundation
import Core451

struct Page: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var title: String
    // Canonical JSON for the rich text document (UTF-8 JSON following our schema).
    var richTextJSON: Data
    // Serialized block-based document (equations, charts, text blocks).
    var documentBlocksJSON: Data
    // Optional attachment records (e.g., images, graphs, equations) keyed by id.
    var attachments: [String: AttachmentRecord]
    var created: Date
    var modified: Date

    // 🚨 Not codable: live in-memory editor for this page
    var doc: RichTextDocument = RichTextDocument()


    enum CodingKeys: String, CodingKey {
        case id, title, richTextJSON, documentBlocksJSON, attachments, created, modified
    }

    init(
        id: UUID = UUID(),
        title: String = "Untitled",
        richTextJSON: Data = Data(),
        documentBlocksJSON: Data = Data(),
        attachments: [String: AttachmentRecord] = [:],
        created: Date = Date(),
        modified: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.richTextJSON = richTextJSON
        self.documentBlocksJSON = documentBlocksJSON
        self.attachments = attachments
        self.created = created
        self.modified = modified

        // Initialize live RichTextDocument
        self.doc = RichTextDocument()
        if let richDoc = try? RichTextCodec.decodeJSON(richTextJSON) {
            self.doc.load(from: richDoc)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        richTextJSON = try c.decode(Data.self, forKey: .richTextJSON)
        documentBlocksJSON = try c.decodeIfPresent(Data.self, forKey: .documentBlocksJSON) ?? Data()
        attachments = try c.decode([String: AttachmentRecord].self, forKey: .attachments)
        created = try c.decode(Date.self, forKey: .created)
        modified = try c.decode(Date.self, forKey: .modified)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(richTextJSON, forKey: .richTextJSON)
        try c.encode(documentBlocksJSON, forKey: .documentBlocksJSON)
        try c.encode(attachments, forKey: .attachments)
        try c.encode(created, forKey: .created)
        try c.encode(modified, forKey: .modified)
    }

    // MARK: - Sync helpers

    /// Flush the live RichTextDocument back into `richTextJSON`.
    mutating func flush(verbose: Bool = false) {
        let richDoc = doc.toRichDoc()
        if let data = try? RichTextCodec.encodeJSON(richDoc) {
            self.richTextJSON = data
            if verbose {
                print("🧾 Page.flush -> jsonBytes=\(data.count)")
            }
        } else {
            print("❌ Page.flush -> encode failed")
        }
        self.modified = Date()
    }


    // MARK: - Hashable / Equatable
    static func == (lhs: Page, rhs: Page) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
