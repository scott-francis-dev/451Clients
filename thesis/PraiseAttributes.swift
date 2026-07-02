// PraiseAttributes.swift (Shared for App + Widget Extension)
import Foundation
import Core451

#if canImport(ActivityKit) && !os(macOS)
import ActivityKit

@available(iOS 16.1, *)
struct PraiseAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var message: String
        var updatedAt: Date = Date()
    }

    var id: UUID = UUID()
}
#endif
