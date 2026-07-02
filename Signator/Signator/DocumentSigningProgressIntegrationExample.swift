import SwiftUI
import CryptoKit

// MARK: - Local adapter to decouple from app-specific Persona types

struct SigningAuthor {
    let did: String
    let privateKey: P256.Signing.PrivateKey
    let publicKeyBase64: String
}

// Best-effort extraction from an unknown Persona shape without introducing compile-time coupling.
// Tries common property names: did / identifier / id, privateKey / signingKey / keyPair.privateKey, publicKey / keyPair.publicKey
private func makeSigningAuthor(from persona: Any) -> SigningAuthor? {
    // Helper to get a Mirror child by a set of possible labels
    func value<T>(from mirror: Mirror, labels: [String], as type: T.Type = T.self) -> T? {
        for label in labels {
            if let child = mirror.children.first(where: { $0.label == label }), let val = child.value as? T {
                return val
            }
        }
        return nil
    }

    let mirror = Mirror(reflecting: persona)

    // DID candidates
    let did: String? = value(from: mirror, labels: ["did", "identifier", "id", "didString"]) ?? {
        // Sometimes DID might be nested under profile or similar
        if let profile: Any = value(from: mirror, labels: ["profile", "info"]) {
            let m = Mirror(reflecting: profile)
            return value(from: m, labels: ["did", "identifier", "id", "didString"]) as String?
        }
        return nil
    }()

    // Private key candidates
    var privateKey: P256.Signing.PrivateKey? = value(from: mirror, labels: ["privateKey", "signingPrivateKey"]) as P256.Signing.PrivateKey?
    if privateKey == nil {
        // Try nested keyPair.privateKey
        if let keyPair: Any = value(from: mirror, labels: ["keyPair", "keys"]) {
            let km = Mirror(reflecting: keyPair)
            privateKey = value(from: km, labels: ["privateKey", "signingPrivateKey"]) as P256.Signing.PrivateKey?
        }
    }

    // Public key candidates
    var publicKeyData: Data?
    if let pubKey: P256.Signing.PublicKey = value(from: mirror, labels: ["publicKey", "signingPublicKey"]) {
        publicKeyData = pubKey.rawRepresentation
    } else if let keyPair: Any = value(from: mirror, labels: ["keyPair", "keys"]) {
        let km = Mirror(reflecting: keyPair)
        if let pubKey: P256.Signing.PublicKey = value(from: km, labels: ["publicKey", "signingPublicKey"]) {
            publicKeyData = pubKey.rawRepresentation
        }
    } else if let raw: Data = value(from: mirror, labels: ["publicKeyRaw", "publicKeyData"]) {
        publicKeyData = raw
    }

    guard let didUnwrapped = did, let priv = privateKey, let pubData = publicKeyData else {
        return nil
    }

    return SigningAuthor(
        did: didUnwrapped,
        privateKey: priv,
        publicKeyBase64: pubData.base64EncodedString()
    )
}

// A wrapper that always renders, showing progress until author+data are ready
private struct SigningProgressContainer: View {
    let initialData: Data?
    let filename: String
    let metadata: [String: String]?
    let personaManager: PersonaManager
    let onStart: ((Data, SigningAuthor, [String: String]?) async throws -> (docId: String, attestId: String))?
    let onComplete: (String, String) -> Void
    let onDismiss: () -> Void

    @State private var author: SigningAuthor?
    @State private var data: Data?

