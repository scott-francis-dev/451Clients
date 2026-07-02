//
//  ConnectionGuardView.swift
//  451Wallet
//
//  Guard view to ensure connection exists before sharing sensitive information
//

import SwiftUI

/// Use this view to wrap any UI that requires a verified colleague connection
/// It will prompt the user to send a connection request if not already connected
struct ConnectionGuardView<Content: View>: View {
    let recipientDID: String
    let recipientName: String?
    let content: () -> Content
    
    @StateObject private var connectionManager: ConnectionManager
    @State private var showingRequestSheet = false
    @State private var isCheckingConnection = true
    @State private var connectionStatus: ConnectionCheckStatus = .unknown
    
    enum ConnectionCheckStatus {
        case unknown
        case connected(Colleague)
        case pending
        case notConnected
    }
    
    init(
        recipientDID: String,
        recipientName: String? = nil,
        personaManager: PersonaManager,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.recipientDID = recipientDID
        self.recipientName = recipientName
        self.content = content
        _connectionManager = StateObject(wrappedValue: ConnectionManager(personaManager: personaManager))
    }
    
    var body: some View {
        Group {
            if isCheckingConnection {
                ProgressView("Checking connection...")
            } else {
                switch connectionStatus {
                case .connected:
                    // ✅ Connection verified - show protected content
                    content()
                    
                case .pending:
                    pendingConnectionView
                    
                case .notConnected, .unknown:
                    noConnectionView
                }
            }
        }
        .task {
            await checkConnection()
        }
        .sheet(isPresented: $showingRequestSheet) {
            ConnectionRequestSheet(
                recipientDID: recipientDID,
                recipientName: recipientName,
                connectionManager: connectionManager
            )
        }
    }
    
    // MARK: - Views
    
    private var pendingConnectionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text("Connection Pending")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("You've sent a connection request to \(recipientName ?? "this person"). Once they accept, you'll be able to proceed.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                Task {
                    await checkConnection()
                }
            } label: {
                Label("Refresh Status", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    private var noConnectionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.shield.checkmark")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Connection Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("To protect privacy, you need to connect with \(recipientName ?? "this person") before proceeding. They'll need to accept your connection request.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(spacing: 8) {
                Label("Your information will remain private", systemImage: "lock.shield")
                Label("They'll only see your name initially", systemImage: "eye.slash")
                Label("Full details shared after acceptance", systemImage: "checkmark.shield")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical)
            
            Button {
                showingRequestSheet = true
            } label: {
                Label("Send Connection Request", systemImage: "person.badge.plus")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private func checkConnection() async {
        isCheckingConnection = true
        defer { isCheckingConnection = false }
        
        // Sync with server to get latest state
        do {
            try await connectionManager.syncAll()
        } catch {
            print("Failed to sync connections: \(error)")
        }
        
        // Check connection status
        if let colleague = connectionManager.colleague(for: recipientDID) {
            connectionStatus = .connected(colleague)
        } else if connectionManager.hasPendingRequest(did: recipientDID) {
            connectionStatus = .pending
        } else {
            connectionStatus = .notConnected
        }
    }
}

// MARK: - Connection Request Sheet

struct ConnectionRequestSheet: View {
    let recipientDID: String
    let recipientName: String?
    @ObservedObject var connectionManager: ConnectionManager
    
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var requestSent = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Send connection request to:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(recipientName ?? recipientDID)
                            .font(.headline)
                    }
                }
                
                if !requestSent {
                    Section {
                        TextField("Optional message", text: $message, axis: .vertical)
                            .lineLimit(3...6)
                    } header: {
                        Text("Message")
                    } footer: {
                        Text("Add context to help them recognize you (e.g., \"We met at the conference\")")
                    }
                    
                    Section {
                        Button {
                            Task {
                                await sendRequest()
                            }
                        } label: {
                            if isSending {
                                ProgressView()
                            } else {
                                Label("Send Request", systemImage: "paperplane.fill")
                            }
                        }
                        .disabled(isSending)
                    }
                    
                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                } else {
                    Section {
                        Label("Request sent successfully!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    
                    Section {
                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Connection Request")
            .inlineNavigationTitle()
            .toolbar {
                if !requestSent {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    private func sendRequest() async {
        isSending = true
        errorMessage = nil
        
        do {
            _ = try await connectionManager.sendConnectionRequest(
                toDID: recipientDID,
                message: message.isEmpty ? nil : message
            )
            requestSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSending = false
    }
}

// MARK: - Usage Example

#Preview("Connected") {
    ConnectionGuardView(
        recipientDID: "did:key:example123",
        recipientName: "Jane Doe",
        personaManager: PersonaManager()
    ) {
        VStack {
            Text("Protected Content")
                .font(.title)
            Text("This is only shown to connected colleagues")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview("Not Connected") {
    ConnectionGuardView(
        recipientDID: "did:key:example456",
        recipientName: "John Smith",
        personaManager: PersonaManager()
    ) {
        VStack {
            Text("Protected Content")
                .font(.title)
        }
    }
}
