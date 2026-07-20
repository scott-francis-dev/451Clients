//
//  Document451.swift
//  451 Protocol
//
//  Created by User451 on 1/23/26.
//
//  Shared metadata model for the 451 protocol
//  Can be used by both Thesis app and Signator wallet
//

import Foundation
import Observation

/// Core document metadata for the 451 protocol
/// This model is shared between the Thesis app (Book) and Signator wallet
/// Aligned with Dublin Core metadata standards and scholarly publishing practices
@Observable
class Document451: Codable, Identifiable, Equatable, Hashable {
    
    // MARK: - Core Identifiers
    
    /// Stable file id (UUID string) used for storage path and equality
    var id: String = UUID().uuidString
    
    /// Local DID created at draft creation time; used to anchor metadata
    /// Example format: did:local:<UUID> or did:451:<hash>
    var did: String = "did:local:\(UUID().uuidString)"
    
    // MARK: - Descriptive Metadata (Dublin Core)
    
    /// Primary title of the document
    var title: String = ""
    
    /// Secondary title or explanatory subtitle
    var subtitle: String = ""
    
    /// Full description or abstract
    var description: String = ""
    
    /// Primary author(s) - comma-separated or single author
    var author: String = ""
    
    /// Contributors who are not primary authors
    var contributor: String = ""
    
    /// Subject matter, keywords, or topics
    var subject: String = ""
    
    /// Document type (e.g., "contract", "article", "book", "report")
    var type: String = ""
    
    /// Language of the document content (ISO 639 code recommended)
    var language: String = "English"
    
    /// Full transcript of the document (for audio/video content)
    var transcript: String = ""
    
    // MARK: - Persona-aligned Metadata (optional)
    /// Human-readable handle associated with the authoring persona (ATProtocol-style)
    var handle: String? = nil
    /// Preferred display name for the persona (separate from author string)
    var displayName: String? = nil
    /// Optional display publisher or imprint for persona preview
    var displayPublisher: String? = nil
    /// Public affiliations to surface alongside the persona
    var publicAffiliations: String? = nil
    /// Public-facing social links string (comma or space separated)
    var socialLinks: String? = nil
    /// Public contact email associated with the persona
    var publicEmail: String? = nil
    /// Server-provided verification flags (if any)
    var emailVerified: Bool? = nil
    var orcid: String? = nil
    var orcidVerified: Bool? = nil
    /// Additional attributes bag mirrored from persona metadata
    var attributes: [String: String]? = nil
    
    // MARK: - Publication Details
    
    /// Publisher of the document
    var publisher: String = ""
    
    /// Date of publication (ISO 8601 recommended)
    var publicationDate: String = ""
    
    /// Date the document becomes available
    var dateAvailable: String = ""
    
    // MARK: - Rights & Access
    
    /// Access rights level for the document.
    /// Server expects one of: "public" or "private" (lowercase).
    /// UI should bind to `accessRights` for type safety; the underlying `accessrights` is kept for Codable.
    var accessrights: String = ""
    
    /// Standardized access rights options for UI and server
    enum AccessRights: String, CaseIterable, Codable {
        case `public` = "public"
        case `private` = "private"
    }

    /// Typed accessor for access rights, backed by the `accessrights` string for Codable compatibility
    var accessRights: AccessRights {
        get { AccessRights(rawValue: accessrights.lowercased()) ?? .private }
        set { accessrights = newValue.rawValue }
    }
    
    /// Rights statement or license
    var rights: String = ""
    
    /// Person or organization holding rights
    var rightsholder: String = ""
    
    // MARK: - Audience & Context
    
    /// Target audience description
    var audience: String = ""
    
    /// Mediator or intermediary for the audience
    var audiencemediator: String = ""
    
    /// Provenance or historical record of ownership/custody
    var provenance: String = ""
    
    // MARK: - Identifiers
    
    /// Digital Object Identifier (DOI) for academic publications
    var doi: String = ""
    
    /// ISBN for books
    var isbn: String = ""
    
    /// ISSN for periodicals
    var issn: String = ""
    
    /// Generic identifier field for other identification schemes
    var identifier: String = ""
    
    // MARK: - Format & Technical
    
    /// Format description (e.g., "451", "PDF", "DOCX")
    var format: String = "451"
    
    // MARK: - Thesis App Specific (for compatibility)
    
    /// JSON-centric pages (used by Thesis app, ignored by Signator)
    var pages: [Document451Page] = []
    
    // MARK: - Initializer
    
    init() {}
    
    // MARK: - Codable
    
    enum CodingKeys: CodingKey {
        case id, did
        case title, subtitle, description, author, contributor, subject, type, language, transcript
        case handle, displayName, displayPublisher, publicAffiliations, socialLinks, publicEmail, emailVerified, orcid, orcidVerified, attributes
        case publisher, publicationDate, dateAvailable
        case rights, rightsholder, accessrights
        case audience, audiencemediator, provenance
        case doi, isbn, issn, identifier
        case format
        case pages
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(did, forKey: .did)
        
        // Descriptive
        try c.encode(title, forKey: .title)
        try c.encode(subtitle, forKey: .subtitle)
        try c.encode(description, forKey: .description)
        try c.encode(author, forKey: .author)
        try c.encode(contributor, forKey: .contributor)
        try c.encode(subject, forKey: .subject)
        try c.encode(type, forKey: .type)
        try c.encode(language, forKey: .language)
        try c.encode(transcript, forKey: .transcript)
        
