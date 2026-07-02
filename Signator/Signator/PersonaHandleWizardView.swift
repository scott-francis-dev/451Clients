// PersonaHandleWizardView.swift
// Signator
//
// The pre-wizard that explains the persona handle concept before entering
// the main persona creation flow.
//
// Flow: Explainer → Name Input → Publishing House → [Domain Verify] → PersonaTypeSelectionView
//

import SwiftUI

// MARK: - Wizard State

final class PersonaHandleWizardState: ObservableObject {
    @Published var personaName: String = ""
    @Published var publishingHouse: String = ""

    // Domain-specific state
    @Published var useInternetDomain: Bool = false
    @Published var internetDomain: String = ""       // e.g. "mycompany.com"
    @Published var domainVerified: Bool = false
    @Published var domainVerificationMethod: DomainVerificationMethod = .email

    enum DomainVerificationMethod: String, CaseIterable {
        case dns    // User adds a TXT record — proves they own the whole domain
        case email  // Server emails a 6-digit code — proves they belong to the domain
    }

    // The label preview shown throughout the wizard
    var handlePreview: String {
        let n = normalizedSegment(personaName)
        let h = normalizedSegment(useInternetDomain ? internetDomain : publishingHouse)
        if n.isEmpty && h.isEmpty { return "your.name · publishing.house" }
        if h.isEmpty { return n.isEmpty ? "your.name" : n }
        return "\(n) · \(h)"
    }

    func normalizedSegment(_ input: String) -> String {
        var s = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: " ", with: ".")
        // Collapse consecutive periods or dashes that spaces may have produced
        while s.contains("..") { s = s.replacingOccurrences(of: "..", with: ".") }
        while s.contains("--") { s = s.replacingOccurrences(of: "--", with: "-") }
        return s
    }

    // Validation
    var nameIsValid: Bool { isValidSegment(personaName) }
    var publishingHouseIsValid: Bool {
        publishingHouse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || isValidSegment(publishingHouse)
    }

    private func isValidSegment(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 4 else { return false }
        guard !t.hasPrefix("-") && !t.hasSuffix("-") else { return false }
        guard !t.hasPrefix(".") && !t.hasSuffix(".") else { return false }
        guard !t.contains("..") && !t.contains("--") else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-. "))
        return t.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

// MARK: - Entry Point

/// Drop this in place of PersonaTypeSelectionView everywhere the + button is handled.
struct PersonaHandleWizardView: View {
    @StateObject private var wizardState = PersonaHandleWizardState()
    @EnvironmentObject var personaManager: PersonaManager

    var body: some View {
        NavigationStack {
            HandleExplainerView()
                .environmentObject(wizardState)
                .environmentObject(personaManager)
                .navigationTitle("New Persona")
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { personaManager.dismissCreationFlow = true }
                    }
                }
        }
    }
}

// MARK: - Screen 1: Explainer

