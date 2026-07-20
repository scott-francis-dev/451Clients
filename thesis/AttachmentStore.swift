import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A stable identifier for an attachment asset.
public struct AttachmentID: Codable, Hashable {
    public let uuid: UUID

    public init() {
        self.uuid = UUID()
    }
}

/// A minimal store for saving and loading attachment assets associated with a book.
/// Assets are saved in an `assets` subdirectory inside the book directory.
/// The store provides stable URLs based on attachment IDs and a file extension.
public final class AttachmentStore {
    /// Shared singleton instance.
    public static let shared = AttachmentStore()

    private init() {}

    /// Returns the URL for an attachment with the given ID and file extension in the specified book directory.
    /// - Parameters:
    ///   - id: The attachment identifier.
    ///   - bookDirectory: The root directory of the book.
    ///   - ext: The file extension (without dot), e.g. "png".
    /// - Returns: A file URL for the attachment asset.
    public func url(for id: AttachmentID, in bookDirectory: URL, ext: String) -> URL {
        let assetsDir = bookDirectory.appendingPathComponent("assets", isDirectory: true)
        try? FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
        return assetsDir.appendingPathComponent(id.uuid.uuidString).appendingPathExtension(ext)
    }

    /// Saves PNG data for an attachment in the book directory.
    /// - Parameters:
    ///   - data: PNG image data to save.
    ///   - id: Attachment identifier.
    ///   - bookDirectory: The root directory of the book.
    /// - Throws: Throws any filesystem error encountered while writing.
    /// - Returns: The file URL where the data was saved.
    @discardableResult
    public func savePNG(_ data: Data, id: AttachmentID, in bookDirectory: URL) throws -> URL {
        let url = self.url(for: id, in: bookDirectory, ext: "png")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Loads raw data for an attachment.
    /// - Parameters:
    ///   - id: Attachment identifier.
    ///   - bookDirectory: The root directory of the book.
    /// - Returns: The data if found, or nil.
    public func loadData(id: AttachmentID, in bookDirectory: URL) -> Data? {
        let assetsDir = bookDirectory.appendingPathComponent("assets", isDirectory: true)
        // Try to find any file with this UUID prefix (in case extension differs)
        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(at: assetsDir, includingPropertiesForKeys: nil) {
            for file in files where file.deletingPathExtension().lastPathComponent == id.uuid.uuidString {
                return try? Data(contentsOf: file)
            }
        }
        return nil
    }
}

#if canImport(UIKit)
extension UIImage {
    /// Returns PNG data representation of the image.
    public var pngDataRepresentation: Data? {
        return self.pngData()
    }
}
#elseif canImport(AppKit)
extension NSImage {
    /// Returns PNG data representation of the image.
    public var pngDataRepresentation: Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
#endif
