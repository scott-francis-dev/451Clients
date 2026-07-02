//
//  EmailVerificationField.swift
//  Signator
//
//  Created on 1/31/26.
//
//  Email input field with verification support
//  - Validates email format
//  - Sends verification code to email
//  - Allows user to verify via code or link
//

import SwiftUI

/// Email input field with verification support
struct EmailVerificationField: View {
    @Binding var email: String
    @Binding var isVerified: Bool
    
    var onSendVerification: ((String) async -> Bool)? = nil
    var placeholder: String = "email@example.com"
    
    @State private var isSending: Bool = false
    @State private var verificationSent: Bool = false
    @State private var showValidation: Bool = false
    @FocusState private var isFocused: Bool
    
    private var isEmailValid: Bool {
        guard !email.isEmpty else { return true }
        let emailRegex = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return email.range(of: emailRegex, options: [.caseInsensitive, .regularExpression]) != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Email icon
                Image(systemName: isVerified ? "envelope.badge.shield.half.filled" : "envelope")
                    .foregroundColor(isVerified ? .blue : .gray)
                    .font(.title3)
                
                // Input field
                TextField(placeholder, text: $email)
                    .platformKeyboardType(.emailAddress)
                    .platformAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($isFocused)
                    .onChange(of: email) { oldValue, newValue in
                        showValidation = !email.isEmpty
                        
                        // Clear verification status when email changes
                        if oldValue != newValue {
                            isVerified = false
                            verificationSent = false
                        }
                    }
                
                // Clear button
                if !email.isEmpty {
                    Button {
                        email = ""
                        isVerified = false
                        verificationSent = false
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
            if showValidation && !email.isEmpty {
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
            
            // Send verification button
            if isEmailValid && !email.isEmpty && !isVerified && !verificationSent && onSendVerification != nil {
                Button {
                    Task {
                        await sendVerification()
                    }
                } label: {
                    HStack {
                        if isSending {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "paperplane")
                        }
                        Text(isSending ? "Sending..." : "Send Verification Email")
                            .font(.subheadline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .disabled(isSending)
            }
            
            // Verification sent status
            if verificationSent && !isVerified {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "envelope.badge")
                            .foregroundColor(.orange)
                        Text("Verification email sent")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    
                    Text("Check your inbox and click the verification link. You can create the persona now and verify later.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Verification status
            if isVerified {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("Email Verified")
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
            Text("Email is optional but adds credibility to your persona. Verification can be completed later.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Validation UI
    
    private var borderColor: Color {
        if !showValidation || email.isEmpty {
            return Color.platformGray4
        }
        return isEmailValid ? .green : .red
    }
    
    private var validationIcon: String {
        if isVerified {
            return "checkmark.shield.fill"
        }
        return isEmailValid ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
    
    private var validationColor: Color {
        if isVerified {
            return .green
        }
        return isEmailValid ? .green : .red
    }
    
    private var validationMessage: String {
        if isVerified {
            return "Email verified"
        }
        if isEmailValid {
            return "Valid email format"
        }
        return "Invalid email format"
    }
    
    // MARK: - Verification
    
    private func sendVerification() async {
        guard isEmailValid, let onSendVerification = onSendVerification else { return }
        
        isSending = true
        defer { isSending = false }
        
        // Call the verification handler
        let sent = await onSendVerification(email)
        
        // Update sent status
        await MainActor.run {
            verificationSent = sent
        }
    }
}

// MARK: - Email Verification Service

/// Service for sending email verification
class EmailVerificationService {
    static let shared = EmailVerificationService()
    
    private init() {}
    
    /// Send verification email to the user
    /// - Parameters:
    ///   - email: Email address to verify
    ///   - did: DID of the persona (for linking verification)
    /// - Returns: True if email was sent successfully
    func sendVerification(to email: String, for did: String) async -> Bool {
        // This should call your backend API to send verification email
        // For now, this is a placeholder
        
        let urlString = "https://your-api.451.info/api/verify-email"
        
        guard let url = URL(string: urlString) else {
            print("Invalid verification URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = [
            "email": email,
            "did": did
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type")
                return false
            }
            
            return httpResponse.statusCode == 200
        } catch {
            print("Email verification send error: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Verify email with code or token
    /// - Parameters:
    ///   - email: Email address
    ///   - token: Verification token from email link
    /// - Returns: True if verification was successful
    func verifyEmail(_ email: String, token: String) async -> Bool {
        // This should call your backend API to verify the token
        // For now, this is a placeholder
        
        let urlString = "https://your-api.451.info/api/verify-email/confirm"
        
        guard let url = URL(string: urlString) else {
            print("Invalid verification URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = [
            "email": email,
            "token": token
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type")
                return false
            }
            
            return httpResponse.statusCode == 200
        } catch {
            print("Email verification error: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Preview

#Preview("Empty State") {
    VStack {
        EmailVerificationField(
            email: .constant(""),
            isVerified: .constant(false)
        )
        .padding()
        
        Spacer()
    }
}

#Preview("Valid Email") {
    VStack {
        EmailVerificationField(
            email: .constant("jane.wu@wisc.edu"),
            isVerified: .constant(false),
            onSendVerification: { email in
                // Simulate sending
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                return true
            }
        )
        .padding()
        
        Spacer()
    }
}

#Preview("Verification Sent") {
    struct PreviewWrapper: View {
        @State private var email = "jane.wu@wisc.edu"
        @State private var isVerified = false
        @State private var verificationSent = true
        
        var body: some View {
            VStack {
                EmailVerificationField(
                    email: $email,
                    isVerified: $isVerified,
                    onSendVerification: { email in
                        return true
                    }
                )
                .padding()
                .onAppear {
                    // Simulate sent state
                }
                
                Spacer()
            }
        }
    }
    
    return PreviewWrapper()
}

#Preview("Verified") {
    VStack {
        EmailVerificationField(
            email: .constant("jane.wu@wisc.edu"),
            isVerified: .constant(true)
        )
        .padding()
        
        Spacer()
    }
}

#Preview("Invalid Email") {
    VStack {
        EmailVerificationField(
            email: .constant("not-an-email"),
            isVerified: .constant(false)
        )
        .padding()
        
        Spacer()
    }
}