private struct HandleExplainerView: View {
    @EnvironmentObject var wizardState: PersonaHandleWizardState
    @EnvironmentObject var personaManager: PersonaManager
    @State private var navigateToName = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // ── Hero visual ──────────────────────────────────────────────
                VStack(spacing: 16) {
                    // Animated calling-card mockup
                    HandleMockupView(
                        leftLabel: "sara.silver",
                        rightLabel: "silver.publishing",
                        isPublic: true
                    )
                    .padding(.horizontal, 8)

                    Text("Every persona has a two-part handle.")
                        .font(.title2).fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                // ── Part 1 ───────────────────────────────────────────────────
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                        .frame(width: 40, height: 40)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("The Persona Name")
                            .font(.headline)
                        Text("This is your identity within a publishing house — the author, the professional, the voice. It appears to the left of the blue dot.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // ── Blue dot ────────────────────────────────────────────────
                HStack {
                    Spacer()
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.5, blue: 1.0),
                                         Color(red: 0.1, green: 0.3, blue: 0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 14, height: 14)
                        .shadow(color: .blue.opacity(0.5), radius: 6)
                    Text("separates the two parts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                // ── Part 2 ───────────────────────────────────────────────────
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.indigo)
                        .frame(width: 40, height: 40)
                        .background(Color.indigo.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("The Publishing House")
                            .font(.headline)
                        Text("This is your brand, studio, organization, or domain — the entity that stands behind your work. It appears to the right of the blue dot.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // ── DID note ─────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    Label("Under the hood, your true identifier is a permanent cryptographic DID — not the label above.", systemImage: "key.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("The handle label can change; your DID never does.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.platformGray6)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                // ── Continue ─────────────────────────────────────────────────
                Button {
                    navigateToName = true
                } label: {
                    Text("Let's Build Your Handle")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.top, 4)
            }
            .padding()
        }
        .navigationDestination(isPresented: $navigateToName) {
            HandleNameInputView()
                .environmentObject(wizardState)
                .environmentObject(personaManager)
        }
    }
}

// MARK: - Screen 2: Persona Name

private struct HandleNameInputView: View {
    @EnvironmentObject var wizardState: PersonaHandleWizardState
    @EnvironmentObject var personaManager: PersonaManager
    @State private var navigateToHouse = false
    @FocusState private var fieldFocused: Bool

    private var namePreview: String {
        let n = wizardState.normalizedSegment(wizardState.personaName)
        return n.isEmpty ? "your.name" : n
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .leading, spacing: 6) {
                    Text("Choose your persona name.")
                        .font(.title2).fontWeight(.bold)
                    Text("This is the left side of your handle — the author or professional identity.")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .padding(.top, 8)

                // Live preview
                HandleMockupView(
                    leftLabel: namePreview,
                    rightLabel: "publishing.house",
                    isPublic: true,
                    highlightLeft: true
                )

                // Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Persona Name")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    TextField("e.g. Sara Silver", text: $wizardState.personaName)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .padding()
                        .background(Color.platformGray6)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .autocorrectionDisabled()
                        .platformAutocapitalization(.never)
                        .focused($fieldFocused)
                }

                // Rules
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rules")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(.secondary).textCase(.uppercase)

                    RuleRow(
                        text: "At least 4 characters",
                        passed: wizardState.personaName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4
                    )
                    RuleRow(
                        text: "Letters, numbers, periods, and dashes only — no other symbols",
                        passed: {
                            let t = wizardState.personaName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-. "))
                            return !t.isEmpty && t.unicodeScalars.allSatisfy { allowed.contains($0) }
                        }()
                    )
                    RuleRow(
                        text: "Cannot start or end with a dash or period",
                        passed: {
                            let t = wizardState.personaName.trimmingCharacters(in: .whitespacesAndNewlines)
                            return !t.isEmpty && !t.hasPrefix("-") && !t.hasSuffix("-") && !t.hasPrefix(".") && !t.hasSuffix(".")
                        }()
                    )
                    RuleRow(
                        text: "No consecutive periods or dashes (e.g. 'sara..silver' is not allowed)",
                        passed: {
                            let t = wizardState.personaName.trimmingCharacters(in: .whitespacesAndNewlines)
                            return !t.isEmpty && !t.contains("..") && !t.contains("--")
                        }()
                    )
                }
                .padding(14)
                .background(Color.platformGray6)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Tip: periods create sub-parts
                Label("Periods separate sub-parts of a name. 'sara.silver' becomes two parts: 'sara' and 'silver'.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button {
                    navigateToHouse = true
                } label: {
                    HStack {
                        Text("Next: Publishing House")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(wizardState.nameIsValid ? Color.blue : Color.gray.opacity(0.4))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!wizardState.nameIsValid)
                .animation(.easeInOut(duration: 0.2), value: wizardState.nameIsValid)
            }
            .padding()
        }
        .navigationTitle("Persona Name")
        .inlineNavigationTitle()
        .navigationDestination(isPresented: $navigateToHouse) {
            HandlePublishingHouseView()
                .environmentObject(wizardState)
                .environmentObject(personaManager)
        }
        .onAppear { fieldFocused = true }
    }
}

// MARK: - Screen 3: Publishing House

private struct HandlePublishingHouseView: View {
    @EnvironmentObject var wizardState: PersonaHandleWizardState
    @EnvironmentObject var personaManager: PersonaManager
    @State private var navigateToTypeSelection = false
    @State private var navigateToDomainVerify = false
    @FocusState private var fieldFocused: Bool

