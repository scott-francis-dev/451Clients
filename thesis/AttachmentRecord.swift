import Foundation
import CoreGraphics
import Core451

struct AttachmentRecord: Codable, Identifiable, Equatable, Hashable {
    // Stable id referenced by inline objects in the document JSON.
    var id: String
    // "image" | "graph" | "equation" | "custom"
    var kind: String
    // Small JSON payload describing state for graphs/equations/custom objects.
    var state: Data?
    // Path/URL/S3 key for binaries (e.g., images). Can be a local URL string during editing.
    var assetRef: String?
    // Optional size hints for layout.
    var width: Double?
    var height: Double?
    // Optional accessibility alt text/description.
    var alt: String?

    init(
        id: String,
        kind: String,
        state: Data? = nil,
        assetRef: String? = nil,
        width: Double? = nil,
        height: Double? = nil,
        alt: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.state = state
        self.assetRef = assetRef
        self.width = width
        self.height = height
        self.alt = alt
    }
}
