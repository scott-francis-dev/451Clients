import SwiftUI

struct MentionChip: View {
    let profile: PersonaResolvedProfile
    @State private var showPopover = false

    var body: some View {
        Button(action: { showPopover = true }) {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle")
                Text(profile.displayName)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.12))
            .foregroundColor(.blue)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text(profile.displayName).font(.headline)
                if let handle = profile.handle, !handle.isEmpty {
                    LabeledCopyRow(label: "Handle", value: "@\(handle)")
                }
                LabeledCopyRow(label: "DID", value: profile.did)
                if let guid = profile.guid { LabeledCopyRow(label: "GUID", value: guid) }
                if let sid = profile.shortId { LabeledCopyRow(label: "Short ID", value: sid) }
            }
            .padding()
        }
    }
}

struct LabeledCopyRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Button(action: { localCopyToPasteboard(value) }) {
                Text(value).font(.system(.footnote, design: .monospaced))
            }
        }
    }
}

private func localCopyToPasteboard(_ text: String) {
#if canImport(UIKit)
    UIPasteboard.general.string = text
#elseif canImport(AppKit)
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString(text, forType: .string)
#endif
}
