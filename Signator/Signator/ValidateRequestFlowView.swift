// ValidateRequestFlowView.swift
// Placeholder view for the Validate tab

import SwiftUI
import PhotosUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
// PlatformImage comes from Common/Platform/PlatformImage.swift — declaring it here as well made
// two module-scope declarations of the same name once Common became shared.

struct ValidateRequestFlowView: View {
    @ObservedObject var personaManager: PersonaManager
    @State private var showIntegritySheet = false
    @State private var showAuthorSheet = false
    @State private var showPersonaSheet = false
    
    @State private var guidInput: String = ""
    @State private var didDocument: String? = nil
    @State private var validationStatus: Bool? = nil
    @State private var isLoading: Bool = false
    
    @State private var authorDocDID: String = ""
    @State private var authorPersonaDID: String = ""
    @State private var authorResult: String? = nil
    @State private var authorStatus: Bool? = nil
    @State private var authorLoading: Bool = false

    @State private var personaToValidate: String = ""
    @State private var humanValidationLoading: Bool = false
    @State private var humanValidationResult: String? = nil
    @State private var humanValidationError: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppTopHeader()
            
            Text("Validation Tools")
                .font(.title3).bold()
                .padding(.leading, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                //.padding(.top, 24)
            Text("Choose a type of validation to initiate:")
                .font(.title3).foregroundColor(.secondary)
            
            VStack(spacing: 18) {
                GlassCardButton(title: "Validate Document Integrity", subtitle: "Verify document content and signatures match records", color: .blue) {
                    showIntegritySheet = true
                }
                .sheet(isPresented: $showIntegritySheet) {
                    NavigationStack {
                        VStack(alignment: .leading, spacing: 18) {
                            if let validated = validationStatus {
                                HStack {
                                    Image(systemName: validated ? "checkmark.seal.fill" : "xmark.seal")
                                        .foregroundColor(validated ? .green : .red)
                                    Text(validated ? "Validated" : "Not Validated")
                                        .foregroundColor(validated ? .green : .red)
                                        .fontWeight(.semibold)
                                }
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(Color(validated ? .systemGreen : .systemRed).opacity(0.08))
                                .cornerRadius(8)
                            }
                            Form {
                                Section(header: Text("Document GUID")) {
                                    TextField("Enter GUID (e.g. d28c1f0b-...-8cf7)", text: $guidInput)
                                        .autocorrectionDisabled(true)
                                }
                                Section {
                                    Button(action: { validateDocument() }) {
                                        if isLoading {
                                            ProgressView()
                                        } else {
                                            Text("Validate")
                                        }
                                    }
                                    .disabled(guidInput.isEmpty || isLoading)
                                }
                            }
                            if let didDoc = didDocument {
                                Text("DIDDocument:")
                                    .font(.headline)
                                ScrollView {
                                    Text(didDoc)
                                        .font(.system(.body, design: .monospaced))
                                        .padding(8)
#if canImport(UIKit)
                                        .background(Color(UIColor.secondarySystemBackground))
#elseif canImport(AppKit)
                                        .background(Color(NSColor.windowBackgroundColor))
#endif
                                        .cornerRadius(6)
                                        .contextMenu { Button("Copy", action: { copyToPasteboard(didDoc) }) }
                                }
                                .frame(maxHeight: 260)
                            }
                            Spacer()
                        }
                        .navigationTitle("Integrity Validation")
#if canImport(UIKit)
                        .inlineNavigationTitle()
#endif
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showIntegritySheet = false }
                            }
                        }
                        .padding()
                    }
                }

                GlassCardButton(title: "Validate Document Author", subtitle: "Check if a persona is a signer/author of a document", color: .green) {
                    showAuthorSheet = true
                }
                .sheet(isPresented: $showAuthorSheet) {
                    NavigationStack {
                        VStack(alignment: .leading, spacing: 18) {
                            if let validated = authorStatus {
                                HStack {
                                    Image(systemName: validated ? "checkmark.seal.fill" : "xmark.seal")
                                        .foregroundColor(validated ? .green : .red)
                                    Text(validated ? "Validated" : "Not Validated")
                                        .foregroundColor(validated ? .green : .red)
                                        .fontWeight(.semibold)
                                }
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(Color(validated ? .systemGreen : .systemRed).opacity(0.08))
                                .cornerRadius(8)
                            }
                            Form {
                                Section(header: Text("Document DID")) {
                                    TextField("Enter Document DID (e.g. did:example:28c1f0b-...)\n", text: $authorDocDID)
                                        .autocorrectionDisabled(true)
                                }
                                Section(header: Text("Persona DID")) {
                                    TextField("Enter Persona DID (e.g. did:example:john-doe)", text: $authorPersonaDID)
                                        .autocorrectionDisabled(true)
                                }
                                Section {
                                    Button(action: { validateAuthorDocument() }) {
                                        if authorLoading {
                                            ProgressView()
                                        } else {
                                            Text("Validate")
                                        }
                                    }
                                    .disabled(authorDocDID.isEmpty || authorPersonaDID.isEmpty || authorLoading)
                                }
                            }
                            if let authorResult = authorResult {
                                Text("Signing Metadata:")
                                    .font(.headline)
                                ScrollView {
                                    Text(authorResult)
                                        .font(.system(.body, design: .monospaced))
                                        .padding(8)
#if canImport(UIKit)
                                        .background(Color(UIColor.secondarySystemBackground))
#elseif canImport(AppKit)
                                        .background(Color(NSColor.windowBackgroundColor))
#endif
                                        .cornerRadius(6)
                                        .contextMenu { Button("Copy", action: { copyToPasteboard(authorResult) }) }
                                }
                                .frame(maxHeight: 220)
                            }
                            Spacer()
                        }
                        .navigationTitle("Author Validation")
#if canImport(UIKit)
                        .inlineNavigationTitle()
#endif
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showAuthorSheet = false }
                            }
                        }
                        .padding()
                    }
                }

                GlassCardButton(title: "Human-to-Persona Validation", subtitle: "Link a real human to a digital persona as proof", color: .orange) {
                    showPersonaSheet = true
                }
                .sheet(isPresented: $showPersonaSheet) {
                    NavigationStack {
                        VStack(alignment: .leading, spacing: 18) {
                            if let result = humanValidationResult {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("Nonce Received", systemImage: "key.fill")
                                        .font(.headline).foregroundColor(.green)
                                    ScrollView {
                                        Text(result)
                                            .font(.system(.body, design: .monospaced))
                                            .padding(8)
#if canImport(UIKit)
                                            .background(Color(UIColor.secondarySystemBackground))
#elseif canImport(AppKit)
                                            .background(Color(NSColor.windowBackgroundColor))
#endif
                                            .cornerRadius(6)
                                            .contextMenu { Button("Copy", action: { copyToPasteboard(result) }) }
                                    }
                                    .frame(maxHeight: 160)
                                }
                                .padding(.bottom, 12)
                            }
                            if let error = humanValidationError {
                                Text(error)
                                    .foregroundColor(.red)
                                    .padding(.bottom, 8)
                            }
                            Form {
                                Section(header: Text("Persona DID To Validate")) {
                                    TextField("Enter Persona DID (e.g. did:example:alice)", text: $personaToValidate)
                                        .autocorrectionDisabled(true)
                                }
                                Section {
                                    Button(action: { initiateHumanToPersonaValidation() }) {
                                        if humanValidationLoading {
                                            ProgressView()
                                        } else {
                                            Text("Request Validation")
                                        }
                                    }
                                    .disabled(personaToValidate.isEmpty || humanValidationLoading)
                                }
                            }
                            Spacer()
                        }
                        .navigationTitle("ID Verification")
#if canImport(UIKit)
                        .inlineNavigationTitle()
#endif
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showPersonaSheet = false }
                            }
                        }
                        .padding()
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .background(Color.white.ignoresSafeArea())
#if os(iOS) || os(watchOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
    }

    private func validateDocument() {
        isLoading = true
        validationStatus = nil
        didDocument = nil
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network call
            // Mock a DIDDocument result for now
            let mockDIDDoc = """
            {
                "@context": "https://www.w3.org/ns/did/v1",
                "id": "did:example:\(guidInput)",
                "controller": ["did:example:author1"],
                "proof": { "type": "Ed25519Signature2018", "created": "2025-08-14T12:00:00Z" }
            }
            """
            await MainActor.run {
                didDocument = mockDIDDoc
                validationStatus = true // Simulate validated
                isLoading = false
            }
        }
    }
    
    private func validateAuthorDocument() {
        authorLoading = true
        authorStatus = nil
        authorResult = nil
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network call
            // Mock a metadata result for now
            let mockMetadata = """
            {
                "document": "\(authorDocDID)",
                "persona": "\(authorPersonaDID)",
                "role": "Author",
                "signed": true,
                "timestamp": "2025-08-14T12:03:00Z"
            }
            """
            await MainActor.run {
                authorResult = mockMetadata
                authorStatus = true // Simulate validated
                authorLoading = false
            }
        }
    }

    private func initiateHumanToPersonaValidation() {
        humanValidationLoading = true
        humanValidationError = nil
        humanValidationResult = nil
        let did = personaToValidate
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay
            // Mock nonce result from server
            let simulatedNonce = """
            Human-to-Persona Nonce:
            - Persona: \(did)
            - Timestamp: \(ISO8601DateFormatter().string(from: Date()))
            - GPS: 37.7749, -122.4194
            """
            await MainActor.run {
                humanValidationLoading = false
                humanValidationResult = simulatedNonce
                // Uncomment to simulate error:
                // humanValidationError = "Failed to contact server."
            }
        }
    }
}

