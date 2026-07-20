//
//  SendSigningFlowView.swift
//  451Wallet
//
//  Created by User451 on 1/23/26.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import CryptoKit
import CoreGraphics
#if os(iOS)
import UIKit
import ImageIO
import MobileCoreServices
#elseif os(macOS)
import AppKit
import ImageIO
import CoreServices
#endif

struct ReviewSheet: View {
    // Minimal placeholder body to satisfy View conformance and visualize progress/state
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showTilesUI {
                // Simple visualization of server-side workflow tiles
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server Workflow")
                        .font(.headline)
                    ForEach([ProgressTile.s3Cloud, .blockchain, .signatureFile, .searchIndexing]) { tile in
                        let entry = tileProgress[tile] ?? (false, [])
                        HStack {
                            Circle()
                                .fill(entry.completed ? Color.green : Color.gray.opacity(0.4))
                                .frame(width: 10, height: 10)
                            Text(String(describing: tile))
                                .font(.subheadline)
                        }
                    }
                }
            }

            // Linear progress and message
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: currentProgress)
                Text(progressMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Log output
            if !progressLog.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(progressLog.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.caption)
                                .monospaced()
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            // Temporary hook to present signer picker from the primary view
            Button {
                showPickSigners = true
            } label: {
                Label("Pick Signers", systemImage: "person.2")
            }
            .disabled(false)
            
            // Metadata editor button
            Button {
                showMetadataEditor = true
            } label: {
                Label("Edit Metadata", systemImage: "doc.text")
            }
            .disabled(isSubmitting)
        }
        .padding()
        .signerPickerSheet(isPresented: $showPickSigners, selectedSigners: $selectedSigners)
        .sheet(isPresented: $showMetadataEditor) {
            NavigationStack {
                DocumentMetadataEditor(metadata: $metadataForm)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showMetadataEditor = false
                            }
                        }
                    }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Send for Signing")
                    }
                }
                .disabled(isSubmitting)
            }
        }
    }

    // Progress tiles used to visualize server-side workflow
    private enum ProgressTile: Hashable, Identifiable {
        case s3Cloud
        case blockchain
        case signatureFile
        case searchIndexing

        var id: String {
            switch self {
            case .s3Cloud: return "s3Cloud"
            case .blockchain: return "blockchain"
            case .signatureFile: return "signatureFile"
            case .searchIndexing: return "searchIndexing"
            }
        }
    }

    // Tracks completion flag and log lines for each tile
    @State private var tileProgress: [ProgressTile: (completed: Bool, lines: [String]) ] = [:]

    // State used by progress callbacks and UI
    @State private var currentProgress: Double = 0.0
    @State private var progressMessage: String = ""
    @State private var progressLog: [String] = []
    @State private var showTilesUI: Bool = false
    @State private var isSubmitting: Bool = false

    @State private var showPickSigners = false
    @State private var selectedSigners: [SignerSelection] = []

    // Full 451 protocol metadata
    @State private var metadataForm: DocumentMetadataForm = DocumentMetadataForm()
    @State private var showMetadataEditor = false
    
    // ... other properties and methods ...

    /// Embeds the XMP packet into the original PDF data and returns new PDF data, or nil if failed.
    ///
    /// Uses PDFKit to load the PDF, then attempts to save with XMP metadata attached.
    /// Because PDFKit provides limited direct XMP support, this is a pragmatic approach:
    /// We save the PDF to a temporary file with attached metadata dictionary, then read back data.
    /// This may not embed full custom XMP metadata but sets the document attributes.
    ///
    /// TODO: For robust XMP embedding, use lower-level PDF editing libraries or manipulate PDF objects directly.
    private func embedXMPIntoPDF(original: Data, xmp: Data) -> Data? {
        guard let pdf = PDFDocument(data: original) else { return nil }
        
        // Convert form metadata to DocumentMetadata451
        let metadata: DocumentMetadata451 = metadataForm.toMetadata()
        
        // Construct a metadata dictionary with extended keys including subject, keywords, creator, and producer
        var docAttributes: [AnyHashable: Any] = [:]
        if let title = metadata.title, !title.isEmpty {
            docAttributes[PDFDocumentAttribute.titleAttribute] = title
        }
        if let author = metadata.author, !author.isEmpty {
            docAttributes[PDFDocumentAttribute.authorAttribute] = author
        }
        if let subtitle = metadata.subtitle, !subtitle.isEmpty {
            docAttributes[PDFDocumentAttribute.subjectAttribute] = subtitle
        } else if let description = metadata.description, !description.isEmpty {
            docAttributes[PDFDocumentAttribute.subjectAttribute] = description
        }
        var keywords: [String] = []
        if let subject = metadata.subject, !subject.isEmpty { keywords.append(subject) }
        if let audience = metadata.audience, !audience.isEmpty { keywords.append(audience) }
        if let contractId = metadata.contractId, !contractId.isEmpty { keywords.append(contractId) }
        if !keywords.isEmpty {
            docAttributes[PDFDocumentAttribute.keywordsAttribute] = keywords.joined(separator: ", ")
        }
        // Creator/Producer hints
        docAttributes[PDFDocumentAttribute.creatorAttribute] = "Signator"
        docAttributes[PDFDocumentAttribute.producerAttribute] = "Signator"
        
        pdf.documentAttributes = docAttributes
        
        // Attempt to write PDF with metadata to temp file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        
        if !pdf.write(to: tempFileURL) {
            return nil
        }
        
        guard var pdfData = try? Data(contentsOf: tempFileURL) else {
            try? FileManager.default.removeItem(at: tempFileURL)
            return nil
        }
        try? FileManager.default.removeItem(at: tempFileURL)
        
        // Check if pdfData already contains an XMP packet
        let xmpStartMarker = Data("<?xpacket".utf8)
        let xmpEndMarker = Data("<?xpacket end=".utf8) // The ending packet marker prefix
        
        if let startRange = pdfData.range(of: xmpStartMarker),
           let endStartRange = pdfData.range(of: xmpEndMarker, options: [], in: startRange.lowerBound..<pdfData.endIndex) {
            // Find end of xpacket: it ends with "?>"
            // Find index of "?>" after endStartRange.lowerBound
            if let endTagRange = pdfData.range(of: Data("?>".utf8), options: [], in: endStartRange.lowerBound..<pdfData.endIndex) {
                let afterEndIndex = endTagRange.upperBound
                // Replace existing xmp packet bytes with new xmp data
                var newPDFData = Data()
                newPDFData.append(pdfData.prefix(upTo: startRange.lowerBound))
                newPDFData.append(xmp)
                newPDFData.append(pdfData.suffix(from: afterEndIndex))
                return newPDFData
            }
        }
        
        // If no existing XMP packet found, inject a proper PDF Metadata stream object.
        // We must append a new indirect object, update catalog object to reference Metadata,
        // then append a new xref and trailer with updated startxref.
        
        // Helper: find all object numbers defined in PDF
        func findObjectNumbers(in data: Data) -> [Int] {
            // Pattern: "\n<num> 0 obj"
            // Use regex to find all occurrences
            let pattern = "\\n(\\d+) 0 obj"
            var results: [Int] = []
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let str = String(decoding: data, as: UTF8.self)
                let range = NSRange(str.startIndex..<str.endIndex, in: str)
                regex.enumerateMatches(in: str, options: [], range: range) { match, _, _ in
                    if let match = match, match.numberOfRanges > 1,
                       let range1 = Range(match.range(at: 1), in: str),
                       let num = Int(str[range1]) {
                        results.append(num)
                    }
                }
            }
            return results
        }
        
        let objNumbers = findObjectNumbers(in: pdfData)
        guard let maxObjNum = objNumbers.max() else {
            // Cannot find objects, return original data without modification
            return pdfData
        }
        let newObjNum = maxObjNum + 1
        
        // Compose Metadata stream dictionary and contents
        // PDF stream must have length matching the xmp data bytes
        
        // We add a newline before object for safety
        var metadataObject = "\n\(newObjNum) 0 obj\n<< /Type /Metadata /Subtype /XML /Length \(xmp.count) >>\nstream\n".data(using: .utf8)!
        metadataObject.append(xmp)
        metadataObject.append("\nendstream\nendobj\n".data(using: .utf8)!)
        
        // The offset of new object is current length of pdfData
        let newObjOffset = pdfData.count
        
        // Append metadata object to PDF data
        pdfData.append(metadataObject)
        
        // Locate startxref position to find the old xref start offset
        // startxref is at the end of PDF, followed by number and "%%EOF"
        // We search backwards for "startxref"
        guard let startxrefRange = pdfData.range(of: Data("startxref".utf8), options: .backwards) else {
            // Cannot find startxref, return pdfData as is
            return pdfData
        }
        
        // The offset value is after "startxref" + newline(s)
        // Parse the integer offset after startxref
        let afterStartxrefIndex = startxrefRange.upperBound
        let maxIndex = pdfData.count
        let tailData = pdfData[afterStartxrefIndex..<maxIndex]
        
        // Parse first integer after startxref as xref offset
        func parseXrefOffset(_ data: Data) -> Int? {
            // Read as string until non-digit chars
            let str = String(decoding: data, as: UTF8.self)
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            let scanner = Scanner(string: trimmed)
            var val: Int = 0
            if scanner.scanInt(&val) {
                return val
            }
            return nil
        }
        
        guard let oldXrefOffset = parseXrefOffset(tailData) else {
            // Cannot parse old xref offset, return pdfData as is
            return pdfData
        }
        
        // Parse existing xref table starting at oldXrefOffset
        // For simplicity, we won't parse the entire xref, but we will build a new xref table for the new object only,
        // and append a new trailer referencing old trailer with added /Metadata
        
        // To update /Metadata in catalog object, we must find the catalog object number and insert /Metadata <newObjNum> 0 R.
        
        // Find catalog object number:
        // We search for pattern: "\n<num> 0 obj" followed by dictionary containing "/Type /Catalog"
        // This is a rough heuristic, but should work for most PDFs.
        
        func findCatalogObjectNumber(in data: Data) -> Int? {
            let pattern = "\\n(\\d+) 0 obj\\s*<<[^>]*?/Type\\s*/Catalog"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let str = String(decoding: data, as: UTF8.self)
                let range = NSRange(str.startIndex..<str.endIndex, in: str)
                if let match = regex.firstMatch(in: str, options: [], range: range),
                   match.numberOfRanges > 1,
                   let range1 = Range(match.range(at: 1), in: str),
                   let num = Int(str[range1]) {
                    return num
                }
            }
            return nil
        }
        
        guard let catalogObjNum = findCatalogObjectNumber(in: pdfData) else {
            // Cannot find catalog object, cannot inject /Metadata reference, return pdfData as is
            return pdfData
        }
        
        // We need to insert /Metadata <newObjNum> 0 R into catalog object dictionary.
        // To do this, find the catalog object range and insert our new entry before the closing ">>"
        
        // Find catalog object range:
        // Pattern: "\n\(catalogObjNum) 0 obj" ... "endobj"
        let catalogObjPattern = "\\n\(catalogObjNum) 0 obj(.*?)endobj"
        var catalogRangeInData: Range<Data.Index>? = nil
        var catalogContentRangeInData: Range<Data.Index>? = nil
        if let regex = try? NSRegularExpression(pattern: catalogObjPattern, options: [.dotMatchesLineSeparators]) {
            let str = String(decoding: pdfData, as: UTF8.self)
            let range = NSRange(str.startIndex..<str.endIndex, in: str)
            if let match = regex.firstMatch(in: str, options: [], range: range),
               match.numberOfRanges > 1,
               let fullRange = Range(match.range(at: 0), in: str),
               let contentRange = Range(match.range(at: 1), in: str) {
                // Convert string ranges to Data ranges
                if let startDataIndex = pdfData.index(pdfData.startIndex, offsetBy: str.distance(from: str.startIndex, to: fullRange.lowerBound), limitedBy: pdfData.endIndex),
                   let endDataIndex = pdfData.index(pdfData.startIndex, offsetBy: str.distance(from: str.startIndex, to: fullRange.upperBound), limitedBy: pdfData.endIndex),
                   let contentStartIndex = pdfData.index(pdfData.startIndex, offsetBy: str.distance(from: str.startIndex, to: contentRange.lowerBound), limitedBy: pdfData.endIndex),
                   let contentEndIndex = pdfData.index(pdfData.startIndex, offsetBy: str.distance(from: str.startIndex, to: contentRange.upperBound), limitedBy: pdfData.endIndex) {
                    catalogRangeInData = startDataIndex..<endDataIndex
                    catalogContentRangeInData = contentStartIndex..<contentEndIndex
                }
            }
        }
        
        guard let catalogRange = catalogRangeInData, let contentRange = catalogContentRangeInData else {
            // Cannot find catalog object range, return pdfData as is
            return pdfData
        }
        
        // Extract catalog content string (inside object dictionary)
        let catalogContentData = pdfData[contentRange]
        var catalogContentStr = String(decoding: catalogContentData, as: UTF8.self)
        
        // Insert /Metadata <newObjNum> 0 R before last ">>"
        if let lastDictEndRange = catalogContentStr.range(of: ">>", options: .backwards) {
            let insertStr = "\n/Metadata \(newObjNum) 0 R\n"
            catalogContentStr.insert(contentsOf: insertStr, at: lastDictEndRange.lowerBound)
        } else {
            // No dictionary end found, just append (unlikely, malformed PDF)
            catalogContentStr.append("\n/Metadata \(newObjNum) 0 R\n")
        }
        
        // Recompose catalog object full data
        let catalogObjPrefixData = pdfData[pdfData.index(catalogRange.lowerBound, offsetBy: 0)..<contentRange.lowerBound]
        let catalogObjSuffixData = pdfData[contentRange.upperBound..<catalogRange.upperBound]
        var newCatalogObjData = Data()
        newCatalogObjData.append(catalogObjPrefixData)
        if let updatedContentData = catalogContentStr.data(using: .utf8) {
            newCatalogObjData.append(updatedContentData)
        } else {
            // If encoding fails, return original pdfData
            return pdfData
        }
        newCatalogObjData.append(catalogObjSuffixData)
        
        // Replace catalog object data in pdfData with new content
        pdfData.replaceSubrange(catalogRange, with: newCatalogObjData)
        
        // Now we must append a new xref section for the new object and update the trailer and startxref
        
        // We'll build a new incremental update xref
        // Format:
        // xref
        // <start object number> <count>
        // <entry line(s)>
        // trailer
        // << ... >>
        // startxref
        // <offset>
        // %%EOF
        
        // Find the old trailer dictionary range by scanning backwards from oldXrefOffset
        // We'll try to find "trailer" keyword followed by a dictionary and "startxref"
        // We'll reuse the existing /Root and other entries except add /Metadata <newObjNum> 0 R
        
        // To extract the old trailer dictionary, find "trailer" starting from oldXrefOffset backward
        guard let trailerRange = pdfData.range(of: Data("trailer".utf8), options: [], in: oldXrefOffset..<pdfData.count) else {
            // Cannot find trailer, return pdfData as is
            return pdfData
        }
        
        // Trailer dictionary starts after "trailer"
        let trailerDictStart = pdfData.index(trailerRange.upperBound, offsetBy: 1, limitedBy: pdfData.endIndex) ?? trailerRange.upperBound
        
        // Find the end of trailer dictionary: it's enclosed in << ... >>
        // We'll find matching << and >> after trailerDictStart
        func findDictionaryRange(in data: Data, startingAt index: Data.Index) -> Range<Data.Index>? {
            // Find first occurrence of '<<' at or after index
            guard let dictStartRange = data.range(of: Data("<<".utf8), options: [], in: index..<data.endIndex) else { return nil }
            var pos = dictStartRange.upperBound
            var depth = 1
            while pos < data.endIndex && depth > 0 {
                if data[pos..<min(data.endIndex, data.index(pos, offsetBy: 2))] == Data("<<".utf8) {
                    depth += 1
                    pos = data.index(pos, offsetBy: 2)
                } else if data[pos..<min(data.endIndex, data.index(pos, offsetBy: 2))] == Data(">>".utf8) {
                    depth -= 1
                    pos = data.index(pos, offsetBy: 2)
                } else {
                    pos = data.index(after: pos)
                }
            }
            if depth == 0 {
                return dictStartRange.lowerBound..<pos
            }
            return nil
        }
        
        guard let trailerDictRange = findDictionaryRange(in: pdfData, startingAt: trailerDictStart) else {
            return pdfData
        }
        
        let trailerDictData = pdfData[trailerDictRange]
        guard var trailerDictStr = String(data: trailerDictData, encoding: .utf8) else {
            return pdfData
        }
        
        // We want to add /Metadata <newObjNum> 0 R to the trailer dictionary if not already present.
        // But typically Metadata is a key in the catalog object, not trailer. So we leave trailer unchanged.
        // Just keep trailerDictStr as is.
        
        // Find /Root entry (we preserve it)
        // We'll keep trailer as is, but must add /Size entry updated to newObjNum + 1
        // We replace /Size <old> with /Size <newObjNum+1>
        
        let newSizeValue = newObjNum + 1
        let sizePattern = "/Size \\d+"
        if let regex = try? NSRegularExpression(pattern: sizePattern, options: []) {
            let nsrange = NSRange(trailerDictStr.startIndex..<trailerDictStr.endIndex, in: trailerDictStr)
            trailerDictStr = regex.stringByReplacingMatches(in: trailerDictStr, options: [], range: nsrange, withTemplate: "/Size \(newSizeValue)")
        } else {
            // If regex fails, try simple replacement
            if let sizeRange = trailerDictStr.range(of: "/Size ") {
                let afterSize = trailerDictStr[sizeRange.upperBound...]
                if let endOfNumber = afterSize.firstIndex(where: { !$0.isNumber }) {
                    trailerDictStr.replaceSubrange(sizeRange.lowerBound..<endOfNumber, with: "/Size \(newSizeValue)")
                }
            }
        }
        
        // Compose new xref section incrementally
        let newXrefOffset = pdfData.count
        
        var incrementalXref = "\nxref\n\(newObjNum) 1\n"
        let offsetString = String(format: "%010d 00000 n \n", newObjOffset)
        incrementalXref.append(offsetString)
        incrementalXref.append("trailer\n")
        incrementalXref.append(trailerDictStr)
        incrementalXref.append("\nstartxref\n")
        incrementalXref.append("\(newXrefOffset)\n%%EOF\n")
        
        guard let incrementalXrefData = incrementalXref.data(using: .utf8) else {
            // Failed to encode incremental xref, return pdfData as is
            return pdfData
        }
        
        pdfData.append(incrementalXrefData)
        
        return pdfData
    }
    
    func submit() async {
        await MainActor.run {
            isSubmitting = true
            currentProgress = 0
            progressMessage = "Starting..."
            progressLog.removeAll()
            tileProgress.removeAll()
            showTilesUI = false
        }
        defer { Task { @MainActor in isSubmitting = false } }
        
        // Remove any references or declarations of privateKey, authorDID, personaPublicKey, additionalSigners
        
        // Define the nested helper performDocumentSigningWorkflow inside submit()
        func performDocumentSigningWorkflow(
            documentData: Data,
            originalFilename: String?,
            metadata: DocumentMetadata451
        ) async throws -> (documentId: String, attestEntryID: String, accessCode: String?) {
            return try await DocumentSigningService.completeSigningWorkflowWithSSEProgress(
                documentData: documentData,
                originalFilename: originalFilename,
                metadata: metadata,
                onProgress: { update in
                    Task { @MainActor in
                        currentProgress = update.progress
                        progressMessage = update.message
                        let pct = String(format: "%.0f", update.progress * 100)
                        progressLog.append("[\(pct)%] \(update.message)")
                    }
                },
                onServerProgress: { serverProgress in
                    Task { @MainActor in
                        currentProgress = serverProgress.progress
                        progressMessage = serverProgress.message
                        showTilesUI = true
                        let msg = serverProgress.message.lowercased()
                        @MainActor func append(_ tile: ProgressTile, _ line: String) {
                            var entry = tileProgress[tile] ?? (false, [])
                            entry.lines.append(line)
                            tileProgress[tile] = entry
                        }
                        @MainActor func complete(_ tile: ProgressTile, _ line: String? = nil) {
                            var entry = tileProgress[tile] ?? (false, [])
                            if let line { entry.lines.append(line) }
                            entry.completed = true
                            tileProgress[tile] = entry
                        }
                        if msg.contains("provider") || msg.contains("upload") || msg.contains("s3") || msg.contains("minio") || msg.contains("backblaze") || msg.contains("r2") {
                            append(ProgressTile.s3Cloud, serverProgress.message)
                            if msg.contains("success") || msg.contains("uploaded") || msg.contains("complete") { complete(ProgressTile.s3Cloud) }
                        }
                        if msg.contains("ledger") || msg.contains("proof") || msg.contains("attest") || msg.contains("blockchain") {
                            append(ProgressTile.blockchain, serverProgress.message)
                            if msg.contains("success") || msg.contains("created") || msg.contains("complete") { complete(ProgressTile.blockchain) }
                        }
                        if msg.contains("signature") || msg.contains("signatures") || msg.contains("sign file") || msg.contains("signing") {
                            append(ProgressTile.signatureFile, serverProgress.message)
                            if msg.contains("success") || msg.contains("created") || msg.contains("complete") { complete(ProgressTile.signatureFile) }
                        }
                        if msg.contains("index") || msg.contains("search") || msg.contains("metadata") {
                            append(ProgressTile.searchIndexing, serverProgress.message)
                            if msg.contains("indexed") || msg.contains("complete") || msg.contains("success") { complete(ProgressTile.searchIndexing) }
                        }
                        let progressPercent = String(format: "%.0f", serverProgress.progress * 100)
                        progressLog.append("[\(progressPercent)%] \(serverProgress.message)")
                        if let docId = serverProgress.documentId, !progressLog.contains(where: { $0.contains(docId) }) {
                            progressLog.append("  └─ Document ID: \(docId)")
                        }
                        if let entryId = serverProgress.entryId, !progressLog.contains(where: { $0.contains(entryId) }) {
                            progressLog.append("  └─ Entry ID: \(entryId)")
                        }
                    }
                }
            )
        }
        
        // Usage example inside submit() replacing old call site:
        // let (documentId, attestEntryID, accessCode) = try await performDocumentSigningWorkflow(documentData: dataForSubmission, originalFilename: originalFilename)
        
        // ... rest of submit() implementation ...
    }

    // ... rest of ReviewSheet ...
}

