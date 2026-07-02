//
//  SignerService.swift
//  451Wallet
//
//  Created by User451 on 4/25/25.
//


import Foundation
import CryptoKit

struct SignerService {
    
    /// Hashes the input data with SHA-256.
    static func hashDocument(data: Data) -> Data {
        let hash = SHA256.hash(data: data)
        return Data(hash)
    }
    
    /// Signs the given hash using the user's private key.
    static func signHash(hash: Data, privateKey: P256.Signing.PrivateKey) throws -> Data {
        let signature = try privateKey.signature(for: hash)
        return signature.derRepresentation
    }
    
    /// Signs raw document data.
    static func signDocument(data: Data, privateKey: P256.Signing.PrivateKey) throws -> (hash: Data, signature: Data) {
        let hash = hashDocument(data: data)
        let signature = try signHash(hash: hash, privateKey: privateKey)
        return (hash, signature)
    }
    
    /// Embeds signatures into a JSON document.
    static func embedSignaturesInJSON(jsonData: Data, documentSignature: Data, personaSignature: Data) throws -> Data {
        guard var jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            throw NSError(domain: "SignerService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"])
        }
        
        jsonObject["_signatures"] = [
            "documentSignature": documentSignature.base64EncodedString(),
            "personaSignature": personaSignature.base64EncodedString()
        ]
        
        return try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted])
    }
}
