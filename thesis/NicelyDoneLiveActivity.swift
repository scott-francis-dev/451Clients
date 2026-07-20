// NicelyDoneLiveActivity.swift (Widget Extension)
import ActivityKit
import WidgetKit
import SwiftUI

struct NicelyDoneLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PraiseAttributes.self) { context in
            ZStack {
                Color.black.opacity(0.85)
                VStack(spacing: 6) {
                    Text(context.state.message)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(context.state.updatedAt, style: .time)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.vertical, 10)
            }
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 6) {
                        Text(context.state.message)
                            .font(.headline)
                        Text("Updated: \(context.state.updatedAt.formatted(date: .omitted, time: .standard))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "hand.thumbsup.fill")
            } compactTrailing: {
                Text("OK")
                    .font(.caption2)
            } minimal: {
                Image(systemName: "hand.thumbsup.fill")
            }
        }
    }
}
