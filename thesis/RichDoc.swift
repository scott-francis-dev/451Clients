import Foundation
import Core451

// Top-level JSON document schema for rich text.
public struct RichDoc: Codable, Equatable {
    public var version: Int
    public var blocks: [Block]

    public init(version: Int = 1, blocks: [Block] = []) {
        self.version = version
        self.blocks = blocks
    }
}

public struct Block: Codable, Equatable {
    public var id: String
    public var type: BlockType
    public var level: Int?            // for headings
    public var list: ListType?        // for lists
    public var align: TextAlignment?  // paragraph alignment
    public var inlines: [Inline]

    public init(
        id: String = UUID().uuidString,
        type: BlockType = .paragraph,
        level: Int? = nil,
        list: ListType? = nil,
        align: TextAlignment? = nil,
        inlines: [Inline] = []
    ) {
        self.id = id
        self.type = type
        self.level = level
        self.list = list
        self.align = align
        self.inlines = inlines
    }
}

public enum BlockType: String, Codable {
    case paragraph
    case heading
    case listItem
    case codeBlock
}

public enum ListType: String, Codable {
    case bullet
    case numbered
}

public enum TextAlignment: String, Codable {
    case left
    case center
    case right
    case justified
}

public enum Inline: Codable, Equatable {
    case text(TextRun)
    case object(ObjectRun)

    public enum CodingKeys: String, CodingKey {
        case kind
        case text
        case object
    }

    public enum Kind: String, Codable {
        case text
        case object
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .text:
            let tr = try c.decode(TextRun.self, forKey: .text)
            self = .text(tr)
        case .object:
            let or = try c.decode(ObjectRun.self, forKey: .object)
            self = .object(or)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let tr):
            try c.encode(Kind.text, forKey: .kind)
            try c.encode(tr, forKey: .text)
        case .object(let or):
            try c.encode(Kind.object, forKey: .kind)
            try c.encode(or, forKey: .object)
        }
    }
}

public struct TextRun: Codable, Equatable {
    public var text: String
    public var attrs: Attributes

    public init(text: String, attrs: Attributes = Attributes()) {
        self.text = text
        self.attrs = attrs
    }
}

// Inline object node (image/graph/equation/custom)
public struct ObjectRun: Codable, Equatable {
    public var id: String                   // stable id
    public var kind: ObjectKind             // image/graph/equation/custom
    public var size: ObjectSize?            // optional layout hints
    public var alt: String?                 // accessibility description
    public var state: [String: JSONValue]?  // free-form JSON state for live objects
    public var assetRef: String?            // for images or external assets

    public init(
        id: String = UUID().uuidString,
        kind: ObjectKind,
        size: ObjectSize? = nil,
        alt: String? = nil,
        state: [String: JSONValue]? = nil,
        assetRef: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.size = size
        self.alt = alt
        self.state = state
        self.assetRef = assetRef
    }
}

public enum ObjectKind: String, Codable {
    case image
    case graph
    case equation
    case custom
}

public struct ObjectSize: Codable, Equatable {
    public var width: Double?
    public var height: Double?

    public init(width: Double? = nil, height: Double? = nil) {
        self.width = width
        self.height = height
    }
}

// Supported text attributes for a run.
public struct Attributes: Codable, Equatable {
    public var bold: Bool?
    public var italic: Bool?
    public var underline: Bool?
    public var strikethrough: Bool?
    public var foreground: String?   // hex RGBA, e.g., #RRGGBBAA
    public var background: String?   // hex RGBA
    public var fontFamily: String?
    public var fontSize: Double?
    public var link: String?

    public init(
        bold: Bool? = nil,
        italic: Bool? = nil,
        underline: Bool? = nil,
        strikethrough: Bool? = nil,
        foreground: String? = nil,
        background: String? = nil,
        fontFamily: String? = nil,
        fontSize: Double? = nil,
        link: String? = nil
    ) {
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.strikethrough = strikethrough
        self.foreground = foreground
        self.background = background
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.link = link
    }
}

// A minimal JSON value type for arbitrary state payloads.
public enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        if c.decodeNil() { self = .null; return }
        throw DecodingError.typeMismatch(JSONValue.self, .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSONValue"))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .object(let o): try c.encode(o)
        case .array(let a): try c.encode(a)
        case .null: try c.encodeNil()
        }
    }
}
