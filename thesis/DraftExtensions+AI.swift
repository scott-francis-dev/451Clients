//
//  DraftExtensions+AI.swift
//  wordsmatter
//
//  Created by User451 on 1/1/26.
//

import Foundation

/// Extensions to integrate AI features into your existing Draft/Book workflow
extension Book {
    
    /// Generate smart tags for this book based on its content
    @available(iOS 26.0, macOS 15.2, *)
    func generateAITags() async throws -> [String] {
        let manager = LanguageModelManager.shared
        
        let isAvailable = await MainActor.run { manager.isAvailable }
        guard isAvailable else {
            throw LanguageModelError.modelUnavailable
        }
        
        // Gather content from all pages
        let allText = pages
            .compactMap { page in
                guard let richDoc = try? RichTextCodec.decodeJSON(page.richTextJSON) else {
                    return nil
                }
                return richDoc.plainText()
            }
            .joined(separator: "\n\n")
        
        // Combine with metadata for better context
        let contextText = """
        Title: \(title)
        \(subtitle.isEmpty ? "" : "Subtitle: \(subtitle)")
        \(author.isEmpty ? "" : "Author: \(author)")
        \(description.isEmpty ? "" : "Description: \(description)")
        
        Content:
        \(allText)
        """
        
        return try await manager.generateTags(contextText, maxTags: 8)
    }
    
    /// Generate a description for this book based on its content
    @available(iOS 26.0, macOS 15.2, *)
    func generateAIDescription() async throws -> String {
        let manager = LanguageModelManager.shared
        
        let isAvailable = await MainActor.run { manager.isAvailable }
        guard isAvailable else {
            throw LanguageModelError.modelUnavailable
        }
        
        // Gather content from first few pages
        let sampleText = pages
            .prefix(3)
            .compactMap { page in
                guard let richDoc = try? RichTextCodec.decodeJSON(page.richTextJSON) else {
                    return nil
                }
                return richDoc.plainText()
            }
            .joined(separator: "\n\n")
        
        let prompt = """
        Title: \(title)
        
        Content sample:
        \(sampleText)
        
        Write a concise description (2-3 sentences) that captures the essence of this work.
        """
        
        return try await manager.summarize(prompt, length: .short)
    }
}

extension Page {
    
    /// Get plain text content from this page
    func plainTextContent() -> String {
        guard let richDoc = try? RichTextCodec.decodeJSON(richTextJSON) else {
            return ""
        }
        return richDoc.plainText()
    }
    
    /// Improve the writing in this page
    @available(iOS 26.0, macOS 15.2, *)
    mutating func improveWriting() async throws {
        let manager = LanguageModelManager.shared
        
        let isAvailable = await MainActor.run { manager.isAvailable }
        guard isAvailable else {
            throw LanguageModelError.modelUnavailable
        }
        
        let currentText = plainTextContent()
        guard !currentText.isEmpty else { return }
        
        let improvedText = try await manager.improveWriting(currentText)
        
        // Update the page with improved text
        let newDoc = RichDoc(version: 1, blocks: [
            Block(type: .paragraph, inlines: [.text(TextRun(text: improvedText))])
        ])
        
        if let data = try? RichTextCodec.encodeJSON(newDoc) {
            richTextJSON = data
            // Reload the doc
            doc.load(from: newDoc)
        }
    }
    
    /// Summarize the content of this page
    @available(iOS 26.0, macOS 15.2, *)
    func summarize() async throws -> String {
        let manager = LanguageModelManager.shared
        
        let isAvailable = await MainActor.run { manager.isAvailable }
        guard isAvailable else {
            throw LanguageModelError.modelUnavailable
        }
        
        let currentText = plainTextContent()
        guard !currentText.isEmpty else {
            return ""
        }
        
        return try await manager.summarize(currentText, length: .medium)
    }
}

// MARK: - RichDoc Extensions

extension RichDoc {
    /// Extract plain text from a RichDoc
    func plainText() -> String {
        blocks.compactMap { block in
            block.inlines.compactMap { inline in
                if case .text(let textRun) = inline {
                    return textRun.text
                }
                return nil
            }.joined(separator: " ")
        }.joined(separator: "\n")
    }
}

// MARK: - AI-Enhanced Draft Creation

extension DraftsStore {
    
