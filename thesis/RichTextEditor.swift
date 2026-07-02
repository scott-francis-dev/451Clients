import SwiftUI
import RichTextKit
import Core451

#if canImport(UIKit)
import UIKit
#endif

// MARK: - iOS/tvOS implementation (TextKit 2) when available
#if canImport(UIKit) && canImport(UIKit.UITextLayoutManager)

// TextKit 2–only editor bridge for iOS/iPadOS.
// Requires iOS 16+/tvOS 16+ SDKs.
/*
@available(iOS 16.0, *)
@available(tvOS 16.0, *)
struct RichTextEditor: UIViewRepresentable {
    @Binding var attributedText: NSMutableAttributedString
    @Binding var selectedRange: NSRange

    // Metrics and callback
    @Binding var scrollProgress: CGFloat
    @Binding var caretProgress: CGFloat
    var onScrollNearEnd: (() -> Void)? = nil

    // Overscroll page-change callbacks
    var onOverscrollAtTop: (() -> Void)? = nil
    var onOverscrollAtBottom: (() -> Void)? = nil

    // Configuration
    var overscrollThreshold: CGFloat = 120
    var overscrollCooldown: TimeInterval = 0.6

    // Formatting action handlers (invoked by toolbar)
    var onToggleBold: (() -> Void)? = nil
    var onToggleItalic: (() -> Void)? = nil
    var onToggleUnderline: (() -> Void)? = nil
    var onToggleStrikethrough: (() -> Void)? = nil

    // Accessory content closure
    var accessory: (() -> AnyView)? = nil

    // Editor base font size for new typing (kept in sync with codec default 24)
    private let defaultTypingPointSize: CGFloat = 24

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate, UIScrollViewDelegate {
        var parent: RichTextEditor

        // TextKit 2 pipeline pieces we own
        let contentStorage = NSTextContentStorage()
        let textContainer = NSTextContainer()

        private var lastTriggerAt: Date = .distantPast
        private var didAnnounceTopHaptic = false
        private var didAnnounceBottomHaptic = false

        // MARK: - Formatting wiring
        private var boldHandler: (() -> Void)?
        private var italicHandler: (() -> Void)?
        private var underlineHandler: (() -> Void)?
        private var strikeHandler: (() -> Void)?

        // Accessory hosting controller
        var accessoryHost: UIHostingController<AnyView>?

        func installAccessory(on textView: UITextView, content: AnyView?) {
            if let content = content {
                if accessoryHost == nil {
                    accessoryHost = UIHostingController(rootView: content)
                    accessoryHost?.view.backgroundColor = .clear
                    accessoryHost?.view.translatesAutoresizingMaskIntoConstraints = false
                    let container = UIView()
                    container.backgroundColor = .clear
                    container.addSubview(accessoryHost!.view)
                    NSLayoutConstraint.activate([
                        accessoryHost!.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                        accessoryHost!.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                        accessoryHost!.view.topAnchor.constraint(equalTo: container.topAnchor),
                        accessoryHost!.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                        container.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
                    ])
                    textView.inputAccessoryView = container
                    textView.reloadInputViews()
                } else {
                    accessoryHost?.rootView = content
                }
            } else {
                accessoryHost = nil
                textView.inputAccessoryView = nil
                textView.reloadInputViews()
            }
        }

        func installFormattingHandlers(onBold: (() -> Void)?, onItalic: (() -> Void)?, onUnderline: (() -> Void)?, onStrikethrough: (() -> Void)?, textView: UITextView) {
            // Capture weak reference to textView via closures that call into our apply methods
            let weakTV = WeakTextView(textView)
            self.boldHandler = { [weak self] in self?.toggleFontTrait(.traitBold, textView: weakTV.view) }
            self.italicHandler = { [weak self] in self?.toggleFontTrait(.traitItalic, textView: weakTV.view) }
            self.underlineHandler = { [weak self] in self?.toggleUnderline(textView: weakTV.view) }
            self.strikeHandler = { [weak self] in self?.toggleStrikethrough(textView: weakTV.view) }
        }

        func performBold() { boldHandler?() }
        func performItalic() { italicHandler?() }
        func performUnderline() { underlineHandler?() }
        func performStrikethrough() { strikeHandler?() }

        private func syncTypingAttributes(from attr: NSAttributedString, at index: Int, to textView: UITextView) {
            let length = attr.length
            guard length > 0 else { return }
            let clampedIndex = max(0, min(index, length - 1))
            let effective = attr.attributes(at: clampedIndex, effectiveRange: nil)
            var typing = textView.typingAttributes
            let keys: [NSAttributedString.Key] = [
                .font,
                .foregroundColor,
                .backgroundColor,
                .underlineStyle,
                .underlineColor,
                .strikethroughStyle,
                .strikethroughColor,
                .kern
            ]
            for k in keys {
                if let v = effective[k] {
                    typing[k] = v
                } else {
                    typing.removeValue(forKey: k)
                }
            }
            textView.typingAttributes = typing
        }

        private func applyToSelectionOrTyping(_ textView: UITextView?, _ work: (NSMutableAttributedString, NSRange) -> Void) {
            guard let tv = textView else { return }
            let storage = contentStorage.textStorage ?? NSTextStorage()
            contentStorage.textStorage = storage
            let attr = storage
            var sel = tv.selectedRange
            if sel.length > 0 {
                work(attr, sel)
            } else {
                // Empty selection: apply to typing attributes by temporary insertion
                let loc = max(0, min(sel.location, attr.length))
                let placeholder = NSAttributedString(string: "\u{200B}", attributes: tv.typingAttributes)
                attr.insert(NSMutableAttributedString(attributedString: placeholder), at: loc)
                let temp = NSRange(location: loc, length: 1)
                work(attr, temp)

                // Sync typing attributes from the effective attributes at the caret (only if temp char exists)
                if attr.length > 0 && loc < attr.length {
                    syncTypingAttributes(from: attr, at: loc, to: tv)
                }

                attr.deleteCharacters(in: temp)
                tv.selectedRange = NSRange(location: loc, length: 0)
                // Also update typingAttributes to reflect the change if we modified font/underline/etc.
            }
            // Push back into parent bindings
            pullFromTextView(tv)
        }

        private func toggleFontTrait(_ trait: UIFontDescriptor.SymbolicTraits, textView: UITextView?) {
            applyToSelectionOrTyping(textView) { attr, range in
                attr.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                    let current = (value as? UIFont) ?? UIFont.systemFont(ofSize: 24)
                    var traits = current.fontDescriptor.symbolicTraits
                    if traits.contains(trait) { traits.remove(trait) } else { traits.insert(trait) }
                    if let newDesc = current.fontDescriptor.withSymbolicTraits(traits) {
                        let newFont = UIFont(descriptor: newDesc, size: current.pointSize)
                        attr.addAttribute(.font, value: newFont, range: subRange)
                    }
                }
            }
        }

        private func toggleUnderline(textView: UITextView?) {
            applyToSelectionOrTyping(textView) { attr, range in
                let current = attr.attribute(.underlineStyle, at: range.location, effectiveRange: (nil as NSRangePointer?)) as? NSNumber
                let new = (current?.intValue ?? 0) == 0 ? NSUnderlineStyle.single.rawValue : 0
                attr.addAttribute(.underlineStyle, value: new, range: range)
            }
        }

        private func toggleStrikethrough(textView: UITextView?) {
            applyToSelectionOrTyping(textView) { attr, range in
                let current = attr.attribute(.strikethroughStyle, at: range.location, effectiveRange: (nil as NSRangePointer?)) as? NSNumber
                let new = (current?.intValue ?? 0) == 0 ? NSUnderlineStyle.single.rawValue : 0
                attr.addAttribute(.strikethroughStyle, value: new, range: range)
            }
        }

        private struct WeakTextView { weak var view: UITextView?; init(_ v: UITextView) { self.view = v } }

        init(_ parent: RichTextEditor) {
            self.parent = parent
            super.init()
        }

        // MARK: - Sync helpers

        func attachPipeline(to textView: UITextView) {
            // Use the text view’s own layout manager (read-only property).
            guard let layoutManager: UITextLayoutManager = textView.textLayoutManager else {
                return
            }

            // Ensure contentStorage has a backing textStorage and is seeded.
            if contentStorage.textStorage == nil {
                contentStorage.textStorage = NSTextStorage()
            }

            // If this layoutManager is not already connected to our contentStorage, connect it.
            if layoutManager.textContentStorage !== contentStorage {
                // Detach from any previous content storage if needed
                layoutManager.textContentStorage = contentStorage
            }

            // Ensure layout manager uses our text container
            if layoutManager.textContainer !== textContainer {
                layoutManager.textContainer = textContainer
            }

            // Seed content and selection once attached
            if contentStorage.textStorage?.length == 0 {
                contentStorage.textStorage?.setAttributedString(parent.attributedText)
            }
            textView.selectedRange = parent.selectedRange

            let len = contentStorage.textStorage?.length ?? 0
            #if DEBUG
            print("🔗 attachPipeline -> connected to textView.textLayoutManager, textStorage length=\(len)")
            #endif
        }

        func setInitialText(on textView: UITextView) {
            attachPipeline(to: textView)
            // Always set current content in case we were created with non-empty text
            contentStorage.textStorage?.setAttributedString(parent.attributedText)
            textView.selectedRange = parent.selectedRange

            applyDefaultTypingAttributes(to: textView)
            updateMetrics(textView)
            let len = contentStorage.textStorage?.length ?? 0
            #if DEBUG
            print("📥 setInitialText length=\(len)")
            #endif
        }

        func pullFromTextView(_ textView: UITextView) {
            if let ts = contentStorage.textStorage {
                // Avoid creating unnecessary NSMutableAttributedString copies
                let len = ts.length
                #if DEBUG
                print("🖊️ pullFromTextView length=\(len)")
                #endif
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // Only create copy if the content actually changed
                    if self.parent.attributedText.length != len || self.parent.attributedText.string != ts.string {
                        self.parent.attributedText = NSMutableAttributedString(attributedString: ts)
                    }
                    self.parent.selectedRange = textView.selectedRange
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.selectedRange = textView.selectedRange
                }
            }
            updateMetrics(textView)
        }

        func applyDefaultTypingAttributes(to textView: UITextView) {
            var updated = textView.typingAttributes
            if updated[.font] == nil {
                updated[.font] = UIFont.systemFont(ofSize: parent.defaultTypingPointSize)
            }
            textView.typingAttributes = updated
        }

        // MARK: - UITextViewDelegate

        func textViewDidChange(_ textView: UITextView) {
            let len = contentStorage.textStorage?.length ?? 0
            #if DEBUG
            print("✏️ textViewDidChange length=\(len)")
            #endif
            pullFromTextView(textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            applyDefaultTypingAttributes(to: textView)
            pullFromTextView(textView)
        }

        // MARK: - UIScrollViewDelegate

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let tv = scrollView as? UITextView else { return }
            updateMetrics(tv)
            handleOverscroll(tv)
        }

        // MARK: - Metrics

        func updateMetrics(_ textView: UITextView) {
            let contentHeight = max(textView.contentSize.height, 1)
            let visibleHeight = max(textView.bounds.height, 1)
            let bottom = textView.contentOffset.y + visibleHeight
            let denom = max(1, contentHeight - visibleHeight)
            let sp = min(1, max(0, (bottom - visibleHeight) / denom))

            var cp: CGFloat = 0
            if let tvRange = textView.selectedTextRange {
                let caretRect = textView.caretRect(for: tvRange.end)
                let caretBottom = caretRect.maxY
                cp = min(1, max(0, caretBottom / contentHeight))
            }

            DispatchQueue.main.async {
                self.parent.scrollProgress = sp
                self.parent.caretProgress = cp
                if sp > 0.95 || cp > 0.95 {
                    self.parent.onScrollNearEnd?()
                }
            }
        }

        // MARK: - Overscroll

        private func handleOverscroll(_ textView: UITextView) {
            let contentHeight = textView.contentSize.height
            let visibleHeight = textView.bounds.height
            let maxOffsetY = max(0, contentHeight - visibleHeight)

            let y = textView.contentOffset.y
            let topOverscroll = max(0, -y)
            let bottomOverscroll = max(0, y - maxOffsetY)

            let now = Date()

            if topOverscroll > 0, topOverscroll >= parent.overscrollThreshold * 0.6, !didAnnounceTopHaptic {
                didAnnounceTopHaptic = true
                didAnnounceBottomHaptic = false
                approachHaptic()
            } else if bottomOverscroll > 0, bottomOverscroll >= parent.overscrollThreshold * 0.6, !didAnnounceBottomHaptic {
                didAnnounceBottomHaptic = true
                didAnnounceTopHaptic = false
                approachHaptic()
            } else if topOverscroll == 0, bottomOverscroll == 0 {
                didAnnounceTopHaptic = false
                didAnnounceBottomHaptic = false
            }

            guard now.timeIntervalSince(lastTriggerAt) >= parent.overscrollCooldown else { return }

            if topOverscroll >= parent.overscrollThreshold {
                lastTriggerAt = now
                commitHaptic()
                DispatchQueue.main.async { self.parent.onOverscrollAtTop?() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    textView.setContentOffset(CGPoint(x: 0, y: 20), animated: false)
                }
            } else if bottomOverscroll >= parent.overscrollThreshold {
                lastTriggerAt = now
                commitHaptic()
                DispatchQueue.main.async { self.parent.onOverscrollAtBottom?() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    let newMax = max(0, textView.contentSize.height - textView.bounds.height)
                    textView.setContentOffset(CGPoint(x: 0, y: max(0, newMax - 20)), animated: false)
                }
            }
        }

        private func approachHaptic() {
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.prepare()
            gen.impactOccurred()
        }

        private func commitHaptic() {
            let gen = UINotificationFeedbackGenerator()
            gen.prepare()
            gen.notificationOccurred(.success)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    private func connectFormattingHandlers(_ coordinator: Coordinator, textView: UITextView) {
        coordinator.installFormattingHandlers(onBold: onToggleBold, onItalic: onToggleItalic, onUnderline: onToggleUnderline, onStrikethrough: onToggleStrikethrough, textView: textView)
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView(frame: .zero)
        tv.isEditable = true
        tv.isScrollEnabled = true
        tv.backgroundColor = .clear
        tv.delegate = context.coordinator
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tv.alwaysBounceVertical = true

        // Attach TextKit 2 pipeline and seed content
        context.coordinator.setInitialText(on: tv)
        connectFormattingHandlers(context.coordinator, textView: tv)

        context.coordinator.installAccessory(on: tv, content: accessory?())

        tv.scrollsToTop = false
        (tv as UIScrollView).delegate = context.coordinator

        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Ensure pipeline remains attached (defensive)
        context.coordinator.attachPipeline(to: uiView)

        // Only push attributedText into textStorage if the content actually differs
        if let ts = context.coordinator.contentStorage.textStorage {
            if ts.length != attributedText.length || ts.string != attributedText.string {
                let sel = uiView.selectedRange
                ts.setAttributedString(attributedText)
                if sel.location <= attributedText.length {
                    uiView.selectedRange = sel
                }
                #if DEBUG
                print("📤 updateUIView pushed attributedText length=\(attributedText.length)")
                #endif
            }
        } else {
            context.coordinator.contentStorage.textStorage = NSTextStorage(attributedString: attributedText)
            #if DEBUG
            print("📤 updateUIView seeded textStorage length=\(attributedText.length)")
            #endif
        }

        if uiView.selectedRange != selectedRange {
            uiView.selectedRange = selectedRange
        }

        context.coordinator.applyDefaultTypingAttributes(to: uiView)

        context.coordinator.installAccessory(on: uiView, content: accessory?())

        DispatchQueue.main.async {
            context.coordinator.updateMetrics(uiView)
        }
    }

    // Exposed actions to be called by SwiftUI toolbar
    func boldAction(_ uiView: UITextView, context: Context) { context.coordinator.performBold() }
    func italicAction(_ uiView: UITextView, context: Context) { context.coordinator.performItalic() }
    func underlineAction(_ uiView: UITextView, context: Context) { context.coordinator.performUnderline() }
    func strikethroughAction(_ uiView: UITextView, context: Context) { context.coordinator.performStrikethrough() }

    // Exposed direct formatting triggers
    func performBold(_ uiView: UITextView, context: Context) { context.coordinator.performBold() }
    func performItalic(_ uiView: UITextView, context: Context) { context.coordinator.performItalic() }
    func performUnderline(_ uiView: UITextView, context: Context) { context.coordinator.performUnderline() }
    func performStrikethrough(_ uiView: UITextView, context: Context) { context.coordinator.performStrikethrough() }
}
*/