    private var housePreview: String {
        let h = wizardState.normalizedSegment(wizardState.publishingHouse)
        return h.isEmpty ? "publishing.house" : h
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .leading, spacing: 6) {
                    Text("Choose your publishing house.")
                        .font(.title2).fontWeight(.bold)
                    Text("This is the right side of your handle — the brand or organization that stands behind your work.")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .padding(.top, 8)

                // Live preview
                HandleMockupView(
                    leftLabel: wizardState.normalizedSegment(wizardState.personaName),
                    rightLabel: housePreview,
                    isPublic: true,
                    highlightRight: true
                )

                // Decentralized concept explanation
                VStack(alignment: .leading, spacing: 8) {
                    Label("A decentralized concept", systemImage: "network")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(.indigo)

                    Text("A publishing house is not owned by any platform. It can be any name you choose — a studio, a collective, a personal brand — or it can be an internet domain you already own.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(Color.indigo.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.indigo.opacity(0.2), lineWidth: 1)
                )

                // Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Publishing House Name")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(.secondary).textCase(.uppercase)

                    TextField("e.g. Silver Publishing", text: $wizardState.publishingHouse)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .padding()
                        .background(Color.platformGray6)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .autocorrectionDisabled()
                        .platformAutocapitalization(.never)
                        .focused($fieldFocused)

                    Text("Leave blank to publish under our default domain (451.info).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Internet domain button
                Button {
                    navigateToDomainVerify = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 36, height: 36)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("I'll use my internet domain")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Use .com, .org, .edu, or any domain you own. It will be corroborated. Let's do that now →")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(Color.platformBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.blue.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                Divider()

                Button {
                    navigateToTypeSelection = true
                } label: {
                    HStack {
                        Text("Continue")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding()
        }
        .navigationTitle("Publishing House")
        .inlineNavigationTitle()
        .navigationDestination(isPresented: $navigateToTypeSelection) {
            PersonaTypeSelectionView(
                initialName: wizardState.personaName,
                initialPublishingHouse: wizardState.publishingHouse
            )
            .environmentObject(personaManager)
        }
        .navigationDestination(isPresented: $navigateToDomainVerify) {
            HandleDomainVerificationView(onVerified: {
                navigateToTypeSelection = true
            })
            .environmentObject(wizardState)
            .environmentObject(personaManager)
        }
        .onAppear { fieldFocused = false }
    }
}

// MARK: - Screen 4: Domain Verification

struct HandleDomainVerificationView: View {
    @EnvironmentObject var wizardState: PersonaHandleWizardState
    @EnvironmentObject var personaManager: PersonaManager
    var onVerified: () -> Void

    @State private var domainInput: String = ""
    @State private var selectedMethod: PersonaHandleWizardState.DomainVerificationMethod = .email

    // DNS flow
    @State private var dnsChallenge: String = ""
    @State private var dnsVerifying = false
    @State private var dnsResult: VerificationResult? = nil

    // Email flow
    @State private var emailPrefix: String = "admin"
    @State private var emailSent = false
    @State private var emailSending = false
    @State private var codeInput: String = ""
    @State private var emailVerifying = false
    @State private var emailResult: VerificationResult? = nil

    enum VerificationResult { case success, failure(String) }

    private var domainForVerification: String {
        domainInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var verificationEmail: String { "\(emailPrefix)@\(domainForVerification)" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .leading, spacing: 6) {
                    Text("Verify your domain.")
                        .font(.title2).fontWeight(.bold)
                    Text("Two ways to prove your relationship to a domain. Choose the one that fits.")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .padding(.top, 8)

                // Domain input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Domain")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(.secondary).textCase(.uppercase)

                    TextField("e.g. mycompany.com", text: $domainInput)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .padding()
                        .background(Color.platformGray6)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .autocorrectionDisabled()
                        .platformAutocapitalization(.never)
                        .platformKeyboardType(.url)
                }

                // Method picker
                Picker("Verification method", selection: $selectedMethod) {
                    Text("Email code").tag(PersonaHandleWizardState.DomainVerificationMethod.email)
                    Text("DNS record").tag(PersonaHandleWizardState.DomainVerificationMethod.dns)
                }
                .pickerStyle(.segmented)

                // ── DNS method ──────────────────────────────────────────────
                if selectedMethod == .dns {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "server.rack")
                                .foregroundColor(.indigo)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("DNS TXT Record")
                                    .font(.headline)
                                Text("Proves you control the entire domain — ideal for organizations.")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }

                        if dnsChallenge.isEmpty {
                            Button {
                                dnsChallenge = "signator-verify=\(UUID().uuidString.lowercased().prefix(16))"
                            } label: {
                                Text("Generate Challenge Token")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.indigo.opacity(0.12))
                                    .foregroundColor(.indigo)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Add this TXT record to your DNS:")
                                    .font(.subheadline).fontWeight(.medium)

                                VStack(alignment: .leading, spacing: 4) {
                                    dnsRow(label: "Host", value: "_signator-verify.\(domainForVerification.isEmpty ? "yourdomain.com" : domainForVerification)")
                                    dnsRow(label: "Type", value: "TXT")
                                    dnsRow(label: "Value", value: dnsChallenge)
                                    dnsRow(label: "TTL", value: "300")
                                }
                                .padding(12)
                                .background(Color.platformGray6)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.indigo.opacity(0.2), lineWidth: 1)
                                )

                                Text("DNS changes can take up to 48 hours to propagate, but usually just minutes.")
                                    .font(.caption).foregroundColor(.secondary)

                                if case .failure(let msg) = dnsResult {
                                    Label(msg, systemImage: "xmark.circle.fill")
                                        .font(.caption).foregroundColor(.red)
                                }
                                if case .success = dnsResult {
                                    Label("Domain verified!", systemImage: "checkmark.circle.fill")
                                        .font(.subheadline).fontWeight(.semibold).foregroundColor(.green)
                                }

                                Button {
                                    verifyDNS()
                                } label: {
                                    HStack {
                                        if dnsVerifying { ProgressView().tint(.white) }
                                        Text(dnsVerifying ? "Checking…" : "I've Added the Record — Verify")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.indigo)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .disabled(dnsVerifying || domainForVerification.isEmpty)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.indigo.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // ── Email method ────────────────────────────────────────────
                if selectedMethod == .email {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.badge.shield.half.filled")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Email Verification")
                                    .font(.headline)
                                Text("Proves you are associated with this domain — ideal for individuals.")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }

                        // Email selector
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Send code to:")
                                .font(.caption).foregroundColor(.secondary)

                            HStack(spacing: 0) {
                                Picker("Prefix", selection: $emailPrefix) {
                                    Text("admin").tag("admin")
                                    Text("webmaster").tag("webmaster")
                                    Text("info").tag("info")
                                    Text("postmaster").tag("postmaster")
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()

                                Text("@\(domainForVerification.isEmpty ? "yourdomain.com" : domainForVerification)")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.platformGray6)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        Button {
                            sendVerificationEmail()
                        } label: {
                            HStack {
                                if emailSending { ProgressView().tint(.blue) }
                                Text(emailSending ? "Sending…" : (emailSent ? "Resend Code" : "Send Verification Code"))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(emailSending || domainForVerification.isEmpty)

                        if emailSent {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Enter the 6-digit code sent to \(verificationEmail):")
                                    .font(.subheadline)

                                TextField("000000", text: $codeInput)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                                    .multilineTextAlignment(.center)
                                    .platformKeyboardType(.numberPad)
                                    .padding()
                                    .background(Color.platformGray6)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .onChange(of: codeInput) { val in
                                        codeInput = String(val.filter(\.isNumber).prefix(6))
                                    }

                                if case .failure(let msg) = emailResult {
                                    Label(msg, systemImage: "xmark.circle.fill")
                                        .font(.caption).foregroundColor(.red)
                                }
                                if case .success = emailResult {
                                    Label("Email verified!", systemImage: "checkmark.circle.fill")
                                        .font(.subheadline).fontWeight(.semibold).foregroundColor(.green)
                                }

                                Button {
                                    verifyEmailCode()
                                } label: {
                                    HStack {
                                        if emailVerifying { ProgressView().tint(.white) }
                                        Text(emailVerifying ? "Verifying…" : "Verify Code")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(codeInput.count == 6 ? Color.blue : Color.gray.opacity(0.4))
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .disabled(codeInput.count != 6 || emailVerifying)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // Skip / verified note
                Button {
                    wizardState.useInternetDomain = false
                    onVerified()
                } label: {
                    Text("Skip domain verification for now")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .underline()
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
        }
        .navigationTitle("Verify Domain")
        .inlineNavigationTitle()
        .onAppear {
            domainInput = wizardState.internetDomain
        }
    }

    // MARK: - DNS verification

    private func verifyDNS() {
        guard !domainForVerification.isEmpty else { return }
        dnsVerifying = true
        dnsResult = nil

        let domain = domainForVerification
        let challenge = dnsChallenge

        Task {
            let url = URL(string: "\(ServerConfig.baseURL)/api/persona/verify-dns")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONEncoder().encode(["domain": domain, "challenge": challenge])

            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                let json = try? JSONDecoder().decode([String: Bool].self, from: data)
                let verified = json?["verified"] ?? false

                await MainActor.run {
                    dnsVerifying = false
                    if verified {
                        dnsResult = .success
                        wizardState.useInternetDomain = true
                        wizardState.internetDomain = domain
                        wizardState.domainVerified = true
                        wizardState.domainVerificationMethod = .dns
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { onVerified() }
                    } else {
                        dnsResult = .failure("TXT record not found yet. DNS changes can take a few minutes to propagate.")
                    }
                }
            } catch {
                await MainActor.run {
                    dnsVerifying = false
                    dnsResult = .failure("Could not reach verification server.")
                }
            }
        }
    }

    // MARK: - Email verification

    private func sendVerificationEmail() {
        guard !domainForVerification.isEmpty else { return }
        emailSending = true
        emailResult = nil

        let email = verificationEmail

        Task {
            let url = URL(string: "\(ServerConfig.baseURL)/api/persona/send-domain-code")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONEncoder().encode(["email": email, "domain": domainForVerification])

            do {
                let (_, _) = try await URLSession.shared.data(for: req)
                await MainActor.run {
                    emailSending = false
                    emailSent = true
                }
            } catch {
                await MainActor.run {
                    emailSending = false
                }
            }
        }
    }

    private func verifyEmailCode() {
        guard codeInput.count == 6 else { return }
        emailVerifying = true
        emailResult = nil

        let code = codeInput
        let email = verificationEmail
        let domain = domainForVerification

        Task {
            let url = URL(string: "\(ServerConfig.baseURL)/api/persona/verify-domain-code")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONEncoder().encode(["email": email, "code": code, "domain": domain])

            do {
                let (data, _) = try await URLSession.shared.data(for: req)
                let json = try? JSONDecoder().decode([String: Bool].self, from: data)
                let verified = json?["verified"] ?? false

                await MainActor.run {
                    emailVerifying = false
                    if verified {
                        emailResult = .success
                        wizardState.useInternetDomain = true
                        wizardState.internetDomain = domain
                        wizardState.domainVerified = true
                        wizardState.domainVerificationMethod = .email
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { onVerified() }
                    } else {
                        emailResult = .failure("That code is incorrect or expired. Try again.")
                    }
                }
            } catch {
                await MainActor.run {
                    emailVerifying = false
                    emailResult = .failure("Could not reach verification server.")
                }
            }
        }
    }

    private func dnsRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Shared: Handle Mockup Visual

/// Reusable calling-card preview used across wizard screens.
/// Shows [leftLabel] ·blue· [rightLabel] using the same glass style as PersonaHandleCard.
struct HandleMockupView: View {
    let leftLabel: String
    let rightLabel: String
    var isPublic: Bool = true
    var highlightLeft: Bool = false
    var highlightRight: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Left part (persona name)
            Text(leftLabel)
                .font(.title3).fontWeight(.semibold)
                .foregroundColor(highlightLeft ? .blue : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // The blue dot
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.2, green: 0.5, blue: 1.0),
                                 Color(red: 0.1, green: 0.3, blue: 0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 9, height: 9)
                .shadow(color: .blue.opacity(0.6), radius: 4)
                .padding(.horizontal, 7)

            // Right part (publishing house)
            Text(rightLabel)
                .font(.title3).fontWeight(.semibold)
                .foregroundColor(highlightRight ? .indigo : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isPublic ? Color.blue.opacity(0.08) : Color.purple.opacity(0.08))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isPublic ? Color.blue.opacity(0.25) : Color.purple.opacity(0.25), lineWidth: 1)
        }
        .shadow(color: .blue.opacity(0.1), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Shared: Rule Row

private struct RuleRow: View {
    let text: String
    let passed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: passed ? "checkmark.circle.fill" : "circle")
                .font(.subheadline)
                .foregroundColor(passed ? .green : .secondary)
                .padding(.top, 1)
            Text(text)
                .font(.subheadline)
                .foregroundColor(passed ? .primary : .secondary)
        }
    }
}

// MARK: - Preview

#Preview("Handle Wizard") {
    PersonaHandleWizardView()
        .environmentObject(PersonaManager())
}
