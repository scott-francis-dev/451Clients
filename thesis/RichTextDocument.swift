import Foundation
import SwiftUI
import Combine
import Core451

@MainActor
final class RichTextDocument: ObservableObject {
    @Published var attributed: NSMutableAttributedString
    @Published var selectedRange: NSRange = NSRange(location: 0, length: 0)

    init(initial: NSMutableAttributedString = NSMutableAttributedString(string: "")) {
        self.attributed = initial
    }

    // MARK: - Loading/Saving

    /// Load a `RichDoc` object (already decoded from JSON).
    func load(from richDoc: RichDoc) {
        self.attributed = RichTextCodec.makeAttributedString(from: richDoc)
        // Place caret at end of content (more natural for editing)
        let end = self.attributed.length
        self.selectedRange = NSRange(location: end, length: 0)
    }

    /// Convert current attributed text to a `RichDoc`.
    func toRichDoc() -> RichDoc {
        RichTextCodec.makeRichDoc(from: attributed)
    }

    /// Load directly from JSON data.
    func load(from jsonData: Data) {
        if let richDoc = try? RichTextCodec.decodeJSON(jsonData) {
            load(from: richDoc)
        } else {
            self.attributed = NSMutableAttributedString(string: "")
            self.selectedRange = NSRange(location: 0, length: 0)
        }
    }

    /// Export current state to JSON data.
    func toJSON() -> Data {
        let doc = toRichDoc()
        return (try? RichTextCodec.encodeJSON(doc)) ?? Data()
    }

    // MARK: - Formatting

    func toggleBold() { toggleFontTrait(bold: true) }
    func toggleItalic() { toggleFontTrait(italic: true) }

    func toggleUnderline() {
        toggleAttributedInt(key: .underlineStyle, onValue: NSUnderlineStyle.single.rawValue)
    }

    func toggleStrikethrough() {
        toggleAttributedInt(key: .strikethroughStyle, onValue: NSUnderlineStyle.single.rawValue)
    }

    func setForeground(_ color: Color) {
        #if canImport(UIKit)
        let ui = UIColor(color)
        #elseif canImport(AppKit)
        let ui = NSColor(color)
        #endif
        applyToSelectionOrTyping { attr, range in
            attr.addAttribute(.foregroundColor, value: ui, range: range)
        }
    }

    func setBackground(_ color: Color) {
        #if canImport(UIKit)
        let ui = UIColor(color)
        #elseif canImport(AppKit)
        let ui = NSColor(color)
        #endif
        applyToSelectionOrTyping { attr, range in
            attr.addAttribute(.backgroundColor, value: ui, range: range)
        }
    }

    func setFontSize(_ size: CGFloat) {
        applyToSelectionOrTyping { attr, range in
            attr.enumerateAttribute(.font, in: range) { value, subRange, _ in
                #if canImport(UIKit)
                let base = (value as? UIFont) ?? .systemFont(ofSize: size)
                let new = UIFont(descriptor: base.fontDescriptor, size: size)
                #elseif canImport(AppKit)
                let base = (value as? NSFont) ?? .systemFont(ofSize: size)
                let new = NSFont(descriptor: base.fontDescriptor, size: size) ?? NSFont.systemFont(ofSize: size)
                #endif
                attr.addAttribute(.font, value: new, range: subRange)
            }
        }
    }

