// EquationSerializationTests.swift
// Verifies that an equation created in the app is actually captured on save and
// restored on load. Equations live in the block document model as a source
// string; every CAS result (derivative, integral, …) is recomputed from it, so
// persisting the string is sufficient and is what these tests pin down.
//
// Path under test:
//   [DocumentBlock] → DocumentBlock.encodeBlocks → page.documentBlocksJSON
//                   → Codable Page → (disk) → decode → DocumentBlock.decodeBlocks

import Testing
import Foundation
@testable import thesis

@Suite("Equation serialization")
struct EquationSerializationTests {

    @Test("equation block round-trips through the block codec")
    func blockCodecRoundTrip() {
        let id = UUID()
        let blocks: [DocumentBlock] = [
            .equation(id: id, objectId: "obj-1", expression: "x^2 + 2x - 1")
        ]

        let data = DocumentBlock.encodeBlocks(blocks)
        let decoded = DocumentBlock.decodeBlocks(from: data)

        #expect(decoded?.count == 1)
        guard case .equation(let dId, let dObj, let dExpr)? = decoded?.first else {
            Issue.record("expected an equation block after decoding")
            return
        }
        #expect(dId == id)
        #expect(dObj == "obj-1")
        #expect(dExpr == "x^2 + 2x - 1")
    }

    @Test("a non-trivial expression survives verbatim")
    func preservesExactSource() {
        let source = "sin(2x) + 1/x - sqrt(y)"
        let blocks: [DocumentBlock] = [
            .equation(id: UUID(), objectId: "e", expression: source)
        ]
        let decoded = DocumentBlock.decodeBlocks(from: DocumentBlock.encodeBlocks(blocks))
        guard case .equation(_, _, let expr)? = decoded?.first else {
            Issue.record("expected an equation block")
            return
        }
        #expect(expr == source)
    }

    @Test("equation persists through a full Page encode/decode")
    func pageCodecRoundTrip() throws {
        let source = "x^3 - 6x^2 + 11x - 6"
        var page = Page(title: "Doc")
        page.documentBlocksJSON = DocumentBlock.encodeBlocks([
            .equation(id: UUID(), objectId: "e", expression: source)
        ])

        let encoded = try JSONEncoder().encode(page)
        let restored = try JSONDecoder().decode(Page.self, from: encoded)

        let decoded = DocumentBlock.decodeBlocks(from: restored.documentBlocksJSON)
        guard case .equation(_, _, let expr)? = decoded?.first else {
            Issue.record("expected an equation block after Page round-trip")
            return
        }
        #expect(expr == source)
    }

    @Test("multiple blocks keep equations alongside other content")
    func mixedBlocks() {
        let blocks: [DocumentBlock] = [
            .equation(id: UUID(), objectId: "a", expression: "a^2 + b^2"),
            .equation(id: UUID(), objectId: "b", expression: "exp(x)")
        ]
        let decoded = DocumentBlock.decodeBlocks(from: DocumentBlock.encodeBlocks(blocks)) ?? []
        let expressions: [String] = decoded.compactMap {
            if case .equation(_, _, let e) = $0 { return e }
            return nil
        }
        #expect(expressions == ["a^2 + b^2", "exp(x)"])
    }

    @Test("the restored source still parses through the CAS bridge")
    func restoredSourceIsComputable() {
        let blocks: [DocumentBlock] = [
            .equation(id: UUID(), objectId: "e", expression: "x^2 + 2x - 1")
        ]
        let decoded = DocumentBlock.decodeBlocks(from: DocumentBlock.encodeBlocks(blocks))
        guard case .equation(_, _, let expr)? = decoded?.first,
              let parsed = ExpressionParser.parseExpression(expr) else {
            Issue.record("restored expression did not parse")
            return
        }
        // The whole point of persisting only the source: CAS results recompute.
        let derivative = Expr(parsed.mathNode).differentiated(withRespectTo: "x")
        #expect(derivative == 2 * Expr.sym("x") + 2)
    }
}
