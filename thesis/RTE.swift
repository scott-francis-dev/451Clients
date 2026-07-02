import Core451
#if os(iOS) || os(tvOS)
import UIKit
import Foundation

extension RichTextEditor {
  // Apply a mutation to the current selection only (no typingAttributes fallback)
  // Resolves the UITextView from the provided parameter or current first responder.
  @MainActor
  private func applyAttributeToSelection(textView: UITextView?, mutate: (NSMutableAttributedString, NSRange) -> Void) {
    print("🪢 applyAttributeToSelection ENTER provided textView=\(String(describing: textView))")

    // Resolve text view using provided instance or first responder fallback
    guard let tv = resolveTextView(textView) else {
      print("🪢 applyAttributeToSelection could not resolve UITextView — aborting")
      return
    }

    var range = tv.selectedRange
    print("🪢 applyAttributeToSelection selectedRange=\(range)")

    // Require a non-empty selection; if empty, do nothing (selection-only behavior)
    guard range.length > 0 else {
      print("🪢 applyAttributeToSelection empty selection — skipping (selection-only)")
      return
    }

    // Work on a mutable copy
    let mutable = NSMutableAttributedString(attributedString: tv.attributedText ?? NSAttributedString(string: tv.text ?? ""))

    // Clamp range within bounds of the string
    let clampedLocation = max(0, min(range.location, mutable.length))
    let clampedLength = max(0, min(range.length, mutable.length - clampedLocation))
    let clamped = NSRange(location: clampedLocation, length: clampedLength)
    print("🪢 applyAttributeToSelection clamped=\(clamped) len(attr)=\(mutable.length)")

    // Perform mutation
    mutate(mutable, clamped)

    // Apply back and preserve original selection
    tv.attributedText = mutable
    tv.selectedRange = range
    print("🪢 applyAttributeToSelection EXIT applied and preserved selection=\(range)")
  }