    /// Create a new draft with AI-generated outline
    @available(iOS 26.0, macOS 15.2, *)
    func createDraftWithAIOutline(title: String, description: String) async throws -> Book {
        let manager = LanguageModelManager.shared
        
        let isAvailable = await MainActor.run { manager.isAvailable }
        guard isAvailable else {
            throw LanguageModelError.modelUnavailable
        }
        
        // Generate outline
        let outline = try await manager.generateOutline(title: title, description: description)
        
        // Create book
        var book = Book()
        book.id = UUID().uuidString
        book.did = "did:local:\(book.id)"
        book.title = outline.title
        book.description = description
        
        // Create pages from outline sections
        var pages: [Page] = []
        
        for (index, section) in outline.sections.enumerated() {
            let pageDoc = RichDoc(version: 1, blocks: [
                Block(type: .heading, inlines: [.text(TextRun(text: section.heading))]),
                Block(type: .paragraph, inlines: [.text(TextRun(text: section.description))]),
                Block(type: .paragraph, inlines: [.text(TextRun(text: ""))]) // Empty paragraph for writing
            ])
            
            if let data = try? RichTextCodec.encodeJSON(pageDoc) {
                let page = Page(
                    title: section.heading,
                    richTextJSON: data
                )
                pages.append(page)
            }
        }
        
        book.pages = pages
        
        try await save(book)
        return book
    }
}

// MARK: - Batch Processing

@available(iOS 26.0, macOS 15.2, *)
struct BatchAIProcessor {
    let manager = LanguageModelManager.shared
    
    /// Improve writing for multiple pages with progress updates
    func improvePages(_ pages: [Page], progressHandler: @escaping (Int, Int) -> Void) async throws -> [Page] {
        let isAvailable = await MainActor.run { manager.isAvailable }
        guard isAvailable else {
            throw LanguageModelError.modelUnavailable
        }
        
        var improvedPages: [Page] = []
        
        for (index, var page) in pages.enumerated() {
            let currentText = page.plainTextContent()
            
            if !currentText.isEmpty {
                let improvedText = try await manager.improveWriting(currentText)
                
                let newDoc = RichDoc(version: 1, blocks: [
                    Block(type: .paragraph, inlines: [.text(TextRun(text: improvedText))])
                ])
                
                if let data = try? RichTextCodec.encodeJSON(newDoc) {
                    page.richTextJSON = data
                    page.doc.load(from: newDoc)
                }
            }
            
            improvedPages.append(page)
            progressHandler(index + 1, pages.count)
        }
        
        return improvedPages
    }
    
    /// Generate summaries for all pages in a book
    func summarizeBook(_ book: Book) async throws -> String {
        let isAvailable = await MainActor.run { manager.isAvailable }
        guard isAvailable else {
            throw LanguageModelError.modelUnavailable
        }
        
        var summaries: [String] = []
        
        for page in book.pages {
            let text = page.plainTextContent()
            if !text.isEmpty {
                let summary = try await manager.summarize(text, length: .short)
                summaries.append("**\(page.title)**: \(summary)")
            }
        }
        
        return summaries.joined(separator: "\n\n")
    }
}

// MARK: - Example Usage in a View

/*
 Example: How to use these extensions in your views
 
 // In a draft editing view
 @State private var book: Book
 
 // Improve a specific page
 Button("Improve This Page") {
     Task {
         do {
             try await book.pages[currentPageIndex].improveWriting()
             try await DraftsStore.shared.save(book)
         } catch {
             print("Error: \(error)")
         }
     }
 }
 
 // Generate tags for the book
 Button("Generate Tags") {
     Task {
         do {
             let tags = try await book.generateAITags()
             book.subject = tags.joined(separator: ", ")
             try await DraftsStore.shared.save(book)
         } catch {
             print("Error: \(error)")
         }
     }
 }
 
 // Create a new draft with AI outline
 Button("Create from AI Outline") {
     Task {
         do {
             let newBook = try await DraftsStore.shared.createDraftWithAIOutline(
                 title: "My New Book",
                 description: "A comprehensive guide to..."
             )
             // Navigate to the new book
         } catch {
             print("Error: \(error)")
         }
     }
 }
 
 // Batch process multiple pages
 Button("Improve All Pages") {
     Task {
         let processor = BatchAIProcessor()
         do {
             book.pages = try await processor.improvePages(book.pages) { completed, total in
                 print("Progress: \(completed)/\(total)")
             }
             try await DraftsStore.shared.save(book)
         } catch {
             print("Error: \(error)")
         }
     }
 }
 */

