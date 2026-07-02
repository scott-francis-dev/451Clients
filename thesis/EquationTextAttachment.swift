import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit

final class EquationTextAttachment: NSTextAttachment {
    var objectId: String
    var expressionSource: String

    /// Shared display height for both the static image and the live inline view,
    /// so the reserved line height never changes when editing starts.
    static let displayHeight: CGFloat = 34
    static let displayWidth: CGFloat = 420

    init(objectId: String, expressionSource: String = "x^2 + 2x - 1") {
        self.objectId = objectId
        self.expressionSource = expressionSource
        super.init(data: nil, ofType: nil)
        renderImage()
    }

    required init?(coder: NSCoder) { nil }

    func renderImage() {
        let parsed = ExpressionParser.parseExpression(expressionSource)
        let displayText = "ƒ  " + (parsed?.prettyString ?? expressionSource)

        let font = UIFont.systemFont(ofSize: 15, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label
        ]
        let str = NSAttributedString(string: displayText, attributes: attrs)
        let textSize = str.size()
        let pad: CGFloat = 12
        let size = CGSize(width: Self.displayWidth, height: Self.displayHeight)

        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { _ in
            UIColor.secondarySystemBackground.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1), cornerRadius: 6).fill()
            UIColor.separator.setStroke()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1), cornerRadius: 6).stroke()
            str.draw(at: CGPoint(x: pad, y: (size.height - textSize.height) / 2))
        }

        self.image = img
        self.bounds = CGRect(origin: .zero, size: size)
    }

    @available(iOS 15.0, *)
    override func viewProvider(
        for parentView: UIView?,
        location: any NSTextLocation,
        textContainer: NSTextContainer?
    ) -> NSTextAttachmentViewProvider? {
        EquationInlineViewProvider(
            textAttachment: self,
            parentView: parentView,
            textLayoutManager: textContainer?.textLayoutManager,
            location: location
        )
    }
}

#elseif canImport(AppKit)
import AppKit

final class EquationTextAttachment: NSTextAttachment {
    var objectId: String
    var expressionSource: String

    /// Shared display height for both the static image and the live inline view,
    /// so the reserved line height never changes when editing starts.
    static let displayHeight: CGFloat = 34
    static let displayWidth: CGFloat = 420

    init(objectId: String, expressionSource: String = "x^2 + 2x - 1") {
        self.objectId = objectId
        self.expressionSource = expressionSource
        super.init(data: nil, ofType: nil)
        renderImage()
    }

    required init?(coder: NSCoder) { nil }

    func renderImage() {
        let parsed = ExpressionParser.parseExpression(expressionSource)
        let displayText = "ƒ  " + (parsed?.prettyString ?? expressionSource)

        let font = NSFont.systemFont(ofSize: 15, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        let str = NSAttributedString(string: displayText, attributes: attrs)
        let textSize = str.size()
        let pad: CGFloat = 12
        let imgSize = NSSize(width: Self.displayWidth, height: Self.displayHeight)

        let img = NSImage(size: imgSize, flipped: false) { rect in
            NSColor.controlBackgroundColor.withAlphaComponent(0.6).setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()
            NSColor.separatorColor.setStroke()
            let border = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
            border.lineWidth = 0.5
            border.stroke()
            str.draw(at: NSPoint(x: pad, y: (rect.height - textSize.height) / 2))
            return true
        }

        self.image = img
        self.bounds = CGRect(origin: .zero, size: imgSize)
    }

    @available(macOS 12.0, *)
    override func viewProvider(
        for parentView: NSView?,
        location: any NSTextLocation,
        textContainer: NSTextContainer?
    ) -> NSTextAttachmentViewProvider? {
        EquationInlineViewProvider(
            textAttachment: self,
            parentView: parentView,
            textLayoutManager: textContainer?.textLayoutManager,
            location: location
        )
    }
}
#endif