  // Resolve current UITextView from first responder if none is passed in
  private func currentFirstResponder() -> UIResponder? {
    UIApplication.shared.sendAction(#selector(UIResponder._captureFirstResponder(_:)), to: nil, from: nil, for: nil)
    return UIResponder._lastFirstResponder
  }

  private func resolveTextView(_ provided: UITextView?) -> UITextView? {
    if let provided = provided { return provided }
    if let tv = currentFirstResponder() as? UITextView { return tv }
    return nil
  }

  // Helper to capture first responder via responder chain
  // We declare this in an internal extension within this file scope.

  @MainActor
  func toggleStrikethroughOnSelection(textView: UITextView?) {
    // Legacy UIKit helper: prefer routing formatting via RichTextDocument for JSON fidelity.
    print("🪢 RTE.toggleStrikethroughOnSelection ENTER textView=\(String(describing: textView)))")
    if textView == nil { print("🪢 RTE.toggleStrikethroughOnSelection no provided UITextView — will attempt first responder fallback") }
    applyAttributeToSelection(textView: textView) { attr, range in
      print("🪢 RTE.toggleStrikethroughOnSelection applying in range=\(range))")
      let current = (attr.attribute(.strikethroughStyle, at: range.location, effectiveRange: nil) as? NSNumber)?.intValue ?? 0
      let newValue = current == 0 ? NSUnderlineStyle.single.rawValue : 0
      print("🪢 RTE.toggleStrikethroughOnSelection current=\(current) -> newValue=\(newValue)")
      attr.addAttribute(.strikethroughStyle, value: newValue, range: range)
      let post = attr.attribute(.strikethroughStyle, at: range.location, effectiveRange: nil) as Any?
      print("🪢 RTE.toggleStrikethroughOnSelection APPLIED post=\(String(describing: post)) in range=\(range))")
    }
  }

  // DEPRECATED: prefer applyAttributeToSelection(textView:mutate:) for selection-only actions.
  private func applyToSelectionOrTyping(_ textView: UITextView?, _ mutate: (NSMutableAttributedString, NSRange) -> Void) {
    print("🆂 (TK2) applyToSelectionOrTyping: ENTER textView=\(String(describing: textView)))")
    guard let textView = textView else {
      print("🆂 (TK2) applyToSelectionOrTyping: textView is nil — aborting")
      return
    }

    // Work with a mutable copy of the attributed text
    let mutable = NSMutableAttributedString(attributedString: textView.attributedText ?? NSAttributedString(string: textView.text ?? ""))

    var range = textView.selectedRange
    print("🆂 (TK2) applyToSelectionOrTyping: selectedRange=\(range) len(attr)=\(mutable.length)")

    // If there's no selection (length == 0), toggle typing attributes so future input reflects the change.
    if range.length == 0 {
      var typing = textView.typingAttributes
      let current = (typing[.strikethroughStyle] as? NSNumber)?.intValue ?? 0
      let newValue = current == 0 ? NSUnderlineStyle.single.rawValue : 0
      typing[.strikethroughStyle] = newValue
      textView.typingAttributes = typing
      print("🆂 (TK2) applyToSelectionOrTyping: caret-only -> toggled typingAttributes .strikethroughStyle to \(newValue)")
      print("🆂 (TK2) applyToSelectionOrTyping: typingAttributes now=\(textView.typingAttributes)")
      return
    }

    // Ensure the range is within bounds
    let clampedLocation = max(0, min(range.location, mutable.length))
    let clampedLength = max(0, min(range.length, mutable.length - clampedLocation))
    let clamped = NSRange(location: clampedLocation, length: clampedLength)
    print("🆂 (TK2) applyToSelectionOrTyping: clamped=\(clamped)")

    mutate(mutable, clamped)

    // Apply back to the text view and preserve selection
    textView.attributedText = mutable
    textView.selectedRange = NSRange(location: clampedLocation + clampedLength, length: 0)
    print("🆂 (TK2) applyToSelectionOrTyping: EXIT applied, caret moved to end of clamped range")
  }

  // NOTE: For selection-only behavior, call toggleStrikethroughOnSelection(textView:)
  private func toggleStrikethrough(textView: UITextView?) {
    print("🆂 (TK2) toggleStrikethrough: ENTER textView=\(String(describing: textView))")
    applyToSelectionOrTyping(textView) { attr, range in
      print("🆂 (TK2) toggleStrikethrough: before range=\(range)")
      var effective = NSRange(location: 0, length: 0)
      let current = attr.attribute(NSAttributedString.Key.strikethroughStyle, at: max(0, min(range.location, attr.length == 0 ? 0 : attr.length - 1)), effectiveRange: &effective) as? NSNumber
      let newValue = (current?.intValue ?? 0) == 0 ? NSUnderlineStyle.single.rawValue : 0
      print("🆂 (TK2) will set .strikethroughStyle -> \(newValue) in \(range)")
      attr.addAttribute(NSAttributedString.Key.strikethroughStyle, value: newValue, range: range)
      var postEff = NSRange(location: 0, length: 0)
      let post = attr.attribute(NSAttributedString.Key.strikethroughStyle, at: range.location, effectiveRange: &postEff) as? NSNumber
      print("🆂 (TK2) applied .strikethroughStyle -> \(post?.intValue ?? -1) at \(range)")
      let startIndex = range.location
      let endIndex = max(0, min(range.location + max(0, range.length - 1), attr.length == 0 ? 0 : attr.length - 1))
      let startVal = attr.attribute(.strikethroughStyle, at: startIndex, effectiveRange: nil) as Any?
      let endVal = attr.attribute(.strikethroughStyle, at: endIndex, effectiveRange: nil) as Any?
      print("🆂 (TK2) probe: start=\(startIndex) -> \(String(describing: startVal)); end=\(endIndex) -> \(String(describing: endVal))")
    }
  }
}

fileprivate extension UIResponder {
  private static weak var _lastFR: UIResponder?
  static var _lastFirstResponder: UIResponder? { _lastFR }
  @objc func _captureFirstResponder(_ sender: Any?) { UIResponder._lastFR = self }
}
#endif

