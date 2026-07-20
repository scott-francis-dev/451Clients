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
                       actionLabel: "Start signing", route: .signDocument, needsPersona: true),
        SignatorAction(id: "signin", title: "Sign in with Signator",
                       subtitle: "Authenticate to any Signator-enabled service.",
                       systemImage: "person.badge.shield.checkmark.fill", imageName: "DigitalLock", tint: .blue,
                       actionLabel: "Sign in", route: .signIn, needsPersona: true),
        SignatorAction(id: "institution", title: "Request Institution Access",
                       subtitle: "Apply for a role credential at a healthcare institution.",
                       systemImage: "building.2.crop.circle.fill", imageName: nil, tint: .pink,
                       actionLabel: "Request access", route: .requestInstitution, needsPersona: true),
        SignatorAction(id: "witness", title: "Capture Witness Video",
                       subtitle: "Record a witness statement for the record.",
                       systemImage: "video.fill", imageName: "Protest2", tint: .purple,
                       actionLabel: "Capture", route: .captureWitness, needsPersona: true),
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
                       actionLabel: "Notarize", route: .notarize, needsPersona: true),
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
                       actionLabel: "Choose template", route: .template, needsPersona: true),
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
                    PersonaCreationView(personaManager: personaManager,
                                        initialIsPublicPersona: true,
                                        initialPurpose: .publishing)
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

#Preview {
    SignatorCreateDeckView(personaManager: PersonaManager())
}
