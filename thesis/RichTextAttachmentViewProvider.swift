import Foundation

// Helper keys for attachment userInfo so the codec and editor agree.
enum AttachmentUserInfoKeys {
    static let objectId = "objectId"
    static let objectKind = "objectKind"
}

// In future iteration, we can add platform-specific NSTextAttachmentViewProvider subclasses
// that host SwiftUI views inline based on objectKind/objectId.
