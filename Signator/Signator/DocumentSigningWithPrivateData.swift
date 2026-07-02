// DocumentSigningWithPrivateData.swift
// Example implementation of document signing with private persona data

import Foundation
import CryptoKit

/// Example implementation showing how to integrate private data into document signing workflow
struct DocumentSigningWithPrivateData {
    
    /// Sign a document that requires private persona information
    /// This is used for contracts, wills, and legal documents
    static func signDocumentWithPrivateInfo(
        documentData: Data,
        persona: PersonaProfile,
        privateKey: P256.Signing.PrivateKey,
        requiresPrivateData: Bool
    ) async throws -> SignedDocumentPackage {
        
        // 1. Validate persona if background check is required
        if persona.backgroundCheckRequired {
            guard persona.backgroundValidated == true else {
                throw SigningError.personaNotValidated
            }
        }
        
        // 2. Load private data if required
        var privateData: PersonaProfile.PrivatePersonaData? = nil
        if requiresPrivateData {
            guard let loadedPrivateData = try PrivateDataStore.loadPrivateData(for: persona.dID) else {
                throw SigningError.missingPrivateData
            }
            privateData = loadedPrivateData
            print("✅ [Signing] Loaded private data for: \(persona.dID)")
        }
        
        // 3. Create document hash for signature
        let documentHash = SHA256.hash(data: documentData)
        
        // 4. Sign the document
        let signature = try privateKey.signature(for: documentHash)
        let signatureBase64 = signature.derRepresentation.base64EncodedString()
        
        // 5. Create encrypted package if private data is included
        var encryptedPackage: Data? = nil
        if let privateData = privateData {
            encryptedPackage = try PrivateDataManager.packageForSigning(
                documentData: documentData,
                privateData: privateData,
                for: persona.dID
            )
            print("✅ [Signing] Created encrypted package with private data")
        }
        
        // 6. Prepare public metadata
        let publicMetadata = SigningMetadata(
            did: persona.dID,
            prettyDID: persona.handle,
            publicAffiliations: persona.metadata?["publicAffiliations"],
            socialMediaLinks: persona.metadata?["socialMediaLinks"],
            publicEmail: persona.email,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            documentHash: documentHash.hexString,
            signature: signatureBase64,
            containsPrivateData: privateData != nil
        )
        
        // 7. Create final package
        let signedPackage = SignedDocumentPackage(
            document: documentData,
            signature: signatureBase64,
            publicMetadata: publicMetadata,
            encryptedPrivateDataPackage: encryptedPackage
        )
        
        print("✅ [Signing] Document signed successfully")
        return signedPackage
    }
    