struct DocumentMetadataEditor: View {
    @Binding var metadata: DocumentMetadataForm

    var body: some View {
        Form {
            Section("Core") {
                TextField("Title", text: $metadata.title)
                TextField("Subtitle", text: $metadata.subtitle)
                TextField("Subject", text: $metadata.subject)
                TextField("Type", text: $metadata.type)
                TextField("Language", text: $metadata.language)
            }

            Section("Description") {
                TextEditor(text: $metadata.description)
                    .frame(minHeight: 120)
            }

            Section("Attribution") {
                TextField("Author", text: $metadata.author)
                TextField("Publisher", text: $metadata.publisher)
                TextField("Audience", text: $metadata.audience)
            }

            Section("Rights") {
                TextField("Rights", text: $metadata.rights)
                TextField("Access Rights", text: $metadata.accessrights)
            }

            Section("Identifiers") {
                TextField("DOI", text: $metadata.doi)
                TextField("ISBN", text: $metadata.isbn)
                TextField("Contract ID", text: $metadata.contractId)
            }
        }
        .navigationTitle("Metadata")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// `SignerSelection` now lives in Common (Common/Models/SignerSelection.swift).

struct PickSignersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selections: [SignerSelection] = []
    let onDone: ([SignerSelection]) -> Void

    private var collaborators: [PersonaResolvedProfile] {
        CollaboratorsStore.shared.collaborators
    }
    var body: some View {
        NavigationStack {
            List {
                if collaborators.isEmpty {
                    Section {
                        Text("No contacts yet. Add collaborators in the Contacts tab to pick signers here.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(collaborators, id: \.did) { profile in
                        HStack(spacing: 12) {
                            Button(action: { toggleSelection(for: profile) }) {
                                Image(systemName: isSelected(profile.did) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isSelected(profile.did) ? .blue : .secondary)
                            }
                            .buttonStyle(.plain)

                            // Show the signator's handle / DID
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.handle ?? profile.did)
                                    .font(.body)
                                if profile.handle != nil {
                                    Text(profile.did)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }

                            Spacer()
                            if let idx = selections.firstIndex(where: { $0.did == profile.did }) {
                                Picker("Role", selection: $selections[idx].role) {
                                    Text("Author").tag(DocumentSigningService.SignerRole.author)
                                    Text("Contract Party").tag(DocumentSigningService.SignerRole.contractParty)
                                    Text("Witness").tag(DocumentSigningService.SignerRole.witness)
                                    Text("Notary").tag(DocumentSigningService.SignerRole.notary)
                                    Text("Reviewer").tag(DocumentSigningService.SignerRole.reviewer)
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pick Signers")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(selections)
                        dismiss()
                    }
                    .disabled(selections.isEmpty)
                }
            }
        }
    }

    private func isSelected(_ did: String) -> Bool {
        selections.contains(where: { $0.did == did })
    }

    private func toggleSelection(for profile: PersonaResolvedProfile) {
        if let idx = selections.firstIndex(where: { $0.did == profile.did }) {
            selections.remove(at: idx)
        } else {
            selections.append(SignerSelection(did: profile.did, role: .contractParty))
        }
    }
}

extension View {
    func signerPickerSheet(isPresented: Binding<Bool>, selectedSigners: Binding<[SignerSelection]>) -> some View {
        self.sheet(isPresented: isPresented) {
            PickSignersView { selections in
                selectedSigners.wrappedValue = selections
                isPresented.wrappedValue = false
            }
        }
    }
}

// All top-level duplicate definitions and instructional comments removed.