// Helper GlassCardButton control for visual consistency
struct GlassCardButton: View {
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    Circle().fill(color.opacity(0.16)).frame(width: 44, height: 44)
                    Image(systemName: iconName).foregroundColor(color).font(.system(size: 24, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundColor(.primary)
                    Text(subtitle).font(.footnote).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.gray)
            }
            .padding(18)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: color.opacity(0.10), radius: 8, x: 0, y: 6)
        }
    }
    
    // Choose icon based on title (simple heuristic)
    private var iconName: String {
        if title.contains("Integrity") { return "checkmark.shield" }
        if title.contains("Author") { return "person.crop.circle.badge.checkmark" }
        if title.contains("Human-to-Persona") { return "person.text.rectangle" }
        if title.contains("Witness") { return "quote.bubble" }
        return "doc"
    }
}

#if canImport(UIKit)
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var images: [PlatformImage]
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 6
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            for result in results {
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                    if let image = object as? UIImage {
                        DispatchQueue.main.async {
                            self.parent.images.append(image)
                        }
                    }
                }
            }
        }
    }
}
#elseif canImport(AppKit)
struct PhotoPicker: NSViewControllerRepresentable {
    @Binding var images: [PlatformImage]

    func makeNSViewController(context: Context) -> NSViewController {
        let viewController = NSViewController()
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = true
            panel.allowedFileTypes = ["public.image"]
            panel.begin { response in
                if response == .OK {
                    for url in panel.urls {
                        if let nsImage = NSImage(contentsOf: url) {
                            self.images.append(nsImage)
                        }
                    }
                }
            }
        }
        return viewController
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
}
#endif

private func copyToPasteboard(_ text: String) {
    #if canImport(UIKit)
    UIPasteboard.general.string = text
    #elseif canImport(AppKit)
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    #endif
}