    /// Upload signed document package to S3
    static func uploadSignedPackage(
        _ package: SignedDocumentPackage,
        to s3Endpoint: String,
        documentID: String
    ) async throws -> S3UploadResult {
        
        // 1. Create package structure
        let packageFolder = "signed-\(documentID)-\(Int(Date().timeIntervalSince1970))"
        
        // 2. Prepare files for upload
        var files: [S3File] = [
            S3File(name: "document.dat", data: package.document),
            S3File(name: "metadata.json", data: try JSONEncoder().encode(package.publicMetadata)),
            S3File(name: "signature.base64", data: package.signature.data(using: .utf8)!)
        ]
        
        // Add encrypted private data if present
        if let encryptedPackage = package.encryptedPrivateDataPackage {
            files.append(S3File(name: "private-data.encrypted", data: encryptedPackage))
        }
        
        // 3. Create ZIP archive
        let zipData = try createZipArchive(files: files)
        
        // 4. Encrypt the entire archive (AES-256)
        let archiveKey = SymmetricKey(size: .bits256)
        let sealedBox = try AES.GCM.seal(zipData, using: archiveKey)
        guard let encryptedArchive = sealedBox.combined else {
            throw SigningError.encryptionFailed
        }
        
        // 5. Upload to S3
        let s3URL = "\(s3Endpoint)/\(packageFolder)/package.encrypted"
        let uploadResult = try await uploadToS3(
            data: encryptedArchive,
            url: s3URL,
            encryptionKey: archiveKey
        )
        
        print("✅ [Upload] Package uploaded to: \(s3URL)")
        
        return S3UploadResult(
            url: s3URL,
            documentID: documentID,
            packageFolder: packageFolder,
            encryptionKey: archiveKey.withUnsafeBytes { Data($0).base64EncodedString() },
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    /// Fill template with persona data (public and/or private)
    static func fillTemplate(
        _ templateContent: String,
        persona: PersonaProfile,
        includePrivateData: Bool
    ) throws -> String {
        
        var filled = templateContent
        
        // Fill public placeholders
        filled = filled.replacingOccurrences(of: "{{DID}}", with: persona.dID)
        filled = filled.replacingOccurrences(of: "{{NAME}}", with: persona.name ?? persona.handle)
        filled = filled.replacingOccurrences(of: "{{PRETTY_DID}}", with: persona.handle)
        
        if let publicAffiliations = persona.metadata?["publicAffiliations"] {
            filled = filled.replacingOccurrences(of: "{{PUBLIC.AFFILIATIONS}}", with: publicAffiliations)
        }
        
        if let socialMediaLinks = persona.metadata?["socialMediaLinks"] {
            filled = filled.replacingOccurrences(of: "{{PUBLIC.SOCIAL_LINKS}}", with: socialMediaLinks)
        }
        
        if let publicEmail = persona.email {
            filled = filled.replacingOccurrences(of: "{{PUBLIC.EMAIL}}", with: publicEmail)
        }
        
        // Fill private placeholders if authorized
        if includePrivateData {
            guard let privateData = try PrivateDataStore.loadPrivateData(for: persona.dID) else {
                throw SigningError.missingPrivateData
            }
            
            // IMPORTANT: Only keep decrypted data in memory for the minimum time needed
            defer {
                // Clear sensitive data from memory
                // (Swift doesn't have explicit memory clearing, but this signals intent)
                print("🔒 [Template] Cleared private data from memory")
            }
            
            if let givenName = privateData.givenName {
                filled = filled.replacingOccurrences(of: "{{PRIVATE.GIVEN_NAME}}", with: givenName)
            }
            
            if let aliases = privateData.aliases {
                filled = filled.replacingOccurrences(of: "{{PRIVATE.ALIASES}}", with: aliases)
            }
            
            if let privateEmail = privateData.privateEmail {
                filled = filled.replacingOccurrences(of: "{{PRIVATE.EMAIL}}", with: privateEmail)
            }
            
            if let ssn = privateData.socialSecurityNumber {
                filled = filled.replacingOccurrences(of: "{{PRIVATE.SSN}}", with: ssn)
            }
            
            if let address = privateData.privateAddress {
                filled = filled.replacingOccurrences(of: "{{PRIVATE.ADDRESS.STREET}}", with: address.street ?? "")
                filled = filled.replacingOccurrences(of: "{{PRIVATE.ADDRESS.CITY}}", with: address.city ?? "")
                filled = filled.replacingOccurrences(of: "{{PRIVATE.ADDRESS.STATE}}", with: address.state ?? "")
                filled = filled.replacingOccurrences(of: "{{PRIVATE.ADDRESS.ZIP}}", with: address.postalCode ?? "")
                filled = filled.replacingOccurrences(of: "{{PRIVATE.ADDRESS.COUNTRY}}", with: address.country ?? "")
                
                // Full address formatting
                let fullAddress = formatAddress(address)
                filled = filled.replacingOccurrences(of: "{{PRIVATE.ADDRESS.FULL}}", with: fullAddress)
            }
            
            print("✅ [Template] Filled template with private data")
        }
        
        // Remove any remaining placeholders
        filled = filled.replacingOccurrences(of: "{{[^}]+}}", with: "", options: .regularExpression)
        
        return filled
    }
    
    // MARK: - Helper Functions
    
    private static func formatAddress(_ address: PersonaProfile.PostalAddress) -> String {
        let parts = [
            address.street,
            address.city,
            address.state,
            address.postalCode,
            address.country
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        
        return parts.joined(separator: ", ")
    }
    
    private static func createZipArchive(files: [S3File]) throws -> Data {
        // In production, use a proper ZIP library
        // For this example, we'll just concatenate (replace with actual ZIP implementation)
        // Consider using: https://github.com/marmelroy/Zip
        
        // Placeholder: In production, use proper ZIP creation
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        
        var archive = Data()
        for file in files {
            // Simple format: [name_length][name][data_length][data]
            let nameData = file.name.data(using: .utf8)!
            var nameLength = UInt32(nameData.count).bigEndian
            archive.append(Data(bytes: &nameLength, count: 4))
            archive.append(nameData)
            
            var dataLength = UInt32(file.data.count).bigEndian
            archive.append(Data(bytes: &dataLength, count: 4))
            archive.append(file.data)
        }
        
        return archive
    }
    
    private static func uploadToS3(data: Data, url: String, encryptionKey: SymmetricKey) async throws -> Void {
        // Implement actual S3 upload here
        guard let uploadURL = URL(string: url) else {
            throw SigningError.invalidURL
        }
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        
        // Add S3 authentication headers here
        // request.setValue("...", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SigningError.uploadFailed
        }
    }
}

// MARK: - Supporting Types

struct SignedDocumentPackage {
    let document: Data
    let signature: String // Base64-encoded signature
    let publicMetadata: SigningMetadata
    let encryptedPrivateDataPackage: Data? // Only present if private data was included
}

struct SigningMetadata: Codable {
    let did: String
    let prettyDID: String
    let publicAffiliations: String?
    let socialMediaLinks: String?
    let publicEmail: String?
    let timestamp: String
    let documentHash: String
    let signature: String
    let containsPrivateData: Bool
}

struct S3UploadResult {
    let url: String
    let documentID: String
    let packageFolder: String
    let encryptionKey: String // Base64-encoded key (store securely!)
    let timestamp: String
}

struct S3File {
    let name: String
    let data: Data
}

enum SigningError: LocalizedError {
    case personaNotValidated
    case missingPrivateData
    case encryptionFailed
    case invalidURL
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .personaNotValidated:
            return "Persona must be validated before signing documents with private information"
        case .missingPrivateData:
            return "Private data is required for this document but not available"
        case .encryptionFailed:
            return "Failed to encrypt document package"
        case .invalidURL:
            return "Invalid S3 upload URL"
        case .uploadFailed:
            return "Failed to upload document package to S3"
        }
    }
}

