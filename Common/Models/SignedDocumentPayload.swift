//
//  SignedDocumentPayload.swift
//  451Wallet
//
//  Created by Scott Francis on 4/29/25.
//


struct SignedDocumentPayload: Codable {
    let documentId: String
    let documentType: String
    let signedDocument: String
    let signatures: Signatures
    let persona: Persona

    struct Signatures: Codable {
        let documentHash: String
        let documentSignature: String
        let personaSignature: String
    }

    struct Persona: Codable {
        let did: String
        let publicKey: String
    }
}
