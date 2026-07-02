import SwiftUI
import CryptoKit

// MARK: - Pending Signatures API Models
struct SignedSearchRequest: Codable {
    let personaDID: String
    let query: String
    let timestamp: String
    let signature: String
}

struct PendingSignaturesResponse: Codable {
    let personaDID: String
    let pendingCount: Int
    let documents: [PendingDocument]
}

struct PendingDocument: Codable, Identifiable {
    var id: String { documentDID }
    let documentDID: String
    let title: String?
    let type: String?
    let requiredSignatures: Int
    let currentSignatureCount: Int
    let createdAt: String?
    let authorizedSigners: [String]
    let documentHash: String?
}

// MARK: - Pending Signatures Service
enum PendingSignaturesService {
    static func makeTimestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    static func canonicalMessage(personaDID: String, query: String, timestamp: String) -> String {
        "\(personaDID)|\(query)|\(timestamp)"
    }

    static func signMessageBase64(_ message: String, privateKey: P256.Signing.PrivateKey) throws -> String {
        let data = Data(message.utf8)
        let signature = try privateKey.signature(for: data)
        return Data(signature.derRepresentation).base64EncodedString()
    }

    static func fetchPending(
        personaDID: String,
        query: String = "",
        privateKey: P256.Signing.PrivateKey,
        baseURLString: String
    ) async throws -> PendingSignaturesResponse {
        guard let baseURL = URL(string: baseURLString) else {
            throw URLError(.badURL)
        }
        let timestamp = makeTimestamp()
        let message = canonicalMessage(personaDID: personaDID, query: query, timestamp: timestamp)
        let signature = try signMessageBase64(message, privateKey: privateKey)
        let body = SignedSearchRequest(personaDID: personaDID, query: query, timestamp: timestamp, signature: signature)

        var request = URLRequest(url: baseURL.appendingPathComponent("/search/pending-signatures"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            if statusCode == 404, bodyString.localizedCaseInsensitiveContains("not found") {
                return PendingSignaturesResponse(personaDID: personaDID, pendingCount: 0, documents: [])
            }
            throw NSError(domain: "PendingSignaturesService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(bodyString)"])
        }
        return try JSONDecoder().decode(PendingSignaturesResponse.self, from: data)
    }
}

// MARK: - Submit Signature Service
enum DocumentSignatureService {
    struct SubmitResponse: Codable { let status: String? }

    static func submitSignature(
        documentDID: String,
        signerPersonaDID: String,
        signatureBase64: String,
        signatureType: String = "P256-ES256",
        timestamp: String,
        documentHash: String?,
        baseURLString: String
    ) async throws -> SubmitResponse {
        guard let baseURL = URL(string: baseURLString) else { throw URLError(.badURL) }
        var request = URLRequest(url: baseURL.appendingPathComponent("/documents/\(documentDID)/sign"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: String] = [
            "signerPersonaDID": signerPersonaDID,
            "signature": signatureBase64,
            "signatureType": signatureType,
            "timestamp": timestamp
        ]
        if let documentHash = documentHash { body["documentHash"] = documentHash }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "DocumentSignatureService", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Server error: \(bodyString)"])
        }
        return (try? JSONDecoder().decode(SubmitResponse.self, from: data)) ?? SubmitResponse(status: nil)
    }
}

struct MainTabView: View {
    @EnvironmentObject private var personaManager: PersonaManager
    @State private var showPersonaSheet = false
    @State private var selectedTab: Int = 0
    @State private var incomingProposedPersonaToken: String? = nil
    
    var body: some View {
        let documentData = Data() // TODO: Replace with real document data
        let persona = personaManager.activePersona()
        let personaDid = persona?.id ?? ""
        let personaPublicKey = persona?.publicKeyBase64 ?? ""
        
        TabView(selection: $selectedTab) {
            // Sign Tab
            NavigationStack {
                SignRequestsView(personaManager: personaManager, showPersonaSheet: $showPersonaSheet)
            }
            .tabItem {
                Label("Dashboard", systemImage: "gauge")
            }
            .tag(0)
            
            // Contacts Tab
            NavigationStack {
                ContactsView(personaManager: personaManager, showPersonaSheet: $showPersonaSheet)
            }
            .tabItem {
                Label("Friends/Colleagues", systemImage: "person.2")
            }
            .tag(1)
            
            // Personas Tab
            NavigationStack {
                PersonasTabView(personaManager: personaManager, showPersonaSheet: $showPersonaSheet)
            }
            .tabItem {
                Label("Personas", systemImage: "person.2.fill")
            }
            .tag(2)
        }
        .onChange(of: personaManager.personas.count) { oldCount, newCount in
            // First persona just created — land on the Personas tab
            if oldCount == 0 && newCount == 1 {
                selectedTab = 3
            }
        }
        .sheet(isPresented: $showPersonaSheet) {
            NavigationStack {
                PersonasTabView(personaManager: personaManager, showPersonaSheet: $showPersonaSheet)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showPersonaSheet = false }
                        }
                    }
            }
        }
        .sheet(isPresented: Binding(get: { incomingProposedPersonaToken != nil },
                                     set: { if !$0 { incomingProposedPersonaToken = nil } })) {
            ProposedPersonaReviewView(tokenString: incomingProposedPersonaToken!)
                .environmentObject(personaManager)
        }
        .onOpenURL { url in
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  components.scheme == "signator",
                  components.host == "proposed-persona",
                  let tokenValue = components.queryItems?.first(where: { (item: URLQueryItem) in item.name == "token" })?.value,
                  !tokenValue.isEmpty else { return }
            incomingProposedPersonaToken = tokenValue
        }
    }
}

// MARK: - Persona Button Component
struct PersonaButton: View {
    @ObservedObject var personaManager: PersonaManager
    @Binding var showPersonaSheet: Bool
    
    var body: some View {
        Button {
            showPersonaSheet = true
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.title3)
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Manage Persona")
    }
}

// MARK: - Reusable Name & Publisher Display Component
struct NameAndPublisherView: View {
    let name: String
    let publisher: String?
    let nameFont: Font
    let publisherFont: Font
    
    init(name: String, publisher: String?, nameFont: Font = .headline, publisherFont: Font = .subheadline) {
        self.name = name
        self.publisher = publisher
        self.nameFont = nameFont
        self.publisherFont = publisherFont
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Name (no label chip)
            Text(name)
                .font(nameFont)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Publisher: sphere chip + text (if available)
            if let publisher = publisher, !publisher.isEmpty {
                atSymbolChip
                Text(publisher)
                    .font(publisherFont)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
    }
    
    private var atSymbolChip: some View {
        ZStack {
            // Rounded background
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.blue.opacity(0.15))
                .frame(width: 24, height: 24)
            
            // Blue sphere representing "@"
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 10, height: 10)
        }
    }
}

// MARK: - Publisher Extraction Utilities
extension Persona {
    /// Extract publisher name from handle or affiliations
    /// Example: "larry.long.long-publishing.451.info" -> "Long Publishing"
    var publisher: String? {
        // Try to extract from affiliations first
        if let affiliations = self.affiliations, !affiliations.isEmpty {
            return affiliations
        }
        
        // Try to extract from handle (e.g., "larry.long.long-publishing.451.info")
        let components = handle.split(separator: ".")
        
        // Look for publisher component (typically the 3rd component in pattern: firstname.lastname.publisher.domain.tld)
        if components.count >= 3 {
            let publisherComponent = components[2]
            
            // Convert "long-publishing" to "Long Publishing"
            let formatted = String(publisherComponent)
                .replacingOccurrences(of: "-", with: " ")
                .split(separator: " ")
                .map { $0.capitalized }
                .joined(separator: " ")
            
            return formatted.isEmpty ? nil : formatted
        }
        
        return nil
    }
}

