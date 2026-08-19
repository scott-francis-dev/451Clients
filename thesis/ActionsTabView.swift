// ActionsTabView.swift
// thesis
//
// The signing/wallet actions hub — all 451 actions available from one tab.
// Mirrors the Quick Actions card from the Signator dashboard.

import SwiftUI
import CryptoKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Pending Signatures types (shared with actions tab)

struct SignRequestsTabRequest: Identifiable {
    enum Status { case pending, signed }
    let id: String
    let title: String
    let subtitle: String
    let status: Status
    let documentId: String
    let pendingDocument: DocumentSigningService.PendingDocument?
}

// MARK: - Actions Tab Root View

struct ActionsTabView: View {
    @EnvironmentObject private var personaManager: PersonaManager
    @State private var showPersonaSheet = false
    @State private var requests: [SignRequestsTabRequest] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var requestsSentCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerCard
            Divider()
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .opacity(0.4)

            if personaManager.personas.isEmpty {
                noPersonaPrompt
            } else if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading pending signatures...")
                    Spacer()
                }
                .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        pendingSummaryCard
                        quickActionsCard
                        activityCard
                    }
                    .padding(.horizontal, 4)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .onReceive(NotificationCenter.default.publisher(for: InitiatedSigningStore.didUpdateNotification)) { _ in
            requestsSentCount = InitiatedSigningStore.shared.load().count
        }
        .task { await loadPendingDocuments() }
        .refreshable { await loadPendingDocuments() }
        .sheet(isPresented: $showPersonaSheet) {
            NavigationStack {
                PersonaManagerView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showPersonaSheet = false }
                        }
                    }
            }
        }
        .navigationTitle("Actions")
        #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("451 Actions")
                    .font(.title3).bold()
                Text("Sign, witness, notarize, and verify")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 12) {
                Button(action: { Task { await loadPendingDocuments() } }) {
                    Image(systemName: isLoading ? "arrow.clockwise.circle.fill" : "arrow.clockwise")
                        .font(.title3)
                        .foregroundColor(isLoading ? .blue : .primary)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                Button(action: { showPersonaSheet = true }) {
                    Image(systemName: "person.crop.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.gray.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    // MARK: - No Persona Prompt

    private var noPersonaPrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("Create a Persona First")
                .font(.title3).bold()
            Text("You need a persona to sign documents and take actions on the 451 network.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Create Persona") { showPersonaSheet = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Pending Summary

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

            if requests.isEmpty && errorMessage == nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No requests yet")
                        .font(.subheadline).fontWeight(.semibold)
                    Text("You're ready to sign as soon as something arrives.")
                        .font(.footnote).foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }

            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text(error).font(.footnote).foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.platformGroupedBackground))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.gray.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Quick Actions Card

    private var quickActionsCard: some View {
        let actions = allQuickActions

        return VStack(alignment: .leading, spacing: 12) {
            Label("Quick Actions", systemImage: "bolt.fill")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 0) {
                ForEach(actions) { item in
                    quickActionRow(for: item)
                    if item.id != actions.last?.id {
                        Divider()
                    }
                }
            }
            .background(Color.platformSecondaryGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.platformGroupedBackground))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.gray.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Activity Card

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
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.platformGroupedBackground))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.gray.opacity(0.15), lineWidth: 1))
    }

    private func activityRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.footnote).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.semibold)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Quick Action Items

    private enum QuickActionDestination {
        case signDocument
        case captureWitnessVideo
        case notarizeEvent
        case documentList
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

    private var allQuickActions: [QuickActionItem] {
        [
            QuickActionItem(title: "Sign a Document", subtitle: "Send a document for signatures", systemImage: "doc.text", imageName: "SignDocument", destination: .signDocument),
            QuickActionItem(title: "Capture Witness Video", subtitle: "Record a witness statement for the record", systemImage: "video.fill", imageName: "Protest2", destination: .captureWitnessVideo),
            QuickActionItem(title: "Notarize a Document", subtitle: "Record and notarize a verifiable event", systemImage: "checkmark.seal", imageName: "Notary", destination: .notarizeEvent),
            QuickActionItem(title: "Browse Signed Documents", subtitle: "View and manage your document history", systemImage: "doc.on.doc", imageName: nil, destination: .documentList),
            QuickActionItem(title: "Document Presence of Machinery or Real Property", subtitle: "Capture evidence of on-site assets", systemImage: "building.2", imageName: "machine", destination: .placeholder("Document Presence of Machinery or Real Property")),
            QuickActionItem(title: "Acknowledge Receipt of Valuable", subtitle: "Confirm receipt of high-value items", systemImage: "shippingbox.fill", imageName: "Diamonds", destination: .placeholder("Acknowledge Receipt of Valuable")),
            QuickActionItem(title: "Sign and Submit Credentials", subtitle: "Submit verified professional credentials", systemImage: "doc.badge.gearshape", imageName: "Diploma", destination: .placeholder("Sign and Submit Credentials")),
            QuickActionItem(title: "Sign Consent / Assent Form", subtitle: "Collect consent and assent signatures", systemImage: "checklist", imageName: "Consent", destination: .placeholder("Sign Consent / Assent Form")),
            QuickActionItem(title: "Acknowledge Receipt of Medical Records", subtitle: "Confirm medical record delivery", systemImage: "heart.text.square", imageName: "Xray", destination: .placeholder("Acknowledge Receipt of Medical Records")),
            QuickActionItem(title: "Acknowledge that an Event Occurred", subtitle: "Create a verified event record", systemImage: "calendar.badge.checkmark", imageName: "Acknowledge", destination: .placeholder("Acknowledge that an Event Occurred")),
            QuickActionItem(title: "Validate a Human Signed a Document", subtitle: "Confirm the signer and signature", systemImage: "person.text.rectangle", imageName: "DocumentSign", destination: .placeholder("Validate a Human Signed a Document")),
            QuickActionItem(title: "Validate that a Person Appeared at a Time and Location", subtitle: "Capture presence with time and place", systemImage: "location.fill", imageName: "PeopleTalking", destination: .placeholder("Validate that a Person Appeared at a Time and Location")),
            QuickActionItem(title: "Sign a Completion of Milestones", subtitle: "Certify milestones are complete", systemImage: "flag.checkered", imageName: "Milestone", destination: .placeholder("Sign a Completion of Milestones")),
            QuickActionItem(title: "Sign a Milestone as an Independent Third Party", subtitle: "Provide third-party milestone validation", systemImage: "person.2.badge.checkmark", imageName: "ThirdPartyValidation", destination: .placeholder("Sign a Milestone as an Independent Third Party")),
            QuickActionItem(title: "Validate Credentials of Professional", subtitle: "Third-party credential validation", systemImage: "person.crop.circle.badge.checkmark", imageName: "ValidateCredentials", destination: .placeholder("Validate Credentials of Professional")),
            QuickActionItem(title: "Start from a Template", subtitle: "Build from a reusable template", systemImage: "square.grid.2x2", imageName: "Templates", destination: .placeholder("Start from a Template")),
        ]
    }

    @ViewBuilder
    private func quickActionDestination(for item: QuickActionItem) -> some View {
        switch item.destination {
        case .signDocument:
            SendSigningFlowView(personaManager: personaManager)
        case .captureWitnessVideo:
#if os(iOS)
            QuickActionMediaCaptureView(title: "Capture Witness Video")
                .environmentObject(personaManager)
#else
            QuickActionPlaceholderView(title: "Capture Witness Video")
#endif
        case .notarizeEvent:
            NotarizeEventFlowView(personaManager: personaManager)
        case .documentList:
            DocumentListView(blocks: [])
        case .placeholder(let title):
            QuickActionPlaceholderView(title: title)
        }
    }

    private func quickActionRow(for item: QuickActionItem) -> some View {
        NavigationLink {
            quickActionDestination(for: item)
        } label: {
            HStack(spacing: 12) {
                quickActionThumbnail(for: item)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(item.subtitle)
                        .font(.footnote).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote).foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func quickActionThumbnail(for item: QuickActionItem) -> some View {
        ZStack {
            if let imageName = item.imageName, let image = loadImage(named: imageName) {
#if canImport(UIKit)
                Image(uiImage: image).resizable().scaledToFill()
#elseif canImport(AppKit)
                Image(nsImage: image).resizable().scaledToFill()
#endif
            } else {
                Image(systemName: item.systemImage)
                    .foregroundColor(.blue)
                    .font(.system(size: 22, weight: .semibold))
            }
        }
        .frame(width: 52, height: 52)
        .background(Color.blue.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.blue.opacity(0.15), lineWidth: 1))
    }

#if canImport(UIKit)
    private func loadImage(named name: String) -> UIImage? {
        if let img = UIImage(named: name) { return img }
        for ext in ["jpg", "jpeg", "png"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return UIImage(contentsOfFile: url.path)
            }
        }
        return nil
    }
#elseif canImport(AppKit)
    private func loadImage(named name: String) -> NSImage? {
        if let img = NSImage(named: name) { return img }
        for ext in ["jpg", "jpeg", "png"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return NSImage(contentsOf: url)
            }
        }
        return nil
    }
