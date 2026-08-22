import SwiftUI
import CryptoKit

/// View for entering an access code to retrieve a document for signing
struct AccessCodeEntryView: View {
    private let initialAccessCodeParam: String?
    private let prefilledPersonaParam: OneTimePersonaData?
    
    @StateObject private var personaManager = PersonaManager()
    @State private var accessCode: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var fetchedDocument: DocumentSigningService.PendingDocument?
    @State private var showDocumentDetail = false
    
    @Environment(\.dismiss) private var dismiss
    
    init(initialAccessCode: String? = nil, prefilledPersona: OneTimePersonaData? = nil) {
        self.initialAccessCodeParam = initialAccessCode
        self.prefilledPersonaParam = prefilledPersona
        if let code = initialAccessCode {
            _accessCode = State(initialValue: code)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "key.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text("Enter Access Code")
                                .font(.title2)
                                .bold()
                        }
                        
                        Text("Enter the 7-digit code you received to access a document for signing.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    // Access Code Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Access Code")
                            .font(.headline)
                        
                        HStack(spacing: 8) {
                            TextField("XXX-XXXX", text: $accessCode)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.title3, design: .monospaced))
                                .textCase(.uppercase)
                                .platformKeyboardType(.numberPad)
                                .platformAutocapitalization(.characters)
                                .disableAutocorrection(true)
                                .onChange(of: accessCode) { _, newValue in
                                    // Format as XXX-XXXX
                                    let filtered = newValue.filter { $0.isNumber || $0 == "-" }
                                    let digitsOnly = filtered.filter { $0.isNumber }
                                    
                                    if digitsOnly.count <= 7 {
                                        if digitsOnly.count > 3 {
                                            let prefix = digitsOnly.prefix(3)
                                            let suffix = digitsOnly.dropFirst(3)
                                            accessCode = "\(prefix)-\(suffix)"
                                        } else {
                                            accessCode = String(digitsOnly)
                                        }
                                    } else {
                                        accessCode = String(accessCode.dropLast())
                                    }
                                }
                            
                            Button {
                                accessCode = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .opacity(accessCode.isEmpty ? 0 : 1)
                        }
                        
                        Text("Format: 3 digits, dash, 4 digits (e.g., 451-7892)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.platformGroupedBackground)
                    .cornerRadius(12)

                    // Submit Button
                    Button {
                        Task { await fetchDocument() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "magnifyingglass")
                                Text("Find Document")
                                    .bold()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValidAccessCode ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isValidAccessCode || isLoading)
                    
                    // Error Message
                    if let error = errorMessage {
                        HStack(alignment: .top, spacing: 12) {
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
                    
                    // Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How it works")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            InfoRow(
                                icon: "1.circle.fill",
                                title: "Receive Code",
                                description: "Get a 7-digit access code from the document sender"
                            )
                            
                            InfoRow(
                                icon: "2.circle.fill",
                                title: "Enter Code",
                                description: "Type the code in the format XXX-XXXX"
                            )
                            
                            InfoRow(
                                icon: "3.circle.fill",
                                title: "Access Document",
                                description: "If authorized, you'll see the document details and can sign"
                            )
                        }
                    }
                    .padding()
                    .background(Color.platformGroupedBackground)
                    .cornerRadius(12)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Access Code")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showDocumentDetail) {
                if let document = fetchedDocument {
                    NavigationView {
                        RealDocumentSigningView(document: document)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") {
                                        showDocumentDetail = false
                                        dismiss()
                                    }
                                }
                            }
                    }
                }
            }
        }
    }
    
    private var isValidAccessCode: Bool {
        let digitsOnly = accessCode.filter { $0.isNumber }
        return digitsOnly.count == 7
    }
    
    private func fetchDocument() async {
        guard let persona = personaManager.activePersona() else {
            errorMessage = "No persona selected"
            return
        }
        
        guard isValidAccessCode else {
            errorMessage = "Please enter a valid 7-digit access code"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let document = try await DocumentSigningService.fetchDocumentByAccessCode(
                accessCode,
                signerDID: persona.id
            )
            
            await MainActor.run {
                self.fetchedDocument = document
                self.showDocumentDetail = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Info Row Component

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    Group {
        AccessCodeEntryView()
        AccessCodeEntryView(initialAccessCode: "451-7892")
    }
}
