//
//  DocumentMetadataEmbedding.swift
//  451Wallet
//
//  Created by Assistant on 1/23/26.
//
//  Embeds metadata INSIDE documents rather than sending it separately.
//  - Binary documents (PDF, images): XMP metadata
//  - Text documents (JSON, Markdown): JSON frontmatter
//  - Generic documents: Wrapper format with metadata header
//

import Foundation
import PDFKit

// MARK: - Document Metadata Embedding

/// Embeds metadata directly into documents before upload
struct DocumentMetadataEmbedder {
    
    enum EmbeddingError: Error {
        case unsupportedFormat
        case embeddingFailed(String)
        case pdfCreationFailed
        case invalidJSON
    }
    
    // MARK: - Main API
    
    /// Embeds metadata into a document based on its format
    /// Returns the modified document data with metadata embedded
    static func embed(
        metadata: DocumentMetadata451,
        into documentData: Data,
        filename: String
    ) throws -> Data {
        let ext = (filename as NSString).pathExtension.lowercased()
        
        switch ext {
        case "pdf":
            return try embedIntoPDF(metadata: metadata, pdfData: documentData)
            
        case "json":
            return try embedIntoJSON(metadata: metadata, jsonData: documentData)
            
        case "txt", "md", "markdown":
            return try embedIntoText(metadata: metadata, textData: documentData, format: ext)
            
        case "jpg", "jpeg", "png", "gif":
            // For images, wrap in a container format with XMP
            return try wrapWithMetadata(metadata: metadata, data: documentData, originalFormat: ext)
            
        default:
            // For unknown formats, use generic wrapper
            return try wrapWithMetadata(metadata: metadata, data: documentData, originalFormat: ext)
        }
    }
    
    // MARK: - PDF Metadata Embedding (XMP)
    
    /// Embeds metadata into PDF using PDF metadata dictionary and XMP
    private static func embedIntoPDF(
        metadata: DocumentMetadata451,
        pdfData: Data
    ) throws -> Data {
        guard let pdfDocument = PDFDocument(data: pdfData) else {
            throw EmbeddingError.pdfCreationFailed
        }
        
        // Create PDF metadata dictionary
        var pdfMetadata: [String: Any] = [:]
        
        if let title = metadata.title {
            pdfMetadata[PDFDocumentAttribute.titleAttribute.rawValue] = title
        }
        if let author = metadata.author {
            pdfMetadata[PDFDocumentAttribute.authorAttribute.rawValue] = author
        }
        if let description = metadata.description {
            pdfMetadata[PDFDocumentAttribute.subjectAttribute.rawValue] = description
        }
        
        // Add custom 451 metadata as XMP
        let xmpMetadata = generateXMP(from: metadata)
        
        // Store XMP in PDF metadata
        pdfMetadata["451:metadata"] = xmpMetadata
        
        // Set the metadata
        pdfDocument.documentAttributes = pdfMetadata
        
        // Return modified PDF
        guard let modifiedPDF = pdfDocument.dataRepresentation() else {
            throw EmbeddingError.embeddingFailed("Could not generate PDF with metadata")
        }
        
        return modifiedPDF
    }
    
