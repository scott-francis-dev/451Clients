import Foundation
import Core451
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Registry of supported rich attribute keys used by the editor.
enum RichAttributeKey: String, CaseIterable {
    case bold
    case italic
    case underline
    case strikethrough
    case highlightColor
}

extension NSAttributedString.Key {
    /// Indicates bold text.
    static let bold = NSAttributedString.Key("app.bold")
    /// Indicates italic text.
    static let italic = NSAttributedString.Key("app.italic")
    /// Indicates underline style.
    static let underline = NSAttributedString.Key("app.underline")
    /// Indicates strikethrough style.
    static let strikethrough = NSAttributedString.Key("app.strikethrough")
    /// Indicates highlight color stored as hex string.
    static let highlightColor = NSAttributedString.Key("app.highlightColor")

    /// Semantic kind of a tagged text range: "concept" | "location" | "variable" (see `EntityKind`).
    /// Layer-2 thesis carrier for the shared entity model. Stored as a String for bridge safety.
    static let entityType = NSAttributedString.Key("app.entityType")
    /// Structured payload for the tagged range, stored as a JSON string: a qid for a concept,
    /// a `VariableManifest` for a variable. Round-tripped to `TextRun.attrs.entityPayload` (JSONValue).
    static let entityPayload = NSAttributedString.Key("app.entityPayload")
}

/// The semantic kind of a typed text range — the thesis carrier's vocabulary for the shared
/// entity model. Persisted as the raw string in `TextRun.attrs.entityType`, so unknown future
/// kinds decode as a plain string rather than failing. See VARIABLE_OBJECT_KIND.md.
public enum EntityKind: String, Codable, CaseIterable {
    case concept
    case location
    case variable
}

/// Codable representation of attribute values.
/// Supports booleans and strings (e.g. hex colors).
struct RichAttributeValue: Codable {
    enum Value: Codable {
        case bool(Bool)
        case string(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let boolValue = try? container.decode(Bool.self) {
                self = .bool(boolValue)
                return
            }
            if let stringValue = try? container.decode(String.self) {
                self = .string(stringValue)
                return
            }
            throw DecodingError.typeMismatch(
                RichAttributeValue.Value.self,
                DecodingError.Context(codingPath: decoder.codingPath,
                                      debugDescription: "Expected Bool or String value"))
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .bool(let b): try container.encode(b)
            case .string(let s): try container.encode(s)
            }
        }
    }

    let value: Value

    init(bool: Bool) {
        self.value = .bool(bool)
    }

    init(string: String) {
        self.value = .string(string)
    }

    var boolValue: Bool? {
        if case .bool(let b) = value { return b }
        return nil
    }

    var stringValue: String? {
        if case .string(let s) = value { return s }
        return nil
    }
}

/// Codable representation of an attribute run: a range with associated attributes.
struct RichAttributeRun: Codable {
    struct CodableRange: Codable {
        let location: Int
        let length: Int

        init(range: NSRange) {
            self.location = range.location
            self.length = range.length
        }

        var nsRange: NSRange {
            NSRange(location: location, length: length)
        }
    }

    let range: CodableRange
    let attributes: [String: RichAttributeValue]
}

// MARK: - Encoding / Decoding Helpers

/// Encode NSAttributedString attributes to a codable dictionary.
/// Only known supported keys are encoded.
func encodeAttributes(_ attrs: [NSAttributedString.Key: Any]) -> [String: RichAttributeValue] {
    var encoded: [String: RichAttributeValue] = [:]

    for (key, value) in attrs {
        switch key {
        case .bold:
            if let boolVal = value as? Bool {
                encoded[key.rawValue] = RichAttributeValue(bool: boolVal)
            }
        case .italic:
            if let boolVal = value as? Bool {
                encoded[key.rawValue] = RichAttributeValue(bool: boolVal)
            }
        case .underline:
            if let intVal = value as? Int {
                // store presence as true if underline style is nonzero
                encoded[key.rawValue] = RichAttributeValue(bool: intVal != 0)
            }
        case .strikethrough:
            if let intVal = value as? Int {
                encoded[key.rawValue] = RichAttributeValue(bool: intVal != 0)
            }
        case .highlightColor:
            #if canImport(AppKit)
            if let color = value as? NSColor {
                // Store as hex string, e.g. "#RRGGBBAA"
                let hex = color.toHexString()
                encoded[key.rawValue] = RichAttributeValue(string: hex)
            }
            #elseif canImport(UIKit)
            if let color = value as? UIColor {
                // Store as hex string, e.g. "#RRGGBBAA"
                let hex = color.toHexString()
                encoded[key.rawValue] = RichAttributeValue(string: hex)
            }
            #endif
        default:
            // Unsupported keys are ignored
            continue
        }
    }

    return encoded
}

