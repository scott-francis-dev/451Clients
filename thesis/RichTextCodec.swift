import Foundation
import SwiftUI
import Core451

#if canImport(UIKit)
import UIKit
typealias UXColor = UIColor
typealias UXFont = UIFont
#elseif canImport(AppKit)
import AppKit
typealias UXColor = NSColor
typealias UXFont = NSFont
#endif

enum RichTextCodecError: Error {
    case invalidJSON
}

// MARK: - JSON <-> Data

struct RichTextCodec {
    static func decodeJSON(_ data: Data) throws -> RichDoc {
        if data.isEmpty {
            return RichDoc(version: 1, blocks: [Block(inlines: [.text(TextRun(text: ""))])])
        }
        let doc = try JSONDecoder().decode(RichDoc.self, from: data)
        return doc
    }

    static func encodeJSON(_ doc: RichDoc) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(doc)
    }
}

// MARK: - NSAttributedString <-> RichDoc

extension RichTextCodec {
    // Convert RichDoc to attributed string for editing.
    static func makeAttributedString(from doc: RichDoc) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        for (idx, block) in doc.blocks.enumerated() {
            let para = attributedString(for: block)
            result.append(para)
            if idx < doc.blocks.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }
        return result
    }

    // Convert attributed string back to RichDoc.
    static func makeRichDoc(from attr: NSAttributedString) -> RichDoc {
        var blocks: [Block] = []
        var location = 0
        while location < attr.length {
            let paraRange = (attr.string as NSString).paragraphRange(for: NSRange(location: location, length: 0))
            let block = blockFromParagraph(attr, range: paraRange)
            blocks.append(block)
            location = paraRange.upperBound
        }
        return RichDoc(version: 1, blocks: blocks)
    }

    private static func attributedString(for block: Block) -> NSAttributedString {
        let para = NSMutableAttributedString()
        for inline in block.inlines {
            switch inline {
            case .text(let run):
                let attrs = attributes(for: run.attrs)
                let piece = NSAttributedString(string: run.text, attributes: attrs)
                para.append(piece)
            case .object(let obj):
                // Placeholder glyph for object; the editor will render a live view attachment.
                let attachment = RichTextAttachment()
                attachment.userInfo = [
                    AttachmentUserInfoKeys.objectId: obj.id,
                    AttachmentUserInfoKeys.objectKind: obj.kind.rawValue
                ]
                let attString = NSAttributedString(attachment: attachment)
                para.append(attString)
            }
        }
        // Paragraph style
        let ps = NSMutableParagraphStyle()
        if let a = block.align {
            switch a {
            case .left: ps.alignment = .left
            case .center: ps.alignment = .center
            case .right: ps.alignment = .right
            case .justified: ps.alignment = .justified
            }
        }
        // Heading levels reflected as larger font size for now.
        if case .heading = block.type, let level = block.level {
            para.addAttribute(.font, value: headingFont(for: level), range: NSRange(location: 0, length: para.length))
        }
        para.addAttribute(.paragraphStyle, value: ps, range: NSRange(location: 0, length: para.length))
        return para
    }

    private static func blockFromParagraph(_ attr: NSAttributedString, range: NSRange) -> Block {
        var inlines: [Inline] = []
        var idx = range.location
        var blockType: BlockType = .paragraph
        var headingLevel: Int? = nil
        var align: TextAlignment? = nil

        // Read paragraph-level attributes
        if range.length > 0 {
            let paraAttrs = attr.attributes(at: range.location, effectiveRange: nil)
            if let ps = paraAttrs[.paragraphStyle] as? NSParagraphStyle {
                switch ps.alignment {
                case .left: align = .left
                case .center: align = .center
                case .right: align = .right
                case .justified: align = .justified
                default: break
                }
            }
            if let f = paraAttrs[.font] as? UXFont {
                // Heuristic: large font implies heading; this is simplistic and can be replaced by explicit custom attribute.
                let size = f.pointSize
                if size >= headingFont(for: 1).pointSize {
                    blockType = .heading
                    // Determine level by nearest heading size
                    headingLevel = headingLevelForFontSize(size)
                }
            }
        }

        while idx < range.upperBound {
            var eff = NSRange(location: 0, length: 0)
            let attrs = attr.attributes(at: idx, effectiveRange: &eff)
            let substring = (attr.string as NSString).substring(with: NSRange(location: idx, length: min(eff.length, range.upperBound - idx)))

            if let attachment = attrs[.attachment] as? RichTextAttachment,
               let info = attachment.userInfo,
               let id = info[AttachmentUserInfoKeys.objectId] as? String,
               let kindRaw = info[AttachmentUserInfoKeys.objectKind] as? String,
               let kind = ObjectKind(rawValue: kindRaw) {
                let object = ObjectRun(id: id, kind: kind)
                inlines.append(.object(object))
            } else {
                // Text run
                var rtAttrs = Attributes()
                if let f = attrs[.font] as? UXFont {
                    rtAttrs.fontSize = Double(f.pointSize)
                    // Family mapping is best-effort; UIFont/NSFont familyName is a proxy.
                    rtAttrs.fontFamily = f.familyName
                    // Bold/Italic detection (heuristic)
                    #if canImport(UIKit)
                    let d = f.fontDescriptor.symbolicTraits
                    rtAttrs.bold = d.contains(.traitBold)
                    rtAttrs.italic = d.contains(.traitItalic)
                    #else
                    let d = f.fontDescriptor.symbolicTraits
                    rtAttrs.bold = d.contains(.bold)
                    rtAttrs.italic = d.contains(.italic)
                    #endif
                }
                if let color = attrs[.foregroundColor] as? UXColor {
                    rtAttrs.foreground = color.toHexRGBA()
                }
                if let bg = attrs[.backgroundColor] as? UXColor {
                    rtAttrs.background = bg.toHexRGBA()
                }
                if let u = attrs[.underlineStyle] as? NSNumber, u.intValue != 0 {
                    rtAttrs.underline = true
                }
                if let s = attrs[.strikethroughStyle] as? NSNumber, s.intValue != 0 {
                    rtAttrs.strikethrough = true
                }
                if let link = attrs[.link] as? URL {
                    rtAttrs.link = link.absoluteString
                } else if let linkStr = attrs[.link] as? String {
                    rtAttrs.link = linkStr
                }

                inlines.append(.text(TextRun(text: substring, attrs: rtAttrs)))
            }

            idx = eff.upperBound
        }

        return Block(
            type: blockType,
            level: headingLevel,
            align: align,
            inlines: inlines
        )
    }

    private static func headingFont(for level: Int) -> UXFont {
        let base: CGFloat
        switch level {
        case 1: base = 34
        case 2: base = 30
        case 3: base = 26
        default: base = 50
        }
        #if canImport(UIKit)
        return .systemFont(ofSize: base, weight: .bold)
        #else
        return .systemFont(ofSize: base, weight: .bold)
        #endif
    }

    private static func headingLevelForFontSize(_ size: CGFloat) -> Int {
        if size >= 34 { return 1 }
        if size >= 30 { return 2 }
        if size >= 26 { return 3 }
        return 4
    }

    private static func attributes(for attrs: Attributes) -> [NSAttributedString.Key: Any] {
        var result: [NSAttributedString.Key: Any] = [:]

        // Font composition
        var fontSize = CGFloat(attrs.fontSize ?? 24) // bumped from 22 to 24
        let base: UXFont
        #if canImport(UIKit)
        base = .systemFont(ofSize: fontSize)
        #else
        base = .systemFont(ofSize: fontSize)
        #endif
        var descriptor = base.fontDescriptor

        #if canImport(UIKit)
        var traits = descriptor.symbolicTraits
        if attrs.bold == true { traits.insert(.traitBold) }
        if attrs.italic == true { traits.insert(.traitItalic) }
        if let new = descriptor.withSymbolicTraits(traits) {
            descriptor = new
        }
        let composed = UXFont(descriptor: descriptor, size: fontSize)
        #else
        // AppKit doesn't use withSymbolicTraits the same way; approximate with weight/italic
        let weight: NSFont.Weight = (attrs.bold == true) ? .bold : .regular
        let composed = NSFont.systemFont(ofSize: fontSize, weight: weight)
        #endif

        result[.font] = composed

        if let hex = attrs.foreground, let c = UXColor(hexRGBA: hex) {
            result[.foregroundColor] = c
        }
        if let hex = attrs.background, let c = UXColor(hexRGBA: hex) {
            result[.backgroundColor] = c
        }
        if attrs.underline == true {
            result[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if attrs.strikethrough == true {
            result[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if let link = attrs.link {
            result[.link] = link
        }
        return result
    }
}

// MARK: - Color helpers

private extension UXColor {
    func toHexRGBA() -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        usingColorSpace(.deviceRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))
        let ai = Int(round(a * 255))
        return String(format: "#%02X%02X%02X%02X", ri, gi, bi, ai)
    }

    convenience init?(hexRGBA: String) {
        var s = hexRGBA
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 8, let v = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((v >> 24) & 0xFF) / 255.0
        let g = CGFloat((v >> 16) & 0xFF) / 255.0
        let b = CGFloat((v >> 8) & 0xFF) / 255.0
        let a = CGFloat(v & 0xFF) / 255.0
        #if canImport(UIKit)
        self.init(red: r, green: g, blue: b, alpha: a)
        #else
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
        #endif
    }
}
