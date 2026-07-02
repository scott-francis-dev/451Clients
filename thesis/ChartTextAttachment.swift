import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit

final class ChartTextAttachment: NSTextAttachment {
    var objectId: String
    var chartData: ChartData

    /// Shared display size for both the static placeholder and the live inline
    /// chart, so the reserved line height never jumps when editing starts.
    static let displayHeight: CGFloat = 172
    static let displayWidth: CGFloat = 420

    init(objectId: String, chartData: ChartData = ChartData.sampleTimeSeries()) {
        self.objectId = objectId
        self.chartData = chartData
        super.init(data: nil, ofType: nil)
        renderImage()
    }

    required init?(coder: NSCoder) { nil }

    func renderImage() {
        ChartPerf.event("ChartTextAttachment.renderImage", "objectId=\(objectId)")
        let label = "📊  " + chartData.visualizationType.rawValue
            + " — \(chartData.series.count) series"

        let font = UIFont.systemFont(ofSize: 14, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.secondaryLabel
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
        let pad: CGFloat = 12
        let size = CGSize(width: Self.displayWidth, height: Self.displayHeight)

        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { _ in
            UIColor.secondarySystemBackground.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1), cornerRadius: 6).fill()
            UIColor.separator.setStroke()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1), cornerRadius: 6).stroke()
            str.draw(at: CGPoint(x: pad, y: pad))
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
        ChartInlineViewProvider(
            textAttachment: self,
            parentView: parentView,
            textLayoutManager: textContainer?.textLayoutManager,
            location: location
        )
    }
}

#elseif canImport(AppKit)
import AppKit

final class ChartTextAttachment: NSTextAttachment {
    var objectId: String
    var chartData: ChartData

    /// Shared display size for both the static placeholder and the live inline
    /// chart, so the reserved line height never jumps when editing starts.
    static let displayHeight: CGFloat = 172
    static let displayWidth: CGFloat = 420

    init(objectId: String, chartData: ChartData = ChartData.sampleTimeSeries()) {
        self.objectId = objectId
        self.chartData = chartData
        super.init(data: nil, ofType: nil)
        renderImage()
    }

    required init?(coder: NSCoder) { nil }

    func renderImage() {
        ChartPerf.event("ChartTextAttachment.renderImage", "objectId=\(objectId)")
        let label = "📊  " + chartData.visualizationType.rawValue
            + " — \(chartData.series.count) series"

        let font = NSFont.systemFont(ofSize: 14, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
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
            // Top-aligned label (AppKit image origin is bottom-left).
            str.draw(at: NSPoint(x: pad, y: rect.height - textSize.height - pad))
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
        ChartInlineViewProvider(
            textAttachment: self,
            parentView: parentView,
            textLayoutManager: textContainer?.textLayoutManager,
            location: location
        )
    }
}
#endif
