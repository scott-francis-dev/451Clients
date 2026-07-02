import ArgumentParser
import Core451
import Foundation

struct SignCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "sign",
        abstract: "Sign a document using a persona's Secure Enclave key"
    )

    @Argument(help: "Path to the document file to sign")
    var filePath: String

    @Option(name: .long, help: "DID of the signing persona")
    var persona: String

    @Option(name: .long, help: "Role of the signer (author, contractParty, witness, notary, reviewer)")
    var role: String = "author"

    @Option(name: .long, help: "Server base URL (overrides config)")
    var server: String?

    @Flag(name: .long, help: "Print verbose output")
    var verbose: Bool = false

    mutating func run() throws {
        if let server = server {
            ServerConfig.setCustomServer(server)
        }

        let url = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError("File not found: \(filePath)")
        }

        let data = try Data(contentsOf: url)
        let fileSize = data.count
        let signerRole = DocumentSigningService.SignerRole(rawValue: role) ?? .author

        if verbose {
            print("Signing: \(url.lastPathComponent) (\(fileSize) bytes)")
            print("Persona: \(persona)")
            print("Role:    \(signerRole.rawValue)")
            print("Server:  \(ServerConfig.baseURL)")
        }

        // TODO: Load persona from store, sign via SecureEnclaveKeyStore,
        //       call DocumentSigningService.uploadDocument()
        print("⚠️  Sign command: signing logic coming soon")
        print("   File:    \(url.lastPathComponent)")
        print("   Persona: \(persona)")
        print("   Role:    \(signerRole.rawValue)")
    }
}
