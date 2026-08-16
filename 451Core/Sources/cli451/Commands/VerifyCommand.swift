import ArgumentParser
import Core451
import Foundation

struct VerifyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "verify",
        abstract: "Verify the signature and blockchain record of a 451 document"
    )

    @Argument(help: "Path to the document file to verify")
    var filePath: String

    @Option(name: .long, help: "Expected signer DID (optional — checks a specific signer)")
    var signer: String?

    @Option(name: .long, help: "Server base URL (overrides config)")
    var server: String?

    @Flag(name: .long, help: "Print verbose output")
    var verbose: Bool = false

    mutating func run() throws {
        if let server = server {
            ServerConfig.overrideURL = server
        }

        let url = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError("File not found: \(filePath)")
        }

        if verbose {
            print("Verifying: \(url.lastPathComponent)")
            if let signer = signer { print("Signer:    \(signer)") }
            print("Server:    \(ServerConfig.baseURL)")
        }

        // Steps:
        // 1. Extract embedded 451 metadata from file
        // 2. Hash document content (SHA-256)
        // 3. Fetch blockchain record for document DID
        // 4. Compare hashes and verify signature against public key in blockchain
        // 5. Report: verified / tampered / not found

        print("⚠️  Verify command: blockchain verification coming soon")
        print("   File: \(url.lastPathComponent)")
    }
}
