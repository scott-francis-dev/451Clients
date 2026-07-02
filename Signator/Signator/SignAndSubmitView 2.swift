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
            // 🚀 Use the new simplified workflow - server handles all signing
            print("🚀 [SignAndSubmit] Uploading document for: \(personaDid)")
            print("   Using DocumentSigningService.uploadDocument() -> /api/document/publish")
            
            // Upload document - server will handle signature collection
            let uploadResponse = try await DocumentSigningService.uploadDocument(
                documentData: documentData,
                originalFilename: nil
            )
            
            submissionSuccess = true
            print("✅ [SignAndSubmit] Document uploaded successfully")
            print("   Document ID: \(uploadResponse.documentId)")
            if let proofEntryID = uploadResponse.ledgerProofEntryID {
                print("   Proof Entry: \(proofEntryID)")
            }
            if let accessCode = uploadResponse.accessCode {
                print("   Access Code: \(accessCode)")
            }
        } catch {
            print("❌ [SignAndSubmit] Error during upload: \(error)")
            errorMessage = error.localizedDescription
            submissionSuccess = false
        }
        
        isSubmitting = false
    }

}
**/
