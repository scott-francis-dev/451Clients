//
//  SignatorCreateDeckView.swift
//  Signator
//
//  The "Create" surface: Signator's create actions presented as a swipeable,
//  full-screen card deck (shared `ActionCardDeck` from Common).
//
//  `SignatorActions.all` is the SINGLE SOURCE OF TRUTH for the create actions —
//  their copy, background images, destination route, and whether they require a
//  persona. Tapping a card pushes its real flow; actions that need a persona
//  prompt creation at the point of need (Common's `.requiresPersona`).
//

import SwiftUI
import AuthenticationServices

// MARK: - Action catalog (single source of truth)

/// Where a create-action goes when chosen.
enum SignatorActionRoute: Hashable {
    case signDocument
    case signIn
    case requestInstitution
    case captureWitness
    case notarize
    case template
    case placeholder            // flow not built yet
}

/// One create-action. The one canonical description used by the Create deck
/// (and any future action surface). Produces an `ActionDeckCard` for the deck.
struct SignatorAction: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let imageName: String?
    let tint: Color
    let actionLabel: String
    let route: SignatorActionRoute
    /// Whether starting this action requires an active persona (prompted at point of need).
    let needsPersona: Bool
    /// The persona purpose to preselect when this action prompts creation.
    var personaPurpose: PersonaPurpose = .publishing
    /// Action-specific copy shown on the persona gate explaining why a persona is needed.
    var personaExplanation: String = "You need a persona — your verifiable signing identity — to continue."

    var card: ActionDeckCard {
        ActionDeckCard(id: id, title: title, subtitle: subtitle,
                       imageName: imageName, systemImage: systemImage,
                       tint: tint, actionLabel: actionLabel)
    }
}

