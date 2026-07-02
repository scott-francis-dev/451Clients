import Foundation
import SwiftUI
import Combine

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class EquationViewModel: ObservableObject {
    @Published var expressionSource: String
    weak var attachment: EquationTextAttachment?

    init(attachment: EquationTextAttachment) {
        self.expressionSource = attachment.expressionSource
        self.attachment = attachment
    }

    func commit(_ newSource: String) {
        expressionSource = newSource
        attachment?.expressionSource = newSource
    }

    var parsed: ParsedExpression? {
        ExpressionParser.parseExpression(expressionSource)
    }

    var prettyString: String {
        parsed?.prettyString ?? expressionSource
    }
}

@available(iOS 15.0, macOS 12.0, *)
final class EquationInlineViewProvider: NSTextAttachmentViewProvider {
    private var viewModel: EquationViewModel?

    // Keep this in sync with EquationTextAttachment's static bounds height so the
    // line reserves the same space whether the static image or this live view is
    // shown — otherwise extra, undeletable space appears when editing begins.
    static let attachmentSize = CGSize(width: 420, height: EquationTextAttachment.displayHeight)

    #if canImport(UIKit)
    override func loadView() {
        guard let eq = textAttachment as? EquationTextAttachment else { return }
        let model = EquationViewModel(attachment: eq)
        viewModel = model
        let host = UIHostingController(rootView: InlineEquationView(model: model))
        host.view.backgroundColor = .clear
        host.view.frame = CGRect(origin: .zero, size: Self.attachmentSize)
        self.view = host.view
    }
    #elseif canImport(AppKit)
    override func loadView() {
        guard let eq = textAttachment as? EquationTextAttachment else { return }
        let model = EquationViewModel(attachment: eq)
        viewModel = model
        let host = NSHostingView(rootView: InlineEquationView(model: model))
        host.frame = CGRect(origin: .zero, size: Self.attachmentSize)
        self.view = host
    }
    #endif

    // Reserve exactly the view's height in the text line (no extra slack).
    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: any NSTextLocation,
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        CGRect(origin: .zero, size: Self.attachmentSize)
    }
}

struct InlineEquationView: View {
    @ObservedObject var model: EquationViewModel
    @State private var showEditor = false

    var body: some View {
        Button {
            showEditor = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "function")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(model.prettyString)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "pencil.circle")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showEditor) {
            EquationAttachmentView(
                objectId: model.attachment?.objectId ?? "eq",
                expression: model.expressionSource,
                onExpressionChanged: { model.commit($0) }
            )
            .frame(width: 340, height: 420)
            .padding(4)
        }
    }
}