#endif

    // MARK: - Placeholder

    struct QuickActionPlaceholderView: View {
        let title: String
        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.title3).fontWeight(.semibold)
                Text("This workflow is being prepared. We'll add the full experience soon.")
                    .font(.footnote).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(24)
            .navigationTitle(title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
    }

    // MARK: - Load Pending Documents

    private func loadPendingDocuments() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        defer {
            Task { @MainActor in isLoading = false }
        }

        let personas = personaManager.personas
        guard !personas.isEmpty else {
            await MainActor.run { requests = [] }
            return
        }

        var aggregated: [SignRequestsTabRequest] = []
        for persona in personas {
            do {
                let documents = try await DocumentSigningService.fetchPendingDocuments(forSignerDID: persona.id)
                let rows = documents.map { doc in
                    SignRequestsTabRequest(
                        id: doc.documentId,
                        title: doc.displayTitle,
                        subtitle: "Signatures: \(doc.currentSignatureCount)/\(doc.requiredSignatures)",
                        status: .pending,
                        documentId: doc.documentId,
                        pendingDocument: doc
                    )
                }
                aggregated.append(contentsOf: rows)
            } catch {
                // Continue for other personas
            }
        }

        await MainActor.run {
            requests = aggregated
            requestsSentCount = InitiatedSigningStore.shared.load().count
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ActionsTabView()
            .environmentObject(PersonaManager())
    }
}
