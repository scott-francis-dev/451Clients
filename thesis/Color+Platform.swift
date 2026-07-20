// Color+Platform.swift
// Cross-platform SwiftUI color aliases.
// Use these instead of Color(.systemXxx) or Color(UIColor.xxx) directly.

import SwiftUI

extension Color {
#if canImport(UIKit)
    static let platformBackground                  = Color(UIColor.systemBackground)
    static let platformSecondaryBackground         = Color(UIColor.secondarySystemBackground)
    static let platformGroupedBackground           = Color(UIColor.systemGroupedBackground)
    static let platformSecondaryGroupedBackground  = Color(UIColor.secondarySystemGroupedBackground)
    static let platformGray6               = Color(UIColor.systemGray6)
    static let platformGray5               = Color(UIColor.systemGray5)
    static let platformGray4               = Color(UIColor.systemGray4)
    static let platformGray                = Color(UIColor.systemGray)
#elseif canImport(AppKit)
    static let platformBackground                  = Color(NSColor.windowBackgroundColor)
    static let platformSecondaryBackground         = Color(NSColor.underPageBackgroundColor)
    static let platformGroupedBackground           = Color(NSColor.controlBackgroundColor)
    static let platformSecondaryGroupedBackground  = Color(NSColor.controlBackgroundColor)
    static let platformGray6               = Color(NSColor.systemGray).opacity(0.18)
    static let platformGray5               = Color(NSColor.systemGray).opacity(0.30)
    static let platformGray4               = Color(NSColor.systemGray).opacity(0.45)
    static let platformGray                = Color(NSColor.systemGray)
#endif
}
