//
//  DocumentMetadataEditor.swift
//  451Wallet
//
//  Created by User451 on 1/23/26.
//
//  UI for collecting comprehensive document metadata
//

import SwiftUI

/// Comprehensive metadata editor for document submission
struct DocumentMetadataEditor: View {
    @Binding var metadata: DocumentMetadataForm
    
    enum MetadataSection: String, CaseIterable, Identifiable {
        case core = "Core Information"
        case description = "Description"
        case creators = "Authors & Contributors"
        case rights = "Rights & Access"
        case publication = "Publication Details"
        case identifiers = "Identifiers"
        case technical = "Technical Details"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .core: return "doc.text"
            case .description: return "text.alignleft"
            case .creators: return "person.2"
            case .rights: return "lock.shield"
            case .publication: return "calendar"
            case .identifiers: return "number"
            case .technical: return "gearshape"
            }
        }
    }
    
    var body: some View {
        Form {
            DocumentMetadataEditorSections(metadata: $metadata)
        }
        .navigationTitle("Document Metadata")
        .inlineNavigationTitle()
    }
}

struct DocumentMetadataEditorSections: View {
    @Binding var metadata: DocumentMetadataForm
    var showsTypePicker: Bool = true
    @State private var expandedSections: Set<DocumentMetadataEditor.MetadataSection> = [.core]

    var body: some View {
        // Core Information (always shown)
        Section {
            TextField("Title *", text: $metadata.title)
                .font(.headline)
            TextField("Subtitle", text: $metadata.subtitle)

            if showsTypePicker {
                Picker("Document Type", selection: $metadata.type) {
                    Text("Contract").tag("contract")
                    Text("Document").tag("document")
                }
                .pickerStyle(.segmented)
                .onAppear {
                    // Ensure default selection is always Contract if unset or invalid
                    let validTags: Set<String> = ["contract", "document"]
                    if !validTags.contains(metadata.type) {
                        metadata.type = "contract"
                    }
                }
            }
        } header: {
            Label("Core Information", systemImage: DocumentMetadataEditor.MetadataSection.core.icon)
        } footer: {
            Text("Title is required. Other fields are optional but recommended.")
                .font(.caption)
        }
        
        // Description
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedSections.contains(.description) },
                set: { isExpanded in
                    if isExpanded {
                        expandedSections.insert(.description)
                    } else {
                        expandedSections.remove(.description)
                    }
                }
            )
        ) {
            TextField("Subject / Keywords", text: $metadata.subject, axis: .vertical)
                .lineLimit(2...4)
            
            TextField("Description / Abstract", text: $metadata.description, axis: .vertical)
                .lineLimit(4...8)
            
            TextField("Target Audience", text: $metadata.audience)
        } label: {
            Label("Description", systemImage: DocumentMetadataEditor.MetadataSection.description.icon)
        }
        
        // Authors & Contributors
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedSections.contains(.creators) },
                set: { isExpanded in
                    if isExpanded {
                        expandedSections.insert(.creators)
                    } else {
                        expandedSections.remove(.creators)
                    }
                }
            )
        ) {
            TextField("Primary Author(s)", text: $metadata.author)
                .platformTextContentType(.name)
            
            TextField("Additional Contributors", text: $metadata.publisher)
            
            TextField("Publisher / Organization", text: $metadata.publisher)
        } label: {
            Label("Authors & Contributors", systemImage: DocumentMetadataEditor.MetadataSection.creators.icon)
        }
        
        // Rights & Access
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedSections.contains(.rights) },
                set: { isExpanded in
                    if isExpanded {
                        expandedSections.insert(.rights)
                    } else {
                        expandedSections.remove(.rights)
                    }
                }
            )
        ) {
            TextField("Rights Statement / License", text: $metadata.rights, axis: .vertical)
                .lineLimit(2...4)
        } label: {
            Label("Rights & Access", systemImage: DocumentMetadataEditor.MetadataSection.rights.icon)
        }
        
        // Publication Details
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedSections.contains(.publication) },
                set: { isExpanded in
                    if isExpanded {
                        expandedSections.insert(.publication)
                    } else {
                        expandedSections.remove(.publication)
                    }
                }
            )
        ) {
            DatePicker("Publication Date", selection: Binding(
                get: {
                    // Parse ISO date string or return current date
                    if let date = ISO8601DateFormatter().date(from: metadata.publicationDate) {
                        return date
                    }
                    return Date()
                },
                set: { date in
                    metadata.publicationDate = ISO8601DateFormatter().string(from: date)
                }
            ), displayedComponents: .date)
            
            Picker("Language", selection: $metadata.language) {
                Text("English").tag("English")
                Text("Spanish").tag("Spanish")
                Text("French").tag("French")
                Text("German").tag("German")
                Text("Chinese").tag("Chinese")
                Text("Japanese").tag("Japanese")
                Text("Other").tag("Other")
            }
        } label: {
            Label("Publication Details", systemImage: DocumentMetadataEditor.MetadataSection.publication.icon)
        }
        
        // Identifiers
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedSections.contains(.identifiers) },
                set: { isExpanded in
                    if isExpanded {
                        expandedSections.insert(.identifiers)
                    } else {
                        expandedSections.remove(.identifiers)
                    }
                }
            )
        ) {
            TextField("DOI", text: $metadata.doi)
                .platformTextContentType(.url)
                .platformKeyboardType(.url)
            
            TextField("ISBN", text: $metadata.isbn)
            
            TextField("Contract ID", text: $metadata.contractId)
        } label: {
            Label("Identifiers", systemImage: DocumentMetadataEditor.MetadataSection.identifiers.icon)
        }
    }
}

/// Compact metadata editor showing only essential fields
struct CompactMetadataEditor: View {
    @Binding var metadata: DocumentMetadataForm
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Title *", text: $metadata.title)
                .textFieldStyle(.roundedBorder)
                .font(.headline)
            
            TextField("Author(s)", text: $metadata.author)
                .textFieldStyle(.roundedBorder)
            
            Picker("Document Type", selection: $metadata.type) {
                Text("Select type").tag("")
                Text("Contract").tag("contract")
                Text("Agreement").tag("agreement")
                Text("Article").tag("article")
                Text("Report").tag("report")
                Text("Other").tag("other")
            }
            .pickerStyle(.menu)
            
            TextField("Description (optional)", text: $metadata.description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview("Full Editor") {
    NavigationStack {
        DocumentMetadataEditor(metadata: .constant(DocumentMetadataForm()))
    }
}

#Preview("Compact Editor") {
    CompactMetadataEditor(metadata: .constant(DocumentMetadataForm()))
}
