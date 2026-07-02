// ActivityManager.swift (App target)
import Foundation
import Core451
#if canImport(ActivityKit) && !os(macOS)
import ActivityKit
#endif


enum ActivityManager {
    // Configuration
    static let triggerPhrase: String = "nicely done"
    static let displayMessage: String = "Nicely done!"
    static let debounceInterval: TimeInterval = 5.0
    static let verboseLogs: Bool = false  // Set to true for detailed logging

    // State
    static var lastTriggeredAt: Date = .distantPast
    static var isActive: Bool = false

    #if canImport(ActivityKit) && !os(macOS)
    static var current: Activity<PraiseAttributes>? = nil
    #endif

    // Triggers

    @MainActor
    static func triggerIfNeeded(forPlainText text: String) {
        let now = Date()
        let contains = text.range(of: triggerPhrase, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        if verboseLogs {
            print("🧪 triggerIfNeeded called. contains='\(contains)' len=\(text.count) Δt=\(now.timeIntervalSince(lastTriggeredAt))s")
        }
        if now.timeIntervalSince(lastTriggeredAt) < debounceInterval { return }
        if contains {
            lastTriggeredAt = now
            startOrUpdatePraise(message: displayMessage)
            scheduleAutoEnd()
        }
    }

    @MainActor
    static func startOrUpdatePraise(message: String) {
        #if canImport(ActivityKit) && !os(macOS)
        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        if verboseLogs {
            print("📣 startOrUpdatePraise. areActivitiesEnabled=\(enabled)")
        }
        guard #available(iOS 16.1, *), enabled else { return }

        let state = PraiseAttributes.ContentState(message: message, updatedAt: Date())
        if let activity = current {
            if verboseLogs {
                print("🔄 Updating existing activity \(activity.id)")
            }
            Task { await activity.update(using: state) }
        } else {
            let attrs = PraiseAttributes(id: UUID())
            do {
                let activity = try Activity<PraiseAttributes>.request(
                    attributes: attrs,
                    contentState: state,
                    pushType: nil
                )
                current = activity
                isActive = true
                if verboseLogs {
                    print("✅ Live Activity started id=\(activity.id)")
                }
            } catch {
                print("❌ Live Activity request failed: \(error)")
            }
        }
        #else
        // ActivityKit not available; nothing to do.
        #endif
    }

    // Auto end after a short delay
    @MainActor
    static func scheduleAutoEnd() {
        let delay: TimeInterval = 2.0
        if verboseLogs {
            print("⏱️ scheduleAutoEnd in \(delay)s")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            endPraise()
        }
    }

    @MainActor
    static func endPraise() {
        #if canImport(ActivityKit) && !os(macOS)
        guard #available(iOS 16.1, *) else { return }
        guard isActive else {
            if verboseLogs {
                print("ℹ️ endPraise: not active; nothing to end")
            }
            return
        }
        if let activity = current {
            let finalState = PraiseAttributes.ContentState(message: displayMessage, updatedAt: Date())
            Task {
                await activity.end(using: finalState, dismissalPolicy: .immediate)
                if verboseLogs {
                    print("🛑 Live Activity ended id=\(activity.id)")
                }
            }
        }
        current = nil
        isActive = false
        #else
        // No-op when ActivityKit is unavailable
        #endif
    }
}
