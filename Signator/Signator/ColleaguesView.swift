//
//  ColleaguesView.swift
//  451Wallet
//
//  View for managing colleagues and connection requests
//

import SwiftUI

struct ColleaguesView: View {
    @StateObject private var connectionManager: ConnectionManager
    @StateObject private var resolver: PersonaResolver
    @StateObject private var personaManager: PersonaManager
    
    @State private var searchText = ""
    @State private var showingAddColleague = false
    @State private var selectedTab: Tab = .colleagues
    @State private var isRefreshing = false
    @State private var selectedColleague: Colleague?
    @State private var showingColleagueDetail = false
    @State private var showingVerificationAlert = false
    
    enum Tab: String, CaseIterable {
        case colleagues = "Colleagues"
        case pending = "Requests"
        case sent = "Sent"
    }
    
    init(personaManager: PersonaManager) {
        let manager = personaManager
        _personaManager = StateObject(wrappedValue: manager)
        _connectionManager = StateObject(wrappedValue: ConnectionManager(personaManager: manager))
        _resolver = StateObject(wrappedValue: PersonaResolver(personaManager: manager))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("View", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case .colleagues:
                        colleaguesListView
                    case .pending:
                        pendingRequestsView
                    case .sent:
                        sentRequestsView
                    }
                }
            }
            .navigationTitle("Colleagues")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddColleague = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        Task {
                            await refreshData()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                }
            }
            .sheet(isPresented: $showingAddColleague) {
                AddColleagueView(
                    connectionManager: connectionManager,
                    resolver: resolver,
                    isPresented: $showingAddColleague
                )
            }
            .sheet(isPresented: $showingColleagueDetail) {
                if let colleague = selectedColleague {
                    ColleagueDetailView(
                        colleague: colleague,
                        connectionManager: connectionManager
                    )
                }
            }
            .alert("Verify Connection", isPresented: $showingVerificationAlert, presenting: selectedColleague) { colleague in
                Button("Send Verification Request") {
                    Task {
                        await sendVerificationRequest(to: colleague)
                    }
                }
                Button("Cancel", role: .cancel) {
                    selectedColleague = nil
                }
            } message: { colleague in
                Text("This colleague hasn't been verified yet. Send a verification request to \(colleague.displayName) to confirm their identity?")
            }
        }
        .task {
            // Initial sync
            await refreshData()
        }
    }
    
    // MARK: - Colleague Actions
    
    private func handleColleagueTap(_ colleague: Colleague) {
        selectedColleague = colleague
        
        // Always show detail view - verification actions will be available there
        showingColleagueDetail = true
    }
    
    private func sendVerificationRequest(to colleague: Colleague) async {
        do {
            // Send connection request as verification
            _ = try await connectionManager.sendConnectionRequest(
                toDID: colleague.did,
                message: "Hi \(colleague.name), I'd like to verify our connection."
            )
            
            // Update colleague status to pending verification
            var updatedColleague = colleague
            updatedColleague.verificationStatus = .pendingVerification
            connectionManager.updateColleague(updatedColleague)
        } catch {
            print("Failed to send verification request: \(error)")
        }
    }
    
    // MARK: - Colleagues List
    
    private var colleaguesListView: some View {
        Group {
            if connectionManager.colleagues.isEmpty {
                emptyColleaguesView
            } else {
                List {
                    ForEach(filteredColleagues) { colleague in
                        Button {
                            handleColleagueTap(colleague)
                        } label: {
                            ColleagueRow(colleague: colleague)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                connectionManager.removeColleague(colleague)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search colleagues")
            }
        }
    }
    
    private var filteredColleagues: [Colleague] {
        if searchText.isEmpty {
            return connectionManager.colleagues.sorted { $0.name < $1.name }
        }
        return connectionManager.colleagues.filter { colleague in
            colleague.name.localizedCaseInsensitiveContains(searchText) ||
            colleague.did.localizedCaseInsensitiveContains(searchText) ||
            (colleague.email?.localizedCaseInsensitiveContains(searchText) ?? false)
        }.sorted { $0.name < $1.name }
    }
    
    private var emptyColleaguesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Colleagues Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add colleagues to share documents and collaborate securely")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showingAddColleague = true
            } label: {
                Label("Add Colleague", systemImage: "person.badge.plus")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Pending Requests
    
    private var pendingRequestsView: some View {
        Group {
            if connectionManager.pendingRequests.isEmpty {
                emptyPendingView
            } else {
                List {
                    ForEach(connectionManager.pendingRequests) { request in
                        PendingRequestRow(
                            request: request,
                            connectionManager: connectionManager
                        )
                    }
                }
            }
        }
    }
    
    private var emptyPendingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Pending Requests")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Connection requests will appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Sent Requests
    
    private var sentRequestsView: some View {
        Group {
            if connectionManager.sentRequests.isEmpty {
                emptySentView
            } else {
                List {
                    ForEach(connectionManager.sentRequests) { request in
                        SentRequestRow(request: request)
                    }
                }
            }
        }
    }
    
    private var emptySentView: some View {
        VStack(spacing: 16) {
            Image(systemName: "paperplane")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Sent Requests")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your connection requests will appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helpers
    
    private func refreshData() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            try await connectionManager.syncAll()
        } catch {
            print("Failed to sync connection data: \(error)")
        }
    }
}

// MARK: - Colleague Row

struct ColleagueRow: View {
    let colleague: Colleague
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with verification badge
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(avatarGradient)
                        .frame(width: 44, height: 44)
                    
                    Text(colleague.initials)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                
                // Verification badge
                if colleague.verificationStatus == .verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .background(
                            Circle()
                                .fill(Color.green)
                                .frame(width: 18, height: 18)
                        )
                        .offset(x: 2, y: 2)
                } else if colleague.verificationStatus == .unverified {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .background(
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 18, height: 18)
                        )
                        .offset(x: 2, y: 2)
                } else if colleague.verificationStatus == .pendingVerification {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .background(
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 18, height: 18)
                        )
                        .offset(x: 2, y: 2)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(colleague.displayName)
                        .font(.headline)
                    
                    // Verification status text
                    if colleague.verificationStatus != .verified {
                        Text(verificationStatusText)
                            .font(.caption2)
                            .foregroundStyle(verificationStatusColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(verificationStatusColor.opacity(0.15))
                            )
                    }
                }
                
                // Use the Signator Calling Card component for handle/DID
                PersonaHandleCard(
                    handle: colleague.handle ?? colleague.did,
                    isPublic: true,
                    size: .compact,
                    showCopyButton: false
                )
            }
            
            Spacer()
            
            if colleague.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var avatarGradient: LinearGradient {
        switch colleague.verificationStatus {
        case .verified:
            return LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .unverified:
            return LinearGradient(colors: [.orange, .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pendingVerification:
            return LinearGradient(colors: [.blue, .blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rejected:
            return LinearGradient(colors: [.red, .red.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private var verificationStatusText: String {
        switch colleague.verificationStatus {
        case .unverified:
            return "Tap to Verify"
        case .pendingVerification:
            return "Verification Pending"
        case .verified:
            return "Verified"
        case .rejected:
            return "Rejected"
        }
    }
    
    private var verificationStatusColor: Color {
        switch colleague.verificationStatus {
        case .unverified:
            return .orange
        case .pendingVerification:
            return .blue
        case .verified:
            return .green
        case .rejected:
            return .red
        }
    }
}

// MARK: - Pending Request Row

struct PendingRequestRow: View {
    let request: ConnectionRequest
    @ObservedObject var connectionManager: ConnectionManager
    
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.requesterPreview?.displayName ?? "Unknown")
                        .font(.headline)
                    
                    if let shortId = request.requesterPreview?.shortId {
                        Text(shortId)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            if let message = request.message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            HStack {
                Button {
                    Task {
                        await accept()
                    }
                } label: {
                    Label("Accept", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
                
                Button {
                    Task {
                        await reject()
                    }
                } label: {
                    Label("Decline", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isProcessing)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func accept() async {
        isProcessing = true
        errorMessage = nil
        
        do {
            _ = try await connectionManager.acceptConnectionRequest(request)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
    }
    
    private func reject() async {
        isProcessing = true
        errorMessage = nil
        
        do {
            try await connectionManager.rejectConnectionRequest(request)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
    }
}

// MARK: - Sent Request Row

struct SentRequestRow: View {
    let request: ConnectionRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(request.recipientPreview?.displayName ?? "Unknown")
                    .font(.headline)
                
                Spacer()
                
                statusBadge
            }
            
            if let message = request.message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text(request.createdAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch request.status {
        case .pending:
            Label("Pending", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.orange)
        case .accepted:
            Label("Accepted", systemImage: "checkmark")
                .font(.caption)
                .foregroundStyle(.green)
        case .rejected:
            Label("Declined", systemImage: "xmark")
                .font(.caption)
                .foregroundStyle(.red)
        case .blocked:
            Label("Blocked", systemImage: "hand.raised")
                .font(.caption)
                .foregroundStyle(.red)
        case .expired:
            Label("Expired", systemImage: "clock.badge.xmark")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Add Colleague View

struct AddColleagueView: View {
    @ObservedObject var connectionManager: ConnectionManager
    @ObservedObject var resolver: PersonaResolver
    @Binding var isPresented: Bool
    
    @State private var searchQuery = ""
    @State private var resolvedProfile: PersonaResolvedProfile?
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var message = ""
    @State private var isSending = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter @handle, short code, or DID", text: $searchQuery)
                        .platformAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    Button {
                        Task {
                            await searchPersona()
                        }
                    } label: {
                        if isSearching {
                            ProgressView()
                        } else {
                            Label("Search", systemImage: "magnifyingglass")
                        }
                    }
                    .disabled(searchQuery.isEmpty || isSearching)
                } header: {
                    Text("Find Colleague")
                }
                
                if let profile = resolvedProfile {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(profile.displayName)
                                .font(.headline)
                            
                            if let shortId = profile.shortId {
                                Text(shortId)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text(profile.did)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    } header: {
                        Text("Found")
                    }
                    
                    Section {
                        TextField("Optional message", text: $message, axis: .vertical)
                            .lineLimit(3...6)
                    } header: {
                        Text("Message")
                    } footer: {
                        Text("This message will be sent with your connection request")
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
                                Label("Send Connection Request", systemImage: "paperplane.fill")
                            }
                        }
                        .disabled(isSending)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Colleague")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func searchPersona() async {
        isSearching = true
        errorMessage = nil
        resolvedProfile = nil
        
        do {
            let profile = try await resolver.resolveStringWithShortCodeSupport(searchQuery)
            resolvedProfile = profile
        } catch {
            errorMessage = "Could not find persona: \(error.localizedDescription)"
        }
        
        isSearching = false
    }
    
    private func sendRequest() async {
        guard let profile = resolvedProfile else { return }
        
        isSending = true
        errorMessage = nil
        
        do {
            let request = try await connectionManager.sendConnectionRequest(
                toDID: profile.did,
                message: message.isEmpty ? nil : message
            )
            
            // Also add as unverified colleague for immediate visibility
            connectionManager.addUnverifiedColleague(
                did: profile.did,
                name: profile.name ?? "Unknown",
                shortId: profile.shortId,
                prettyDID: profile.prettyDID,
                handle: profile.handle
            )
            
            isPresented = false
        } catch {
            errorMessage = "Failed to send request: \(error.localizedDescription)"
        }
        
        isSending = false
    }
}

// MARK: - Colleague Detail View

struct ColleagueDetailView: View {
    let colleague: Colleague
    @ObservedObject var connectionManager: ConnectionManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var isSendingVerification = false
    @State private var notes: String
    @State private var isFavorite: Bool
    @State private var showingDeleteConfirmation = false
    
    init(colleague: Colleague, connectionManager: ConnectionManager) {
        self.colleague = colleague
        self.connectionManager = connectionManager
        _notes = State(initialValue: colleague.notes ?? "")
        _isFavorite = State(initialValue: colleague.isFavorite)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    VStack(spacing: 16) {
                        // Large avatar with verification badge
                        ZStack(alignment: .bottomTrailing) {
                            ZStack {
                                Circle()
                                    .fill(avatarGradient)
                                    .frame(width: 80, height: 80)
                                
                                Text(colleague.initials)
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            
                            // Verification badge
                            verificationBadge
                                .offset(x: 4, y: 4)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(spacing: 4) {
                            Text(colleague.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            verificationStatusLabel
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                
                // Verification Actions
                if colleague.verificationStatus == .unverified {
                    Section {
                        Button {
                            Task {
                                await sendVerificationRequest()
                            }
                        } label: {
                            if isSendingVerification {
                                HStack {
                                    ProgressView()
                                    Text("Sending...")
                                }
                            } else {
                                Label("Send Verification Request", systemImage: "checkmark.seal")
                            }
                        }
                        .disabled(isSendingVerification)
                    } footer: {
                        Text("Send a verification request to confirm this colleague's identity")
                    }
                }
                
                // Contact Information
                Section("Contact Information") {
                    if let email = colleague.email {
                        LabeledContent("Email", value: email)
                    }
                    
                    if let handle = colleague.handle {
                        LabeledContent("Handle", value: "@\(handle)")
                    }
                    
                    if let shortId = colleague.shortId {
                        LabeledContent("Short ID", value: shortId)
                    }
                    
                    if let prettyDID = colleague.prettyDID {
                        LabeledContent("Pretty DID", value: prettyDID)
                    }
                    
                    LabeledContent("DID") {
                        Text(colleague.did)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                // Additional Info
                if colleague.address != nil || colleague.affiliations != nil || colleague.socialLinks != nil {
                    Section("Additional Information") {
                        if let address = colleague.address {
                            LabeledContent("Address", value: address)
                        }
                        
                        if let affiliations = colleague.affiliations {
                            LabeledContent("Affiliations", value: affiliations)
                        }
                        
                        if let socialLinks = colleague.socialLinks {
                            LabeledContent("Social Links", value: socialLinks)
                        }
                    }
                }
                
                // Connection Details
                Section("Connection Details") {
                    LabeledContent("Connected") {
                        Text(colleague.connectedAt, style: .date)
                    }
                    
                    if let lastInteraction = colleague.lastInteractionAt {
                        LabeledContent("Last Interaction") {
                            Text(lastInteraction, style: .relative)
                        }
                    }
                    
                    Toggle("Favorite", isOn: $isFavorite)
                        .onChange(of: isFavorite) { oldValue, newValue in
                            updateFavoriteStatus(newValue)
                        }
                }
                
                // Notes
                Section {
                    TextField("Add notes about this colleague...", text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                        .onChange(of: notes) { oldValue, newValue in
                            saveNotes(newValue)
                        }
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Private notes are only visible to you")
                }
                
                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Remove Colleague", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Colleague Details")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Remove Colleague", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    connectionManager.removeColleague(colleague)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to remove \(colleague.displayName) from your colleagues? This action cannot be undone.")
            }
        }
    }
    
    @ViewBuilder
    private var verificationBadge: some View {
        switch colleague.verificationStatus {
        case .verified:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .background(
                    Circle()
                        .fill(Color.green)
                        .frame(width: 28, height: 28)
                )
        case .unverified:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .background(
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 28, height: 28)
                )
        case .pendingVerification:
            Image(systemName: "clock.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .background(
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 28, height: 28)
                )
        case .rejected:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .background(
                    Circle()
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                )
        }
    }
    
    @ViewBuilder
    private var verificationStatusLabel: some View {
        HStack(spacing: 6) {
            switch colleague.verificationStatus {
            case .verified:
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("Verified")
                    .foregroundStyle(.green)
            case .unverified:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                Text("Unverified")
                    .foregroundStyle(.orange)
            case .pendingVerification:
                Image(systemName: "clock.fill")
                    .foregroundStyle(.blue)
                Text("Verification Pending")
                    .foregroundStyle(.blue)
            case .rejected:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Verification Rejected")
                    .foregroundStyle(.red)
            }
        }
        .font(.subheadline)
        .fontWeight(.medium)
    }
    
    private var avatarGradient: LinearGradient {
        switch colleague.verificationStatus {
        case .verified:
            return LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .unverified:
            return LinearGradient(colors: [.orange, .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pendingVerification:
            return LinearGradient(colors: [.blue, .blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rejected:
            return LinearGradient(colors: [.red, .red.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private func sendVerificationRequest() async {
        isSendingVerification = true
        
        do {
            _ = try await connectionManager.sendConnectionRequest(
                toDID: colleague.did,
                message: "Hi \(colleague.name), I'd like to verify our connection."
            )
            
            // Update colleague status
            var updatedColleague = colleague
            updatedColleague.verificationStatus = .pendingVerification
            connectionManager.updateColleague(updatedColleague)
            
            // Dismiss after sending
            try? await Task.sleep(for: .seconds(0.5))
            dismiss()
        } catch {
            print("Failed to send verification request: \(error)")
        }
        
        isSendingVerification = false
    }
    
    private func updateFavoriteStatus(_ newValue: Bool) {
        var updatedColleague = colleague
        updatedColleague.isFavorite = newValue
        connectionManager.updateColleague(updatedColleague)
    }
    
    private func saveNotes(_ newNotes: String) {
        var updatedColleague = colleague
        updatedColleague.notes = newNotes.isEmpty ? nil : newNotes
        connectionManager.updateColleague(updatedColleague)
    }
}

// MARK: - Preview

#Preview {
    ColleaguesView(personaManager: PersonaManager())
}
