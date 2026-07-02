import SwiftUI

// MARK: - EscrowStatusView

struct EscrowStatusView: View {
    let invoiceId: String
    let projectId: String
    let invoiceAmount: Double
    let payeeUsercode: String
    let currentUsercode: String
    let usertype: String  // "owner" or "contractor"

    @StateObject private var service = EscrowService()
    @State private var showCancelConfirm = false

    var isOwner: Bool { usertype == "owner" }
    var isContractor: Bool { usertype == "contractor" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundColor(.accentColor)
                Text("Escrow")
                    .font(.headline)
            }

            if service.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let error = service.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            } else if let escrow = service.escrow {
                escrowDetailView(escrow: escrow)
            } else {
                noEscrowView
            }
        }
        .padding()
        .background(Color.platformBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .task {
            await service.fetchEscrowStatus(invoiceId: invoiceId)
        }
        .confirmationDialog("Cancel Escrow?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button("Cancel & Refund", role: .destructive) {
                Task { try? await service.cancelEscrow(invoiceId: invoiceId) }
            }
            Button("Keep Escrow", role: .cancel) { }
        } message: {
            Text("This will cancel the escrow and refund the amount to your account.")
        }
    }

    // MARK: - No Escrow

    @ViewBuilder
    private var noEscrowView: some View {
        Text("No escrow has been created for this invoice.")
            .font(.subheadline)
            .foregroundColor(.secondary)

        if isOwner {
            Button {
                Task {
                    try? await service.createEscrow(
                        invoiceId: invoiceId,
                        projectId: projectId,
                        amount: invoiceAmount,
                        payeeUsercode: payeeUsercode
                    )
                }
            } label: {
                Label("Fund Escrow (\(invoiceAmount, format: .currency(code: "USD")))", systemImage: "lock.shield.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(service.isLoading)
        }
    }

    // MARK: - Escrow Detail

    @ViewBuilder
    private func escrowDetailView(escrow: EscrowStatus) -> some View {
        HStack {
            EscrowStatusBadge(status: escrow.status)
            Spacer()
            Text(escrow.amount, format: .currency(code: "USD"))
                .font(.title3)
                .fontWeight(.semibold)
        }

        if let fundedAt = escrow.fundedAt {
            timestampRow(label: "Funded", dateString: fundedAt)
        }
        if let requestedAt = escrow.releaseRequestedAt {
            timestampRow(label: "Release requested", dateString: requestedAt)
        }
        if let releasedAt = escrow.releasedAt {
            timestampRow(label: "Released", dateString: releasedAt)
        }

        // Action buttons
        VStack(spacing: 8) {
            // Contractor: request release
            if isContractor && escrow.status == .funded {
                Button {
                    Task { try? await service.requestRelease(invoiceId: invoiceId) }
                } label: {
                    Label("Request Release", systemImage: "checkmark.seal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(service.isLoading)
            }

            // Owner: approve release
            if isOwner && escrow.status == .releaseRequested {
                Button {
                    Task { try? await service.approveRelease(invoiceId: invoiceId) }
                } label: {
                    Label("Approve Release", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(service.isLoading)
            }

            // Owner: cancel
            if isOwner && (escrow.status == .funded || escrow.status == .releaseRequested) {
                Button {
                    showCancelConfirm = true
                } label: {
                    Label("Cancel & Refund", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(service.isLoading)
            }
        }
        .padding(.top, 4)
    }

    private func timestampRow(label: String, dateString: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(dateString.prefix(10))  // Show YYYY-MM-DD
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - EscrowStatusBadge

struct EscrowStatusBadge: View {
    let status: EscrowStatusValue

    var color: Color {
        switch status {
        case .pending: return .gray
        case .funded: return .blue
        case .releaseRequested: return .orange
        case .released: return .green
        case .cancelled, .refunded: return .red
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}
