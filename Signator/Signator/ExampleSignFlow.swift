//
//  ExampleSignFlow.swift
//  451Wallet
//
//  Created by User451 on 4/25/25.
//

import Foundation
import CryptoKit

func exampleSignFlow(documentData: Data) {
    do {
        // 1. Load user's private key (this would come from secure storage / keychain)
        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: loadPrivateKey())

        // 2. Sign the document
        let (hash, signature) = try SignerService.signDocument(data: documentData, privateKey: privateKey)

        // 3. For JSON files, embed signatures
        if isJSON(data: documentData) {
            let modifiedDocument = try SignerService.embedSignaturesInJSON(
                jsonData: documentData,
                documentSignature: signature,
                personaSignature: signature // (Could be a second different signature if needed)
            )
            
            // Now `modifiedDocument` is ready to upload
        } else {
            // For binary documents, modify EXIF or metadata separately (later step)
        }

    } catch {
        print("Failed to sign document: \(error)")
    }
}

func isJSON(data: Data) -> Bool {
    return (try? JSONSerialization.jsonObject(with: data, options: [])) != nil
}

func loadPrivateKey() -> Data {
    // 🔒 Pull this from secure storage (Keychain or Secure Enclave ideally)
    // For now, dummy data
    fatalError("Private key loading not implemented.")
}

