import Foundation
import Core451

#if canImport(UIKit)
import UIKit
public typealias UXTextAttachment = NSTextAttachment
#elseif canImport(AppKit)
import AppKit
public typealias UXTextAttachment = NSTextAttachment
#endif

// Simple subclass to carry arbitrary metadata for inline objects.
final class RichTextAttachment: UXTextAttachment {
    var userInfo: [String: Any]?
}