    @State private var isRunning = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let data, let author {
                EnhancedDocumentSigningView(
                    documentData: data,
                    authorDID: author.did,
                    authorPrivateKey: author.privateKey,
                    authorPublicKey: author.publicKeyBase64,
                    filename: filename,
                    onComplete: onComplete,
                    onDismiss: onDismiss
                )
            } else {
                VStack(spacing: 16) {
                    Text("SigningProgressContainer mounted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                    ProgressView()
                    Text("Preparing signing...")
                        .font(.headline)
                    if isReadyToStart {
                        if isRunning {
                            Text("Submitting…")
                        } else {
                            Button("Start Submission") { Task { await runStartIfPossible() } }
                        }
                    }
                    Button("Close") { onDismiss() }
                }
                .padding()
                .task { await prepare() }
            }
        }
    }

    private var isReadyToStart: Bool {
        data != nil && author != nil && onStart != nil
    }

    private func runStartIfPossible() async {
        guard let data, let author, let onStart else { return }
        await MainActor.run { isRunning = true; errorMessage = nil }
        do {
            let result = try await onStart(data, author, metadata)
            await MainActor.run {
                onComplete(result.docId, result.attestId)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to submit: \(error.localizedDescription)"
                isRunning = false
            }
        }
    }

    private func prepare() async {
        // snapshot initial data immediately
        if data == nil { self.data = initialData }

        // reflectively grab a persona once
        if author == nil {
            let mirror = Mirror(reflecting: personaManager)
            let selected = mirror.children.first { ["selectedPersona", "current", "activePersona"].contains($0.label ?? "") }?.value
            if let selected, let built = makeSigningAuthor(from: selected) {
                self.author = built
            }
        }
    }
}

/// This file shows how to integrate the EnhancedDocumentSigningView into your existing app
/// Replace your existing signing button/action with this pattern

// MARK: - Integration Example

struct DocumentSigningIntegrationExample: View {
    @State private var showSigningProgress = false
    @State private var documentData: Data?
    @State private var completedDocumentId: String?

    // Your document details
    let documentId: String = "doc_12345"
    let filename: String = "contract.pdf"

    @State private var personaManager = PersonaManager()

    var body: some View {
        VStack(spacing: 20) {
            // Your existing document view...

            Button("Sign Document") {
                // Present immediately; load in background so the user sees progress
                showSigningProgress = true
                Task { await loadDocumentDataIfNeeded() }
            }
            .buttonStyle(.borderedProminent)
        }
        .platformFullScreenCover(isPresented: $showSigningProgress) {
            ZStack {
                Color.platformBackground.ignoresSafeArea()
                SigningProgressContainer(
                    initialData: documentData,
                    filename: filename,
                    metadata: nil, // Send tab can pass user-entered metadata here
                    personaManager: personaManager,
                    onStart: { data, author, metadata in
                        // Example: kick off your server submission and stream updates
                        // Replace this with your real API that returns (docId, attestId)
                        // You can also post progress via Notifications/actors if needed
                        try await Task.sleep(nanoseconds: 1_500_000_000) // simulate longer network delay for visible UI
                        return (docId: "simulated-doc", attestId: "simulated-attestation")
                    },
                    onComplete: { docId, attestId in
                        print("✅ Document signed!")
                        print("   Document ID: \(docId)")
                        print("   Attestation: \(attestId)")
                        completedDocumentId = docId
                        // showSigningProgress = false // Temporarily disabled to verify presentation
                    },
                    onDismiss: {
                        showSigningProgress = false
                    }
                )
            }
        }
    }

    private func loadDocumentDataIfNeeded() async {
        if documentData != nil { return }
        guard let url = URL(string: "\(ServerConfiguration.current.baseURL)/api/document/\(documentId)/content") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run { self.documentData = data }
        } catch {
            print("❌ Failed to load document: \(error)")
        }
    }
}

// MARK: - Real-World Integration for DocumentListView

/// Here's how to modify your RealDocumentSigningView to use the progress view:

extension View {
    /// Helper to present full-screen document signing with progress
    func documentSigningProgress(
        isPresented: Binding<Bool>,
        documentData: Data?,
        authorDID: String,
        authorPrivateKey: P256.Signing.PrivateKey,
        authorPublicKey: String,
        filename: String?,
        onComplete: @escaping (String, String) -> Void
    ) -> some View {
        self.platformFullScreenCover(isPresented: isPresented) {
            Group {
                if let data = documentData {
                    EnhancedDocumentSigningView(
                        documentData: data,
                        authorDID: authorDID,
                        authorPrivateKey: authorPrivateKey,
                        authorPublicKey: authorPublicKey,
                        filename: filename,
                        onComplete: onComplete,
                        onDismiss: {
                            isPresented.wrappedValue = false
                        }
                    )
                } else {
                    ZStack {
                        Color.platformBackground.ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Preparing signing… (no data yet)")
                                .font(.headline)
                            Button("Close") { isPresented.wrappedValue = false }
                        }
                        .padding()
                    }
                }
            }
        }
    }

    /// Overload that accepts a preselected persona to avoid dynamic member lookup issues
    func documentSigningProgress(
        isPresented: Binding<Bool>,
        documentData: Data?,
        persona: Any?,
        filename: String?,
        onComplete: @escaping (String, String) -> Void
    ) -> some View {
        self.platformFullScreenCover(isPresented: isPresented) {
            Group {
                if let data = documentData, let persona = persona, let author = makeSigningAuthor(from: persona) {
                    EnhancedDocumentSigningView(
                        documentData: data,
                        authorDID: author.did,
                        authorPrivateKey: author.privateKey,
                        authorPublicKey: author.publicKeyBase64,
                        filename: filename,
                        onComplete: onComplete,
                        onDismiss: {
                            isPresented.wrappedValue = false
                        }
                    )
                } else {
                    ZStack {
                        Color.platformBackground.ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Preparing signing… (waiting for persona/data)")
                                .font(.headline)
                            Button("Close") { isPresented.wrappedValue = false }
                        }
                        .padding()
                    }
                }
            }
        }
    }
}

extension View {
    /// Present the signing/sending progress flow from the Send tab once the user presses Submit.
    func presentSendProgress(
        isPresented: Binding<Bool>,
        data: Data?,
        filename: String,
        metadata: [String: String]?,
        personaManager: PersonaManager,
        onStart: @escaping (Data, SigningAuthor, [String: String]?) async throws -> (docId: String, attestId: String),
        onComplete: @escaping (String, String) -> Void
    ) -> some View {
        self.platformFullScreenCover(isPresented: isPresented) {
            SigningProgressContainer(
                initialData: data,
                filename: filename,
                metadata: metadata,
                personaManager: personaManager,
                onStart: onStart,
                onComplete: onComplete,
                onDismiss: { isPresented.wrappedValue = false }
            )
        }
    }
}

// MARK: - How to Update Your RealDocumentSigningView

/**
 In your DocumentListView.swift, find the `signDocument()` function and replace it with this:

 ```swift
 struct RealDocumentSigningView: View {
     let document: DocumentSigningService.PendingDocument

     @StateObject private var personaManager = PersonaManager()
     @State private var showSigningProgress = false  // Add this
     @State private var isProcessing = false
     @State private var errorMessage: String?
     @State private var showSuccess = false
     @State private var signedEntryID: String?
     @State private var documentData: Data?
     @State private var isLoadingDocument = false

     var body: some View {
         ScrollView {
             // ... your existing UI ...

             // Replace your existing sign button with this:
             if !document.hasSigned && !document.isFinalized {
                 Button {
                     showSigningProgress = true  // Just show the modal!
                 } label: {
                     HStack {
                         Image(systemName: "signature")
                         Text("Sign Document")
                             .bold()
                     }
                     .frame(maxWidth: .infinity)
                     .padding()
                     .background(Color.blue)
                     .foregroundColor(.white)
                     .cornerRadius(12)
                 }
                 .disabled(documentData == nil)
             }
         }
         .documentSigningProgress(
             isPresented: $showSigningProgress,
             documentData: documentData,
             authorDID: personaManager.selectedPersonaAsAny.flatMap { makeSigningAuthor(from: $0) }?.did ?? "",
             authorPrivateKey: personaManager.selectedPersonaAsAny.flatMap { makeSigningAuthor(from: $0) }?.privateKey ?? P256.Signing.PrivateKey(),
             authorPublicKey: personaManager.selectedPersonaAsAny.flatMap { makeSigningAuthor(from: $0) }?.publicKeyBase64 ?? "",
             filename: document.originalFilename,
             onComplete: { docId, attestId in
                 // Update your UI when signing completes
                 showSuccess = true
                 signedEntryID = attestId

                 // Refresh your document list
                 Task {
                     // await loadPendingDocuments()
                 }
             }
         )
         .onAppear {
             Task {
                 if let docURL = document.documentURL {
                     await downloadDocument(from: docURL)
                 }
             }
         }
     }
 }

*/

