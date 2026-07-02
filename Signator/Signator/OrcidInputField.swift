//
//  OrcidInputField.swift
//  Signator
//
//  Created on 1/31/26.
//
//  ORCID input field with format validation
//  - Validates ORCID format: 0000-0002-1825-0097
//  - Auto-formats with hyphens as user types
//  - Optional server verification
//

import SwiftUI

/// ORCID input field with validation and formatting
struct OrcidInputField: View {
    @Binding var orcid: String
    @Binding var isVerified: Bool
    
    var onVerify: ((String) async -> Bool)? = nil
    
    @State private var isValidating: Bool = false
    @State private var showValidation: Bool = false
    @FocusState private var isFocused: Bool
    
    private var isFormatValid: Bool {
        guard !orcid.isEmpty else { return true }
        let pattern = #"^\d{4}-\d{4}-\d{4}-\d{3}[0-9X]$"#
        return orcid.range(of: pattern, options: .regularExpression) != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // ORCID icon
                Image(systemName: "graduationcap.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                // Input field
                TextField("0000-0002-1825-0097", text: $orcid)
                    .platformKeyboardType(.numbersAndPunctuation)
                    .platformAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .font(.system(.body, design: .monospaced))
                    .focused($isFocused)
                    .onChange(of: orcid) { oldValue, newValue in
                        // Format as user types
                        let formatted = String.formatOrcidInput(newValue)
                        if formatted != newValue {
                            orcid = formatted
                        }
                        showValidation = !orcid.isEmpty
                        
                        // Clear verification status when ORCID changes
                        if oldValue != newValue {
                            isVerified = false
                        }
                    }
                
                // Clear button
                if !orcid.isEmpty {
                    Button {
                        orcid = ""
                        isVerified = false
                        showValidation = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color.platformBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 2)
            )
            
            // Validation feedback
            if showValidation {
                HStack(spacing: 6) {
                    Image(systemName: validationIcon)
                        .foregroundColor(validationColor)
                        .font(.caption)
                    
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundColor(validationColor)
                    
                    Spacer()
                }
            }
            
            // Verify button (appears when format is valid but not verified)
            if isFormatValid && !orcid.isEmpty && !isVerified && onVerify != nil {
                Button {
                    Task {
                        await verifyOrcid()
                    }
                } label: {
                    HStack {
                        if isValidating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "checkmark.seal")
                        }
                        Text(isValidating ? "Verifying..." : "Verify with ORCID")
                            .font(.subheadline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .cornerRadius(8)
                }
                .disabled(isValidating)
            }
            
            // Verification status
            if isVerified {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("ORCID Verified")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Help text
            Text("ORCID is an optional identifier for researchers. Format: 0000-0002-1825-0097")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Validation UI
    
    private var borderColor: Color {
        if !showValidation || orcid.isEmpty {
            return Color.platformGray4
        }
        return isFormatValid ? .green : .red
    }
    
    private var validationIcon: String {
        if isVerified {
            return "checkmark.seal.fill"
        }
        return isFormatValid ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
    
    private var validationColor: Color {
        if isVerified {
            return .green
        }
        return isFormatValid ? .green : .red
    }
    
    private var validationMessage: String {
        if isVerified {
            return "ORCID verified successfully"
        }
        if isFormatValid {
            return "Format is valid"
        }
        return "Invalid ORCID format. Expected: 0000-0002-1825-0097"
    }
    
    // MARK: - Verification
    
    private func verifyOrcid() async {
        guard isFormatValid, let onVerify = onVerify else { return }
        
        isValidating = true
        defer { isValidating = false }
        
        // Call the verification handler
        let verified = await onVerify(orcid)
        
        // Update verification status
        await MainActor.run {
            isVerified = verified
        }
    }
}

// MARK: - ORCID Verification Service

/// Service for verifying ORCID identifiers with the ORCID API
class OrcidVerificationService {
    static let shared = OrcidVerificationService()
    
    private init() {}
    
    /// Verify ORCID with the public ORCID API
    /// - Parameter orcid: The ORCID to verify (format: 0000-0002-1825-0097)
    /// - Returns: True if the ORCID exists in the ORCID registry
    func verify(_ orcid: String) async -> Bool {
        // Remove hyphens for API call
        let cleanOrcid = orcid.replacingOccurrences(of: "-", with: "")
        
        // ORCID public API endpoint
        let urlString = "https://pub.orcid.org/v3.0/\(orcid)"
        
        guard let url = URL(string: urlString) else {
            print("Invalid ORCID URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type")
                return false
            }
            
            // 200 means the ORCID exists
            if httpResponse.statusCode == 200 {
                return true
            } else if httpResponse.statusCode == 404 {
                print("ORCID not found in registry")
                return false
            } else {
                print("ORCID verification failed with status: \(httpResponse.statusCode)")
                return false
            }
        } catch {
            print("ORCID verification error: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Preview

#Preview("Empty State") {
    VStack {
        OrcidInputField(
            orcid: .constant(""),
            isVerified: .constant(false)
        )
        .padding()
        
        Spacer()
    }
}

#Preview("Valid Format") {
    VStack {
        OrcidInputField(
            orcid: .constant("0000-0002-1825-0097"),
            isVerified: .constant(false),
            onVerify: { orcid in
                // Simulate verification
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                return true
            }
        )
        .padding()
        
        Spacer()
    }
}

#Preview("Verified") {
    VStack {
        OrcidInputField(
            orcid: .constant("0000-0002-1825-0097"),
            isVerified: .constant(true)
        )
        .padding()
        
        Spacer()
    }
}

#Preview("Invalid Format") {
    VStack {
        OrcidInputField(
            orcid: .constant("1234-5678"),
            isVerified: .constant(false)
        )
        .padding()
        
        Spacer()
    }
}