extension PersonaResolvedProfile {
    /// Extract publisher name from handle
    /// Example: "larry.long.long-publishing.451.info" -> "Long Publishing"
    var publisher: String? {
        guard let handle = self.handle else { return nil }
        
        // Try to extract from handle (e.g., "larry.long.long-publishing.451.info")
        let components = handle.split(separator: ".")
        
        // Look for publisher component (typically the 3rd component in pattern: firstname.lastname.publisher.domain.tld)
        if components.count >= 3 {
            let publisherComponent = components[2]
            
            // Convert "long-publishing" to "Long Publishing"
            let formatted = String(publisherComponent)
                .replacingOccurrences(of: "-", with: " ")
                .split(separator: " ")
                .map { $0.capitalized }
                .joined(separator: " ")
            
            return formatted.isEmpty ? nil : formatted
        }
        
        return nil
    }
}



// MARK: - Persona Sheet View
struct PersonaSheetView: View {
    @ObservedObject var personaManager: PersonaManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if let persona = personaManager.activePersona() {
                    EditPersonaView(personaManager: personaManager, persona: persona)
                } else {
                    // No persona exists - show welcome onboarding with two paths
                    WelcomeOnboardingView(personaManager: personaManager)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") {
                                    dismiss()
                                }
                            }
                        }
                }
            }
        }
    }
}

struct SignRequest: Identifiable, Hashable {
    enum Status { case pending, signed, finalized }
    let id: String
    let title: String
    let subtitle: String
    let status: Status
    let documentId: String
    let pendingDocument: PendingDocument?
    
    init(id: String, title: String, subtitle: String, status: Status, documentId: String = "", pendingDocument: PendingDocument? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.documentId = documentId
        self.pendingDocument = pendingDocument
    }
    
    // Custom Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(subtitle)
        hasher.combine(status)
        hasher.combine(documentId)
        // Exclude pendingDocument from hashing
    }
    
    // Custom Equatable conformance
    static func == (lhs: SignRequest, rhs: SignRequest) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.subtitle == rhs.subtitle &&
        lhs.status == rhs.status &&
        lhs.documentId == rhs.documentId
        // Exclude pendingDocument from equality check
    }
}

struct SignRequestsView: View {
    @ObservedObject var personaManager: PersonaManager
    @Binding var showPersonaSheet: Bool
    @State private var requests: [SignRequest] = []
    @State private var showingHelp = false
    @State private var showingInstructions = false // Show onboarding instructions
    @State private var showServerSettings = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var requestsSentCount: Int = 0

    @State private var accessCode: String = ""
    @State private var accessCodeError: String? = nil
    @State private var isResolvingAccessCode: Bool = false
    
    // Check if user has no persona
    private var hasNoPersona: Bool {
        let isEmpty = personaManager.personas.isEmpty
        print("🔍 [SignRequestsView] hasNoPersona check: \(isEmpty), persona count: \(personaManager.personas.count)")
        return isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Signator Dashboard")
                        .font(.title3).bold()
                    Text("Pending items and quick actions in one place")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    // Refresh button
                    Button(action: { 
                        Task { await loadPendingDocuments() }
                    }) {
                        Image(systemName: isLoading ? "arrow.clockwise.circle.fill" : "arrow.clockwise")
                            .font(.title3)
                            .foregroundColor(isLoading ? .blue : .primary)
                            .rotationEffect(.degrees(isLoading ? 360 : 0))
                            .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                    
                    Button(action: { showingInstructions = true }) {
                        Image(systemName: "info.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    Button(action: { showPersonaSheet = true }) {
                        Image(systemName: "person.crop.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.gray.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            
            Divider()
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .opacity(0.4)
            
    
            
            if hasNoPersona {
                // Show "no persona" state with server settings access
                NoPersonaView(
                    showPersonaSheet: $showPersonaSheet,
                    showServerSettings: $showServerSettings
                )
                .onAppear {
                    print("✅ [SignRequestsView] NoPersonaView appeared")
                }
            } else if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading pending signatures...")
                    Spacer()
                }
                .padding()
            } else {
                dashboardAndListView
                    .padding(.top, 12)
            }
            Spacer()
        }
        .padding(.horizontal)
        .background(Color.white.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: InitiatedSigningStore.didUpdateNotification)) { _ in
            requestsSentCount = InitiatedSigningStore.shared.load().count
        }
        .sheet(isPresented: $showingInstructions) {
            NavigationStack {
                InstructionsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showingInstructions = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingHelp) {
            NavigationStack {
                SignRequestsHelpView()
            }
        }
        .sheet(isPresented: $showServerSettings) {
            NavigationStack {
                ServerSettingsView()
            }
        }
        .task {
            // Load documents when view appears
            await loadPendingDocuments()
        }
        .refreshable {
            // Pull to refresh support
            await loadPendingDocuments()
        }
    }

    private var dashboardAndListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                pendingSummaryCard
                quickActionsCard
                activityCard

                if !requests.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(requests) { req in
                            SignRequestGlassRow(request: req, personaManager: personaManager)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var pendingSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Ready for you to sign", systemImage: "tray")
                    .font(.headline)
                Spacer()
                Text("\(requests.count)")
                    .font(.headline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Capsule())
            }

            if requests.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No requests yet")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("You're ready to sign as soon as something arrives.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }

            if let error = errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Connection Issue")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        Task { await loadPendingDocuments() }
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.platformGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }

    private var quickActionsCard: some View {
        let quickActions: [QuickActionItem] = [
            QuickActionItem(
                title: "Sign in with Signator",
                subtitle: "Authenticate to any Signator-enabled service",
                systemImage: "person.badge.shield.checkmark.fill",
                imageName: "DigitalLock",
                destination: .signatorSignIn
            ),
            QuickActionItem(
                title: "Request Institution Access",
                subtitle: "Apply for a role credential at a healthcare institution",
                systemImage: "building.2.crop.circle.fill",
                imageName: nil,
                destination: .requestInstitutionAccess
            ),
            QuickActionItem(
                title: "Sign a Document",
                subtitle: "Send a document for signatures",
                systemImage: "doc.text",
                imageName: "SignDocument",
                destination: .signDocument
            ),
            QuickActionItem(
                title: "Capture Witness Video",
                subtitle: "Record a witness statement for the record",
                systemImage: "video.fill",
                imageName: "Protest2",
                destination: .captureWitnessVideo
            ),
            QuickActionItem(
                title: "Document Presence of Machinery or Real Property",
                subtitle: "Capture evidence of on-site assets",
                systemImage: "building.2",
                imageName: "machine",
                destination: .placeholder("Document Presence of Machinery or Real Property")
            ),
            QuickActionItem(
                title: "Acknowledge Receipt of Valuable",
                subtitle: "Confirm receipt of high-value items",
                systemImage: "shippingbox.fill",
                imageName: "Diamonds",
                destination: .placeholder("Acknowledge Receipt of Valuable")
            ),
            QuickActionItem(
                title: "Sign and Submit Credentials",
                subtitle: "Submit verified professional credentials",
                systemImage: "doc.badge.gearshape",
                imageName: "Diploma",
                destination: .placeholder("Sign and Submit Credentials")
            ),
            QuickActionItem(
                title: "Sign Consent / Assent Form",
                subtitle: "Collect consent and assent signatures",
                systemImage: "checklist",
                imageName: "Consent",
                destination: .placeholder("Sign Consent / Assent Form")
            ),
            QuickActionItem(
                title: "Acknowledge Receipt of Medical Records",
                subtitle: "Confirm medical record delivery",
                systemImage: "heart.text.square",
                imageName: "Xray",
                destination: .placeholder("Acknowledge Receipt of Medical Records")
            ),
            QuickActionItem(
                title: "Notarize a Document",
                subtitle: "Record and notarize a verifiable event",
                systemImage: "checkmark.seal",
                imageName: "Notary",
                destination: .notarizeEvent
            ),
            QuickActionItem(
                title: "Acknowledge that an Event Occurred",
                subtitle: "Create a verified event record",
                systemImage: "calendar.badge.checkmark",
                imageName: "Acknowledge",
                destination: .placeholder("Acknowledge that an Event Occurred")
            ),
            QuickActionItem(
                title: "Validate a Human Signed a Document",
                subtitle: "Confirm the signer and signature",
                systemImage: "person.text.rectangle",
                imageName: "DocumentSign",
                destination: .placeholder("Validate a Human Signed a Document")
            ),
            QuickActionItem(
                title: "Validate that a Person Appeared at a Time and Location",
                subtitle: "Capture presence with time and place",
                systemImage: "location.fill",
                imageName: "PeopleTalking",
                destination: .placeholder("Validate that a Person Appeared at a Time and Location")
            ),
            QuickActionItem(
                title: "Sign a Completion of Milestones",
                subtitle: "Certify milestones are complete",
                systemImage: "flag.checkered",
                imageName: "Milestone",
                destination: .placeholder("Sign a Completion of Milestones")
            ),
            QuickActionItem(
                title: "Sign a Milestone as an Independent Third Party",
                subtitle: "Provide third-party milestone validation",
                systemImage: "person.2.badge.checkmark",
                imageName: "ThirdPartyValidation",
                destination: .placeholder("Sign a Milestone as an Independent Third Party")
            ),
            QuickActionItem(
                title: "Validate Credentials of Professional",
                subtitle: "Third-party credential validation",
                systemImage: "person.crop.circle.badge.checkmark",
                imageName: "ValidateCredentials",
                destination: .placeholder("Validate Credentials of Professional")
            ),
            QuickActionItem(
                title: "Start from a Template",
                subtitle: "Build from a reusable template",
                systemImage: "square.grid.2x2",
                imageName: "Templates",
                destination: .template
            )
        ]

        return VStack(alignment: .leading, spacing: 12) {
            Label("Quick Actions", systemImage: "bolt.fill")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 0) {
                ForEach(quickActions) { item in
                    quickActionListRow(for: item)

                    if item.id != quickActions.last?.id {
                        Divider()
                    }
                }
            }
            .background(Color.platformSecondaryGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.platformGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }

    private var activityCard: some View {
        let signedCount = requests.filter { $0.status != .pending }.count
        return VStack(alignment: .leading, spacing: 10) {
            Label("Your Activity", systemImage: "chart.bar")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                activityRow(label: "Documents signed", value: "\(signedCount)")
                activityRow(label: "Requests sent", value: "\(requestsSentCount)")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.platformGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }

    private enum QuickActionDestination {
        case signatorSignIn
        case requestInstitutionAccess
        case signDocument
        case template
        case notarizeEvent
        case captureWitnessVideo
        case placeholder(String)
    }

    private struct QuickActionItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let systemImage: String
        let imageName: String?
        let destination: QuickActionDestination
    }

    @ViewBuilder
    private func quickActionDestination(for item: QuickActionItem) -> some View {
        switch item.destination {
        case .signatorSignIn:
            SignatorSignInInitiatorView()
                .environmentObject(personaManager)
        case .requestInstitutionAccess:
            RequestInstitutionAccessView()
                .environmentObject(personaManager)
        case .signDocument:
            SendSigningFlowView(personaManager: personaManager)
        case .template:
            TemplateSelectionFlowView(personaManager: personaManager)
        case .notarizeEvent:
            NotarizeEventFlowView(personaManager: personaManager)
        case .captureWitnessVideo:
            QuickActionMediaCaptureView(title: "Capture Witness Video")
        case .placeholder(let title):
            QuickActionPlaceholderView(title: title)
        }
    }

    private func quickActionListRow(for item: QuickActionItem) -> some View {
        NavigationLink {
            quickActionDestination(for: item)
        } label: {
            HStack(spacing: 12) {
                quickActionThumbnail(for: item)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(item.subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 147)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func quickActionThumbnail(for item: QuickActionItem) -> some View {
        ZStack {
            if let imageName = item.imageName, let image = loadImage(named: imageName) {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: item.systemImage)
                    .foregroundColor(.blue)
                    .font(.system(size: 22, weight: .semibold))
            }
        }
        .frame(width: 75, height: 132)
        .background(Color.blue.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
        )
    }

    private func loadImage(named name: String) -> PlatformImage? {
        return PlatformImage.named(name)
    }

    private struct QuickActionPlaceholderView: View {
        let title: String

        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.secondary)

                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("This workflow is being prepared. We'll add the full experience soon.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(24)
            .navigationTitle(title)
            .inlineNavigationTitle()
        }
    }

    @ViewBuilder
    private func activityRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 2)
    }
    
    private func loadPendingDocuments() async {
        let requestID = RequestIDGenerator.generate()

        ClientLogger.info(component: LogComponent.signRequestsView, "Starting loadPendingDocuments()", requestID: requestID)

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        defer {
            Task { @MainActor in
                isLoading = false
                ClientLogger.info(component: LogComponent.signRequestsView, "Finished loadPendingDocuments()", requestID: requestID)
            }
        }

        let personas = personaManager.personas
        ClientLogger.info(component: LogComponent.signRequestsView, "Found \(personas.count) persona(s)", requestID: requestID)

        guard !personas.isEmpty else {
            await MainActor.run {
                requests = []
                errorMessage = "No personas found. Please create a persona first."
            }
            ClientLogger.warning(component: LogComponent.signRequestsView, "No personas available - aborting", requestID: requestID)
            return
        }

        // Fetch pending for each persona and aggregate
        var aggregated: [SignRequest] = []

        for persona in personas {
            ClientLogger.info(component: LogComponent.signRequestsView, "🔐 Loading key and querying pending for persona: \(persona.name) | DID: \(persona.id)", requestID: requestID)
            do {
                // Load private key for this persona to sign the search request
                let privateKey = try PrivateKeyStore.loadPrivateKey(for: persona.id)
                let response = try await PendingSignaturesService.fetchPending(
                    personaDID: persona.id,
                    query: "",
                    privateKey: privateKey,
                    baseURLString: ServerConfig.baseURL
                )
                ClientLogger.info(component: LogComponent.signRequestsView, "📥 Persona \(persona.name) has \(response.pendingCount) pending", requestID: requestID)

                // Map response documents into SignRequest rows
                let rows: [SignRequest] = response.documents.map { doc in
                    let title = (doc.title?.isEmpty == false ? doc.title! : "Document")
                    let subtitle = "Signatures: \(doc.currentSignatureCount)/\(doc.requiredSignatures)"
                    return SignRequest(
                        id: doc.documentDID,
                        title: title,
                        subtitle: subtitle,
                        status: .pending,
                        documentId: doc.documentDID,
                        pendingDocument: doc
                    )
                }
                aggregated.append(contentsOf: rows)
            } catch {
                ClientLogger.error(component: LogComponent.signRequestsView, "❌ Failed pending fetch for persona \(persona.id): \(error.localizedDescription)", requestID: requestID)
                // Keep going for other personas; surface a general error if all fail
            }
        }

        await MainActor.run {
            self.requests = aggregated
            self.requestsSentCount = InitiatedSigningStore.shared.load().count
            if aggregated.isEmpty {
                // Optional: Set a gentle message if nothing is pending
                self.errorMessage = nil
            }
            ClientLogger.info(component: LogComponent.signRequestsView, "✅ Updated UI with \(self.requests.count) request(s)", requestID: requestID)
        }
    }
    