    /// Generates XMP metadata block
    private static func generateXMP(from metadata: DocumentMetadata451) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let jsonData = try? encoder.encode(metadata),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return ""
        }
        
        // Wrap in XMP packet
        return """
        <?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                <rdf:Description rdf:about=""
                    xmlns:dc451="http://451.io/metadata/1.0/">
                    <dc451:metadata>\(jsonString.replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;"))</dc451:metadata>
                </rdf:Description>
            </rdf:RDF>
        </x:xmpmeta>
        <?xpacket end="w"?>
        """
    }
    
    // MARK: - JSON Metadata Embedding
    
    /// Embeds metadata into JSON document as a top-level field
    private static func embedIntoJSON(
        metadata: DocumentMetadata451,
        jsonData: Data
    ) throws -> Data {
        guard var json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw EmbeddingError.invalidJSON
        }
        
        // Encode metadata to dictionary
        let metadataJSON = try JSONEncoder().encode(metadata)
        guard let metadataDict = try? JSONSerialization.jsonObject(with: metadataJSON) as? [String: Any] else {
            throw EmbeddingError.embeddingFailed("Could not convert metadata to JSON dictionary")
        }
        
        // Add metadata as top-level field
        json["@metadata"] = metadataDict
        json["@format"] = "451"
        json["@version"] = "1.0"
        
        // Re-serialize
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        return try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
    }
    
    // MARK: - Text/Markdown Metadata Embedding (Frontmatter)
    
    /// Embeds metadata as YAML/JSON frontmatter
    private static func embedIntoText(
        metadata: DocumentMetadata451,
        textData: Data,
        format: String
    ) throws -> Data {
        guard let originalText = String(data: textData, encoding: .utf8) else {
            throw EmbeddingError.embeddingFailed("Could not decode text as UTF-8")
        }
        
        // Generate JSON frontmatter
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let metadataJSON = try encoder.encode(metadata)
        guard let metadataString = String(data: metadataJSON, encoding: .utf8) else {
            throw EmbeddingError.embeddingFailed("Could not encode metadata as JSON")
        }
        
        // Add frontmatter block
        let documentWithMetadata: String
        if format == "md" || format == "markdown" {
            // Markdown: Use YAML-style delimiters but JSON content
            documentWithMetadata = """
            ---
            format: 451
            metadata: \(metadataString.replacingOccurrences(of: "\n", with: "\n  "))
            ---
            
            \(originalText)
            """
        } else {
            // Plain text: Use comment block
            documentWithMetadata = """
            /* 451 Document Metadata
            \(metadataString)
            End Metadata */
            
            \(originalText)
            """
        }
        
        return documentWithMetadata.data(using: .utf8) ?? textData
    }
    
    // MARK: - Generic Wrapper Format
    
    /// Wraps any document with a metadata header
    /// Creates a 451-specific container format
    private static func wrapWithMetadata(
        metadata: DocumentMetadata451,
        data: Data,
        originalFormat: String
    ) throws -> Data {
        // Create wrapper structure:
        // [4 bytes: magic number "451M"]
        // [4 bytes: metadata length]
        // [N bytes: JSON metadata]
        // [4 bytes: document length]
        // [M bytes: original document]
        
        let magicNumber = "451M".data(using: .utf8)!
        
        // Encode metadata
        let encoder = JSONEncoder()
        let metadataJSON = try encoder.encode(metadata)
        
        // Build header
        var wrapper = Data()
        wrapper.append(magicNumber) // Magic number
        wrapper.append(UInt32(metadataJSON.count).data) // Metadata length
        wrapper.append(metadataJSON) // Metadata
        wrapper.append(UInt32(data.count).data) // Document length
        wrapper.append(data) // Original document
        
        return wrapper
    }
    
    // MARK: - Metadata Extraction (for verification/reading)
    
    /// Extracts metadata from a document
    static func extract(from documentData: Data, filename: String) throws -> DocumentMetadata451? {
        let ext = (filename as NSString).pathExtension.lowercased()
        
        switch ext {
        case "pdf":
            return try extractFromPDF(pdfData: documentData)
            
        case "json":
            return try extractFromJSON(jsonData: documentData)
            
        case "txt", "md", "markdown":
            return try extractFromText(textData: documentData)
            
        default:
            return try extractFromWrapper(data: documentData)
        }
    }
    
    private static func extractFromPDF(pdfData: Data) throws -> DocumentMetadata451? {
        guard let pdfDocument = PDFDocument(data: pdfData),
              let attributes = pdfDocument.documentAttributes else {
            return nil
        }
        
        // Try to extract XMP metadata
        if let xmpString = attributes["451:metadata"] as? String {
            // Parse XMP to extract JSON
            // Simple extraction - find JSON between tags
            let pattern = "<dc451:metadata>(.*?)</dc451:metadata>"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
               let match = regex.firstMatch(in: xmpString, range: NSRange(xmpString.startIndex..., in: xmpString)),
               let jsonRange = Range(match.range(at: 1), in: xmpString) {
                let jsonString = String(xmpString[jsonRange])
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                
                if let jsonData = jsonString.data(using: .utf8),
                   let metadata = try? JSONDecoder().decode(DocumentMetadata451.self, from: jsonData) {
                    return metadata
                }
            }
        }
        
        return nil
    }
    
    private static func extractFromJSON(jsonData: Data) throws -> DocumentMetadata451? {
        guard let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let metadataDict = json["@metadata"] as? [String: Any] else {
            return nil
        }
        
        let metadataJSON = try JSONSerialization.data(withJSONObject: metadataDict)
        return try JSONDecoder().decode(DocumentMetadata451.self, from: metadataJSON)
    }
    
    private static func extractFromText(textData: Data) throws -> DocumentMetadata451? {
        guard let text = String(data: textData, encoding: .utf8) else {
            return nil
        }
        
        // Try to extract frontmatter
        // Markdown style: between --- markers
        if text.hasPrefix("---") {
            let pattern = "---\\nformat: 451\\nmetadata: (.*?)\\n---"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let jsonRange = Range(match.range(at: 1), in: text) {
                let jsonString = String(text[jsonRange])
                
                if let jsonData = jsonString.data(using: .utf8),
                   let metadata = try? JSONDecoder().decode(DocumentMetadata451.self, from: jsonData) {
                    return metadata
                }
            }
        }
        
        // Comment style
        if text.contains("/* 451 Document Metadata") {
            let pattern = "/\\* 451 Document Metadata\\n(.*?)\\nEnd Metadata \\*/"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let jsonRange = Range(match.range(at: 1), in: text) {
                let jsonString = String(text[jsonRange])
                
                if let jsonData = jsonString.data(using: .utf8),
                   let metadata = try? JSONDecoder().decode(DocumentMetadata451.self, from: jsonData) {
                    return metadata
                }
            }
        }
        
        return nil
    }
    
    private static func extractFromWrapper(data: Data) throws -> DocumentMetadata451? {
        guard data.count >= 8 else { return nil }
        
        // Check magic number
        let magicNumber = data.prefix(4)
        guard String(data: magicNumber, encoding: .utf8) == "451M" else {
            return nil
        }
        
        // Read metadata length
        let metadataLengthData = data.subdata(in: 4..<8)
        let metadataLength = Int(UInt32(data: metadataLengthData))
        
        guard data.count >= 8 + metadataLength else {
            return nil
        }
        
        // Extract metadata
        let metadataJSON = data.subdata(in: 8..<(8 + metadataLength))
        return try JSONDecoder().decode(DocumentMetadata451.self, from: metadataJSON)
    }
}

