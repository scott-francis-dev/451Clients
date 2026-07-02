import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
// iOS/iPadOS Document Picker
struct DocumentPickerView: UIViewControllerRepresentable {
    var allowedUTTypes: [UTType]
    var allowsMultipleSelection: Bool = false
    var onPick: ([URL]) -> Void
    var onCancel: () -> Void = {}

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: allowedUTTypes, asCopy: false)
        controller.allowsMultipleSelection = allowsMultipleSelection
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        init(_ parent: DocumentPickerView) { self.parent = parent }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancel()
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Start security-scoped access for each URL
            let accessibleURLs: [URL] = urls.compactMap { url in
                guard url.startAccessingSecurityScopedResource() else { return url }
                return url
            }
            parent.onPick(accessibleURLs)
            // Note: Caller is responsible for stopping access when done with the URL(s)
        }
    }
}

#elseif canImport(AppKit)
// macOS Document Picker
struct DocumentPickerView: NSViewControllerRepresentable {
    var allowedUTTypes: [UTType]
    var allowsMultipleSelection: Bool = false
    var onPick: ([URL]) -> Void
    var onCancel: () -> Void = {}

    func makeNSViewController(context: Context) -> NSViewController {
        let viewController = NSViewController()
        
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = self.allowsMultipleSelection
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = self.allowedUTTypes
            
            panel.begin { response in
                if response == .OK {
                    let urls = panel.urls.map { url in
                        _ = url.startAccessingSecurityScopedResource()
                        return url
                    }
                    self.onPick(urls)
                } else {
                    self.onCancel()
                }
            }
        }
        
        return viewController
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
}
#endif

// Entry point for the Initiate tab with three clear options
struct EnhancedSendSigningFlowView: View {
    let personaManager: PersonaManager
    @Binding var showPersonaSheet: Bool
    
    @State private var path: [Destination] = []
    @State private var showingHelp = false
    
    enum Destination: Hashable {
        case signExisting
        case chooseTemplate
        case notarizeEvent
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 16) {
                // Glass card header matching DocumentListView and SignRequestsView
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start a New Request")
                            .font(.title3).bold()
                        Text("Choose how you'd like to begin.")
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
                
                VStack(spacing: 12) {
                    ActionCard(title: "Sign existing document", subtitle: "Pick a file, set metadata, and add signers.", systemImage: "doc.text") {
                        path.append(.signExisting)
                    }
                    
                    ActionCard(title: "Choose from template", subtitle: "Start from a reusable template and assign signers.", systemImage: "square.grid.2x2") {
                        path.append(.chooseTemplate)
                    }
                    
                    ActionCard(title: "Notarize/Verify an Event", subtitle: "Record an event with a verifiable timestamp.", systemImage: "checkmark.seal") {
                        path.append(.notarizeEvent)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .background(Color.white.ignoresSafeArea())
            .sheet(isPresented: $showingHelp) {
                NavigationStack {
                    InitiateHelpView()
                }
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .signExisting:
                    SendSigningFlowView(personaManager: personaManager)
                case .chooseTemplate:
                    TemplateSelectionFlowView(personaManager: personaManager)
                case .notarizeEvent:
                    NotarizeEventFlowView(personaManager: personaManager)
                }
            }
        }
    }
}

struct ActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: systemImage)
                        .foregroundColor(.blue)
                        .font(.system(size: 20, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.blue.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.blue.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stub destination flows

struct SendSigningFlowView: View {
    let personaManager: PersonaManager
    @State private var pickedURL: URL? = nil
    @State private var showingPicker = false
    @State private var importError: String? = nil
    @State private var metadataForm: DocumentMetadataForm
    @State private var currentStep: Step = .document
    @State private var goToParticipants = false

    init(personaManager: PersonaManager) {
        self.personaManager = personaManager
        let form = DocumentMetadataForm()
        form.accessrights = ""
        _metadataForm = State(initialValue: form)
    }

    private enum Step: Int, CaseIterable {
        case document
        case visibility
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if currentStep == .document {
                    DocumentSelectionStepView(
                        pickedURL: $pickedURL,
                        showingPicker: $showingPicker,
                        importError: $importError
                    )
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
                }

                if currentStep == .visibility {
                    DocumentVisibilityStepView(metadataForm: $metadataForm) { access in
                        metadataForm.accessrights = access
                        goToParticipants = true
                    }
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                }
            }
            .animation(.easeInOut(duration: 0.15), value: currentStep)

            Divider()

            HStack {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        currentStep = .document
                    }
                }
                .disabled(currentStep == .document)

                Spacer()

                if currentStep == .document {
                    Button("Next") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            currentStep = .visibility
                        }
                    }
                    .disabled(pickedURL == nil)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(
            NavigationLink(isActive: $goToParticipants) {
                ParticipantsAndMetadataView(
                    personaManager: personaManager,
                    metadataForm: $metadataForm,
                    selectedDocument: pickedURL.map { .fileURL($0, displayName: $0.lastPathComponent) }
                ) { participants, _ in
                    // TODO: Replace with your real backend call
                    // Example: SigningService.shared.send(participants: participants, content: content)
                }
            } label: {
                EmptyView()
            }
            .hidden()
        )
        .navigationTitle("Sign Existing")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPicker) {
            DocumentPickerView(
                allowedUTTypes: [.pdf, .plainText, .rtf, .text, .jpeg, .png, .data],
                allowsMultipleSelection: false,
                onPick: { urls in
                    if let first = urls.first {
                        pickedURL = first
                        importError = nil
                        withAnimation(.easeInOut(duration: 0.15)) {
                            currentStep = .visibility
                        }
                    } else {
                        importError = "No file selected."
                    }
                    showingPicker = false
                },
                onCancel: {
                    showingPicker = false
                }
            )
        }
        .onDisappear {
            // Stop security scoped access if we started it
            if let pickedURL {
                pickedURL.stopAccessingSecurityScopedResource()
            }
        }
    }
}