    private func resolveAccessCodeFormat(_ code: String) -> Bool {
        let dashless = code.replacingOccurrences(of: "-", with: "").uppercased()
        guard dashless.count == 7 else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return dashless.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
    
    private func resolveAccessCodeDestination(code: String) async throws {
        // TODO: Hook into your existing access code flow. For now, simulate success.
        try await Task.sleep(nanoseconds: 400_000_000)
    }
    
    private func resolveAccessCode() async {
        await MainActor.run {
            isResolvingAccessCode = true
            accessCodeError = nil
        }
        defer { Task { await MainActor.run { isResolvingAccessCode = false } } }
        let code = accessCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard resolveAccessCodeFormat(code) else {
            await MainActor.run { accessCodeError = "Invalid code format. Use ABC-1234." }
            return
        }
        do {
            try await resolveAccessCodeDestination(code: code)
            await MainActor.run {
                accessCode = ""
            }
        } catch {
            await MainActor.run { accessCodeError = error.localizedDescription }
        }
    }
    
    /// Client-side logging helper - always prints to console
    private func clientLog(_ message: String) {
        print(message)
    }
}

// New helper view for glass card style rows with sheet support
struct SignRequestGlassRow: View {
    let request: SignRequest
    @ObservedObject var personaManager: PersonaManager
    @State private var showingSigningSheet = false

    private var color: Color {
        switch request.status {
        case .pending: return .blue
        case .signed: return .orange
        case .finalized: return .green
        }
    }

    private var iconName: String {
        switch request.status {
        case .pending: return "pencil"
        case .signed: return "checkmark.circle.fill"
        case .finalized: return "checkmark.seal.fill"
        }
    }

    var body: some View {
        Button { showingSigningSheet = true } label: {
            GlassCardView(
                title: request.title,
                subtitle: request.subtitle,
                color: color,
                systemImage: iconName
            ) { EmptyView() }
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSigningSheet) {
            SignDocumentView(documentDID: request.documentId, documentHash: request.pendingDocument?.documentHash, personaManager: personaManager)
        }
    }
}

struct SignRequestRow: View {
    let request: SignRequest
    @ObservedObject var personaManager: PersonaManager
    @State private var showingSigningSheet = false

    private var color: Color {
        switch request.status {
        case .pending: return .blue
        case .signed: return .orange
        case .finalized: return .green
        }
    }

    private var iconName: String {
        switch request.status {
        case .pending: return "pencil.and.outline"
        case .signed: return "checkmark.circle.fill"
        case .finalized: return "checkmark.seal.fill"
        }
    }
    
    private var statusText: String {
        switch request.status {
        case .pending: return "Pending"
        case .signed: return "Signed"
        case .finalized: return "Finalized"
        }
    }