// MARK: - Editor toolbar overlay helper (iOS)
/*
@available(iOS 16.0, *)
struct EditorToolbarOverlay<Toolbar: View>: View {
    @Binding var attributedText: NSMutableAttributedString
    @Binding var selectedRange: NSRange
    @Binding var scrollProgress: CGFloat
    @Binding var caretProgress: CGFloat

    var onScrollNearEnd: (() -> Void)? = nil
    var onOverscrollAtTop: (() -> Void)? = nil
    var onOverscrollAtBottom: (() -> Void)? = nil

    var overscrollThreshold: CGFloat = 120
    var overscrollCooldown: TimeInterval = 0.6

    @ViewBuilder var toolbar: () -> Toolbar

    var body: some View {
        VStack(spacing: 0) {
            RichTextEditor(
                attributedText: $attributedText,
                selectedRange: $selectedRange,
                scrollProgress: $scrollProgress,
                caretProgress: $caretProgress,
                onScrollNearEnd: onScrollNearEnd,
                onOverscrollAtTop: onOverscrollAtTop,
                onOverscrollAtBottom: onOverscrollAtBottom,
                overscrollThreshold: overscrollThreshold,
                overscrollCooldown: overscrollCooldown
            )
        }
        .floatingToolbar {
            toolbar()
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
        }
    }
}
*/