struct DocumentSelectionStepView: View {
    @Binding var pickedURL: URL?
    @Binding var showingPicker: Bool
    @Binding var importError: String?

    var body: some View {
        Form {
            Section {
                Text("First we need to select a document that will be signed, by the submitter, and, possibly one, or more, other people (personas)")
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Document")) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.blue)
                    if let url = pickedURL {
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                    } else {
                        Text("No file selected")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Choose…") { showingPicker = true }
                }
                if let importError {
                    Text(importError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

struct DocumentVisibilityStepView: View {
    @Binding var metadataForm: DocumentMetadataForm
    let onSelection: (String) -> Void

    var body: some View {
        Form {
            Section(header: Text("Document Visibility")) {
                Text("Most contracts should be private. Publications intended for broader sharing are typically public.")
                    .foregroundStyle(.secondary)

                Button {
                    onSelection("private")
                } label: {
                    DocumentVisibilityOptionRow(
                        title: "Private document",
                        description: "Use for contracts, agreements, and documents meant only for specific signers.",
                        isSelected: metadataForm.accessrights.lowercased() == "private"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    onSelection("public")
                } label: {
                    DocumentVisibilityOptionRow(
                        title: "Public document",
                        description: "Use for publications you want to share broadly with a wider audience.",
                        isSelected: metadataForm.accessrights.lowercased() == "public"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct DocumentVisibilityOptionRow: View {
    let title: String
    let description: String
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.blue.opacity(isSelected ? 0.14 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.blue.opacity(isSelected ? 0.25 : 0.12), lineWidth: 1)
        )
    }
}

struct TemplateSelectionFlowView: View {
    let personaManager: PersonaManager
    
    struct Template: Identifiable, Hashable {
        let id: String // Changed from UUID to String for stability
        let name: String
        let description: String
        let initialContent: String // Default template content
    }
    
    // Make templates static so they maintain identity
    static let availableTemplates: [Template] = [
        Template(
            id: "liability-release",
            name: "Liability Release",
            description: "Liability release and waiver of claims",
            initialContent: """
            Liability Release and Waiver of Claims
            
            This Liability Release and Waiver ("Agreement") is entered into on the date signed below by the undersigned participant ("Participant").
            
            1. Acknowledgment of Risks
            
            Participant acknowledges and agrees that participation in the activity or event described below ("Activity") may involve inherent risks, including but not limited to physical injury, property damage, illness, or other harm. Participant understands these risks and voluntarily chooses to participate.
            
            Description of Activity: __________________________________________
            
            2. Release of Liability
            
            In consideration for being permitted to participate in the Activity, Participant hereby releases, waives, and discharges the following parties from any and all liability, claims, demands, actions, or causes of action arising out of or related to any loss, damage, or injury that may be sustained:
            
            Organizer/Company Name: __________________________________________
            
            Owners, officers, employees, agents, volunteers, and representatives
            
            This release applies to the fullest extent permitted by law, including claims arising from ordinary negligence.
            
            3. Assumption of Responsibility
            
            Participant agrees to assume full responsibility for any risk of bodily injury, property damage, or other loss, whether caused by negligence or otherwise, while participating in the Activity.
            
            4. Medical Consent
            
            Participant authorizes Organizer to obtain medical treatment considered necessary in case of injury or emergency. Participant agrees to be financially responsible for any resulting medical expenses.
            
            5. Indemnification
            
            Participant agrees to indemnify and hold harmless Organizer from any loss, liability, damage, or costs—including attorney's fees—that arise due to Participant's participation in the Activity.
            
            6. Binding Effect
            
            This Agreement is binding upon Participant, their heirs, executors, administrators, successors, and assigns.
            
            7. Governing Law
            
            This Agreement shall be governed by the laws of the State of _________________________.
            
            8. Severability
            
            If any provision of this Agreement is determined to be invalid or unenforceable, the remaining provisions shall remain in full force and effect.
            
            Participant Information
            
            Name: ____________________________________________
            Address: __________________________________________
            Phone: ____________________________________________
            Email: _____________________________________________
            
            Signature: __________________________________________
            Date: _____________________
            
            If Participant is under 18, Parent/Guardian must sign below:
            
            Parent/Guardian Name: __________________________________________
            Signature: __________________________________________
            Date: _____________________
            """
        ),
        Template(
            id: "nda",
            name: "NDA",
            description: "Mutual Non-Disclosure Agreement",
            initialContent: """
            NON-DISCLOSURE AGREEMENT
            
            This Non-Disclosure Agreement (the "Agreement") is entered into as of [DATE] by and between:
            
            Party A: [PARTY A NAME]
            Party B: [PARTY B NAME]
            
            WHEREAS, the parties wish to explore a business opportunity together and will need to disclose confidential information;
            
            NOW, THEREFORE, the parties agree as follows:
            
            1. CONFIDENTIAL INFORMATION
            "Confidential Information" means any information disclosed by one party to the other, whether orally or in writing.
            
            2. OBLIGATIONS
            The receiving party agrees to:
            - Keep all Confidential Information strictly confidential
            - Not disclose to any third parties
            - Use only for the agreed purpose
            
            3. TERM
            This Agreement shall remain in effect for [DURATION].
            
            
            Signatures:
            
            _______________________
            Party A
            
            _______________________
            Party B
            """
        ),
        Template(
            id: "employment-offer",
            name: "Employment Offer",
            description: "Offer letter template",
            initialContent: """
            EMPLOYMENT OFFER LETTER
            
            [DATE]
            
            Dear [CANDIDATE NAME],
            
            We are pleased to offer you the position of [JOB TITLE] at [COMPANY NAME].
            
            POSITION DETAILS:
            - Title: [JOB TITLE]
            - Department: [DEPARTMENT]
            - Reports to: [MANAGER NAME]
            - Start Date: [START DATE]
            
            COMPENSATION:
            - Salary: $[AMOUNT] per year
            - Benefits: [BENEFITS SUMMARY]
            
            This offer is contingent upon successful completion of background checks and verification of your right to work.
            
            Please sign below to accept this offer.
            
            Sincerely,
            
            [COMPANY NAME]
            
            
            I accept this offer:
            
            _______________________
            [CANDIDATE NAME]
            Date: __________
            """
        ),
        Template(
            id: "sales-contract",
            name: "Sales Contract",
            description: "Standard sales agreement",
            initialContent: """
            SALES AGREEMENT
            
            This Sales Agreement (the "Agreement") is made as of [DATE] between:
            
            Seller: [SELLER NAME]
            Buyer: [BUYER NAME]
            
            1. SALE OF GOODS/SERVICES
            The Seller agrees to sell and the Buyer agrees to purchase the following:
            
            Description: [DESCRIPTION]
            Quantity: [QUANTITY]
            Price: $[AMOUNT]
            
            2. PAYMENT TERMS
            Payment shall be made as follows:
            - Due Date: [DUE DATE]
            - Payment Method: [METHOD]
            
            3. DELIVERY
            Delivery shall occur on or before [DELIVERY DATE] at [LOCATION].
            
            4. WARRANTIES
            [WARRANTY TERMS]
            
            5. GOVERNING LAW
            This Agreement shall be governed by the laws of [JURISDICTION].
            
            
            Signatures:
            
            _______________________
            Seller
            
            _______________________
            Buyer
            """
        )
    ]
    
    var body: some View {
        List {
            Section("Choose a template") {
                ForEach(Self.availableTemplates) { template in
                    NavigationLink(value: template) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name).font(.headline)
                            Text(template.description).font(.footnote).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationDestination(for: Template.self) { template in
            TemplateEditorView(template: template, personaManager: personaManager)
        }
        .navigationTitle("Templates")
    }
}

// MARK: - Template Editor View

struct TemplateEditorView: View {
    let template: TemplateSelectionFlowView.Template
    let personaManager: PersonaManager
    
    @State private var documentText: String = ""
    @State private var showingPreview = false
    
    @State private var metadataForm = DocumentMetadataForm()
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Editor toolbar
            HStack {
                Text("Edit Document")
                    .font(.headline)
                Spacer()
                Button {
                    showingPreview.toggle()
                } label: {
                    Label(showingPreview ? "Edit" : "Preview", systemImage: showingPreview ? "pencil" : "eye")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            
            // Editor or Preview
            if showingPreview {
                // Preview mode
                ScrollView {
                    Text(documentText)
                        .font(.system(.body, design: .serif))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.white)
            } else {
                // Edit mode
                TextEditor(text: $documentText)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color.white)
                    .scrollContentBackground(.hidden)
            }
            
            // Bottom toolbar with actions
            VStack(spacing: 12) {
                Divider()
                
                HStack(spacing: 12) {
                    Button {
                        // Reset to template
                        documentText = template.initialContent
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    NavigationLink {
                        ParticipantsAndMetadataView(
                            personaManager: personaManager,
                            metadataForm: $metadataForm,
                            selectedDocument: .inlineText(documentText, suggestedFilename: "document.txt")
                        ) { participants, _ in
                            // Hook for backend send after participants selection
                        }
                    } label: {
                        Label("Next: Add Signers", systemImage: "arrow.right")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(documentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            documentText = template.initialContent
        }
    }
}

struct NotarizeEventFlowView: View {
    let personaManager: PersonaManager
    @State private var eventDescription: String = ""
    
    var body: some View {
        Form {
            Section(header: Text("Event Details")) {
                TextField("Describe the event", text: $eventDescription)
            }
            Section {
                Button {
                    // TODO: Implement notarization logic
                } label: {
                    Label("Notarize Event", systemImage: "checkmark.seal")
                }
                .disabled(eventDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Notarize Event")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum SignerRole: String, CaseIterable, Identifiable {
    case signator = "Signator"
    case witness = "Witness"
    case notary = "Notary"
    case author = "Author/Creator"

    var id: String { rawValue }
}

struct ParticipantsAndMetadataView: View {
    let personaManager: PersonaManager
    @Binding var metadataForm: DocumentMetadataForm
    
    enum SelectedDocument {
        case inlineText(String, suggestedFilename: String)
        case fileURL(URL, displayName: String)
    }
    
    var selectedDocument: SelectedDocument? = nil // Either inline template text or a picked file URL
    
    var onSend: (([Participant], String?) -> Void)? = nil
    
    @State private var participants: [Participant] = []
    
    @State private var showFriendsPicker = false
    @State private var showPersonasPicker = false
    @State private var showManualEntry = false
    
    @State private var manualHandleOrDID: String = ""
    @State private var manualName: String = ""
    @State private var manualRole: SignerRole = .signator
    
    @State private var sendErrorMessage: String? = nil
    @State private var sendSuccessMessage: String? = nil
    @State private var sendProgressMessage: String? = nil
    @State private var sendProgressValue: Double = 0
    @State private var isSending = false
    @State private var sseClient: ProductionSSEClient? = nil
    @State private var wantsMetadata: Bool? = nil

    @State private var vesselProviders: Set<String> = []
    @State private var vesselCreated = false
    @State private var documentUploaded = false
    @State private var didUploaded = false
    @State private var metadataUploaded = false
    @State private var signaturesUploaded = false
    @State private var indexingComplete = false

    struct Participant: Identifiable, Hashable {
        let id = UUID()
        var name: String
        var email: String
        var didOrHandle: String?
        var role: SignerRole
        var source: Source

        enum Source: String, Hashable { case friend, persona, manual }
    }
    
    var body: some View {
        Form {
            if let selectedDocument {
                Section(header: Text("Document Preview")) {
                    switch selectedDocument {
                    case .inlineText(let text, _):
                        Text(text)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(5)
                            .padding(.vertical, 4)
                        Text("Full document will be included when sent")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    case .fileURL(let url, let displayName):
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.blue)
                            Text(displayName)
                                .lineLimit(1)
                            Spacer()
                        }
                        Text(url.path)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            if wantsMetadata == nil {
                Section(header: Text("Additional Metadata")) {
                    Text("Would you like to add additional metadata to this document?")
                        .foregroundStyle(.secondary)
                    Button("Yes, add metadata") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            wantsMetadata = true
                        }
                    }
                    Button("No, skip") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            wantsMetadata = false
                        }
                    }
                }
            }

            if wantsMetadata == true {
                DocumentMetadataEditorSections(metadata: $metadataForm, showsTypePicker: false)
            }

            if wantsMetadata != nil {
                Section(header: Text("Participants / Signers")) {
                    ForEach($participants) { $p in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Name", text: $p.name)
                            TextField("Email", text: $p.email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                            if let did = p.didOrHandle, !did.isEmpty {
                                Text(did)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Picker("Role", selection: $p.role) {
                                ForEach(SignerRole.allCases) { role in
                                    Text(role.rawValue).tag(role)
                                }
                            }
                            .pickerStyle(.menu)
                            Divider()
                        }
                    }
                    .onDelete { offsets in
                        participants.remove(atOffsets: offsets)
                    }

                    Button { showFriendsPicker = true } label: {
                        Label("Add from Friends/Colleagues", systemImage: "person.2")
                    }
                    Button { showPersonasPicker = true } label: {
                        Label("Add from My Personas", systemImage: "person.crop.circle")
                    }
                    Button { showManualEntry = true } label: {
                        Label("Add by DID or Label", systemImage: "plus.rectangle.on.rectangle")
                    }
                }
            }
            
            Section {
                Button {
                    Task { await sendDocument() }
                } label: {
                    HStack {
                        Spacer()
                        Label("Send", systemImage: "paperplane")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(participants.isEmpty || isSending)
            }

            if isSending || sendProgressMessage != nil || sendSuccessMessage != nil {
                Section(header: Text("Processing Status")) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let message = sendProgressMessage, !message.isEmpty {
                            Text(message)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        ProgressView(value: sendProgressValue)
                        statusRow(
                            title: "Document vessel created",
                            detail: vesselProviderSummary,
                            isDone: vesselCreated
                        )
                        statusRow(
                            title: "Document uploaded",
                            detail: nil,
                            isDone: documentUploaded
                        )
                        statusRow(
                            title: "DID document uploaded",
                            detail: nil,
                            isDone: didUploaded
                        )
                        statusRow(
                            title: "Metadata uploaded",
                            detail: nil,
                            isDone: metadataUploaded
                        )
                        statusRow(
                            title: "Signature files uploaded",
                            detail: nil,
                            isDone: signaturesUploaded
                        )
                        statusRow(
                            title: "Indexed for search and discovery",
                            detail: nil,
                            isDone: indexingComplete
                        )
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Details & Signers")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showManualEntry) {
            NavigationStack {
                Form {
                    Section(header: Text("Identifier")) {
                        TextField("Label/Handle or DID", text: $manualHandleOrDID)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Section(header: Text("Optional")) {
                        TextField("Display Name", text: $manualName)
                    }
                    Section(header: Text("Role")) {
                        Picker("Role", selection: $manualRole) {
                            ForEach(SignerRole.allCases) { role in
                                Text(role.rawValue).tag(role)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .navigationTitle("Add Participant")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showManualEntry = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            let name = manualName.isEmpty ? manualHandleOrDID : manualName
                            participants.append(Participant(
                                name: name,
                                email: "",
                                didOrHandle: manualHandleOrDID,
                                role: manualRole,
                                source: .manual
                            ))
                            showManualEntry = false
                            manualHandleOrDID = ""
                            manualName = ""
                            manualRole = .signator
                        }
                        .disabled(manualHandleOrDID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showFriendsPicker) {
            FriendsPickerSheet(onDone: { selections in
                for sel in selections { participants.append(sel) }
                showFriendsPicker = false
            }, onCancel: { showFriendsPicker = false })
        }
        .sheet(isPresented: $showPersonasPicker) {
            PersonasPickerSheet(personaManager: personaManager, onDone: { selections in
                for sel in selections { participants.append(sel) }
                showPersonasPicker = false
            }, onCancel: { showPersonasPicker = false })
        }
        .alert("Send Failed", isPresented: .constant(sendErrorMessage != nil), actions: {
            Button("OK") { sendErrorMessage = nil }
        }, message: {
            Text(sendErrorMessage ?? "Unknown error")
        })
        .alert("Document Sent", isPresented: .constant(sendSuccessMessage != nil), actions: {
            Button("OK") { sendSuccessMessage = nil }
        }, message: {
            Text(sendSuccessMessage ?? "")
        })
    }
    
    // MARK: - Send Document Method
    
    private func sendDocument() async {
        print("🚀 [sendDocument] Starting document send...")

        // Prepare document data and filename based on selectedDocument
        guard let selectedDocument else {
            print("❌ [sendDocument] No selected document!")
            await MainActor.run { sendErrorMessage = "No document selected to send" }
            return
        }
        
        var documentData: Data
        let originalFilename: String
        
        switch selectedDocument {
        case .inlineText(let text, let suggestedFilename):
            print("📄 [sendDocument] Inline text length: \(text.count) characters")
            documentData = text.data(using: .utf8) ?? Data()
            originalFilename = suggestedFilename
        case .fileURL(let url, let displayName):
            print("📄 [sendDocument] File URL: \(url)")
            do {
                documentData = try Data(contentsOf: url)
            } catch {
                print("❌ [sendDocument] Failed reading file: \(error)")
                await MainActor.run { sendErrorMessage = "Failed to read selected file" }
                return
            }
            originalFilename = displayName
        }
        
        do {
            if let embedded = try embedMetadataIfNeeded(documentData: documentData, filename: originalFilename) {
                documentData = embedded
            }
        } catch {
            await MainActor.run {
                sendErrorMessage = "Failed to embed metadata: \(error.localizedDescription)"
                isSending = false
            }
            return
        }

        print("📦 [sendDocument] Document data size: \(documentData.count) bytes")

        await MainActor.run {
            isSending = true
            sendProgressValue = 0
            sendProgressMessage = "Preparing upload..."
            resetSendSummary()
        }

        var waitForSSECompletion = false
        defer {
            if !waitForSSECompletion {
                Task { @MainActor in isSending = false }
            }
        }

        do {
            print("📤 [sendDocument] Calling DocumentSigningService.uploadDocument()...")
            let uploadResponse = try await DocumentSigningService.uploadDocument(
                documentData: documentData,
                originalFilename: originalFilename,
                metadata: nil,
                useEmbeddedMetadata: true,
                onTransportProgress: { fraction in
                    let clamped = max(0.0, min(1.0, fraction))
                    let percent = Int(clamped * 100)
                    Task { @MainActor in
                        sendProgressValue = clamped
                        sendProgressMessage = "Uploading... \(percent)%"
                    }
                }
            )
            print("✅ Document uploaded successfully! ID: \(uploadResponse)")

            if let taskId = uploadResponse.taskId, !taskId.isEmpty {
                waitForSSECompletion = true
                await MainActor.run {
                    sendProgressMessage = "Processing on server..."
                }
                await connectSSEProgress(taskId: taskId)
            } else {
                await MainActor.run {
                    sendProgressValue = 1.0
                    sendProgressMessage = "Finalizing…"
                }
            }

            do {
                try persistInitiatedSigning(
                    uploadResponse: uploadResponse,
                    originalFilename: originalFilename,
                    documentData: documentData,
                    selectedDocument: selectedDocument,
                    participants: participants
                )
            } catch {
                ClientLogger.warning(
                    component: LogComponent.documentService,
                    "Saved to server, but failed to persist local record: \(error.localizedDescription)"
                )
            }
            
            await MainActor.run {
                if let onSend {
                    // For compatibility, pass inline text if available; otherwise nil
                    let inlineText: String?
                    switch selectedDocument {
                    case .inlineText(let text, _): inlineText = text
                    case .fileURL: inlineText = nil
                    }
                    onSend(participants, inlineText)
                }
                if !waitForSSECompletion {
                    sendSuccessMessage = "Document uploaded successfully."
                }
            }
        } catch {
            print("❌ [sendDocument] Send failed: \(error)")
            await MainActor.run { sendErrorMessage = "Failed to send document: \(error.localizedDescription)" }
        }
    }

    private func embedMetadataIfNeeded(documentData: Data, filename: String) throws -> Data? {
        let metadata = buildMetadataWithParticipants()
        guard let metadata else { return nil }
        do {
            return try DocumentMetadataEmbedder.embed(metadata: metadata, into: documentData, filename: filename)
        } catch {
            ClientLogger.error(
                component: LogComponent.documentService,
                "Failed to embed metadata: \(error.localizedDescription)"
            )
            throw error
        }
    }

    private func buildMetadataWithParticipants() -> DocumentMetadata451? {
        let base = metadataForm.toMetadata()
        let signers = participants.compactMap { participant -> DocumentMetadata451.SignerMetadata? in
            let did = participant.didOrHandle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let resolvedDID = did.isEmpty ? participant.email.trimmingCharacters(in: .whitespacesAndNewlines) : did
            guard !resolvedDID.isEmpty else { return nil }
            return DocumentMetadata451.SignerMetadata(
                did: resolvedDID,
                role: signerRoleString(participant.role),
                publicKey: nil,
                displayName: participant.name.isEmpty ? nil : participant.name
            )
        }

        if base == DocumentMetadata451() && signers.isEmpty {
            return nil
        }

        var enriched = base
        if !signers.isEmpty {
            enriched.signers = signers
        }
        return enriched
    }

    private func signerRoleString(_ role: SignerRole) -> String {
        switch role {
        case .author:
            return "author"
        case .witness:
            return "witness"
        case .notary:
            return "notary"
        case .signator:
            return "contractParty"
        }
    }

    private func persistInitiatedSigning(
        uploadResponse: DocumentSigningService.UploadResponse,
        originalFilename: String,
        documentData: Data,
        selectedDocument: SelectedDocument,
        participants: [Participant]
    ) throws {
        let documentUUID = uploadResponse.folder ?? uploadResponse.documentId
        let version = ISO8601DateFormatter().string(from: Date())
        let contentType: String
        let sourceURL: URL

        switch selectedDocument {
        case .inlineText:
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(documentUUID)-\(version).txt")
            try documentData.write(to: tempURL, options: .atomic)
            sourceURL = tempURL
            contentType = "text/plain"
        case .fileURL(let url, _):
            sourceURL = url
            if url.pathExtension.lowercased() == "pdf" {
                contentType = "application/pdf"
            } else {
                contentType = "application/octet-stream"
            }
        }

        let (absoluteURL, relativePath) = try InitiatedSigningStore.shared.copyDocumentToStore(
            sourceURL: sourceURL,
            documentUUID: documentUUID,
            version: version,
            contentType: contentType
        )

        let attrs = try FileManager.default.attributesOfItem(atPath: absoluteURL.path)
        let fileSize = (attrs[.size] as? NSNumber)?.int64Value ?? 0

        var metaDict: [String: String] = [
            "documentId": uploadResponse.documentId,
            "folder": uploadResponse.folder ?? "",
            "documentURL": uploadResponse.documentURL ?? "",
            "metadataURL": uploadResponse.metadataURL ?? "",
            "didDocumentURL": uploadResponse.didDocumentURL ?? "",
            "taskId": uploadResponse.taskId ?? ""
        ]

        metaDict = metaDict.filter { !$0.value.isEmpty }

        let authors = participants
            .filter { $0.role == .author }
            .map { $0.didOrHandle ?? $0.email }
            .compactMap { $0 }

        let contractParties = participants
            .filter { $0.role != .author }
            .map { $0.didOrHandle ?? $0.email }
            .compactMap { $0 }

        let record = InitiatedSigningRecord(
            id: UUID().uuidString,
            documentUUID: documentUUID,
            version: version,
            title: originalFilename,
            originalFilename: originalFilename,
            savedFilePath: relativePath,
            fileSize: fileSize,
            contentType: contentType,
            createdAt: version,
            metadata: metaDict,
            contractParties: contractParties,
            authors: authors,
            accessCode: uploadResponse.accessCode
        )

        InitiatedSigningStore.shared.append(record)
    }

    private var vesselProviderSummary: String {
        let providers = vesselProviders.sorted()
        if providers.isEmpty {
            return "Waiting for storage providers"
        }
        return providers.joined(separator: "; ")
    }

    private func statusRow(title: String, detail: String?, isDone: Bool) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isDone ? .green : .secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func resetSendSummary() {
        vesselProviders.removeAll()
        vesselCreated = false
        documentUploaded = false
        didUploaded = false
        metadataUploaded = false
        signaturesUploaded = false
        indexingComplete = false
    }

    private func markAllSummaryComplete() {
        if vesselProviders.isEmpty {
            vesselProviders = ["Backblaze B2", "Cloudflare R2", "S3.451.info"]
        }
        vesselCreated = true
        documentUploaded = true
        didUploaded = true
        metadataUploaded = true
        signaturesUploaded = true
        indexingComplete = true
    }

    private func waitForProgressPresentation() async {
        try? await Task.sleep(nanoseconds: 1_500_000_000)
    }

    private func connectSSEProgress(taskId: String) async {
        let client = ProductionSSEClient()
        await MainActor.run { sseClient = client }
        await client.connectToProgressStream(
            baseURL: ServerConfig.baseURL,
            taskId: taskId,
            onProgress: { progress in
                Task { @MainActor in
                    handleProgressStep(progress)
                }
            },
            onComplete: { completion in
                Task { @MainActor in
                    markAllSummaryComplete()
                    sendProgressValue = 1.0
                    sendProgressMessage = completion.message ?? "Document processing complete"
                    await waitForProgressPresentation()
                    sendSuccessMessage = "Document processed successfully."
                    isSending = false
                    sseClient?.disconnect()
                    sseClient = nil
                }
            },
            onError: { error in
                Task { @MainActor in
                    if error.message.lowercased().contains("task not found") {
                        markAllSummaryComplete()
                        sendProgressValue = 1.0
                        sendProgressMessage = "Server finished before progress stream"
                        await waitForProgressPresentation()
                        sendSuccessMessage = "Document processed successfully."
                        isSending = false
                        sseClient?.disconnect()
                        sseClient = nil
                    } else {
                        sendErrorMessage = "Server processing error: \(error.message)"
                        isSending = false
                        sseClient?.disconnect()
                        sseClient = nil
                    }
                }
            },
            onStreamClosed: {
                Task { @MainActor in
                    markAllSummaryComplete()
                    sendProgressValue = 1.0
                    sendProgressMessage = "Server stream closed"
                    await waitForProgressPresentation()
                    sendSuccessMessage = "Document processed successfully."
                    isSending = false
                    sseClient?.disconnect()
                    sseClient = nil
                }
            }
        )
    }

    private func handleProgressStep(_ progress: ProgressStep) {
        let mapped = ServerProgressMapper.mapServerStep(progress.step, serverProgress: progress.progress)
        sendProgressValue = mapped.progress
        sendProgressMessage = mapped.description
        updateSummary(for: progress)
    }

    private func updateSummary(for progress: ProgressStep) {
        let step = progress.step.lowercased()
        if let provider = providerName(from: progress) {
            vesselProviders.insert(provider)
            vesselCreated = true
        }

        if step.contains("s3_upload") {
            vesselCreated = true
        }

        if step.contains("s3_upload_complete") || step.contains("document_uploaded") || step.contains("upload_complete") {
            documentUploaded = true
        }

        if step.contains("did_document") || step.contains("did_uploaded") || step.contains("did_saved") {
            didUploaded = true
        }

        if step.contains("metadata") && (step.contains("uploaded") || step.contains("saved") || step.contains("created") || step.contains("extracted")) {
            metadataUploaded = true
        }

        if step.contains("signature") && (step.contains("uploaded") || step.contains("saved") || step.contains("created")) {
            signaturesUploaded = true
        }

        if step.contains("index") && (step.contains("complete") || step.contains("indexed")) {
            indexingComplete = true
        }
    }

    private func providerName(from progress: ProgressStep) -> String? {
        let step = progress.step.lowercased()
        let detailsProvider = progress.details?["provider"]?.lowercased() ?? ""

        if step.contains("backblaze") || detailsProvider.contains("backblaze") || detailsProvider.contains("b2") {
            return "Backblaze B2"
        }
        if step.contains("r2") || step.contains("cloudflare") || detailsProvider.contains("r2") || detailsProvider.contains("cloudflare") {
            return "Cloudflare R2"
        }
        if step.contains("minio") || step.contains("s3.451") || step.contains("s3_local") ||
            detailsProvider.contains("minio") || detailsProvider.contains("s3.451") {
            return "S3.451.info"
        }

        return nil
    }
}

struct FriendsPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tempSelections: [ParticipantsAndMetadataView.Participant] = []
    let onDone: ([ParticipantsAndMetadataView.Participant]) -> Void
    let onCancel: () -> Void

    private var collaborators: [PersonaResolvedProfile] { CollaboratorsStore.shared.collaborators }

    var body: some View {
        NavigationStack {
            List {
                if collaborators.isEmpty {
                    Section {
                        Text("No contacts yet. Add collaborators in the Contacts tab to pick signers here.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(collaborators, id: \.did) { profile in
                        HStack {
                            Button(action: { toggleSelection(for: profile) }) {
                                Image(systemName: isSelected(profile.did) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isSelected(profile.did) ? .blue : .secondary)
                            }
                            .buttonStyle(.plain)
                            VStack(alignment: .leading) {
                                Text(profile.displayName)
                                Text(profile.did)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            if let idx = tempSelections.firstIndex(where: { $0.didOrHandle == profile.did }) {
                                Picker("Role", selection: $tempSelections[idx].role) {
                                    ForEach(SignerRole.allCases) { role in
                                        Text(role.rawValue).tag(role)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pick Friends/Colleagues")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { onDone(tempSelections); dismiss() }
                        .disabled(tempSelections.isEmpty)
                }
            }
        }
    }

    private func isSelected(_ did: String) -> Bool { tempSelections.contains(where: { $0.didOrHandle == did }) }

    private func toggleSelection(for profile: PersonaResolvedProfile) {
        if let idx = tempSelections.firstIndex(where: { $0.didOrHandle == profile.did }) {
            tempSelections.remove(at: idx)
        } else {
            tempSelections.append(ParticipantsAndMetadataView.Participant(
                name: profile.displayName,
                email: "",
                didOrHandle: profile.did,
                role: .signator,
                source: .friend
            ))
        }
    }
}

struct PersonasPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let personaManager: PersonaManager
    @State private var tempSelections: [ParticipantsAndMetadataView.Participant] = []
    let onDone: ([ParticipantsAndMetadataView.Participant]) -> Void
    let onCancel: () -> Void

    var personas: [Persona] { personaManager.personas }

    var body: some View {
        NavigationStack {
            List {
                if personas.isEmpty {
                    Section { Text("No personas available.").foregroundColor(.secondary) }
                } else {
                    ForEach(personas, id: \.id) { persona in
                        HStack {
                            Button(action: { toggleSelection(for: persona) }) {
                                Image(systemName: isSelected(persona.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isSelected(persona.id) ? .blue : .secondary)
                            }
                            .buttonStyle(.plain)
                            VStack(alignment: .leading) {
                                Text(persona.id)
                                Text(persona.id)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            if let idx = tempSelections.firstIndex(where: { $0.didOrHandle == persona.id }) {
                                Picker("Role", selection: $tempSelections[idx].role) {
                                    ForEach(SignerRole.allCases) { role in
                                        Text(role.rawValue).tag(role)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pick My Personas")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { onDone(tempSelections); dismiss() }
                        .disabled(tempSelections.isEmpty)
                }
            }
        }
    }

    private func isSelected(_ id: String) -> Bool {
        tempSelections.contains { selection in
            // A selection is considered selected if any temp selection matches the persona's DID for this id
            if let persona = personas.first(where: { $0.id == id }) {
                return selection.didOrHandle == persona.id
            }
            return false
        }
    }

    private func toggleSelection(for persona: Persona) {
        if let idx = tempSelections.firstIndex(where: { $0.didOrHandle == persona.id }) {
            tempSelections.remove(at: idx)
        } else {
            tempSelections.append(ParticipantsAndMetadataView.Participant(
                name: persona.id,
                email: "",
                didOrHandle: persona.id,
                role: .signator,
                source: .persona
            ))
        }
    }
}

struct InitiateHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Initiating Signing Requests")
                        .font(.headline)
                    Text("Use this tab to start new signing requests. You have three options to choose from based on your needs.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sign Existing Document")
                        .font(.headline)
                    Text("Upload a PDF or other document, add metadata, and invite others to sign it.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose from Template")
                        .font(.headline)
                    Text("Start from a pre-configured template with predefined fields and signers. Great for recurring documents like contracts or agreements.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notarize/Verify an Event")
                        .font(.headline)
                    Text("Create a verifiable timestamp for an event or action without requiring a document. Useful for recording agreements or confirmations.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("About Initiating")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    EnhancedSendSigningFlowView(personaManager: PersonaManager(), showPersonaSheet: .constant(false))
}
