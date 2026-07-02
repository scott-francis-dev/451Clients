import SwiftUI
import CryptoKit
import Core451

extension BlockchainBlock {
    var title: String {
        if let dict = data.value as? [String: CodableData] {
            if let t = dict["title"]?.value as? String {
                return t
            }
            if let n = dict["name"]?.value as? String {
                return n
            }
        } else if let str = data.value as? String {
            return str
        }
        return "Untitled"
    }
    var subtitle: String {
        if let dict = data.value as? [String: CodableData] {
            if let sub = dict["subtitle"]?.value as? String {
                return sub
            }
            if let desc = dict["description"]?.value as? String {
                return desc
            }
            if let address = dict["address"]?.value as? String {
                return address
            }
        }
        return "Type: \(type)"
    }
}

struct DocumentListView: View {
    let blocks: [BlockchainBlock]
    @State private var pendingDocuments: [DocumentSigningService.PendingDocument] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAccessCodeEntry = false
    @StateObject private var personaManager = PersonaManager()
    @State private var path = NavigationPath()
    
    var body: some View {
        let displayBlocks = blocks.isEmpty ? Self.testBlocks : blocks
        
        
        NavigationStack(path: $path) {
            
            
        VStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 16) {
                // Unified in-view header matching the Requests look
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Requests for Signatures")
                            .font(.title3).bold()
                        Text("Review and sign documents sent to you")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            showAccessCodeEntry = true
                        } label: {
                            Image(systemName: "key.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            // TODO: Add persona selection if needed
                        }) {
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
                
                ScrollView {
                    VStack(spacing: 16) {
                        
                        VStack(alignment: .leading, spacing: 16) {
                            // Show real pending documents if available
                            if !pendingDocuments.isEmpty {
                                
                                ForEach(pendingDocuments.filter { !$0.hasSigned && !$0.isFinalized }) { doc in
                                    NavigationLink(destination: RealDocumentSigningView(document: doc)) {
                                        GlassCardView(
                                            title: doc.displayTitle,
                                            subtitle: doc.displaySubtitle,
                                            color: .unsignedAccent,
                                            systemImage: "pencil"
                                        ) {
                                            EmptyView()
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                                
                                let signedDocs = pendingDocuments.filter { $0.hasSigned || $0.isFinalized }
                                if !signedDocs.isEmpty {
                                    Text("Signed Documents")
                                        .font(.title3).bold()
                                        .padding(.top, 8)
                                        .padding(.leading, 20)
                                    
                                    ForEach(signedDocs) { doc in
                                        NavigationLink(destination: RealDocumentSigningView(document: doc)) {
                                            GlassCardView(
                                                title: doc.displayTitle,
                                                subtitle: "Signed as \(doc.requiredRole.rawValue.capitalized)",
                                                color: .green,
                                                systemImage: "checkmark.seal.fill"
                                            ) {
                                                EmptyView()
                                            }
                                            .padding(.horizontal, 20)
                                        }
                                    }
                                }
                            } else if isLoading {
                                HStack {
                                    ProgressView()
                                    Text("Loading documents...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 20)
                            } else if let error = errorMessage {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Unable to load documents")
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Button("Retry") {
                                        Task { await loadPendingDocuments() }
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(.leading, 20)
                            } else {
                                // Fallback to test blocks if no real data
                                let requests = displayBlocks.filter { $0.signature == nil || $0.signature?.isEmpty == true }
                                let signed = displayBlocks.filter { $0.signature != nil && !$0.signature!.isEmpty }
                                
                                if requests.isEmpty && signed.isEmpty {
                                    Text("No documents available")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .padding(.leading, 20)
                                } else {
                                    if !requests.isEmpty {
                                        Text("Requests for signatures:")
                                            .font(.title3).bold()
                                            .padding(.leading, 20)
                                        
                                        ForEach(requests.prefix(3)) { block in
                                            NavigationLink(destination: DocumentSigningView(block: block)) {
                                                GlassCardView(
                                                    title: block.title,
                                                    subtitle: block.subtitle,
                                                    color: .unsignedAccent,
                                                    systemImage: "pencil"
                                                ) {
                                                    EmptyView()
                                                }
                                                .padding(.horizontal, 20)
                                            }
                                        }
                                    }
                                    
                                    if !signed.isEmpty {
                                        Text("Signed Documents")
                                            .font(.title3).bold()
                                            .padding(.top, 8)
                                            .padding(.leading, 20)
                                        
                                        ForEach(signed) { block in
                                            NavigationLink(destination: DocumentSigningView(block: block)) {
                                                GlassCardView(
                                                    title: block.title,
                                                    subtitle: block.subtitle,
                                                    color: .green,
                                                    systemImage: "checkmark.seal.fill"
                                                ) {
                                                    EmptyView()
                                                }
                                                .padding(.horizontal, 20)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.white.ignoresSafeArea())
        .task {
            await loadPendingDocuments()
        }
        .refreshable {
            await loadPendingDocuments()
        }
        .sheet(isPresented: $showAccessCodeEntry) {
            AccessCodeEntryView()
        }
        }
    }
    
    private func loadPendingDocuments() async {
        guard let currentPersona = personaManager.activePersona() else {
            errorMessage = "No persona selected"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let documents = try await DocumentSigningService.fetchPendingDocuments(
                forSignerDID: currentPersona.id
            )
            await MainActor.run {
                self.pendingDocuments = documents
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                // Provide more helpful error messages for common server issues
                let errorString = error.localizedDescription
                if errorString.contains("blockchainIndex") || errorString.contains("Index") {
                    self.errorMessage = "Server configuration error: Search index not configured. Please contact your administrator."
                } else if errorString.contains("timed out") || errorString.contains("etcd") {
                    self.errorMessage = "Server database connection failed. The server may be starting up or experiencing issues."
                } else {
                    self.errorMessage = errorString
                }
                self.isLoading = false
            }
        }
    }
    
    static let testBlocks: [BlockchainBlock] = [
        BlockchainBlock(
            index: 1,
            timestamp: 1710000001,
            previousHash: "prev1",
            hash: "hash1",
            data: CodableData(["title": CodableData("Employment Contract"), "subtitle": CodableData("Sign before 5/18/2025"), "description": CodableData("Full-time employment offer for Nora Q.")]),
            type: "sign",
            isDeprecated: false,
            replacedBy: nil,
            s3UploadResults: [],
            signature: nil,
            publicKey: nil
        ),
        BlockchainBlock(
            index: 2,
            timestamp: 1710000002,
            previousHash: "prev2",
            hash: "hash2",
            data: CodableData(["title": CodableData("NDA for Startup Launch"), "subtitle": CodableData("Review and sign by 5/20/2025"), "description": CodableData("Non-disclosure agreement for project Kappa.")]),
            type: "sign",
            isDeprecated: false,
            replacedBy: nil,
            s3UploadResults: [],
            signature: nil,
            publicKey: nil
        ),
        BlockchainBlock(
            index: 3,
            timestamp: 1710000003,
            previousHash: "prev3",
            hash: "hash3",
            data: CodableData(["title": CodableData("Apartment Lease Agreement"), "subtitle": CodableData("Lease for 2025-2026"), "description": CodableData("1-year lease at 17 Market St.")]),
            type: "sign",
            isDeprecated: false,
            replacedBy: nil,
            s3UploadResults: [],
            signature: nil,
            publicKey: nil
        ),
        BlockchainBlock(
            index: 4,
            timestamp: 1710000004,
            previousHash: "prev4",
            hash: "hash4",
            data: CodableData(["title": CodableData("Deposit Receipt"), "subtitle": CodableData("Signed by landlord"), "description": CodableData("Holding deposit for 17 Market St.")]),
            type: "sign",
            isDeprecated: false,
            replacedBy: nil,
            s3UploadResults: [],
            signature: "sample_signature",
            publicKey: nil
        )
    ]
}

struct DocumentSigningView: View {
    let block: BlockchainBlock
    
    var body: some View {
        VStack(spacing: 20) {
            Text(block.title)
                .font(.title)
                .bold()
                .padding()
            
            Text(block.subtitle)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("Document ID: \(block.id)")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Real Document Signing View

struct RealDocumentSigningView: View {
    let document: DocumentSigningService.PendingDocument
    
    @StateObject private var personaManager = PersonaManager()
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var signedEntryID: String?
    @State private var documentData: Data?
    @State private var isLoadingDocument = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Document Info
                VStack(alignment: .leading, spacing: 12) {
                    Text(document.displayTitle)
                        .font(.title2)
                        .bold()
                    
                    // Access Code Display (if available)
                    if let accessCode = document.accessCode {
                        HStack {
                            Image(systemName: "key.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("Access Code:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(accessCode)
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .textSelection(.enabled)
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    HStack {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Uploaded by: \(document.uploadedBy)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let date = document.uploadedAt {
                        HStack {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "tag.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Role: \(document.requiredRole.rawValue.capitalized)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(document.hasSigned ? .green : .orange)
                        Text(document.hasSigned ? "Signed" : "Awaiting signature")
                            .font(.subheadline)
                            .foregroundColor(document.hasSigned ? .green : .orange)
                    }
                }
                .padding()
                .background(Color.platformGroupedBackground)
                .cornerRadius(12)
                
                // Existing Signatures
                if !document.existingSignatures.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Signatures (\(document.existingSignatures.count))")
                            .font(.headline)
                        
                        ForEach(document.existingSignatures, id: \.ledgerEntryID) { signer in
                            HStack {
                                Image(systemName: "signature")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(signer.did)
                                        .font(.subheadline)
                                    HStack {
                                        Text(signer.role.capitalized)
                                            .font(.caption)
                                            .padding(4)
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(4)
                                        Text(signer.timestamp)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.platformGray6)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.platformGroupedBackground)
                    .cornerRadius(12)
                }
                
                // Document Preview/Download
                if let docURL = document.documentURL {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Document")
                            .font(.headline)
                        
                        if isLoadingDocument {
                            HStack {
                                ProgressView()
                                Text("Loading document...")
                                    .font(.subheadline)
                            }
                            .padding()
                        } else if let data = documentData {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text(document.originalFilename ?? "Document")
                                        .font(.subheadline)
                                    Text("\(data.count) bytes")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                // TODO: Add preview or open functionality
                            }
                            .padding()
                            .background(Color.platformGray6)
                            .cornerRadius(8)
                        } else {
                            Button("Download Document") {
                                Task { await downloadDocument(from: docURL) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(Color.platformGroupedBackground)
                    .cornerRadius(12)
                }
                
                // Sign Button
                if !document.hasSigned && !document.isFinalized {
                    Button {
                        Task { await signDocument() }
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "signature")
                                Text("Sign Document")
                                    .bold()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessing || documentData == nil)
                } else if document.hasSigned {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("You have signed this document")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Error Message
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Success Message
                if showSuccess, let entryID = signedEntryID {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Document Signed Successfully")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        Text("Ledger Entry ID:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(entryID)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationTitle("Sign Document")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .task {
            if let docURL = document.documentURL {
                await downloadDocument(from: docURL)
            }
        }
    }
    
    private func downloadDocument(from urlString: String) async {
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid document URL"
            return
        }
        
        isLoadingDocument = true
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run {
                self.documentData = data
                self.isLoadingDocument = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to download document: \(error.localizedDescription)"
                self.isLoadingDocument = false
            }
        }
    }
    
    private func signDocument() async {
        guard let persona = personaManager.activePersona() else {
            errorMessage = "No persona selected"
            return
        }
        
        guard let data = documentData else {
            errorMessage = "Document not loaded"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        do {
            // In a real app, you would load the actual private key for this persona
            // For demo purposes, we'll generate a temporary key
            let privateKey = P256.Signing.PrivateKey()
            let publicKey = privateKey.publicKey.rawRepresentation.base64EncodedString()
            
            let documentHash = Data(SHA256.hash(data: data))
            
            // Get the last entry ID to chain from
            let previousID = document.existingSignatures.last?.ledgerEntryID ?? document.ledgerProofEntryID
            
            let response = try await DocumentSigningService.addSignature(
                documentId: document.documentId,
                signerDID: persona.id,
                signerPublicKey: publicKey,
                documentHash: documentHash,
                privateKey: privateKey,
                role: document.requiredRole,
                previousEntryID: previousID
            )
            
            await MainActor.run {
                self.signedEntryID = response.ledgerEntryID
                self.showSuccess = true
                self.isProcessing = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to sign: \(error.localizedDescription)"
                self.isProcessing = false
            }
        }
    }
}

struct GlassCardView<Content: View>: View {
    let title: String
    let subtitle: String
    let color: Color
    let systemImage: String?
    let content: () -> Content

    init(title: String, subtitle: String, color: Color, systemImage: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.systemImage = systemImage
        self.content = content
    }

    // Reusable chrome that matches the "draft list" aesthetic
    @ViewBuilder
    private var chrome: some View {
        HStack(spacing: 12) {
            // Leading accent bar
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.8), color.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6)
                .padding(.vertical, 12)

            // Optional icon badge
            if let systemImage {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.15))
                        .background(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .frame(width: 36, height: 36)
                .shadow(color: color.opacity(0.35), radius: 6, x: 0, y: 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    var body: some View {
        ZStack { content() }
            .frame(maxWidth: .infinity, minHeight: 88)
            // Background: Liquid Glass on supported OS, fallback material otherwise
            .background(
                Group {
                    #if !os(visionOS)
                    if #available(iOS 26.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *) {
                        RoundedRectangle(
                            cornerRadius: 16,
                            style: .continuous
                        )
                        .fill(.clear)
                        .glassEffect(
                            .regular
                                .tint(.white.opacity(0.08))
                                .interactive(),
                            in: .rect(cornerRadius: 16)
                        )
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.04))
                            .background(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                    #else
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                        .background(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    #endif
                }
            )
            .overlay(chrome)
            // Crisp outline
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            // Subtle top highlight
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 1)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .allowsHitTesting(false)
            }
            // Subtle bottom shadow
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.10), .clear],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: 2)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .allowsHitTesting(false)
            }
            // Faint grain overlay for texture
            .overlay(
                GrainOverlay()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// Lightweight, deterministic grain overlay (no external assets)
private struct GrainOverlay: View {
    @State private var points: [CGPoint] = []

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                // Draw tiny white dots to simulate fine grain
                for p in points {
                    let rect = CGRect(x: p.x, y: p.y, width: 1, height: 1)
                    context.fill(Path(rect), with: .color(.white.opacity(0.06)))
                }
            }
            .onAppear {
                if points.isEmpty {
                    let size = proxy.size
                    var rng = SeededGenerator(seed: 42)
                    // Density scales with area; tweak divisor to taste
                    let density = max(1, Int((size.width * size.height) / 900))
                    points = (0..<density).map { _ in
                        CGPoint(
                            x: CGFloat.random(in: 0...size.width, using: &rng),
                            y: CGFloat.random(in: 0...size.height, using: &rng)
                        )
                    }
                }
            }
        }
        .blendMode(.overlay)
        .opacity(0.06)
        .allowsHitTesting(false)
    }
}

// Simple deterministic RNG for reproducible grain
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = 2862933555777941757 &* state &+ 3037000493
        return state
    }
}

// Refined accent palette for cards
private extension Color {
    // Sophisticated yellow (amber) — default for unsigned requests
    static let unsignedAccent = Color(red: 0.94, green: 0.73, blue: 0.25) // #F0BA40
    // Subdued red — switch to this by using `.unsignedAccentRed` in the call site
    static let unsignedAccentRed = Color(red: 0.86, green: 0.38, blue: 0.33) // #DB6154
}

