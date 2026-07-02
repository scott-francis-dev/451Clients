//
//  SignAndSubmitView.swift
//  451Wallet
//
//  Created by User451 on 4/25/25.
//
/**
import SwiftUI
import CryptoKit
import Foundation

struct SignAndSubmitView: View {
    let documentData: Data
    let personaDid: String
    let personaPublicKey: String
    
    @State private var isSubmitting = false
    @State private var submissionSuccess: Bool? = nil
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            if isSubmitting {
                ProgressView("Signing and submitting...")
            } else if let success = submissionSuccess {
                if success {
                    VStack {
                        Text("✅ Document Submitted Successfully!")
                            .font(.headline)
                            .foregroundColor(.green)
                        Button("Done") {
                            // Dismiss or navigate home
                        }
                        .padding()
                    }
                } else {
                    VStack {
                        Text("❌ Failed to Submit Document")
                            .font(.headline)
                            .foregroundColor(.red)
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding()
                        }
                        Button("Try Again") {
                            Task {
                                await signAndSubmit()
                            }
                        }
                        .padding()
                    }
                }
            } else {
                Button("Sign and Submit") {
                    Task {
                        await signAndSubmit()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear {
            // Optionally start automatically
            Task {
                await signAndSubmit()
            }
        }
    }
    
    func signAndSubmit() async {
        isSubmitting = true
        submissionSuccess = nil
        errorMessage = nil
        
        do {
            // 🔐 Sign with Secure Enclave key (private key never exposed)
            print("🔐 [SignAndSubmit] Signing with Secure Enclave for: \(personaDid)")
            
            // Sign the document
            let (documentHash, documentSignature) = try SignerService.signDocumentWithSecureEnclave(
                data: documentData,
                personaDid: personaDid
            )
            
            _ = try SecureEnclaveKeyStore.sign(documentHash, for: personaDid)
            
            // Build metadata for unified submit endpoint
            let hashB64 = documentHash.base64EncodedString()
            let metadata = DocumentMetadata(
                documentId: nil, // Let server generate
                title: nil,      // Client can omit; server doesn’t require
                authors: [personaDid],
                participants: nil, // This view doesn’t collect others; include if you have them elsewhere
                witnesses: nil,
                fileType: "json", // or other type as appropriate
                documentHash: hashB64
            )
            
            // Submit to unified endpoint
            try await WalletAPI.submitDocument(document: documentData, metadata: metadata)
            
            submissionSuccess = true
            print("✅ [SignAndSubmit] Document signed and submitted successfully")
        } catch {
            print("❌ [SignAndSubmit] Error during sign/submit: \(error)")
            errorMessage = error.localizedDescription
            submissionSuccess = false
        }
        
        isSubmitting = false
    }

}

**/
