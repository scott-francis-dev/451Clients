import ArgumentParser
import Core451

struct CLI451: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "451",
        abstract: "451 Protocol command-line tool",
        discussion: """
        Interact with the 451 protocol from the command line.
        Sign documents, capture witness proof, stream to S3, write sensor data.

        Examples:
          451 sign document.pdf --persona did:451:abc123
          451 witness --photos 2 --then-video --persona did:451:abc123
          451 stream --source /dev/video0 --persona did:451:abc123
          451 write --sensor-data readings.json --persona did:451:abc123
          451 verify document.pdf
        """,
        subcommands: [
            SignCommand.self,
            WitnessCommand.self,
            StreamCommand.self,
            WriteCommand.self,
            VerifyCommand.self,
        ]
    )
}

CLI451.main()