enum SignatorActions {
    /// The canonical list of create actions (formerly duplicated in
    /// SignRequestsView.quickActions).
    static let all: [SignatorAction] = [
        SignatorAction(id: "signdoc", title: "Sign a Document",
                       subtitle: "Send a document for signatures.",
                       systemImage: "doc.text", imageName: "SignDocument", tint: .indigo,
                       actionLabel: "Start signing", route: .signDocument, needsPersona: true,
                       personaPurpose: .publishing,
                       personaExplanation: "Signing a document attaches your verifiable identity to it. Before you pick a document, you'll create a persona — the identity you'll sign as."),
        SignatorAction(id: "signin", title: "Sign in with Signator",
                       subtitle: "Authenticate to any Signator-enabled service.",
                       systemImage: "person.badge.shield.checkmark.fill", imageName: "DigitalLock", tint: .blue,
                       actionLabel: "Sign in", route: .signIn, needsPersona: true,
                       personaPurpose: .publishing,
                       personaExplanation: "Signing in with Signator proves who you are to a service. Your persona is the identity you'll present when you sign in."),
        SignatorAction(id: "institution", title: "Request Institution Access",
                       subtitle: "Apply for a role credential at a healthcare institution.",
                       systemImage: "building.2.crop.circle.fill", imageName: nil, tint: .pink,
                       actionLabel: "Request access", route: .requestInstitution, needsPersona: true,
                       personaPurpose: .legal,
                       personaExplanation: "Institution access is granted to a professional identity. Your persona will hold the role credential you're requesting."),
        SignatorAction(id: "witness", title: "Capture Witness Video",
                       subtitle: "Record a witness statement for the record.",
                       systemImage: "video.fill", imageName: "Protest2", tint: .purple,
                       actionLabel: "Capture", route: .captureWitness, needsPersona: true,
                       personaPurpose: .proof,
                       personaExplanation: "A witness recording is only as strong as the identity behind it. Your persona certifies who captured the statement."),
        SignatorAction(id: "machinery", title: "Document Presence of Machinery or Real Property",
                       subtitle: "Capture evidence of on-site assets.",
                       systemImage: "building.2", imageName: "machine", tint: .brown,
                       actionLabel: "Document", route: .placeholder, needsPersona: false),
        SignatorAction(id: "valuable", title: "Acknowledge Receipt of Valuable",
                       subtitle: "Confirm receipt of high-value items.",
                       systemImage: "shippingbox.fill", imageName: "Diamonds", tint: .teal,
                       actionLabel: "Acknowledge", route: .placeholder, needsPersona: false),
        SignatorAction(id: "credentials", title: "Sign and Submit Credentials",
                       subtitle: "Submit verified professional credentials.",
                       systemImage: "doc.badge.gearshape", imageName: "Diploma", tint: .orange,
                       actionLabel: "Submit", route: .placeholder, needsPersona: false),
        SignatorAction(id: "consent", title: "Sign Consent / Assent Form",
                       subtitle: "Collect consent and assent signatures.",
                       systemImage: "checklist", imageName: "Consent", tint: .green,
                       actionLabel: "Sign", route: .placeholder, needsPersona: false),
        SignatorAction(id: "medrecords", title: "Acknowledge Receipt of Medical Records",
                       subtitle: "Confirm medical record delivery.",
                       systemImage: "heart.text.square", imageName: "Xray", tint: .cyan,
                       actionLabel: "Acknowledge", route: .placeholder, needsPersona: false),
        SignatorAction(id: "notarize", title: "Notarize a Document",
                       subtitle: "Record and notarize a verifiable event.",
                       systemImage: "checkmark.seal", imageName: "Notary", tint: .mint,
                       actionLabel: "Notarize", route: .notarize, needsPersona: true,
                       personaPurpose: .legal,
                       personaExplanation: "Notarizing creates a verified record in your name. Your persona is the identity that vouches for the event."),
        SignatorAction(id: "event", title: "Acknowledge that an Event Occurred",
                       subtitle: "Create a verified event record.",
                       systemImage: "calendar.badge.checkmark", imageName: "Acknowledge", tint: .blue,
                       actionLabel: "Acknowledge", route: .placeholder, needsPersona: false),
        SignatorAction(id: "validatesign", title: "Validate a Human Signed a Document",
                       subtitle: "Confirm the signer and signature.",
                       systemImage: "person.text.rectangle", imageName: "DocumentSign", tint: .indigo,
                       actionLabel: "Validate", route: .placeholder, needsPersona: false),
        SignatorAction(id: "presence", title: "Validate that a Person Appeared at a Time and Location",
                       subtitle: "Capture presence with time and place.",
                       systemImage: "location.fill", imageName: "PeopleTalking", tint: .purple,
                       actionLabel: "Validate", route: .placeholder, needsPersona: false),
        SignatorAction(id: "milestone", title: "Sign a Completion of Milestones",
                       subtitle: "Certify milestones are complete.",
                       systemImage: "flag.checkered", imageName: "Milestone", tint: .red,
                       actionLabel: "Sign", route: .placeholder, needsPersona: false),
        SignatorAction(id: "thirdparty", title: "Sign a Milestone as an Independent Third Party",
                       subtitle: "Provide third-party milestone validation.",
                       systemImage: "person.2.badge.checkmark", imageName: "ThirdPartyValidation", tint: .orange,
                       actionLabel: "Sign", route: .placeholder, needsPersona: false),
        SignatorAction(id: "validatecreds", title: "Validate Credentials of Professional",
                       subtitle: "Third-party credential validation.",
                       systemImage: "person.crop.circle.badge.checkmark", imageName: "ValidateCredentials", tint: .teal,
                       actionLabel: "Validate", route: .placeholder, needsPersona: false),
        SignatorAction(id: "template", title: "Start from a Template",
                       subtitle: "Build from a reusable template.",
                       systemImage: "square.grid.2x2", imageName: "Templates", tint: .green,
                       actionLabel: "Choose template", route: .template, needsPersona: true,
                       personaPurpose: .publishing,
                       personaExplanation: "Documents you build from a template are signed and sent as you. Your persona is that signing identity."),
    ]

    static func action(id: String) -> SignatorAction? { all.first { $0.id == id } }
}

// MARK: - Create deck

struct SignatorCreateDeckView: View {
    @ObservedObject var personaManager: PersonaManager
    /// The action currently being navigated to.
    @State private var chosen: SignatorAction?
    /// The action tapped, awaiting a persona (point-of-need gate).
    @State private var pending: SignatorAction?
    @State private var wantsPersona = false

