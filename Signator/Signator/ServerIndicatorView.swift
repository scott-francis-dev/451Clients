//
//  ServerIndicatorView.swift
//  Development helper to show which server is active
//

import SwiftUI

/// A small banner that shows the current server configuration (DEBUG builds only)
struct ServerIndicatorView: View {
    var body: some View {
        #if DEBUG
        if ServerConfig.isUsingCustomServer {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "server.rack")
                        .font(.caption2)
                    Text("Custom Server")
                        .font(.caption2)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                .foregroundColor(.orange)
                
                Text(ServerConfig.baseURL)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
        }
        #endif
    }
}

#Preview {
    VStack {
        ServerIndicatorView()
        Spacer()
    }
}
