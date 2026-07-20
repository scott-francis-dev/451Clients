//
//  SignerService+SecureEnclave.swift
//  451Wallet
//
//  Secure Enclave-aware signing utilities
//

import Foundation
import CryptoKit

extension SignerService {
    
    /// Signs document data using Secure Enclave key
    /// Returns (documentHash, documentSignature)
    static func signDocumentWithSecureEnclave(data: Data, personaDid: String) throws -> (Data, P256.Signing.ECDSASignature) {
        // Hash the document
        let hash = SHA256.hash(data: data)
        let hashData = Data(hash)
        
        // Sign with Secure Enclave
        let signature = try SecureEnclaveKeyStore.sign(hashData, for: personaDid)
        
        return (hashData, signature)
    }
    
    /// Signs a hash using Secure Enclave key
    static func signHashWithSecureEnclave(hash: Data, personaDid: String) throws -> P256.Signing.ECDSASignature {
        return try SecureEnclaveKeyStore.sign(hash, for: personaDid)
    }
}
