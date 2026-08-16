import XCTest

/// Runs the built `451cli` binary as a subprocess. This is the only layer that
/// covers the tool as a user actually invokes it: argument parsing, validation,
/// exit codes, and what lands on stdout/stderr.
final class CLIInvocationTests: XCTestCase {

    // MARK: - Harness

    private struct Result {
        let stdout: String
        let stderr: String
        let exitCode: Int32

        var combined: String { stdout + stderr }
    }

    /// The binary sits next to the xctest bundle in the products directory.
    private static var binaryURL: URL {
        Bundle(for: CLIInvocationTests.self)
            .bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("451cli")
    }

    @discardableResult
    private func run(_ arguments: String...) throws -> Result {
        let binary = Self.binaryURL
        try XCTSkipUnless(
            FileManager.default.isExecutableFile(atPath: binary.path),
            "451cli not found at \(binary.path) — run `swift build` first"
        )

        let process = Process()
        process.executableURL = binary
        process.arguments = arguments

        let outPipe = Pipe(), errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        // Read before waiting so a large output cannot fill the pipe and deadlock.
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return Result(
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self),
            exitCode: process.terminationStatus
        )
    }

    private static let subcommands = ["sign", "witness", "stream", "write", "verify"]

    /// A file that exists, for commands that validate their input path.
    private func makeTempFile(contents: String = "451") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cli451-\(UUID().uuidString).txt")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    // MARK: - Top-level interface

    func testHelpListsEverySubcommand() throws {
        let result = try run("--help")
        XCTAssertEqual(result.exitCode, 0)
        for subcommand in Self.subcommands {
            XCTAssertTrue(
                result.stdout.contains(subcommand),
                "`--help` did not list `\(subcommand)`"
            )
        }
    }

    func testEverySubcommandHasHelp() throws {
        for subcommand in Self.subcommands {
            let result = try run(subcommand, "--help")
            XCTAssertEqual(result.exitCode, 0, "`\(subcommand) --help` failed")
            XCTAssertTrue(
                result.stdout.contains("USAGE"),
                "`\(subcommand) --help` printed no usage"
            )
        }
    }

    func testUnknownSubcommandFails() throws {
        let result = try run("nonsense")
        XCTAssertNotEqual(result.exitCode, 0)
    }

    // MARK: - Required arguments

    func testSignRequiresPersona() throws {
        let file = try makeTempFile()
        let result = try run("sign", file.path)
        XCTAssertNotEqual(result.exitCode, 0, "sign should require --persona")
        XCTAssertTrue(result.combined.contains("persona"), result.combined)
    }

    func testVerifyRejectsMissingFile() throws {
        let result = try run("verify", "/definitely/not/here.pdf")
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertTrue(
            result.combined.contains("File not found"),
            result.combined
        )
    }

    func testSignRejectsMissingFile() throws {
        let result = try run("sign", "/definitely/not/here.pdf", "--persona", "did:451:abc")
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertTrue(result.combined.contains("File not found"), result.combined)
    }

    func testWriteRequiresFileOrJSON() throws {
        let result = try run("write", "--persona", "did:451:abc")
        XCTAssertNotEqual(result.exitCode, 0, "write needs --file or --json")
        XCTAssertTrue(
            result.combined.contains("--file") || result.combined.contains("--json"),
            result.combined
        )
    }

    func testWriteAcceptsInlineJSON() throws {
        let result = try run("write", "--persona", "did:451:abc", "--json", #"{"a":1}"#)
        XCTAssertEqual(result.exitCode, 0, result.combined)
    }

    // MARK: - Server resolution

    func testDefaultsToProductionServer() throws {
        let file = try makeTempFile()
        let result = try run("verify", file.path, "--verbose")
        XCTAssertEqual(result.exitCode, 0, result.combined)
        XCTAssertTrue(
            result.stdout.contains("https://api.451.info"),
            result.stdout
        )
    }

    func testServerFlagOverridesDefault() throws {
        let file = try makeTempFile()
        let result = try run("verify", file.path, "--verbose", "--server", "http://localhost:8080")
        XCTAssertEqual(result.exitCode, 0, result.combined)
        XCTAssertTrue(result.stdout.contains("http://localhost:8080"), result.stdout)
    }

    func testServerFlagAddsMissingScheme() throws {
        let file = try makeTempFile()
        let result = try run("verify", file.path, "--verbose", "--server", "api.dev.451.info")
        XCTAssertTrue(result.stdout.contains("https://api.dev.451.info"), result.stdout)
    }

    /// `--server` is a per-invocation flag. Regression guard: it previously
    /// wrote to UserDefaults, so one run silently redirected every later run.
    func testServerFlagDoesNotLeakIntoTheNextInvocation() throws {
        let file = try makeTempFile()

        let redirected = try run("verify", file.path, "--verbose", "--server", "http://localhost:8080")
        XCTAssertTrue(redirected.stdout.contains("http://localhost:8080"), redirected.stdout)

        let subsequent = try run("verify", file.path, "--verbose")
        XCTAssertTrue(
            subsequent.stdout.contains("https://api.451.info"),
            "--server leaked into a later invocation: \(subsequent.stdout)"
        )
        XCTAssertFalse(subsequent.stdout.contains("localhost"), subsequent.stdout)
    }

    /// Every command exposes `--server`, so none of them may leak either.
    func testServerFlagIsAcceptedByEverySubcommand() throws {
        let file = try makeTempFile()
        let invocations: [[String]] = [
            ["sign", file.path, "--persona", "did:451:abc"],
            ["witness", "--persona", "did:451:abc"],
            ["stream", "--source", file.path, "--persona", "did:451:abc"],
            ["write", "--persona", "did:451:abc", "--json", "{}"],
            ["verify", file.path],
        ]

        for var arguments in invocations {
            let name = arguments[0]
            arguments += ["--verbose", "--server", "http://localhost:9999"]

            let process = Process()
            process.executableURL = Self.binaryURL
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let output = String(decoding: data, as: UTF8.self)
            XCTAssertEqual(process.terminationStatus, 0, "`\(name)` failed: \(output)")
            XCTAssertTrue(
                output.contains("http://localhost:9999"),
                "`\(name)` ignored --server: \(output)"
            )
        }
    }
}
