import SwiftUI
import Foundation

struct HaveMyOwnDomainView: View {
    @Binding var name: String
    @Binding var customDomain: String
    @Binding var didInput: String

    let isPublicPersona: Bool
    let defaultDomain: String
    let fullDID: String
    let displayHandle: String
    let fullHandle: String
    let isDIDValid: Bool
    let validationState: () -> (isValid: Bool, reason: String?)
    let dnsVerificationView: () -> AnyView

    var body: some View {
        VStack(spacing: 12) {
            TextField("Author Name", text: $name)
            TextField("Your Domain (e.g., example.com)", text: $customDomain)
                .platformAutocapitalization(.never)
                .autocorrectionDisabled(true)
            TextField("Handle", text: $didInput)
                .platformAutocapitalization(.never)
                .autocorrectionDisabled(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Full handle:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(fullHandle)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            if !validationState().isValid {
                if let reason = validationState().reason {
                    Text(reason)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("DNS Verification")
                    .font(.headline)
                dnsVerificationView()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HaveMyOwnDomainView(
        name: .constant("John Doe"),
        customDomain: .constant("example.com"),
        didInput: .constant("johndoe"),
        isPublicPersona: true,
        defaultDomain: "default.com",
        fullDID: "did:example:123456789",
        displayHandle: "johndoe",
        fullHandle: "johndoe@example.com",
        isDIDValid: true,
        validationState: { (true, nil) },
        dnsVerificationView: { AnyView(Text("DNS verification UI here")) }
    )
}