#elseif canImport(UIKit)
// MARK: - iOS/tvOS fallback stub for older SDKs
/*
struct RichTextEditor: View {
    @Binding var attributedText: NSMutableAttributedString
    @Binding var selectedRange: NSRange

    @Binding var scrollProgress: CGFloat
    @Binding var caretProgress: CGFloat
    var onScrollNearEnd: (() -> Void)? = nil

    var onOverscrollAtTop: (() -> Void)? = nil
    var onOverscrollAtBottom: (() -> Void)? = nil

    var overscrollThreshold: CGFloat = 120
    var overscrollCooldown: TimeInterval = 0.6

    var body: some View {
        // Minimal placeholder so the app still builds on older SDKs.
        TextEditor(text: Binding(
            get: { attributedText.string },
            set: { new in
                attributedText = NSMutableAttributedString(string: new)
                selectedRange = NSRange(location: min(selectedRange.location, attributedText.length), length: 0)
            }
        ))
    }
}
*/
#endif

// MARK: - macOS implementation (TextKit 2)
#if canImport(AppKit)
import AppKit

// TextKit 2–only editor bridge for macOS.
// Requires macOS 13+ SDK.
/*
@available(macOS 13.0, *)
struct RichTextEditor: NSViewRepresentable {
    @Binding var attributedText: NSMutableAttributedString
    @Binding var selectedRange: NSRange

    // Metrics and callback
    @Binding var scrollProgress: CGFloat
    @Binding var caretProgress: CGFloat
    var onScrollNearEnd: (() -> Void)? = nil

    // Overscroll page-change callbacks
    var onOverscrollAtTop: (() -> Void)? = nil
    var onOverscrollAtBottom: (() -> Void)? = nil

    // Configuration
    var overscrollThreshold: CGFloat = 120
    var overscrollCooldown: TimeInterval = 0.6

    // Editor base font size for new typing (kept in sync with codec default 24)
    private let defaultTypingPointSize: CGFloat = 24

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor

        // TextKit 2 pipeline
        let contentStorage = NSTextContentStorage()
        let layoutManager = NSTextLayoutManager()
        let textContainer = NSTextContainer()

        private var lastTriggerAt: Date = .distantPast
        private var didAnnounceTopHaptic = false
        private var didAnnounceBottomHaptic = false

        init(_ parent: RichTextEditor) {
            self.parent = parent
            super.init()
            contentStorage.addTextLayoutManager(layoutManager)
            layoutManager.textContainer = textContainer
        }

        func setInitialText(on textView: NSTextView) {
            if contentStorage.textStorage == nil {
                contentStorage.textStorage = NSTextStorage()
            }
            contentStorage.textStorage?.setAttributedString(parent.attributedText)
            textView.setSelectedRange(parent.selectedRange)

            applyDefaultTypingAttributes(to: textView)
            updateMetrics(textView)

            let len = contentStorage.textStorage?.length ?? 0
            #if DEBUG
            print("📥 setInitialText length=\(len)")
            #endif
        }

        func pullFromTextView(_ textView: NSTextView) {
            if let ts = contentStorage.textStorage {
                let current = NSMutableAttributedString(attributedString: ts)
                let len = current.length
                #if DEBUG
                print("🖊️ pullFromTextView length=\(len)")
                #endif
                DispatchQueue.main.async {
                    self.parent.attributedText = current
                    self.parent.selectedRange = textView.selectedRange()
                }
            } else {
                DispatchQueue.main.async {
                    self.parent.selectedRange = textView.selectedRange()
                }
            }
            updateMetrics(textView)
        }

        func applyDefaultTypingAttributes(to textView: NSTextView) {
            var attrs = textView.typingAttributes
            if attrs[.font] == nil {
                attrs[.font] = NSFont.systemFont(ofSize: parent.defaultTypingPointSize)
                textView.typingAttributes = attrs
            }
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let len = contentStorage.textStorage?.length ?? 0
            #if DEBUG
            print("✏️ textDidChange length=\(len)")
            #endif
            pullFromTextView(tv)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            applyDefaultTypingAttributes(to: tv)
            pullFromTextView(tv)
        }

        // MARK: - Metrics and overscroll

        @objc func contentViewBoundsDidChange(_ note: Notification) {
            guard let clipView = note.object as? NSClipView,
                  let scrollView = clipView.enclosingScrollView,
                  let tv = scrollView.documentView as? NSTextView else { return }
            updateMetrics(tv)
            handleOverscroll(tv, scrollView: scrollView)
        }

        func updateMetrics(_ textView: NSTextView) {
            guard let scrollView = textView.enclosingScrollView else { return }
            let docRect = textView.bounds
            let visRect = scrollView.documentVisibleRect

            let contentHeight = max(docRect.height, 1)
            let visibleHeight = max(visRect.height, 1)
            let bottom = visRect.maxY
            let denom = max(1, contentHeight - visibleHeight)
            let sp = min(1, max(0, (bottom - visibleHeight) / denom))

            var cp: CGFloat = 0
            if let ts = contentStorage.textStorage {
                let sel = textView.selectedRange()
                let charIndex = sel.location + sel.length
                let loc = min(charIndex, ts.length)

                let docRange = contentStorage.documentRange
                if let start = contentStorage.location(docRange.location, offsetBy: loc) {
                    let caretRange = NSTextRange(location: start, end: start)
                    if let fragment = layoutManager.textLayoutFragment(for: caretRange.location, in: .downstream) {
                        let caretBottom = fragment.layoutFragmentFrame.maxY
                        let totalHeight = max(layoutManager.usageBoundsForTextContainer(textContainer).height, contentHeight)
                        if totalHeight > 0 {
                            cp = min(1, max(0, caretBottom / totalHeight))
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                self.parent.scrollProgress = sp
                self.parent.caretProgress = cp
                if sp > 0.95 || cp > 0.95 {
                    self.parent.onScrollNearEnd?()
                }
            }
        }

        private func handleOverscroll(_ textView: NSTextView, scrollView: NSScrollView) {
            let docRect = textView.bounds
            let visRect = scrollView.documentVisibleRect

            let contentHeight = docRect.height
            let visibleHeight = visRect.height
            let maxOffsetY = max(0, contentHeight - visibleHeight)

            let y = visRect.origin.y
            let topOverscroll = max(0, -y)
            let bottomOverscroll = max(0, y - maxOffsetY)

            let now = Date()

            if topOverscroll > 0, topOverscroll >= parent.overscrollThreshold * 0.6, !didAnnounceTopHaptic {
                didAnnounceTopHaptic = true
                didAnnounceBottomHaptic = false
                approachHaptic()
            } else if bottomOverscroll > 0, bottomOverscroll >= parent.overscrollThreshold * 0.6, !didAnnounceBottomHaptic {
                didAnnounceBottomHaptic = true
                didAnnounceTopHaptic = false
                approachHaptic()
            } else if topOverscroll == 0, bottomOverscroll == 0 {
                didAnnounceTopHaptic = false
                didAnnounceBottomHaptic = false
            }

            guard now.timeIntervalSince(lastTriggerAt) >= parent.overscrollCooldown else { return }

            if topOverscroll >= parent.overscrollThreshold {
                lastTriggerAt = now
                commitHaptic()
                DispatchQueue.main.async { self.parent.onOverscrollAtTop?() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    scrollView.contentView.scroll(to: NSPoint(x: 0, y: 20))
                    scrollView.reflectScrolledClipView(scrollView.contentView)
                }
            } else if bottomOverscroll >= parent.overscrollThreshold {
                lastTriggerAt = now
                commitHaptic()
                DispatchQueue.main.async { self.parent.onOverscrollAtBottom?() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    let newMax = max(0, textView.bounds.height - scrollView.documentVisibleRect.height)
                    scrollView.contentView.scroll(to: NSPoint(x: 0, y: max(0, newMax - 20)))
                    scrollView.reflectScrolledClipView(scrollView.contentView)
                }
            }
        }

        private func approachHaptic() {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }

        private func commitHaptic() {
            NSHapticFeedbackManager.defaultPerformer.perform(.success, performanceTime: .now)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator

        context.coordinator.setInitialText(on: textView)

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.verticalScrollElasticity = .automatic

        scroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.contentViewBoundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scroll.contentView
        )

        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if let ts = context.coordinator.contentStorage.textStorage {
            if ts != attributedText {
                if ts.string != attributedText.string || ts.length != attributedText.length {
                    let sel = textView.selectedRange()
                    ts.setAttributedString(attributedText)
                    if sel.location <= attributedText.length {
                        textView.setSelectedRange(sel)
                    }
                    #if DEBUG
                    print("📤 updateNSView pushed attributedText length=\(attributedText.length)")
                    #endif
                }
            }
        } else {
            context.coordinator.contentStorage.textStorage = NSTextStorage(attributedString: attributedText)
            #if DEBUG
            print("📤 updateNSView seeded textStorage length=\(attributedText.length)")
            #endif
        }

        if textView.selectedRange() != selectedRange {
            textView.setSelectedRange(selectedRange)
        }

        context.coordinator.applyDefaultTypingAttributes(to: textView)

        DispatchQueue.main.async {
            context.coordinator.updateMetrics(textView)
        }
    }
}
*/
#endif