    var body: some View {
        Button {
            showingSigningSheet = true
        } label: {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: iconName)
                        .foregroundColor(color)
                        .font(.system(size: 20, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(request.subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                    Text(statusText)
                        .font(.caption2)
                        .foregroundColor(color)
                }
                
                // Chevron to indicate it's tappable
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(color.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(color.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSigningSheet) {
            SignDocumentView(documentDID: request.documentId, documentHash: request.pendingDocument?.documentHash, personaManager: personaManager)
        }
    }
}

struct SignDocumentView: View {
    let documentDID: String
    let documentHash: String?
    @ObservedObject var personaManager: PersonaManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPersonaDID: String? = nil
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Document") {
                    LabeledContent("Document DID", value: documentDID)
                        .textSelection(.enabled)
                }

                Section("Sign As") {
                    if personaManager.personas.isEmpty {
                        Text("No personas available. Please create a persona first.")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Select Persona", selection: $selectedPersonaDID) {
                            Text("Choose a persona...").tag(nil as String?)
                            ForEach(personaManager.personas, id: \.id) { persona in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(persona.name)
                                        if let publisher = persona.publisher {
                                            Text("@ \(publisher)")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Text(persona.id)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .tag(persona.id as String?)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        Task { await submitSignature() }
                    } label: {
                        HStack { Spacer(); isSubmitting ? AnyView(ProgressView()) : AnyView(Label("Sign", systemImage: "signature")); Spacer() }
                    }
                    .disabled(selectedPersonaDID == nil || isSubmitting)
                }

                if let errorMessage { Section { Text(errorMessage).foregroundColor(.red).font(.caption) } }
                if let successMessage { Section { Text(successMessage).foregroundColor(.green).font(.caption) } }
            }
            .navigationTitle("Sign Document")
            .inlineNavigationTitle()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private func submitSignature() async {
        guard let did = selectedPersonaDID,
              let persona = personaManager.personas.first(where: { $0.id == did }) else { return }
        await MainActor.run { isSubmitting = true; errorMessage = nil; successMessage = nil }
        defer { Task { await MainActor.run { isSubmitting = false } } }

        do {
            // The server should validate against the authoritative document hash.
            // We sign a canonical message for auth if desired; otherwise just submit the signature blob over doc hash.
            // Here we sign the document DID + timestamp as a simple proof of possession (adjust if server expects different input).
            let timestamp = ISO8601DateFormatter().string(from: Date())
            // Prefer signing the document hash when available (distributed path)
            let message: String
            if let hash = documentHash, !hash.isEmpty {
                message = hash
            } else {
                message = "\(documentDID)|\(did)|\(timestamp)"
            }
            let privateKey = try PrivateKeyStore.loadPrivateKey(for: did)
            let signature = try privateKey.signature(for: Data(message.utf8))
            let signatureB64 = Data(signature.derRepresentation).base64EncodedString()

            _ = try await DocumentSignatureService.submitSignature(
                documentDID: documentDID,
                signerPersonaDID: did,
                signatureBase64: signatureB64,
                signatureType: "P256-ES256",
                timestamp: timestamp,
                documentHash: documentHash,
                baseURLString: ServerConfig.baseURL
            )

            await MainActor.run { successMessage = "Signature submitted." }
            try? await Task.sleep(nanoseconds: 900_000_000)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

struct SignRequestsHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Signing Requests")
                        .font(.headline)
                    Text("When someone requests your signature on a document, it will appear here. You can review the document and choose which persona to sign with.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Access Codes")
                        .font(.headline)
                    Text("If someone shares a document access code with you (like '451-7892'), tap the # button at the top to enter it and access the document directly.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pending vs. Signed")
                        .font(.headline)
                    Text("Pending requests are shown with a blue indicator. Once you've signed, they'll be marked with an orange indicator. When the document is finalized, it turns green.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Security")
                        .font(.headline)
                    Text("All signatures are cryptographically secure and verifiable. Your private keys never leave your device.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("About Signing")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

struct ContactsView: View {
    @ObservedObject var personaManager: PersonaManager
    @Binding var showPersonaSheet: Bool
    @State private var resolver: PersonaResolver? = nil
    @State private var searchText: String = ""
    @State private var showingHelp = false
    @State private var searchResults: [PersonaResolvedProfile] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var showSearchResultsSheet = false
    @State private var selectedProfiles: Set<String> = [] // DIDs of selected profiles
    @State private var searchError: String? = nil
    @State private var lastSearchQuery: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Glass card header matching other tabs
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Signator Colleagues")
                        .font(.title3).bold()
                    Text("Search directory to add contacts")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button(action: { showingHelp = true }) {
                        Image(systemName: "info.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    Button(action: { showPersonaSheet = true }) {
                        Image(systemName: "person.crop.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.gray.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            
            Divider()
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .opacity(0.4)
            
            // Search box
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search by name, DID, or code...", text: $searchText)
                        .textFieldStyle(.plain)
                        .platformAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if !searchText.isEmpty {
                        Button {
                            ClientLogger.info(component: LogComponent.contactsView, "User cleared search")
                            searchText = ""
                            searchResults = []
                            showSearchResultsSheet = false
                            searchError = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Search status/error message
                if let error = searchError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                        Button("Retry") {
                            if !lastSearchQuery.isEmpty {
                                Task {
                                    await performServerSearch(query: lastSearchQuery)
                                }
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                } else if isSearching {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Searching directory...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .onChange(of: searchText) { newValue in
                ClientLogger.debug(component: LogComponent.contactsView, "Search text changed: '\(newValue)'")
                
                searchTask?.cancel()
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Clear error when user starts typing again
                if searchError != nil && !trimmed.isEmpty {
                    searchError = nil
                }
                
                guard !trimmed.isEmpty, trimmed.count >= 2 else {
                    ClientLogger.debug(component: LogComponent.contactsView, "Search text too short or empty, clearing results")
                    searchResults = []
                    showSearchResultsSheet = false
                    searchError = nil
                    return
                }
                
                ClientLogger.debug(component: LogComponent.contactsView, "Scheduling search with 300ms debounce for: '\(trimmed)'")
                
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                    if Task.isCancelled {
                        ClientLogger.debug(component: LogComponent.contactsView, "Search task cancelled for: '\(trimmed)'")
                        return
                    }
                    await performServerSearch(query: trimmed)
                }
            }
            
            // Contacts list - always show saved contacts (no filtering)
            if let resolver {
                CollaboratorsListView(
                    store: .shared,
                    personaManager: personaManager,
                    resolver: resolver,
                    mode: .manage,
                    searchText: "" // Don't filter - search is for adding new contacts
                )
                .padding(.horizontal, 20)
            } else {
                Text("Loading…")
                    .padding(.leading, 20)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .background(Color.white.ignoresSafeArea())
        .sheet(isPresented: $showingHelp) {
            NavigationStack {
                ContactsHelpView()
            }
        }
        .sheet(isPresented: $showSearchResultsSheet) {
            SearchResultsSheet(
                searchQuery: searchText,
                searchResults: searchResults,
                selectedProfiles: $selectedProfiles,
                onAdd: {
                    let requestID = RequestIDGenerator.generate()
                    ClientLogger.info(component: LogComponent.contactsView, "Adding selected contacts to store", requestID: requestID)
                    
                    // Add all selected profiles to contacts
                    var addedCount = 0
                    for profile in searchResults where selectedProfiles.contains(profile.did) {
                        ClientLogger.debug(component: LogComponent.contactsView, "Adding contact: \(profile.displayName) (\(profile.did))", requestID: requestID)
                        CollaboratorsStore.shared.add(profile)
                        addedCount += 1
                    }
                    
                    ClientLogger.info(component: LogComponent.contactsView, "✅ Added \(addedCount) contact(s)", requestID: requestID)
                    
                    // Clear selection and close
                    selectedProfiles.removeAll()
                    showSearchResultsSheet = false
                    searchText = ""
                    searchResults = []
                }
            )
        }
        .onAppear {
            ClientLogger.info(component: LogComponent.contactsView, "ContactsView appeared")
            if resolver == nil {
                ClientLogger.info(component: LogComponent.contactsView, "Initializing PersonaResolver with baseURL: \(ServerConfig.baseURL)")
                resolver = PersonaResolver(baseURLString: ServerConfig.baseURL, personaManager: personaManager)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func performServerSearch(query: String) async {
        let requestID = RequestIDGenerator.generate()
        
        ClientLogger.info(component: LogComponent.contactsView, "🔍 Starting search", requestID: requestID)
        ClientLogger.info(component: LogComponent.contactsView, "Query: '\(query)'", requestID: requestID)
        
        guard let resolver = resolver else {
            ClientLogger.error(component: LogComponent.contactsView, "PersonaResolver not initialized", requestID: requestID)
            await MainActor.run {
                searchError = "Search service not available"
            }
            return
        }
        
        await MainActor.run {
            isSearching = true
            searchError = nil
            lastSearchQuery = query
        }
        
        defer {
            Task { @MainActor in
                isSearching = false
                ClientLogger.info(component: LogComponent.contactsView, "Search completed", requestID: requestID)
            }
        }
        
        do {
            ClientLogger.info(component: LogComponent.contactsView, "📤 Calling resolver.searchWithParams()", requestID: requestID)
            ClientLogger.debug(component: LogComponent.contactsView, "Parameters: limit=20, publicOnly=false (search all personas)", requestID: requestID)
            
            // Search the server directory for both public and private personas
            // Private personas can be searched by their contacts/collaborators
            let results = try await resolver.searchWithParams(
                query: query,
                limit: 20,
                offset: nil,
                publicOnly: false,  // Allow searching for both public and private personas
                waitForIndexing: nil
            )
            
            ClientLogger.info(component: LogComponent.contactsView, "📥 Received \(results.count) result(s) from server", requestID: requestID)
            
            // Log each result for debugging
            for (index, profile) in results.enumerated() {
                ClientLogger.debug(component: LogComponent.contactsView, "Result[\(index)]: \(profile.displayName) | DID: \(profile.did)", requestID: requestID)
                if let shortId = profile.shortId {
                    ClientLogger.debug(component: LogComponent.contactsView, "  └─ Short ID: \(shortId)", requestID: requestID)
                }
            }
            
            // Filter out results that are already in saved contacts
            let savedDIDs = Set(CollaboratorsStore.shared.collaborators.map { $0.did.lowercased() })
            ClientLogger.debug(component: LogComponent.contactsView, "Filtering against \(savedDIDs.count) saved contact(s)", requestID: requestID)
            
            let newResults = results.filter { !savedDIDs.contains($0.did.lowercased()) }
            
            let filteredCount = results.count - newResults.count
            if filteredCount > 0 {
                ClientLogger.info(component: LogComponent.contactsView, "Filtered out \(filteredCount) already-saved contact(s)", requestID: requestID)
            }
            
            ClientLogger.info(component: LogComponent.contactsView, "✅ Showing \(newResults.count) new result(s)", requestID: requestID)
            
            await MainActor.run {
                searchResults = newResults
                searchError = nil
                
                // Show sheet if we have results
                if !newResults.isEmpty {
                    ClientLogger.info(component: LogComponent.contactsView, "Opening search results sheet", requestID: requestID)
                    showSearchResultsSheet = true
                } else if results.isEmpty {
                    // No results at all from server
                    ClientLogger.info(component: LogComponent.contactsView, "No results found on server", requestID: requestID)
                    searchError = "No matches found for '\(query)'"
                } else {
                    // Had results but all were filtered
                    ClientLogger.info(component: LogComponent.contactsView, "All results were already in contacts", requestID: requestID)
                    searchError = "All matches are already in your contacts"
                }
            }
        } catch {
            ClientLogger.error(component: LogComponent.contactsView, "❌ Search failed: \(error.localizedDescription)", requestID: requestID)
            ClientLogger.error(component: LogComponent.contactsView, "Error type: \(type(of: error))", requestID: requestID)
            
            if let urlError = error as? URLError {
                ClientLogger.error(component: LogComponent.contactsView, "URLError code: \(urlError.code.rawValue)", requestID: requestID)
            }
            
            await MainActor.run {
                searchResults = []
                searchError = "Search failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Search Results Sheet

struct SearchResultsSheet: View {
    let searchQuery: String
    let searchResults: [PersonaResolvedProfile]
    @Binding var selectedProfiles: Set<String>
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.platformGroupedBackground
                    .ignoresSafeArea()
                
                if searchResults.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 56))
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text("No Results Found")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Try searching by name, DID, or short code")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Text("Query: '\(searchQuery)'")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .padding()
                } else {
                    // Results list
                    ScrollView {
                        VStack(spacing: 12) {
                            // Header with result count
                            HStack {
                                Text("\(searchResults.count) \(searchResults.count == 1 ? "Result" : "Results")")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if !selectedProfiles.isEmpty {
                                    Text("\(selectedProfiles.count) selected")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            
                            // Results
                            ForEach(searchResults, id: \.did) { profile in
                                SearchResultRow(
                                    profile: profile,
                                    isSelected: selectedProfiles.contains(profile.did),
                                    onToggle: {
                                        if selectedProfiles.contains(profile.did) {
                                            selectedProfiles.remove(profile.did)
                                            ClientLogger.debug(component: LogComponent.contactsView, "Deselected: \(profile.displayName)")
                                        } else {
                                            selectedProfiles.insert(profile.did)
                                            ClientLogger.debug(component: LogComponent.contactsView, "Selected: \(profile.displayName)")
                                        }
                                    }
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Search Results")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        ClientLogger.info(component: LogComponent.contactsView, "User cancelled search results")
                        selectedProfiles.removeAll()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add (\(selectedProfiles.count))") {
                        ClientLogger.info(component: LogComponent.contactsView, "Adding \(selectedProfiles.count) contact(s)")
                        onAdd()
                        dismiss()
                    }
                    .disabled(selectedProfiles.isEmpty)
                    .fontWeight(selectedProfiles.isEmpty ? .regular : .semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !selectedProfiles.isEmpty {
                    HStack(spacing: 12) {
                        // Selection summary
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                            Text("\(selectedProfiles.count) selected")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        // Clear button
                        Button {
                            ClientLogger.info(component: LogComponent.contactsView, "Cleared selection")
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedProfiles.removeAll()
                            }
                        } label: {
                            Text("Clear")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.gray.opacity(0.2)),
                        alignment: .top
                    )
                }
            }
        }
        .onAppear {
            ClientLogger.info(component: LogComponent.contactsView, "Search results sheet appeared with \(searchResults.count) result(s)")
        }
    }
}

struct SearchResultRow: View {
    let profile: PersonaResolvedProfile
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Selection indicator with animation
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.blue)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                
                // Profile icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.15), Color.blue.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Profile info
                VStack(alignment: .leading, spacing: 6) {
                    // Name and publisher with selection highlight
                    NameAndPublisherView(
                        name: profile.displayName,
                        publisher: profile.publisher,
                        nameFont: isSelected ? .body.weight(.semibold) : .body.weight(.medium),
                        publisherFont: .caption
                    )
                    .foregroundColor(isSelected ? .blue : .primary)
                    
                    // DID with monospace font
                    Text(profile.did)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    // Short ID badge if available
                    if let shortId = profile.shortId, !shortId.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "number")
                                .font(.system(size: 9))
                            Text(shortId)
                                .font(.system(.caption2, design: .monospaced))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(0.5)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.05) : Color.platformBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.15),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected ? Color.blue.opacity(0.1) : Color.clear,
                radius: isSelected ? 4 : 0,
                x: 0,
                y: 2
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct AddContactByIdentifierView: View {
    let resolver: PersonaResolver
    @Environment(\.dismiss) private var dismiss
    @State private var manualIdentifier: String = ""
    @State private var manualAddInFlight = false
    @State private var manualAddError: String? = nil
    @State private var visibilityPublicOnly: Bool = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Identifier") {
                    TextField("Enter DID, @handle, or short ID (ABC-1234)", text: $manualIdentifier)
                        .autocorrectionDisabled(true)
#if canImport(UIKit)
                        .platformAutocapitalization(.never)
#endif
                }
                Section("Search Scope") {
                    Picker("Visibility", selection: $visibilityPublicOnly) {
                        Text("Public").tag(true)
                        Text("All").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                if let err = manualAddError {
                    Section { 
                        Text(err).foregroundColor(.red) 
                    }
                }
            }
            .navigationTitle("Add Contact")
#if canImport(UIKit)
            .inlineNavigationTitle()
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { 
                    Button("Cancel") { 
                        dismiss()
                    } 
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(manualAddInFlight ? "Adding…" : "Add") {
                        Task { await addManualCollaborator() }
                    }
                    .disabled(manualIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manualAddInFlight)
                }
            }
        }
    }
    
    private func addManualCollaborator() async {
        let raw = manualIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        await MainActor.run { manualAddInFlight = true; manualAddError = nil }
        defer { Task { await MainActor.run { manualAddInFlight = false } } }
        do {
            // Try exact resolve first with short-code support
            let profile = try await resolver.resolveStringWithShortCodeSupport(raw)
            await MainActor.run {
                CollaboratorsStore.shared.add(profile)
                dismiss()
            }
        } catch {
            // If resolve fails, try broader search according to visibility toggle
            do {
                let hits = try await resolver.searchWithParams(query: raw, limit: 1, offset: nil, publicOnly: visibilityPublicOnly, waitForIndexing: nil)
                if let first = hits.first {
                    await MainActor.run {
                        CollaboratorsStore.shared.add(first)
                        dismiss()
                    }
                } else {
                    await MainActor.run { manualAddError = "No results found." }
                }
            } catch {
                await MainActor.run { manualAddError = error.localizedDescription }
            }
        }
    }
}

struct ContactsHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What are Contacts?")
                        .font(.headline)
                    Text("Contacts are people you work with regularly. Save them here to quickly add them when initiating signing requests.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Adding Contacts")
                        .font(.headline)
                    Text("• Tap the + button to add a new contact\n• Search the directory for public personas\n• Enter a DID, @handle, or 7-digit code directly")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Finding Anonymous Parties")
                        .font(.headline)
                    Text("If someone shares a 7-digit code with you (e.g., ABC-1234), you can add them as a contact even if they're not in the public directory.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("About Contacts")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}


// MARK: - Document Signing Detail View

struct DocumentSigningDetailView: View {
    let pendingDocument: DocumentSigningService.PendingDocument
    @ObservedObject var personaManager: PersonaManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPersonaDID: String?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                // Document Information
                Section("Document Details") {
                    LabeledContent("Title", value: pendingDocument.displayTitle)
                    LabeledContent("Uploaded By", value: pendingDocument.uploadedBy)
                    LabeledContent("Your Role", value: pendingDocument.requiredRole.rawValue.capitalized)
                    
                    if let uploadedAt = pendingDocument.uploadedAt {
                        LabeledContent("Uploaded", value: uploadedAt)
                    }
                    
                    if let accessCode = pendingDocument.formattedAccessCode {
                        LabeledContent("Access Code", value: accessCode)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                
                // Existing Signatures
                if !pendingDocument.existingSignatures.isEmpty {
                    Section("Existing Signatures (\(pendingDocument.existingSignatures.count))") {
                        ForEach(pendingDocument.existingSignatures, id: \.ledgerEntryID) { sig in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "signature")
                                        .foregroundColor(.blue)
                                    Text(sig.did)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(sig.role.capitalized)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                Text(sig.timestamp)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Persona Selection
                if pendingDocument.status == "pending" {
                    Section("Sign As") {
                        if personaManager.personas.isEmpty {
                            Text("No personas available. Please create a persona first.")
                                .foregroundColor(.secondary)
                        } else {
                            Picker("Select Persona", selection: $selectedPersonaDID) {
                                Text("Choose a persona...").tag(nil as String?)
                                ForEach(personaManager.personas, id: \.id) { persona in
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Text(persona.name)
                                            if let publisher = persona.publisher {
                                                Text("@ \(publisher)")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Text(persona.id)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .tag(persona.id as String?)
                                }
                            }
                        }
                    }
                    
                    // Sign Button
                    Section {
                        Button {
                            Task { await signDocument() }
                        } label: {
                            HStack {
                                Spacer()
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                } else {
                                    Image(systemName: "signature")
                                    Text("Sign Document")
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                        }
                        .disabled(selectedPersonaDID == nil || isProcessing)
                        .foregroundColor(selectedPersonaDID == nil ? .secondary : .blue)
                    }
                }
                
                // Status Messages
                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                if let success = successMessage {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(success)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("Sign Document")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func signDocument() async {
        let requestID = RequestIDGenerator.generate()
        
        ClientLogger.info(component: LogComponent.documentSigningDetail, "Starting signDocument()", requestID: requestID)
        ClientLogger.info(component: LogComponent.documentSigningDetail, "Document: \(pendingDocument.displayTitle)", requestID: requestID)
        ClientLogger.info(component: LogComponent.documentSigningDetail, "DocumentID: \(pendingDocument.documentId)", requestID: requestID)
        
        guard let selectedDID = selectedPersonaDID else {
            ClientLogger.warning(component: LogComponent.documentSigningDetail, "No persona selected", requestID: requestID)
            return
        }
        
        ClientLogger.info(component: LogComponent.documentSigningDetail, "Selected persona: \(selectedDID)", requestID: requestID)
        
        guard let persona = personaManager.personas.first(where: { $0.id == selectedDID }) else {
            await MainActor.run {
                errorMessage = "Selected persona not found"
            }
            ClientLogger.error(component: LogComponent.documentSigningDetail, "Selected persona not found in manager", requestID: requestID)
            return
        }
        
        await MainActor.run {
            isProcessing = true
            errorMessage = nil
            successMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
                ClientLogger.info(component: LogComponent.documentSigningDetail, "Finished signDocument()", requestID: requestID)
            }
        }
        
        do {
            ClientLogger.debug(component: LogComponent.documentSigningDetail, "Loading private key from keychain", requestID: requestID)
            // Get the persona's private key from the Keychain
            let privateKey = try PrivateKeyStore.loadPrivateKey(for: selectedDID)
            let publicKey = persona.publicKeyBase64
            
            ClientLogger.info(component: LogComponent.documentSigningDetail, "✅ Private key loaded successfully", requestID: requestID)
            ClientLogger.debug(component: LogComponent.documentSigningDetail, "Public key: \(publicKey.prefix(20))...", requestID: requestID)
            
            // Create document hash from the stored hash
            guard let documentHashData = Data(base64Encoded: pendingDocument.documentHash) else {
                ClientLogger.error(component: LogComponent.documentSigningDetail, "Invalid document hash encoding", requestID: requestID)
                throw DocumentSigningError.invalidDocumentId
            }
            
            ClientLogger.debug(component: LogComponent.documentSigningDetail, "Document hash decoded: \(documentHashData.base64EncodedString().prefix(20))...", requestID: requestID)
            
            // Determine previous entry ID (last signature or proof)
            let previousEntryID: String
            if let lastSig = pendingDocument.existingSignatures.last {
                previousEntryID = lastSig.ledgerEntryID
                ClientLogger.info(component: LogComponent.documentSigningDetail, "Chaining to last signature: \(previousEntryID)", requestID: requestID)
            } else {
                guard let proofEntryID = pendingDocument.ledgerProofEntryID else {
                    ClientLogger.error(component: LogComponent.documentSigningDetail, "Missing ledger proof entry ID", requestID: requestID)
                    throw DocumentSigningError.invalidDocumentId
                }
                previousEntryID = proofEntryID
                ClientLogger.info(component: LogComponent.documentSigningDetail, "Chaining to proof entry: \(previousEntryID)", requestID: requestID)
            }
            
            ClientLogger.info(component: LogComponent.documentSigningDetail, "Calling DocumentSigningService.addSignature()", requestID: requestID)
            ClientLogger.info(component: LogComponent.documentSigningDetail, "Role: \(pendingDocument.requiredRole.rawValue)", requestID: requestID)
            
            // Add signature via the service
            let response = try await DocumentSigningService.addSignature(
                documentId: pendingDocument.documentId,
                signerDID: selectedDID,
                signerPublicKey: publicKey,
                documentHash: documentHashData,
                privateKey: privateKey,
                role: pendingDocument.requiredRole,
                previousEntryID: previousEntryID
            )
            
            ClientLogger.info(component: LogComponent.documentSigningDetail, "✅ Signature added successfully", requestID: requestID)
            ClientLogger.info(component: LogComponent.documentSigningDetail, "Ledger entry ID: \(response.ledgerEntryID)", requestID: requestID)
            ClientLogger.info(component: LogComponent.documentSigningDetail, "Ledger index: \(response.ledgerIndex)", requestID: requestID)
            
            await MainActor.run {
                successMessage = "Document signed successfully!"
            }
            
            // Dismiss after a short delay
            ClientLogger.debug(component: LogComponent.documentSigningDetail, "Waiting 1.5s before dismissing...", requestID: requestID)
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            await MainActor.run {
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to sign: \(error.localizedDescription)"
            }
            ClientLogger.error(component: LogComponent.documentSigningDetail, "Error signing document: \(error)", requestID: requestID)
            ClientLogger.error(component: LogComponent.documentSigningDetail, "Error type: \(type(of: error))", requestID: requestID)
        }
    }
    
    /// Client-side logging helper
    private func clientLog(_ message: String) {
        print(message)
    }
}

// MARK: - No Persona Empty State View
struct NoPersonaView: View {
    @Binding var showPersonaSheet: Bool
    @Binding var showServerSettings: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 72))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("Create Your Persona")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("You'll need a persona to sign documents and receive signature requests.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                showPersonaSheet = true
            } label: {
                Text("Create Persona")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
            
            // Server configuration access (always visible during development)
            VStack(spacing: 12) {
                Divider()
                    .padding(.horizontal, 40)
                    .padding(.vertical, 8)
                
                VStack(spacing: 8) {
                    #if DEBUG
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Development Mode")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                    #endif
                    
                    Text("Current Server:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(ServerConfig.baseURL)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.blue)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    Button {
                        showServerSettings = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "server.rack")
                            Text("Change Server")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: 200)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.orange)
                        .cornerRadius(10)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.top, 16)
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Personas Tab View
struct PersonasTabView: View {
    @ObservedObject var personaManager: PersonaManager
    @Binding var showPersonaSheet: Bool
    @State private var showingHelp = false
    @State private var showServerSettings = false
    @State private var showingCreate = false
    @State private var showAcceptProposal = false
    @State private var showProposePersona = false
    @State private var editTarget: Persona? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Glass card header matching other tabs
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Personas")
                        .font(.title3).bold()
                    Text("Manage your identities and keys")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button(action: { showingHelp = true }) {
                        Image(systemName: "info.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showAcceptProposal = true }) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Accept a proposed persona")
                    
                    Button(action: { showingCreate = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.gray.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Proposed Personas")
                    .font(.headline)
                Text("Send a proposed persona to a client or accept one they sent you.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Button(action: { showProposePersona = true }) {
                    Label("Propose Persona for Client", systemImage: "person.crop.circle.badge.checkmark")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)

                Button(action: { showAcceptProposal = true }) {
                    Label("Accept Proposed Persona", systemImage: "person.crop.circle.badge.plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.platformBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 20)

            Divider()
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .opacity(0.4)
            
            // Personas List
            if personaManager.personas.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        Text("No Personas Yet")
                            .font(.headline)
                        Text("Create a persona to sign documents and manage your digital identity.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    Button {
                        showingCreate = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create Persona")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: 280)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(personaManager.personas, id: \.id) { persona in
                            PersonaRowView(
                                persona: persona,
                                isActive: personaManager.activePersona()?.id == persona.id,
                                onSelect: {
                                    personaManager.setActivePersona(persona)
                                },
                                onEdit: {
                                    editTarget = persona
                                },
                                onAddToContacts: {
                                    let profile = PersonaResolvedProfile(
                                        did: persona.id,
                                        handle: persona.handle,
                                        prettyDID: persona.displayName ?? persona.name,
                                        name: persona.displayName ?? persona.name
                                    )
                                    CollaboratorsStore.shared.add(profile)
                                    ClientLogger.info(
                                        component: LogComponent.contactsView,
                                        "Added persona to Friends/Colleagues: \(persona.id)"
                                    )
                                },
                                onDelete: {
                                    personaManager.deletePersona(persona)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    
                    // Server Configuration Section
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                            .padding(.vertical, 16)
                        
                        Text("Server Configuration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            #if DEBUG
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Development Mode")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }
                            #endif
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Server")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(ServerConfig.baseURL)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.blue)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Button {
                                showServerSettings = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "server.rack")
                                    Text("Change Server")
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.orange)
                                .cornerRadius(10)
                            }
                            .padding(.top, 4)
                        }
                        .padding()
                        .background(Color.platformBackground)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            
            Spacer()
        }
        .background(Color.platformGroupedBackground.ignoresSafeArea())
        .sheet(isPresented: $showingHelp) {
            NavigationStack {
                PersonasHelpView()
            }
        }
        .sheet(isPresented: $showServerSettings) {
            NavigationStack {
                ServerSettingsView()
            }
        }
        .sheet(isPresented: $showingCreate) {
            PersonaHandleWizardView()
                .environmentObject(personaManager)
        }
        .sheet(isPresented: $showAcceptProposal) {
            NavigationStack {
                ProposedPersonaEntryView()
                    .environmentObject(personaManager)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showAcceptProposal = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showProposePersona) {
            NavigationStack {
                CreateProposalForClientView()
                    .environmentObject(personaManager)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showProposePersona = false }
                        }
                    }
            }
        }
        .sheet(item: $editTarget, onDismiss: { editTarget = nil }) { persona in
            NavigationStack {
                PersonaEditView(personaManager: personaManager, persona: persona) { updated in
                    personaManager.updatePersona(updated)
                }
            }
        }
        .onChange(of: personaManager.dismissCreationFlow) { _, shouldDismiss in
            if shouldDismiss {
                showingCreate = false
                personaManager.dismissCreationFlow = false
            }
        }
    }
}

// MARK: - Persona Row View
struct PersonaRowView: View {
    let persona: Persona
    let isActive: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onAddToContacts: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteAlert = false
    
    private var displayName: String {
        if !persona.name.isEmpty { return persona.name }
        return persona.id
    }
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            personaRowContent
        }
        .buttonStyle(.plain)
        .alert("Delete Persona", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete '\(displayName)'? This action cannot be undone and will remove the persona's private key from the Secure Enclave.")
        }
    }
    
    // MARK: - Subviews
    
    private var personaRowContent: some View {
        HStack(spacing: 12) {
            iconView
            personaInfoView
            Spacer()
            actionsMenu
        }
        .padding(12)
        .background(rowBackground)
        .overlay(rowBorder)
    }
    
    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? Color.blue.opacity(0.12) : Color.gray.opacity(0.08))
                .frame(width: 50, height: 50)
            Image(systemName: isActive ? "person.crop.circle.fill" : "person.crop.circle")
                .foregroundColor(isActive ? .blue : .secondary)
                .font(.system(size: 24))
        }
    }
    
    private var personaInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Name and Publisher separated by blue sphere
            HStack(spacing: 8) {
                // Name part (from displayName field)
                if let displayName = persona.displayName {
                    Text(displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                } else {
                    // Fallback: try to extract from handle
                    Text(persona.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                // Blue sphere separator
                ZStack {
                    Circle()
                        .fill(persona.visibility == .public ? Color.blue : Color.purple)
                        .frame(width: 8, height: 8)
                        .shadow(color: (persona.visibility == .public ? Color.blue : Color.purple).opacity(0.5), radius: 4)
                    
                    Image(systemName: "at")
                        .font(.system(size: 4, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Publishing house part (from displayPublisher field)
                if let displayPublisher = persona.displayPublisher {
                    Text(displayPublisher)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                } else {
                    // Fallback: show handle
                    Text(persona.handle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Active indicator
            if isActive {
                activeIndicator
            }
        }
    }
    
    @ViewBuilder
    private var activeIndicator: some View {
        if isActive {
            Text("Active")
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.15))
                .foregroundColor(.green)
                .cornerRadius(12)
        }
    }
    
    private var actionsMenu: some View {
        Menu {
            if !isActive {
                Button {
                    onSelect()
                } label: {
                    Label("Set as Active", systemImage: "checkmark.circle")
                }
            }
            
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Button {
                onAddToContacts()
            } label: {
                Label("Add to Friends/Colleagues", systemImage: "person.badge.plus")
            }
            .disabled(isInContacts)
            
            Divider()
            
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundColor(.secondary)
        }
    }
    
    private var isInContacts: Bool {
        CollaboratorsStore.shared.contains(did: persona.id)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isActive ? Color.blue.opacity(0.05) : Color.platformBackground)
    }
    
    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(isActive ? Color.blue.opacity(0.3) : Color.gray.opacity(0.15), lineWidth: isActive ? 2 : 1)
    }
}

// MARK: - Personas Help View
struct PersonasHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What are Personas?")
                        .font(.headline)
                    Text("Personas are your digital identities. Each persona has its own cryptographic keys stored securely in the Secure Enclave. You can have multiple personas for different purposes.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Active Persona")
                        .font(.headline)
                    Text("The active persona is used by default when signing documents or receiving signature requests. Tap any persona to make it active.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Public vs. Private")
                        .font(.headline)
                    Text("Public personas are listed in the directory and can be found by others. Private personas are kept anonymous and can only be shared via your short code.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Security")
                        .font(.headline)
                    Text("Your private keys are stored in the Secure Enclave and never leave your device. Each persona has a unique key pair for signing documents.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Short Code")
                        .font(.headline)
                    Text("Each persona has a unique 7-character code (like ABC-1234) that others can use to find and add you, even if your persona is private.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("About Personas")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Settings List View
struct SettingsListView: View {
    @ObservedObject var personaManager: PersonaManager
    @Binding var showPersonaSheet: Bool
    @State private var showServerSettings = false
    @State private var showingHelp = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Glass card header matching other tabs
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.title3).bold()
                    Text("Manage your account and preferences")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button(action: { showingHelp = true }) {
                        Image(systemName: "info.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.gray.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            
            Divider()
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .opacity(0.4)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Account Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Account")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 20)
                        
                        Button {
                            showPersonaSheet = true
                        } label: {
                            HStack {
                                Label("Your Persona", systemImage: "person.crop.circle")
                                    .foregroundColor(.primary)
                                Spacer()
                                if let persona = personaManager.activePersona() {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        HStack(spacing: 6) {
                                            NameAndPublisherView(
                                                name: persona.name,
                                                publisher: persona.publisher,
                                                nameFont: .subheadline,
                                                publisherFont: .caption
                                            )
                                            .foregroundColor(.secondary)
                                            
                                            Text(persona.visibility == .public ? "Public" : "Private")
                                                .font(.caption2)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background((persona.visibility == .public ? Color.blue.opacity(0.15) : Color.gray.opacity(0.2)))
                                                .foregroundColor(persona.visibility == .public ? .blue : .gray)
                                                .cornerRadius(3)
                                        }
                                        Text(persona.shortIDPhoneStyle)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text("Not Created")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.platformBackground)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }
                    
                    #if DEBUG
                    // Development Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Development")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 20)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            NavigationLink {
                                ServerSettingsView()
                            } label: {
                                HStack {
                                    Label("Server Configuration", systemImage: "server.rack")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if ServerConfig.isUsingCustomServer {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Server")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(ServerConfig.baseURL)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                            
                            Text("Server settings are only available in debug builds. Use this to configure ngrok or other development servers.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                        }
                        .background(Color.platformBackground)
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                    }
                    #endif
                    
                    // About Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            HStack {
                                Text("Version")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            
                            Divider()
                                .padding(.leading, 20)
                            
                            HStack {
                                Text("Build")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .background(Color.platformBackground)
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 20)
            }
            
            Spacer()
        }
        .background(Color.platformGroupedBackground.ignoresSafeArea())
        .sheet(isPresented: $showingHelp) {
            NavigationStack {
                SettingsHelpView()
            }
        }
    }
}

// MARK: - Settings Help View
struct SettingsHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings Overview")
                        .font(.headline)
                    Text("Manage your account settings, view app information, and configure development options.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Persona")
                        .font(.headline)
                    Text("View and edit your persona information, including your name, visibility settings, and short ID code.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Development Settings")
                        .font(.headline)
                    Text("In debug builds, you can configure custom server URLs for testing and development purposes.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("About Settings")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

// Placeholder for SendView
/*
struct SendView: View {
    var body: some View {
        VStack(spacing: 40) {
            Image(systemName: "paperplane")
                .font(.system(size: 56))
                .foregroundColor(.blue)
            Text("Send Documents Placeholder")
                .font(.title2)
                .foregroundColor(.gray)
        }
        .navigationTitle("Send")
    }
}
*/