    func setAlignment(_ alignment: TextAlignment) {
        applyToParagraphs { attr, paraRange in
            let ps = (attr.attribute(.paragraphStyle, at: paraRange.location, effectiveRange: nil) as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            switch alignment {
            case .left: ps.alignment = .left
            case .center: ps.alignment = .center
            case .right: ps.alignment = .right
            case .justified: ps.alignment = .justified
            }
            attr.addAttribute(.paragraphStyle, value: ps, range: paraRange)
        }
    }

    func addLink(_ urlString: String) {
        applyToSelectionOrTyping { attr, range in
            attr.addAttribute(.link, value: urlString, range: range)
        }
    }

    // MARK: - Insert objects (attachments)

    func insertGraph() {
        let id = UUID().uuidString
        let attachment = ChartTextAttachment(objectId: id)
        insertBlockAttachment(attachment)
    }

    func insertEquation() {
        let id = UUID().uuidString
        let attachment = EquationTextAttachment(objectId: id)
        insertBlockAttachment(attachment)
    }

    func insertImagePlaceholder() { insertGenericAttachment(kind: "image") }

    private func insertBlockAttachment(_ attachment: NSTextAttachment) {
        let attString = NSMutableAttributedString(attachment: attachment)
        let ps = NSMutableParagraphStyle()
        ps.alignment = .left
        attString.addAttribute(.paragraphStyle, value: ps, range: NSRange(location: 0, length: attString.length))

        let wrapped = NSMutableAttributedString(string: "\n")
        wrapped.append(attString)
        wrapped.append(NSAttributedString(string: "\n"))

        attributed.replaceCharacters(in: selectedRange, with: wrapped)
        let newLoc = selectedRange.location + wrapped.length
        selectedRange = NSRange(location: newLoc, length: 0)
    }

    private func insertGenericAttachment(kind: String) {
        let id = UUID().uuidString
        let attachment = RichTextAttachment()
        attachment.userInfo = [
            AttachmentUserInfoKeys.objectId: id,
            AttachmentUserInfoKeys.objectKind: kind
        ]
        let attString = NSAttributedString(attachment: attachment)
        attributed.replaceCharacters(in: selectedRange, with: attString)
        let newLoc = selectedRange.location + attString.length
        selectedRange = NSRange(location: newLoc, length: 0)
    }

    // MARK: - Helpers

    private func toggleFontTrait(bold: Bool = false, italic: Bool = false) {
        applyToSelectionOrTyping { attr, range in
            attr.enumerateAttribute(.font, in: range) { value, subRange, _ in
                #if canImport(UIKit)
                let current = (value as? UIFont) ?? .systemFont(ofSize: UIFont.systemFontSize)
                var traits = current.fontDescriptor.symbolicTraits
                if bold { traits = traits.symmetricToggle(.traitBold) }
                if italic { traits = traits.symmetricToggle(.traitItalic) }
                if let newDesc = current.fontDescriptor.withSymbolicTraits(traits) {
                    let new = UIFont(descriptor: newDesc, size: current.pointSize)
                    attr.addAttribute(.font, value: new, range: subRange)
                }
                #elseif canImport(AppKit)
                let current = (value as? NSFont) ?? .systemFont(ofSize: NSFont.systemFontSize)
                var target = current
                if bold {
                    let weight: NSFont.Weight = current.fontName.lowercased().contains("bold") ? .regular : .bold
                    target = NSFont.systemFont(ofSize: current.pointSize, weight: weight)
                }
                // Simple italic toggle approximation using descriptor (AppKit lacks symbolicTraits API parity)
                if italic {
                    let italicDesc = target.fontDescriptor.withSymbolicTraits(.italic)
                    target = NSFont(descriptor: italicDesc, size: target.pointSize) ?? target
                }
                attr.addAttribute(.font, value: target, range: subRange)
                #endif
            }
        }
    }

    private func toggleAttributedInt(key: NSAttributedString.Key, onValue: Int) {
        applyToSelectionOrTyping { attr, range in
            let current = attr.attribute(key, at: range.location, effectiveRange: nil) as? NSNumber
            let new = (current?.intValue ?? 0) == 0 ? onValue : 0
            attr.addAttribute(key, value: new, range: range)
        }
    }

    private func applyToSelectionOrTyping(_ work: (NSMutableAttributedString, NSRange) -> Void) {
        // If there is a selection, apply to that; otherwise affect typing attributes by
        // applying to a temporary zero-width character and removing it.
        let range = selectedRange
        if range.length > 0 {
            work(attributed, range)
            return
        }
        // Empty selection: apply to a temporary character to simulate typing attributes
        let loc = max(0, min(range.location, attributed.length))
        let tempRange = NSRange(location: loc, length: 0)
        let placeholder = NSAttributedString(string: "\u{200B}")
        attributed.insert(placeholder.mutableCopy() as! NSMutableAttributedString, at: tempRange.location)
        let appliedRange = NSRange(location: tempRange.location, length: 1)
        work(attributed, appliedRange)
        // Remove placeholder, keep caret in place
        attributed.deleteCharacters(in: appliedRange)
        selectedRange = NSRange(location: tempRange.location, length: 0)
    }

    private func applyToParagraphs(_ work: (NSMutableAttributedString, NSRange) -> Void) {
        guard attributed.length > 0 else { return }
        let paraRange = (attributed.string as NSString).paragraphRange(for: selectedRange)
        work(attributed, paraRange)
    }
}

#if canImport(UIKit)
private extension UIFontDescriptor.SymbolicTraits {
    func symmetricToggle(_ trait: UIFontDescriptor.SymbolicTraits) -> UIFontDescriptor.SymbolicTraits {
        var t = self
        if t.contains(trait) { t.remove(trait) } else { t.insert(trait) }
        return t
    }
}
#endif

#if canImport(AppKit)
private extension NSFont {
    var weight: NSFont.Weight {
        if fontName.lowercased().contains("bold") { return .bold }
        return .regular
    }
}
#endif