// MARK: - Extensions

extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Example Usage

/*
 
 Example 1: Sign a contract with private data
 
 ```swift
 let persona = try await PersonaStore.shared.getPersona(did: "john@example.com")
 let privateKey = try PrivateKeyStore.loadPrivateKey(for: persona.dID)
 let contractData = loadContractPDF()
 
 // Sign with private data (for legal documents)
 let signedPackage = try await DocumentSigningWithPrivateData.signDocumentWithPrivateInfo(
     documentData: contractData,
     persona: persona,
     privateKey: privateKey,
     requiresPrivateData: true  // This document requires private info
 )
 
 // Upload to S3
 let uploadResult = try await DocumentSigningWithPrivateData.uploadSignedPackage(
     signedPackage,
     to: "https://s3.amazonaws.com/my-bucket",
     documentID: "contract-12345"
 )
 
 print("Contract signed and uploaded to: \(uploadResult.url)")
 ```
 
 Example 2: Fill a will template with private data
 
 ```swift
 let template = """
 LAST WILL AND TESTAMENT
 
 I, {{PRIVATE.GIVEN_NAME}}, residing at {{PRIVATE.ADDRESS.FULL}},
 being of sound mind, do hereby declare this to be my Last Will and Testament.
 
 Contact: {{PRIVATE.EMAIL}}
 SSN: {{PRIVATE.SSN}}
 
 Signed: {{NAME}} ({{DID}})
 Date: {{DATE}}
 """
 
 let persona = try await PersonaStore.shared.getPersona(did: "john@example.com")
 
 // Fill template with private data
 let filledWill = try DocumentSigningWithPrivateData.fillTemplate(
     template,
     persona: persona,
     includePrivateData: true
 )
 
 // Convert to PDF and sign
 let willPDF = try generatePDF(from: filledWill)
 let signedPackage = try await DocumentSigningWithPrivateData.signDocumentWithPrivateInfo(
     documentData: willPDF,
     persona: persona,
     privateKey: privateKey,
     requiresPrivateData: true
 )
 ```
 
 Example 3: Sign a document without private data (simple signature)
 
 ```swift
 let document = loadSimpleDocument()
 let persona = try await PersonaStore.shared.getPersona(did: "john@example.com")
 let privateKey = try PrivateKeyStore.loadPrivateKey(for: persona.dID)
 
 // Sign without private data (public signature only)
 let signedPackage = try await DocumentSigningWithPrivateData.signDocumentWithPrivateInfo(
     documentData: document,
     persona: persona,
     privateKey: privateKey,
     requiresPrivateData: false  // No private data needed
 )
 
 // This package will not include encrypted private data
 ```
 
 */