    var body: some View {
        NavigationStack {
            ActionCardDeck(cards: SignatorActions.all.map(\.card)) { card in
                guard let action = SignatorActions.action(id: card.id) else { return }
                if action.needsPersona {
                    // Gate on a persona; requiresPersona either proceeds immediately
                    // (one exists) or prompts creation, then proceeds.
                    pending = action
                    wantsPersona = true
                } else {
                    chosen = action
                }
            }
            // Keep the deck itself full-screen (no bar); pushed flows show their own.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $chosen) { action in
                destination(for: action.route)
            }
            .requiresPersona(
                personaManager,
                isActive: $wantsPersona,
                onSatisfied: {
                    chosen = pending
                    pending = nil
                },
                createPersona: {
                    PersonaGateView(personaManager: personaManager, action: pending)
                }
            )
        }
    }

    /// Routes an action to its real, already-built flow. Same destinations the
    /// Dashboard's Quick Actions used. Unbuilt flows show a placeholder.
    @ViewBuilder
    private func destination(for route: SignatorActionRoute) -> some View {
        switch route {
        case .signDocument:       SendSigningFlowView(personaManager: personaManager)
        case .signIn:             SignatorSignInInitiatorView().environmentObject(personaManager)
        case .requestInstitution: RequestInstitutionAccessView().environmentObject(personaManager)
        case .captureWitness:     QuickActionMediaCaptureView(title: "Capture Witness Video")
        case .notarize:           NotarizeEventFlowView(personaManager: personaManager)
        case .template:           TemplateSelectionFlowView(personaManager: personaManager)
        case .placeholder:        placeholderDestination
        }
    }

    private var placeholderDestination: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("This workflow is being prepared.")
                .font(.headline)
            Text("We'll add the full experience soon.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .navigationTitle("Coming soon")
        .inlineNavigationTitle()
    }
}

// MARK: - Persona gate

/// Apple provides the user's name and email only on the FIRST authorization
/// for this app — later sign-ins return nil — so persist them the moment we
/// get them and prefill persona creation from storage thereafter.
enum AppleIDPrefill {
    private static let nameKey = "appleSignIn.prefillName"
    private static let emailKey = "appleSignIn.prefillEmail"

    static var name: String? {
        get { UserDefaults.standard.string(forKey: nameKey) }
        set { UserDefaults.standard.set(newValue, forKey: nameKey) }
    }

    static var email: String? {
        get { UserDefaults.standard.string(forKey: emailKey) }
        set { UserDefaults.standard.set(newValue, forKey: emailKey) }
    }

    /// Store whatever the credential carries (first authorization only).
    static func remember(_ credential: ASAuthorizationAppleIDCredential) {
        if let components = credential.fullName {
            let formatted = PersonNameComponentsFormatter.localizedString(from: components, style: .default)
            if !formatted.isEmpty { name = formatted }
        }
        if let credentialEmail = credential.email, !credentialEmail.isEmpty {
            email = credentialEmail
        }
    }

    // ── Crafted suggestions (all editable by the user) ─────────────
    //
    // The email's domain (icloud.com, gmail.com, …) is NEVER used in a
    // suggestion — 451 doesn't own those names. Only the local part is
    // mined, and PersonaCreationView roots the composed handle under
    // 451's own default domain.

    private static func tokens(_ s: String?) -> [String] {
        guard let s else { return [] }
        return s.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    /// Dotted, sanitized email local part: "Francis.Home+tag@icloud.com" → "francis.home".
    static var emailLocalPart: String? {
        guard let email, let at = email.firstIndex(of: "@") else { return nil }
        var local = String(email[..<at])
        if let plus = local.firstIndex(of: "+") { local = String(local[..<plus]) }
        let parts = tokens(local)
        return parts.isEmpty ? nil : parts.joined(separator: ".")
    }

    /// Best-effort person name: the Apple account name, else the humanized
    /// email local part ("francis.home" → "Francis Home").
    static var craftedName: String? {
        if let name, !name.isEmpty { return name }
        guard let local = emailLocalPart else { return nil }
        return local.split(separator: ".").map { String($0).capitalized }.joined(separator: " ")
    }

    /// Publishing-house label suggestion:
    /// - the email local part when it isn't just the person's name ("francis.home")
    /// - else family name + ".house" ("francis.house")
    /// - else "publishing.house" when all we had was the email
    static var craftedPublishingHouse: String? {
        let appleName = tokens(name)
        if let local = emailLocalPart, !appleName.isEmpty,
           Set(local.split(separator: ".").map(String.init)) != Set(appleName) {
            return local
        }
        if let family = appleName.last { return family + ".house" }
        return emailLocalPart != nil ? "publishing.house" : nil
    }
}

/// Shown by `requiresPersona` when an action needs a persona and none exists.
/// Explains — in the tapped action's own words — why a persona is required,
/// offers Sign in with Apple to prefill name/email, manual setup, and help.
struct PersonaGateView: View {
    @ObservedObject var personaManager: PersonaManager
    /// The action that triggered the gate; nil falls back to generic copy.
    let action: SignatorAction?