        try c.encodeIfPresent(handle, forKey: .handle)
        try c.encodeIfPresent(displayName, forKey: .displayName)
        try c.encodeIfPresent(displayPublisher, forKey: .displayPublisher)
        try c.encodeIfPresent(publicAffiliations, forKey: .publicAffiliations)
        try c.encodeIfPresent(socialLinks, forKey: .socialLinks)
        try c.encodeIfPresent(publicEmail, forKey: .publicEmail)
        try c.encodeIfPresent(emailVerified, forKey: .emailVerified)
        try c.encodeIfPresent(orcid, forKey: .orcid)
        try c.encodeIfPresent(orcidVerified, forKey: .orcidVerified)
        try c.encodeIfPresent(attributes, forKey: .attributes)
        
        // Publication
        try c.encode(publisher, forKey: .publisher)
        try c.encode(publicationDate, forKey: .publicationDate)
        try c.encode(dateAvailable, forKey: .dateAvailable)
        
        // Rights
        try c.encode(rights, forKey: .rights)
        try c.encode(rightsholder, forKey: .rightsholder)
        try c.encode(accessrights, forKey: .accessrights)
        
        // Audience
        try c.encode(audience, forKey: .audience)
        try c.encode(audiencemediator, forKey: .audiencemediator)
        try c.encode(provenance, forKey: .provenance)
        
        // Identifiers
        try c.encode(doi, forKey: .doi)
        try c.encode(isbn, forKey: .isbn)
        try c.encode(issn, forKey: .issn)
        try c.encode(identifier, forKey: .identifier)
        
        // Format
        try c.encode(format, forKey: .format)
        
        // Thesis-specific
        try c.encode(pages, forKey: .pages)
    }
    
    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try c.decode(String.self, forKey: .id)
        did = (try? c.decode(String.self, forKey: .did)) ?? "did:local:\(id)"
        
        // Descriptive
        title = try c.decode(String.self, forKey: .title)
        subtitle = try c.decode(String.self, forKey: .subtitle)
        description = try c.decode(String.self, forKey: .description)
        author = try c.decode(String.self, forKey: .author)
        contributor = try c.decode(String.self, forKey: .contributor)
        subject = try c.decode(String.self, forKey: .subject)
        type = try c.decode(String.self, forKey: .type)
        language = try c.decode(String.self, forKey: .language)
        transcript = try c.decode(String.self, forKey: .transcript)
        
        handle = try? c.decode(String.self, forKey: .handle)
        displayName = try? c.decode(String.self, forKey: .displayName)
        displayPublisher = try? c.decode(String.self, forKey: .displayPublisher)
        publicAffiliations = try? c.decode(String.self, forKey: .publicAffiliations)
        socialLinks = try? c.decode(String.self, forKey: .socialLinks)
        publicEmail = try? c.decode(String.self, forKey: .publicEmail)
        emailVerified = try? c.decode(Bool.self, forKey: .emailVerified)
        orcid = try? c.decode(String.self, forKey: .orcid)
        orcidVerified = try? c.decode(Bool.self, forKey: .orcidVerified)
        attributes = try? c.decode([String: String].self, forKey: .attributes)
        
        // Publication
        publisher = try c.decode(String.self, forKey: .publisher)
        publicationDate = try c.decode(String.self, forKey: .publicationDate)
        dateAvailable = try c.decode(String.self, forKey: .dateAvailable)
        
        // Rights
        rights = try c.decode(String.self, forKey: .rights)
        rightsholder = try c.decode(String.self, forKey: .rightsholder)
        accessrights = try c.decode(String.self, forKey: .accessrights)
        
        // Audience
        audience = try c.decode(String.self, forKey: .audience)
        audiencemediator = try c.decode(String.self, forKey: .audiencemediator)
        provenance = try c.decode(String.self, forKey: .provenance)
        
        // Identifiers
        doi = try c.decode(String.self, forKey: .doi)
        isbn = try c.decode(String.self, forKey: .isbn)
        issn = try c.decode(String.self, forKey: .issn)
        identifier = try c.decode(String.self, forKey: .identifier)
        
        // Format
        format = try c.decode(String.self, forKey: .format)
        
        // Thesis-specific (optional, may not exist in Signator uploads)
        pages = (try? c.decode([Document451Page].self, forKey: .pages)) ?? []
        
        // Rehydrate page docs if pages exist (Thesis app specific)
        for i in pages.indices {
            var page = pages[i]
            page.doc = Document451RichText()
            page.doc.load(from: page.richTextJSON)
            pages[i] = page
        }
    }
    
    // MARK: - Equatable & Hashable
    
    static func == (lhs: Document451, rhs: Document451) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Document451Page Model (for Thesis app compatibility)

/// Document451Page model used by Thesis app for rich text documents
/// Signator doesn't use pages, but includes this for protocol compatibility
struct Document451Page: Codable, Identifiable, Equatable, Hashable {
    var id: String = UUID().uuidString
    var title: String = ""
    var richTextJSON: String = ""
    
    // Runtime-only rich text document (not encoded)
    var doc: Document451RichText = Document451RichText()
    
    enum CodingKeys: String, CodingKey {
        case id, title, richTextJSON
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(richTextJSON, forKey: .richTextJSON)
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        richTextJSON = try c.decode(String.self, forKey: .richTextJSON)
        doc = Document451RichText()
    }
    
    init() {}
    
    // Equatable conformance (ignore runtime doc)
    static func == (lhs: Document451Page, rhs: Document451Page) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.richTextJSON == rhs.richTextJSON
    }
    
    // Hashable conformance (ignore runtime doc)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(richTextJSON)
    }
}

/// Placeholder for Document451RichText (Thesis app provides real implementation)
/// Signator can use a stub version
class Document451RichText: Codable {
    func load(from json: String) {
        // Thesis app implements this
        // Signator doesn't need it
    }
    
    init() {}
}