// MARK: - RichTextKit Implementation

/// A wrapper around RichTextKit's RichTextEditor that provides a familiar interface
struct RichTextKitEditor: View {
    @StateObject private var context = RichTextContext()
    
    @Binding var attributedText: NSMutableAttributedString
    @Binding var selectedRange: NSRange
    
    // Metrics and callbacks (for compatibility - may not all be implemented)
    @Binding var scrollProgress: CGFloat
    @Binding var caretProgress: CGFloat
    var onScrollNearEnd: (() -> Void)? = nil
    var onOverscrollAtTop: (() -> Void)? = nil
    var onOverscrollAtBottom: (() -> Void)? = nil
    var overscrollThreshold: CGFloat = 120
    var overscrollCooldown: TimeInterval = 0.6
    
    // Formatting handlers
    var onToggleBold: (() -> Void)? = nil
    var onToggleItalic: (() -> Void)? = nil
    var onToggleUnderline: (() -> Void)? = nil
    var onToggleStrikethrough: (() -> Void)? = nil
    
    var accessory: (() -> AnyView)? = nil
    
    var body: some View {
        RichTextKit.RichTextEditor(
            text: Binding(
                get: { NSAttributedString(attributedString: attributedText) },
                set: { newValue in
                    attributedText = NSMutableAttributedString(attributedString: newValue)
                }
            ),
            context: context
        )
        .onAppear {
            // Set initial content using the context's method
            context.setAttributedString(to: attributedText)
        }
    }
}

// MARK: - Convenience typealias for drop-in replacement
typealias RichTextEditor = RichTextKitEditor