    @State private var showCreation = false
    @State private var showHelp = false
    @State private var appleErrorMessage: String?
    /// Shown when Apple authorizes but withholds name/email (anything after
    /// the first-ever authorization, or while a revocation is still
    /// propagating): let the user type them right here instead.
    @State private var needsManualDetails = false
    @State private var manualName = ""
    @State private var manualEmail = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: action?.systemImage ?? "person.crop.circle.badge.plus")
                    .font(.system(size: 44))
                    .foregroundStyle(action?.tint ?? .blue)

                Text("First, create your persona")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(action?.personaExplanation ??
                     "You need a persona — your verifiable signing identity — to continue.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("This takes about a minute, and you only do it once.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let appleErrorMessage {
                    Text(appleErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                if needsManualDetails {
                    VStack(spacing: 12) {
                        Text("You're signed in with Apple, but Apple only shares your name and email the first time you ever authorize an app. Enter them once and we'll remember them.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        TextField("Your name", text: $manualName)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled(true)

                        TextField("Email", text: $manualEmail)
                            .textFieldStyle(.roundedBorder)
                            .platformAutocapitalization(.never)
                            .platformKeyboardType(.emailAddress)
                            .autocorrectionDisabled(true)

                        Button {
                            let name = manualName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let email = manualEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !name.isEmpty { AppleIDPrefill.name = name }
                            if !email.isEmpty { AppleIDPrefill.email = email }
                            showCreation = true
                        } label: {
                            Text("Continue")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(manualName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } else {
                    VStack(spacing: 12) {
                        SignInWithAppleButton(.continue) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                        .frame(height: 48)

                        Button {
                            showCreation = true
                        } label: {
                            Text("Set up manually")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button("What's a persona?") {
                            showHelp = true
                        }
                        .font(.footnote)
                    }
                }
            }
            .padding(24)
            .navigationDestination(isPresented: $showCreation) {
                PersonaCreationView(personaManager: personaManager,
                                    initialIsPublicPersona: true,
                                    initialName: AppleIDPrefill.craftedName,
                                    initialEmail: AppleIDPrefill.email,
                                    initialPublishingHouse: AppleIDPrefill.craftedPublishingHouse,
                                    initialPurpose: action?.personaPurpose ?? .publishing)
            }
            .sheet(isPresented: $showHelp) {
                NavigationStack {
                    PersonaHelpView()
                }
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                appleErrorMessage = "Could not read your Apple ID details. You can set up manually instead."
                return
            }
            let sharedName = credential.fullName.map {
                PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
            } ?? ""
            print("🍎 Apple credential — name: \(sharedName.isEmpty ? "NOT shared" : sharedName), email: \(credential.email ?? "NOT shared"), user: \(credential.user), realUserStatus: \(credential.realUserStatus.rawValue)")
            AppleIDPrefill.remember(credential)
            print("🍎 Prefill after storing — name: \(AppleIDPrefill.name ?? "nil"), email: \(AppleIDPrefill.email ?? "nil"), craftedName: \(AppleIDPrefill.craftedName ?? "nil"), craftedHouse: \(AppleIDPrefill.craftedPublishingHouse ?? "nil")")

            // Apple only shares name/email on the FIRST authorization. If we
            // got nothing now and have nothing stored, collect them here so
            // the crafting pipeline works regardless of Apple's cache.
            if AppleIDPrefill.craftedName == nil {
                appleErrorMessage = nil
                needsManualDetails = true
                return
            }
            appleErrorMessage = nil
            showCreation = true

        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            appleErrorMessage = "Sign in with Apple didn't complete. You can set up manually instead."
        }
    }
}

#Preview {
    SignatorCreateDeckView(personaManager: PersonaManager())
}

#Preview("Persona gate") {
    PersonaGateView(personaManager: PersonaManager(),
                    action: SignatorActions.action(id: "signdoc"))
}
