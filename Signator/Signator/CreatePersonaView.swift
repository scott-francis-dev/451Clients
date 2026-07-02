import SwiftUI
import CryptoKit

private let rootLevelTLDs: Set<String> = [
    ".com", ".org", ".edu", ".net", ".gov", ".io", ".co", ".us", ".biz", ".info", ".me", ".dev", ".ai", ".app", ".tv", ".xyz", ".pro", ".ca", ".uk", ".de", ".fr", ".it", ".es", ".jp", ".ru", ".au", ".ch", ".nl", ".in", ".br", ".za", ".pl", ".be", ".eu", ".tr", ".fi", ".gr", ".no", ".se", ".ae", ".cz", ".hu", ".dk", ".hk", ".sg", ".nz", ".mx", ".ar", ".cl", ".il", ".ie", ".kr", ".cn", ".tw", ".pt", ".sk", ".ro", ".bg", ".lv", ".lt", ".ee"
]

struct CreatePersonaView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var personaManager: PersonaManager
    
    @State private var givenName: String = ""
    @State private var address: String = ""
    @State private var didInput: String = ""
    @State private var affiliations: String = ""
    @State private var socialLinks: String = ""
    @State private var errorMessage: String? = nil
    
    private var normalizedDID: String {
        // Normalize input to server-accepted @handle format:
        // - starts with '@'
        // - only lowercase letters and periods
        // - collapse separators and multiple periods
        var s = didInput.lowercased()

        // If input looks like 'left @ right' or contains '@', convert to '@left.right'
        if let range = s.range(of: " at ") {
            let left = String(s[..<range.lowerBound])
            let right = String(s[range.upperBound...])
            s = "@\(left).\(right)"
        } else if let atIndex = s.firstIndex(of: "@") {
            let left = String(s[..<atIndex])
            let right = String(s[s.index(after: atIndex)...])
            if !left.isEmpty {
                s = "@\(left).\(right)"
            } else {
                s = "@\(right)"
            }
        } else {
            // No '@' — add it
            s = "@" + s
        }

        // Replace common separators with periods
        s = s.replacingOccurrences(of: " ", with: ".")
            .replacingOccurrences(of: "_", with: ".")
            .replacingOccurrences(of: "-", with: ".")

        // Keep only '@', '.', and lowercase letters
        let allowed: Set<Character> = Set("@.abcdefghijklmnopqrstuvwxyz")
        s = String(s.filter { allowed.contains($0) })

        // Collapse multiple periods
        while s.contains("..") {
            s = s.replacingOccurrences(of: "..", with: ".")
        }

        // Ensure starts with '@'
        if !s.hasPrefix("@") {
            s = "@" + s
        }

        // Trim leading/trailing periods after '@'
        var body = String(s.dropFirst())
        body = body.trimmingCharacters(in: CharacterSet(charactersIn: "."))

        // Enforce max length 500
        let rebuilt = "@" + body
        return rebuilt.count > 500 ? String(rebuilt.prefix(500)) : rebuilt
    }
    
    private var isDIDValid: Bool {
        validationState().isValid
    }
    
    private func deriveGivenName() -> String {
        // Derive a human-friendly name from the handle by using text before '@' if present,
        // otherwise the text after '@'
        let separators = ["@", " at "]
        var firstPart = didInput
        var secondPart = ""
        for sep in separators {
            if let range = didInput.range(of: sep, options: .caseInsensitive) {
                firstPart = String(didInput[..<range.lowerBound])
                secondPart = String(didInput[range.upperBound...])
                break
            }
        }
        // Prefer non-empty part; for @handle, firstPart may be empty, so use secondPart
        let source = firstPart.isEmpty ? secondPart : firstPart

        // Replace common separators with spaces and title-case the words
        let cleaned = source
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        let words = cleaned
            .split(separator: " ")
            .map { word -> String in
                let lower = word.lowercased()
                return lower.prefix(1).uppercased() + lower.dropFirst()
            }
        return words.joined(separator: " ")
    }

    private func validationState() -> (isValid: Bool, reason: String?) {
        let handle = normalizedDID

        // Must start with '@'
        guard handle.hasPrefix("@") else {
            return (false, "Handle must start with '@'")
        }

        // Length check
        if handle.count > 500 {
            return (false, "Too long (max 500 characters)")
        }

        // Only lowercase letters and periods after '@'
        let body = String(handle.dropFirst())
        if body.first(where: { !($0 >= "a" && $0 <= "z") && $0 != "." }) != nil {
            return (false, "Only lowercase letters and periods are allowed")
        }

        // No empty segments; no leading/trailing periods
        let segments = body.split(separator: ".", omittingEmptySubsequences: false)
        if segments.isEmpty {
            return (false, "Handle must include at least one period")
        }
        if segments.contains(where: { $0.isEmpty }) {
            return (false, "No empty segments (e.g., '..' or leading/trailing '.')")
        }

        // Period count between 1 and 10 inclusive
        let periodCount = body.filter { $0 == "." }.count
        if periodCount < 1 || periodCount > 10 {
            return (false, "Include between 1 and 10 periods")
        }

        // At least 8 letters total (exclude periods)
        let lettersCount = body.filter { $0 >= "a" && $0 <= "z" }.count
        if lettersCount < 8 {
            return (false, "At least 8 letters required")
        }

        // Duplicate check using normalized id
        let isDuplicate = personaManager.personas.contains { p in
            p.id.lowercased() == handle.lowercased()
        }
        if isDuplicate {
            return (false, "A persona with this ID already exists")
        }

        return (true, nil)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Keep DID at the top
                Section(header: Text("Username or Handle")) {
                    TextField("Enter a handle starting with @ (at least 8 letters, include a period .)", text: $didInput)
                        .autocorrectionDisabled(true)
                        .onChange(of: didInput) { _ in
                            // Auto-fill Given Name from the handle's left part if user hasn't set it
                            if givenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                let derived = deriveGivenName()
                                if !derived.isEmpty { givenName = derived }
                            }
                        }
                    HStack {
                        Text("Normalized:")
                        Spacer()
                        Text(normalizedDID)
                            .foregroundColor(.secondary)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if !didInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: validationState().isValid ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                .foregroundColor(validationState().isValid ? .green : .red)
                            Text(validationState().isValid ? "Looks good" : (validationState().reason ?? "Invalid input"))
                                .font(.footnote)
                                .foregroundColor(validationState().isValid ? .green : .red)
                        }
                        .padding(.top, 2)
                    }
                }
                // Then Name
                Section(header: Text("Given Name (for Contracts)")) {
                    TextField("Given Name", text: $givenName)
                }
                // Then Address
                Section(header: Text("Address")) {
                    TextField("Address", text: $address)
                }
                // Then Affiliations
                Section(header: Text("Affiliations")) {
                    TextField("Affiliations", text: $affiliations)
                }
                // Then Social Links
                Section(header: Text("Social Links")) {
                    TextField("Social Links (comma-separated URLs)", text: $socialLinks)
                }
                Section {
                    Button("Create Persona") {
                        createPersona()
                    }
                    .disabled(!isDIDValid || givenName.isEmpty)
                }
            }
            .navigationTitle("New Persona")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Error", isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { _ in errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func createPersona() {
        guard isDIDValid else {
            errorMessage = "The normalized Persona DID is invalid or already exists."
            return
        }
        
        // Generate a new keypair for this persona
        let privateKey = P256.Signing.PrivateKey()
        let publicKeyRaw = privateKey.publicKey.rawRepresentation
        
        // Ensure uncompressed format begins with 0x04 and is 65 bytes if needed
        let publicKeyUncompressed: Data
        if publicKeyRaw.count == 65 && publicKeyRaw.first == 0x04 {
            publicKeyUncompressed = publicKeyRaw
        } else if publicKeyRaw.count == 64 {
            publicKeyUncompressed = Data([0x04]) + publicKeyRaw
        } else {
            // Fallback to whatever representation exists
            publicKeyUncompressed = publicKeyRaw
        }
        let publicKeyBase64 = publicKeyUncompressed.base64EncodedString()
        
        // Persist the private key for this DID
        try? PrivateKeyStore.savePrivateKey(privateKey, for: normalizedDID)
        
        // Build lightweight Persona and add it
        let now = ISO8601DateFormatter().string(from: Date())
        let persona = Persona(
            id: normalizedDID,
            controller: normalizedDID,
            name: givenName.isEmpty ? normalizedDID : givenName,
            handle: normalizedDID,
            address: address.isEmpty ? nil : address,
            affiliations: affiliations.isEmpty ? nil : affiliations,
            socialLinks: socialLinks.isEmpty ? nil : socialLinks,
            publicKeyBase64: publicKeyBase64,
            storageEndpoints: nil,
            createdAt: now,
            updatedAt: nil,
            eTag: nil,
            status: "active"
        )
        
        personaManager.addPersona(persona)
        presentationMode.wrappedValue.dismiss()
    }
}
