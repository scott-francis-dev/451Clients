import Foundation
import Observation
import Core451

@Observable
class Book: Codable, Identifiable, Equatable, Hashable {
    // Stable file id (UUID string) used for storage path and equality
    var id: String = UUID().uuidString

    // Local DID created at draft creation time; used to anchor metadata
    // Example format: did:local:<UUID>
    var did: String = "did:local:\(UUID().uuidString)"

    var accessrights = ""
    var audience: String = ""
    var audiencemediator = ""
    var author: String = ""
    var contributor = ""
    var dateAvailable = ""
    var description: String = ""
    var doi: String = ""
    var format: String = "451"
    var identifier: String = ""
    var isbn: String = ""
    var issn: String = ""
    var language: String = "English"
    var provenance: String = ""
    var publicationDate: String = ""
    var publisher: String = ""
    var rights = ""
    var rightsholder = ""
    var subject: String = ""
    var subtitle: String = ""
    var title: String = ""
    var transcript = ""
    var type: String = ""

    // JSON-centric pages
    var pages: [Page] = []

    init() {}

    enum CodingKeys: CodingKey {
        case id, did, accessrights, audience, audiencemediator, author, contributor, dateAvailable, description, doi, format, identifier, isbn, issn, language, provenance, publicationDate, publisher, rights, rightsholder, subject, subtitle, title, transcript, type, pages
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(did, forKey: .did)
        try c.encode(accessrights, forKey: .accessrights)
        try c.encode(audience, forKey: .audience)
        try c.encode(audiencemediator, forKey: .audiencemediator)
        try c.encode(author, forKey: .author)
        try c.encode(contributor, forKey: .contributor)
        try c.encode(dateAvailable, forKey: .dateAvailable)
        try c.encode(description, forKey: .description)
        try c.encode(doi, forKey: .doi)
        try c.encode(format, forKey: .format)
        try c.encode(identifier, forKey: .identifier)
        try c.encode(isbn, forKey: .isbn)
        try c.encode(issn, forKey: .issn)
        try c.encode(language, forKey: .language)
        try c.encode(provenance, forKey: .provenance)
        try c.encode(publicationDate, forKey: .publicationDate)
        try c.encode(publisher, forKey: .publisher)
        try c.encode(rights, forKey: .rights)
        try c.encode(rightsholder, forKey: .rightsholder)
        try c.encode(subject, forKey: .subject)
        try c.encode(subtitle, forKey: .subtitle)
        try c.encode(title, forKey: .title)
        try c.encode(transcript, forKey: .transcript)
        try c.encode(type, forKey: .type)
        try c.encode(pages, forKey: .pages)
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        did = (try? c.decode(String.self, forKey: .did)) ?? "did:local:\(id)"
        accessrights = try c.decode(String.self, forKey: .accessrights)
        audience = try c.decode(String.self, forKey: .audience)
        audiencemediator = try c.decode(String.self, forKey: .audiencemediator)
        author = try c.decode(String.self, forKey: .author)
        contributor = try c.decode(String.self, forKey: .contributor)
        dateAvailable = try c.decode(String.self, forKey: .dateAvailable)
        description = try c.decode(String.self, forKey: .description)
        doi = try c.decode(String.self, forKey: .doi)
        format = try c.decode(String.self, forKey: .format)
        identifier = try c.decode(String.self, forKey: .identifier)
        isbn = try c.decode(String.self, forKey: .isbn)
        issn = try c.decode(String.self, forKey: .issn)
        language = try c.decode(String.self, forKey: .language)
        provenance = try c.decode(String.self, forKey: .provenance)
        publicationDate = try c.decode(String.self, forKey: .publicationDate)
        publisher = try c.decode(String.self, forKey: .publisher)
        rights = try c.decode(String.self, forKey: .rights)
        rightsholder = try c.decode(String.self, forKey: .rightsholder)
        subject = try c.decode(String.self, forKey: .subject)
        subtitle = try c.decode(String.self, forKey: .subtitle)
        title = try c.decode(String.self, forKey: .title)
        transcript = try c.decode(String.self, forKey: .transcript)
        type = try c.decode(String.self, forKey: .type)
        pages = try c.decode([Page].self, forKey: .pages)

        // Rehydrate page docs
        for i in pages.indices {
            var page = pages[i]
            page.doc = RichTextDocument()
            page.doc.load(from: page.richTextJSON)
            pages[i] = page
        }
    }

    static func == (lhs: Book, rhs: Book) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