// MARK: - Helper Extensions

extension UInt32 {
    var data: Data {
        var value = self
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }
    
    init(data: Data) {
        self = data.withUnsafeBytes { $0.load(as: UInt32.self) }
    }
}

// MARK: - Usage Examples

/*
 
 // Example 1: Upload a PDF with embedded metadata
 func uploadPDFWithEmbeddedMetadata(pdfData: Data, metadata: DocumentMetadata451) async throws {
     // Embed metadata INTO the PDF
     let pdfWithMetadata = try DocumentMetadataEmbedder.embed(
         metadata: metadata,
         into: pdfData,
         filename: "contract.pdf"
     )
     
     // Upload just the modified PDF - metadata is already inside it
     let response = try await DocumentSigningService.uploadDocument(
         documentData: pdfWithMetadata,
         originalFilename: "contract.pdf",
         metadata: nil  // No separate metadata needed!
     )
     
     print("✅ Uploaded PDF with embedded metadata: \(response.documentId)")
 }
 
 // Example 2: Upload JSON with embedded metadata
 func uploadJSONWithEmbeddedMetadata(jsonData: Data, metadata: DocumentMetadata451) async throws {
     // Embed metadata as @metadata field in JSON
     let jsonWithMetadata = try DocumentMetadataEmbedder.embed(
         metadata: metadata,
         into: jsonData,
         filename: "data.json"
     )
     
     // Upload - metadata is in the JSON itself
     let response = try await DocumentSigningService.uploadDocument(
         documentData: jsonWithMetadata,
         originalFilename: "data.json",
         metadata: nil
     )
     
     print("✅ Uploaded JSON with embedded metadata: \(response.documentId)")
 }
 
 // Example 3: Upload markdown with frontmatter
 func uploadMarkdownWithFrontmatter(markdownData: Data, metadata: DocumentMetadata451) async throws {
     // Embed as YAML frontmatter
     let markdownWithMetadata = try DocumentMetadataEmbedder.embed(
         metadata: metadata,
         into: markdownData,
         filename: "document.md"
     )
     
     let response = try await DocumentSigningService.uploadDocument(
         documentData: markdownWithMetadata,
         originalFilename: "document.md",
         metadata: nil
     )
     
     print("✅ Uploaded Markdown with frontmatter: \(response.documentId)")
 }
 
 // Example 4: Upload any file with wrapper format
 func uploadWithWrapper(data: Data, filename: String, metadata: DocumentMetadata451) async throws {
     // Wrap in 451 container format
     let wrappedData = try DocumentMetadataEmbedder.embed(
         metadata: metadata,
         into: data,
         filename: filename
     )
     
     let response = try await DocumentSigningService.uploadDocument(
         documentData: wrappedData,
         originalFilename: filename,
         metadata: nil
     )
     
     print("✅ Uploaded wrapped document: \(response.documentId)")
 }
 
 // Example 5: Extract metadata from received document
 func readDocumentMetadata(documentData: Data, filename: String) throws {
     if let metadata = try DocumentMetadataEmbedder.extract(from: documentData, filename: filename) {
         print("📖 Extracted metadata:")
         print("   Title: \(metadata.title ?? "N/A")")
         print("   Author: \(metadata.author ?? "N/A")")
         print("   Type: \(metadata.type ?? "N/A")")
     } else {
         print("⚠️ No embedded metadata found")
     }
 }
 
 */