/// Decode codable attribute dictionary back to native attributes.
/// Note: for font traits like bold/italic, actual font synthesis is handled elsewhere.
func decodeAttributes(_ dict: [String: RichAttributeValue]) -> [NSAttributedString.Key: Any] {
    var decoded: [NSAttributedString.Key: Any] = [:]

    for (keyString, attrVal) in dict {
        switch keyString {
        case NSAttributedString.Key.bold.rawValue:
            if let boolVal = attrVal.boolValue {
                // Placeholder for font trait synthesis
                // For now, store boolean as is
                decoded[.bold] = boolVal
            }
        case NSAttributedString.Key.italic.rawValue:
            if let boolVal = attrVal.boolValue {
                decoded[.italic] = boolVal
            }
        case NSAttributedString.Key.underline.rawValue:
            if let boolVal = attrVal.boolValue {
                decoded[.underline] = boolVal ? NSUnderlineStyle.single.rawValue : NSUnderlineStyle().rawValue
            }
        case NSAttributedString.Key.strikethrough.rawValue:
            if let boolVal = attrVal.boolValue {
                decoded[.strikethrough] = boolVal ? NSUnderlineStyle.single.rawValue : NSUnderlineStyle().rawValue
            }
        case NSAttributedString.Key.highlightColor.rawValue:
            if let hexString = attrVal.stringValue {
                #if canImport(AppKit)
                if let color = NSColor(hexString: hexString) {
                    decoded[.highlightColor] = color
                }
                #elseif canImport(UIKit)
                if let color = UIColor(hexString: hexString) {
                    decoded[.highlightColor] = color
                }
                #endif
            }
        default:
            continue
        }
    }

    return decoded
}

// MARK: - Color Hex Helpers

#if canImport(AppKit)
private extension NSColor {
    /// Convert NSColor to hex string "#RRGGBBAA"
    func toHexString() -> String {
        guard let components = cgColor.components else {
            return "#000000FF"
        }
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        let a: CGFloat

        if components.count >= 4 {
            r = components[0]
            g = components[1]
            b = components[2]
            a = components[3]
        } else if components.count == 2 {
            // Grayscale color (white + alpha)
            r = components[0]
            g = components[0]
            b = components[0]
            a = components[1]
        } else {
            r = 0; g = 0; b = 0; a = 1
        }

        func toByte(_ value: CGFloat) -> UInt8 {
            return UInt8(round(value * 255))
        }

        return String(format: "#%02X%02X%02X%02X",
                      toByte(r), toByte(g), toByte(b), toByte(a))
    }

    /// Init NSColor from hex string like "#RRGGBBAA"
    convenience init?(hexString: String) {
        var hex = hexString
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        guard hex.count == 8 else {
            return nil
        }

        let scanner = Scanner(string: hex)
        var hexNumber: UInt64 = 0
        if !scanner.scanHexInt64(&hexNumber) {
            return nil
        }

        let r = CGFloat((hexNumber & 0xFF000000) >> 24) / 255.0
        let g = CGFloat((hexNumber & 0x00FF0000) >> 16) / 255.0
        let b = CGFloat((hexNumber & 0x0000FF00) >> 8) / 255.0
        let a = CGFloat(hexNumber & 0x000000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
#endif

#if canImport(UIKit)
private extension UIColor {
    /// Convert UIColor to hex string "#RRGGBBAA"
    func toHexString() -> String {
        guard let components = cgColor.components else {
            return "#000000FF"
        }
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        let a: CGFloat

        if components.count >= 4 {
            r = components[0]
            g = components[1]
            b = components[2]
            a = components[3]
        } else if components.count == 2 {
            // Grayscale color (white + alpha)
            r = components[0]
            g = components[0]
            b = components[0]
            a = components[1]
        } else {
            r = 0; g = 0; b = 0; a = 1
        }

        func toByte(_ value: CGFloat) -> UInt8 {
            return UInt8(round(value * 255))
        }

        return String(format: "#%02X%02X%02X%02X",
                      toByte(r), toByte(g), toByte(b), toByte(a))
    }

    /// Init UIColor from hex string like "#RRGGBBAA"
    convenience init?(hexString: String) {
        var hex = hexString
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        guard hex.count == 8 else {
            return nil
        }

        let scanner = Scanner(string: hex)
        var hexNumber: UInt64 = 0
        if !scanner.scanHexInt64(&hexNumber) {
            return nil
        }

        let r = CGFloat((hexNumber & 0xFF000000) >> 24) / 255.0
        let g = CGFloat((hexNumber & 0x00FF0000) >> 16) / 255.0
        let b = CGFloat((hexNumber & 0x0000FF00) >> 8) / 255.0
        let a = CGFloat(hexNumber & 0x000000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
#endif
