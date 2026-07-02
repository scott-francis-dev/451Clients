import SwiftUI

// MARK: - MilestoneTimelineView

struct MilestoneTimelineView: View {
    let projectId: String
    let currentUserDid: String
    let usertype: String  // "ownerfinancer", "contractor", "subcontractor"

    @StateObject private var service = MilestoneService()
    @State private var selectedMilestone: Milestone?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if service.isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 80)
            } else if let schedule = service.schedule {
                scheduleView(schedule)
            } else {
                Text("No milestone schedule on this contract.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .padding()
            }

            if let err = service.errorMessage {
                Text(err).font(.caption).foregroundColor(.red).padding(.horizontal)
            }
        }
        .task { await service.fetchSchedule(projectId: projectId) }
    }

    // MARK: - Schedule View

    @ViewBuilder
    private func scheduleView(_ schedule: MilestoneSchedule) -> some View {
        // Provider + total header
        HStack {
            if let provider = schedule.escrowProvider {
                Label(provider.displayName, systemImage: "lock.shield")
                    .font(.caption).foregroundColor(.indigo)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.indigo.opacity(0.1))
                    .clipShape(Capsule())
            }
            Spacer()
            Text(schedule.totalAmount, format: .currency(code: "USD"))
                .font(.subheadline).fontWeight(.semibold)
        }
        .padding(.horizontal)
        .padding(.top, 12)

        // Horizontal timeline
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(schedule.milestones.enumerated()), id: \.element.id) { index, milestone in
                    MilestoneNode(
                        milestone: milestone,
                        isLast: index == schedule.milestones.count - 1,
                        isSelected: selectedMilestone?.id == milestone.id
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedMilestone = selectedMilestone?.id == milestone.id ? nil : milestone
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }

        // Detail drawer
        if let m = selectedMilestone, let schedule = service.schedule,
           let live = schedule.milestones.first(where: { $0.id == m.id }) {
            MilestoneDetailCard(
                milestone: live,
                projectId: projectId,
                currentUserDid: currentUserDid,
                usertype: usertype,
                service: service
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .padding()
        }
    }
}

// MARK: - MilestoneNode

private struct MilestoneNode: View {
    let milestone: Milestone
    let isLast: Bool
    let isSelected: Bool

    private var dotColor: Color {
        switch milestone.status {
        case .pending:  return .gray
        case .active:   return .blue
        case .signed:   return .yellow
        case .released: return .green
        case .disputed: return .red
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2))
                    .shadow(color: dotColor.opacity(0.4), radius: isSelected ? 6 : 2)

                Text(milestone.title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .multilineTextAlignment(.center)
                    .frame(width: 90)

                Text(milestone.amount, format: .currency(code: "USD"))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(milestone.status.displayName)
                    .font(.caption2)
                    .foregroundColor(dotColor)
            }
            .frame(width: 110)

            if !isLast {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 30, height: 2)
                    .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - MilestoneDetailCard

private struct MilestoneDetailCard: View {
    let milestone: Milestone
    let projectId: String
    let currentUserDid: String
    let usertype: String
    @ObservedObject var service: MilestoneService

    @State private var showSignConfirm = false

    private var canSign: Bool {
        guard let sig = milestone.signatures.first(where: { $0.signerDid == currentUserDid }) else { return false }
        return !sig.isSigned && !["released", "disputed"].contains(milestone.status.rawValue)
    }

    private var canFund: Bool {
        usertype == "ownerfinancer" &&
        milestone.escrow != nil &&
        !(milestone.escrow?.isFunded ?? false) &&
        milestone.status == MilestoneStatus.pending
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Title + status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.title).font(.headline)
                    Text(milestone.description).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                MilestoneStatusBadge(status: milestone.status)
            }

            Divider()

            // Deliverables
            if !milestone.deliverables.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Deliverables", systemImage: "checklist")
                        .font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                    ForEach(milestone.deliverables, id: \.self) { d in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "circle.fill").font(.system(size: 5)).padding(.top, 5)
                            Text(d).font(.subheadline)
                        }
                    }
                }
            }

            // Release condition
            Label(milestone.releaseCondition.displayText, systemImage: "key.fill")
                .font(.caption).foregroundColor(.secondary)

            // Signatures
            if !milestone.signatures.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Signatures", systemImage: "signature")
                        .font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                    ForEach(milestone.signatures) { sig in
                        HStack(spacing: 8) {
                            Image(systemName: sig.isSigned ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(sig.isSigned ? .green : .gray)
                            Text(sig.signerRole.capitalized).font(.subheadline)
                            if let date = sig.signedAt {
                                Spacer()
                                Text(date.prefix(10)).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            // Escrow info
            if let escrow = milestone.escrow {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill").foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(escrow.provider.displayName) Escrow")
                            .font(.subheadline).fontWeight(.medium)
                        Text(escrow.isFunded ? "Funded \(escrow.fundedAt?.prefix(10) ?? "")" : "Not funded")
                            .font(.caption).foregroundColor(escrow.isFunded ? .blue : .secondary)
                        if let rel = escrow.releasedAt {
                            Text("Released \(rel.prefix(10))").font(.caption).foregroundColor(.green)
                        }
                    }
                }
                .padding(10)
                .background(Color.blue.opacity(0.06))
                .cornerRadius(8)
            }

            // Actions
            HStack(spacing: 12) {
                if canFund {
                    Button {
                        Task { try? await service.fundMilestoneEscrow(projectId: projectId, milestoneId: milestone.id) }
                    } label: {
                        Label("Fund Escrow", systemImage: "lock.shield")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(service.isLoading)
                }

                if canSign {
                    Button { showSignConfirm = true } label: {
                        Label("Sign Release", systemImage: "signature")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(service.isLoading)
                }
            }
        }
        .padding()
        .background(Color.platformSecondaryBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .confirmationDialog("Sign Milestone Release?", isPresented: $showSignConfirm, titleVisibility: .visible) {
            Button("Sign") {
                Task {
                    try? await service.signMilestone(
                        projectId: projectId,
                        milestoneId: milestone.id,
                        signerDid: currentUserDid,
                        signerName: currentUserDid,
                        signature: "sig-\(currentUserDid)-\(Date().timeIntervalSince1970)"
                    )
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your cryptographic signature will release this milestone. This action cannot be undone.")
        }
    }
}

// MARK: - MilestoneStatusBadge

struct MilestoneStatusBadge: View {
    let status: MilestoneStatus

    private var color: Color {
        switch status {
        case .pending: return .gray
        case .active: return .blue
        case .signed: return .yellow
        case .released: return .green
        case .disputed: return .red
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(.caption).fontWeight(.semibold)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}
