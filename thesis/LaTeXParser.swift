// LaTeXParser.swift
// Converts LaTeX math strings into MathNode AST for rendering with MathLayout.
//
// Usage:
//   let node = LaTeXParser.parse(#"\frac{d^2y}{dx^2} + \omega^2 y = 0"#)
//   MathView(node: node, fontSize: 22, style: .display)
//
// Input:  LaTeX math content — no outer $…$ or \[…\] delimiters needed.
// Output: MathNode ready for MathView / MathLayout.
//
// Coverage:
//   Greek letters, fractions, radicals, scripts, big operators (∑ ∫ ∏ …),
//   accents, \left…\right, matrix/pmatrix/bmatrix/cases environments,
//   \mathbb number sets, all standard relations/arrows/logic/set symbols.
//   Unknown commands render as \name in upright text — never crashes.

import Foundation

// MARK: - Public API

public enum LaTeXParser {

    /// Parse a LaTeX math string into a MathNode.
    /// Strips surrounding $, $$, \(, \), \[, \] if present.
    public static func parse(_ latex: String) -> MathNode {
        let stripped = stripDelimiters(latex)
        var p = _P(stripped)
        let nodes = p.mathList()
        switch nodes.count {
        case 0:  return .placeholder
        case 1:  return nodes[0]
        default: return .group(nodes)
        }
    }

    private static func stripDelimiters(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        let pairs: [(String, String)] = [("$$", "$$"), ("$", "$"),
                                         ("\\[", "\\]"), ("\\(", "\\)")]
        for (open, close) in pairs {
            if t.hasPrefix(open) && t.hasSuffix(close) && t.count > open.count + close.count {
                t = String(t.dropFirst(open.count).dropLast(close.count))
                break
            }
        }
        return t
    }
}

// MARK: - Tokenizer

private enum _Tok: Equatable {
    case letter(Character)   // a-z A-Z
    case digit(Character)    // 0-9
    case cmd(String)         // \name  or  \{  \}  \,  etc.
    case dblSlash            // \\  (row break in tabular)
    case caret               // ^
    case under               // _
    case lbrace              // {
    case rbrace              // }
    case lbrack              // [
    case rbrack              // ]
    case amp                 // &
    case ws                  // any whitespace (collapsed)
    case other(Character)    // + - = < > | / . , ; : ! ' ~ ( )
}

private func _tokenize(_ s: String) -> [_Tok] {
    var result: [_Tok] = []
    var i = s.startIndex

    func peek() -> Character? { i < s.endIndex ? s[i] : nil }
    func advance() { i = s.index(after: i) }
    func next() -> Character? { let c = peek(); if c != nil { advance() }; return c }

    while i < s.endIndex {
        let c = s[i]
        advance()

        switch c {
        case " ", "\t", "\n", "\r":
            if result.last != .ws { result.append(.ws) }

        case "{": result.append(.lbrace)
        case "}": result.append(.rbrace)
        case "[": result.append(.lbrack)
        case "]": result.append(.rbrack)
        case "^": result.append(.caret)
        case "_": result.append(.under)
        case "&": result.append(.amp)

        case "\\":
            guard let nc = peek() else { break }
            if nc == "\\" { advance(); result.append(.dblSlash); break }
            if nc.isLetter {
                var name = ""
                while let cc = peek(), cc.isLetter { name.append(cc); advance() }
                result.append(.cmd(name))
            } else {
                // Single-char command: \{ \} \, \; \: \! \  \' etc.
                result.append(.cmd(String(nc)))
                advance()
            }

        default:
            if c.isLetter  { result.append(.letter(c)) }
            else if c.isNumber { result.append(.digit(c)) }
            else               { result.append(.other(c)) }
        }
    }
    return result
}

// MARK: - Parser

private struct _P {
    let toks: [_Tok]
    var pos: Int = 0

    init(_ input: String) { toks = _tokenize(input) }

    var cur: _Tok? { pos < toks.count ? toks[pos] : nil }

    @discardableResult mutating func eat() -> _Tok? {
        guard pos < toks.count else { return nil }
        defer { pos += 1 }
        return toks[pos]
    }

    mutating func skipWS() {
        while case .ws = cur ?? .amp { eat() }
    }

    // ── Math list ────────────────────────────────────────────────────────────

    /// Parse a sequence of atoms until `stop` returns true or input ends.
    mutating func mathList(until stop: (_Tok) -> Bool = { _ in false }) -> [MathNode] {
        var nodes: [MathNode] = []
        while let t = cur, !stop(t) {
            guard let n = atomWithScripts() else { break }
            nodes.append(n)
        }
        return nodes
    }

    // ── Atom + scripts ───────────────────────────────────────────────────────

    mutating func atomWithScripts() -> MathNode? {
        skipWS()
        guard var base = atom() else { return nil }

        var sub: MathNode? = nil
        var sup: MathNode? = nil

        loop: while true {
            skipWS()
            switch cur {
            case .under:
                eat()
                sub = group()
            case .caret:
                eat()
                sup = group()
            default:
                break loop
            }
        }

        switch (sub, sup) {
        case (let s?, let p?): return .subsup(base: base, sub: s, sup: p)
        case (let s?, nil):    return .sub(base: base, index: s)
        case (nil, let p?):    return .power(base: base, exp: p)
        default:               return base
        }
    }

    // ── Single atom (no scripts) ─────────────────────────────────────────────

    mutating func atom() -> MathNode? {
        skipWS()
        guard let t = cur else { return nil }
        switch t {

        case .lbrace:
            eat()
            let inner = mathList(until: { $0 == .rbrace })
            eat() // }
            return inner.count == 1 ? inner[0] : .group(inner)

        case .letter(let c):
            eat()
            return .variable(String(c))

        case .digit(let c):
            eat()
            var s = String(c)
            // Accumulate multi-digit number
            while case .digit(let d) = cur { s.append(d); eat() }
            if case .other(".") = cur {
                s.append("."); eat()
                while case .digit(let d) = cur { s.append(d); eat() }
            }
            return .number(Double(s) ?? 0)

        case .other(let c):
            eat()
            switch c {
            case "+":         return .text("+")
            case "-":         return .text("−")
            case "=":         return .text("=")
            case "<":         return .text("<")
            case ">":         return .text(">")
            case "|":         return .symbol(.perp)   // "|" used as separator
            case "/":         return .text("/")
            case "'":         return .symbol(.prime)
            case ",":         return .text(", ")
            case ".":         return .text(".")
            case "(":         return .text("(")
            case ")":         return .text(")")
            case "!":         return .text("!")
            case ";":         return .text(";")
            case ":":         return .text(":")
            case "~":         return .text(" ")   // non-breaking space
            default:          return .text(String(c))
            }

        case .cmd(let name):
            // Stop signals — leave in stream for caller to consume
            if name == "right" || name == "end" { return nil }
            // Row/column separators — leave for tabular parsers
            if t == .amp || t == .dblSlash { return nil }
            eat()
            return cmd(name)

        case .amp, .dblSlash, .rbrace, .rbrack:
            return nil   // structural stop — don't consume

        default:
            eat()
            return nil
        }
    }

    // ── Group: {…} or single atom ────────────────────────────────────────────

    mutating func group() -> MathNode {
        skipWS()
        if case .lbrace = cur ?? .ws {
            eat() // {
            let inner = mathList(until: { $0 == .rbrace })
            eat() // }
            return inner.count == 1 ? inner[0] : .group(inner)
        }
        return atom() ?? .placeholder
    }

    // ── Command dispatcher ───────────────────────────────────────────────────

    mutating func cmd(_ name: String) -> MathNode? {

        // ── Symbol lookup (Greek, operators, relations, …) ──
        if let sym = _symbolMap[name] { return .symbol(sym) }

        // ── Structural commands ─────────────────────────────
        switch name {

        // Fractions
        case "frac", "dfrac", "tfrac", "cfrac":
            return .fraction(group(), group())

        case "binom", "dbinom":
            // Render as (n over k) — close enough for display
            return .bracketed(.paren, .fraction(group(), group()))

        case "over":
            // Old-style: {num \over den} — difficult to handle post-hoc; return placeholder
            return .placeholder

        // Roots
        case "sqrt":
            skipWS()
            var degree: MathNode? = nil
            if case .lbrack = cur ?? .ws {
                eat() // [
                let deg = mathList(until: { $0 == .rbrack })
                eat() // ]
                degree = deg.isEmpty ? nil : (deg.count == 1 ? deg[0] : .group(deg))
            }
            return .radical(degree: degree, group())

        // Big operators with limits
        case "sum":     return bigop(.sum)
        case "prod":    return bigop(.product)
        case "coprod":  return bigop(.coproduct)
        case "int":     return bigop(.integral)
        case "iint":    return bigop(.doubleIntegral)
        case "iiint":   return bigop(.tripleIntegral)
        case "oint":    return bigop(.oint)
        case "bigcup":  return bigop(.union)
        case "bigcap":  return bigop(.intersection)
        case "bigwedge":return bigop(.bigwedge)
        case "bigvee":  return bigop(.bigvee)
        case "bigoplus":return bigop(.bigoplus)
        case "bigotimes":return bigop(.bigotimes)

        // Named operators rendered as upright text (lim, max, etc.)
        // Sub/superscripts will be attached by atomWithScripts().
        case "lim", "limsup", "liminf", "coloneq",
             "sup", "inf", "max", "min", "arg", "det",
             "sin", "cos", "tan", "cot", "sec", "csc",
             "arcsin", "arccos", "arctan",
             "sinh", "cosh", "tanh",
             "log", "ln", "exp",
             "ker", "dim", "rank", "hom", "coker",
             "gcd", "lcm", "deg":
            return .text(name)

        // Accents
        case "hat":         return .accent(.hat,       group())
        case "bar", "overline": return .accent(.bar,   group())
        case "tilde":       return .accent(.tilde,     group())
        case "widetilde":   return .accent(.widetilde, group())
        case "widehat":     return .accent(.widehat,   group())
        case "vec":         return .accent(.vec,       group())
        case "dot":         return .accent(.dot,       group())
        case "ddot":        return .accent(.ddot,      group())
        case "check", "breve": return .accent(.check,  group())
        case "acute":       return .accent(.hat,       group())   // approximate
        case "grave":       return .accent(.check,     group())   // approximate

        // Underline/underbrace — render body only (structural decoration not yet supported)
        case "underline", "underbrace", "overbrace",
             "underset", "overset", "stackrel":
            let body = group()
            _ = group()   // second arg for underset/overset/stackrel
            return body

        // \left…\right auto-sizing brackets
        case "left":
            return leftRight()

        // right is a stop signal — should not be dispatched here
        case "right":
            return nil

        // Environments
        case "begin":
            return environment()

        // Text content
        case "text", "mathrm", "operatorname",
             "mbox", "textit", "textbf", "textrm",
             "mathit":
            return .text(textContent())

        // Pass-through style commands (bold, calligraphic, etc.)
        case "mathbf", "boldsymbol", "bm",
             "mathcal", "mathscr", "mathfrak",
             "mathsf", "mathtt",
             "displaystyle", "textstyle", "scriptstyle",
             "normalsize", "large", "small":
            return group()

        // \mathbb{R} → ℝ etc.
        case "mathbb":
            let arg = group()
            if case .variable(let s) = arg {
                switch s {
                case "R": return .symbol(.reals)
                case "Z": return .symbol(.integers)
                case "N": return .symbol(.naturals)
                case "Q": return .symbol(.rationals)
                case "C": return .symbol(.complex)
                case "H": return .text("ℍ")
                case "F": return .text("𝔽")
                default:  break
                }
            }
            return arg

        // \not — negation of next symbol
        case "not":
            skipWS()
            let next = atom()
            switch next {
            case .symbol(.inSet):        return .symbol(.notIn)
            case .symbol(.subset):       return .symbol(.subset)   // ⊄ not in MathSymbol yet
            case .text("="):             return .symbol(.neq)
            case .symbol(.equiv):        return .text("≢")
            case .symbol(.approx):       return .text("≉")
            case .symbol(.sim):          return .text("≁")
            default:
                if let n = next { return .group([n, .text("̸")]) }
                return .placeholder
            }

        // Spaces — skip in AST, they only affect rendering spacing
        case ",", ":", ";", "!", " ",
             "quad", "qquad", "enspace", "thinspace":
            return nil
        case "hspace", "vspace", "mspace":
            _ = group()   // consume the length argument
            return nil

        // Delimiter commands used outside \left\right
        case "langle":  return .text("⟨")
        case "rangle":  return .text("⟩")
        case "lfloor":  return .text("⌊")
        case "rfloor":  return .text("⌋")
        case "lceil":   return .text("⌈")
        case "rceil":   return .text("⌉")
        case "lvert", "vert": return .text("|")
        case "rvert":   return .text("|")
        case "lVert", "Vert": return .text("‖")
        case "rVert":   return .text("‖")
        case "{", "lbrace": return .text("{")
        case "}", "rbrace": return .text("}")

        // Misc that would otherwise hit the default
        case "limits", "nolimits", "displaylimits",
             "nonumber", "notag", "label",
             "tag":
            if name == "tag" || name == "label" { _ = group() }
            return nil

        // \\ is a line break — skip
        case "\\":
            return nil

        default:
            // Unknown command — render as \name so the user can see it
            return .text("\\\(name)")
        }
    }

    // ── Big operator helper ──────────────────────────────────────────────────

    mutating func bigop(_ op: MathBigOp) -> MathNode {
        // Consume optional _lower and ^upper in any order
        var lower: MathNode = .placeholder
        var upper: MathNode = .placeholder

        for _ in 0..<2 {
            skipWS()
            switch cur {
            case .under: eat(); lower = group()
            case .caret: eat(); upper = group()
            default: break
            }
        }

        // Body is the rest of the current scope — don't greedily consume;
        // the parent mathList will handle it. Return just the operator with limits.
        // The body is whatever follows in the enclosing group — we represent it as
        // an empty placeholder here and let the document-level group supply the body.
        // For a proper body, callers should wrap: \sum_{i}^{n} expr
        // We parse greedily: next atom becomes the body.
        skipWS()
        let body: MathNode = atomWithScripts() ?? .placeholder

        return .bigop(op, lower: lower, upper: upper, body: body)
    }

    // ── \left…\right ────────────────────────────────────────────────────────

    mutating func leftRight() -> MathNode {
        skipWS()
        let openKind = delimiter()

        // Parse inner content until \right
        let inner = mathList(until: { if case .cmd("right") = $0 { return true }; return false })

        // Consume \right + its delimiter
        if case .cmd("right") = cur { eat() }
        skipWS()
        _ = delimiter()   // closing bracket (we use auto-sizing so kind doesn't matter)

        let innerNode: MathNode = inner.count == 1 ? inner[0] : .group(inner)
        return .bracketed(openKind, innerNode)
    }

    /// Consume a delimiter token and return the corresponding bracket kind.
    mutating func delimiter() -> MathBracketKind {
        skipWS()
        guard let t = cur else { return .paren }
        switch t {
        case .other("("), .other(")"):   eat(); return .paren
        case .lbrack, .rbrack:           eat(); return .square
        case .other("|"):                eat(); return .abs
        case .other("."):                eat(); return .paren   // invisible bracket
        case .cmd("{"), .cmd("lbrace"):  eat(); return .curly
        case .cmd("}"), .cmd("rbrace"):  eat(); return .curly
        case .cmd("langle"):             eat(); return .angle
        case .cmd("rangle"):             eat(); return .angle
        case .cmd("lfloor"), .cmd("rfloor"): eat(); return .floor
        case .cmd("lceil"),  .cmd("rceil"):  eat(); return .ceil
        case .cmd("lvert"), .cmd("rvert"), .cmd("vert"): eat(); return .abs
        case .cmd("lVert"), .cmd("rVert"), .cmd("Vert"): eat(); return .norm
        case .cmd("|"):                  eat(); return .norm
        default:                         return .paren
        }
    }

    // ── \begin{env}…\end{env} ────────────────────────────────────────────────

    mutating func environment() -> MathNode {
        skipWS()
        let envName = textContent()

        switch envName {
        case "matrix":  return matrixEnv(bracketKind: nil)
        case "pmatrix": return matrixEnv(bracketKind: .paren)
        case "bmatrix": return matrixEnv(bracketKind: .square)
        case "Bmatrix": return matrixEnv(bracketKind: .curly)
        case "vmatrix": return matrixEnv(bracketKind: .abs)
        case "Vmatrix": return matrixEnv(bracketKind: .norm)
        case "smallmatrix": return matrixEnv(bracketKind: nil)
        case "cases", "dcases": return casesEnv()
        case "align", "align*", "aligned",
             "gather", "gather*", "gathered",
             "multline", "multline*",
             "equation", "equation*",
             "split":
            return alignEnv()
        default:
            // Unknown environment — parse as a group until \end{envName}
            let nodes = mathList(until: _isEnd)
            consumeEnd()
            return nodes.count == 1 ? nodes[0] : .group(nodes)
        }
    }

    // ── Matrix environment ───────────────────────────────────────────────────

    mutating func matrixEnv(bracketKind: MathBracketKind?) -> MathNode {
        var rows: [[MathNode]] = []
        var currentRow: [MathNode] = []

        func flushRow() {
            if !currentRow.isEmpty { rows.append(currentRow); currentRow = [] }
        }

        while let t = cur, !_isEnd(t) {
            if t == .amp {
                eat()
                // Flush current cell into row
                // Cells are accumulated through atomWithScripts calls above
                continue
            }
            if t == .dblSlash {
                eat()
                flushRow()
                continue
            }
            // Parse one full cell: everything until & or \\ or \end
            let cell = mathList(until: { $0 == .amp || $0 == .dblSlash || _isEnd($0) })
            let cellNode: MathNode = cell.count == 1 ? cell[0] : .group(cell)
            currentRow.append(cellNode)
        }
        flushRow()
        consumeEnd()

        let matrix: MathNode = rows.isEmpty ? .placeholder : .matrix(rows)
        if let kind = bracketKind {
            return .bracketed(kind, matrix)
        }
        return matrix
    }

    // ── Cases environment ────────────────────────────────────────────────────

    mutating func casesEnv() -> MathNode {
        var pairs: [(MathNode, MathNode)] = []

        while let t = cur, !_isEnd(t) {
            // Each row: value & condition \\
            let valueCells = mathList(until: { $0 == .amp || $0 == .dblSlash || _isEnd($0) })
            let value: MathNode = valueCells.count == 1 ? valueCells[0] : .group(valueCells)

            var condition: MathNode = .placeholder
            if cur == .amp {
                eat()
                let condCells = mathList(until: { $0 == .dblSlash || _isEnd($0) })
                condition = condCells.count == 1 ? condCells[0] : .group(condCells)
            }

            if cur == .dblSlash { eat() }
            if !valueCells.isEmpty { pairs.append((value, condition)) }
        }
        consumeEnd()
        return pairs.isEmpty ? .placeholder : .cases(pairs)
    }

    // ── Align/aligned environment ────────────────────────────────────────────
    // Flatten each row into a group; rows separated by \\.
    mutating func alignEnv() -> MathNode {
        var rows: [MathNode] = []

        while let t = cur, !_isEnd(t) {
            // Skip & alignment markers within a row
            let row = mathList(until: { $0 == .dblSlash || _isEnd($0) })
            if cur == .dblSlash { eat() }
            if !row.isEmpty {
                rows.append(row.count == 1 ? row[0] : .group(row))
            }
        }
        consumeEnd()
        return rows.count == 1 ? rows[0] : .group(rows)
    }

    // ── Text content: reads literal text from {…} ────────────────────────────

    mutating func textContent() -> String {
        skipWS()
        guard case .lbrace = cur else { return "" }
        eat() // {
        var s = ""
        var depth = 1
        while let t = cur {
            switch t {
            case .lbrace:           depth += 1; s += "{"; eat()
            case .rbrace:
                depth -= 1; eat()
                if depth == 0 { return s }
                s += "}"
            case .letter(let c):    s += String(c); eat()
            case .digit(let c):     s += String(c); eat()
            case .other(let c):     s += String(c); eat()
            case .ws:               s += " "; eat()
            case .cmd(let n):       s += "\\\(n)"; eat()
            default:                eat()
            }
        }
        return s
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    mutating func consumeEnd() {
        if _isEnd(cur ?? .ws) { eat() }
        skipWS()
        _ = textContent()  // consume {envname}
    }
}

private func _isEnd(_ t: _Tok) -> Bool {
    if case .cmd("end") = t { return true }
    return false
}

// MARK: - Symbol Map

private let _symbolMap: [String: MathSymbol] = [
    // ── Greek lowercase ───────────────────────────────────────────────────
    "alpha": .alpha, "beta": .beta, "gamma": .gamma, "delta": .delta,
    "epsilon": .epsilon, "varepsilon": .varepsilon,
    "zeta": .zeta, "eta": .eta,
    "theta": .theta, "vartheta": .vartheta,
    "iota": .iota, "kappa": .kappa, "lambda": .lambda, "mu": .mu,
    "nu": .nu, "xi": .xi,
    "pi": .pi, "varpi": .varpi,
    "rho": .rho, "varrho": .varrho,
    "sigma": .sigma, "varsigma": .varsigma,
    "tau": .tau, "upsilon": .upsilon,
    "phi": .phi, "varphi": .varphi,
    "chi": .chi, "psi": .psi, "omega": .omega,

    // ── Greek uppercase ───────────────────────────────────────────────────
    "Gamma": .Gamma, "Delta": .Delta, "Theta": .Theta, "Lambda": .Lambda,
    "Xi": .Xi, "Pi": .Pi, "Sigma": .Sigma, "Upsilon": .Upsilon,
    "Phi": .Phi, "Psi": .Psi, "Omega": .Omega,

    // ── Calculus / analysis ───────────────────────────────────────────────
    "partial": .partial, "nabla": .nabla,
    "infty": .infinity, "infinity": .infinity,
    "prime": .prime,

    // ── Set theory ────────────────────────────────────────────────────────
    "in": .inSet, "notin": .notIn,
    "subset": .subset, "subseteq": .subseteq, "nsubseteq": .subset,
    "supset": .supset, "supseteq": .supseteq,
    "cup": .union, "cap": .intersection,
    "setminus": .setminus, "emptyset": .emptyset, "varnothing": .emptyset,

    // ── Logic ─────────────────────────────────────────────────────────────
    "forall": .forall, "exists": .exists, "nexists": .nexists,
    "wedge": .wedge, "land": .wedge,
    "vee": .vee, "lor": .vee,
    "lnot": .lnot, "neg": .lnot,
    "top": .top, "bot": .perp,

    // ── Relations ─────────────────────────────────────────────────────────
    "leq": .leq, "le": .leq, "leqslant": .leq,
    "geq": .geq, "ge": .geq, "geqslant": .geq,
    "neq": .neq, "ne": .neq,
    "approx": .approx, "sim": .sim, "simeq": .simeq,
    "cong": .cong, "equiv": .equiv, "propto": .propto,
    "ll": .ll, "gg": .gg,
    "perp": .perp, "mid": .perp,
    "prec": .ll, "succ": .gg,   // approximate

    // ── Arrows ────────────────────────────────────────────────────────────
    "to": .rightArrow, "rightarrow": .rightArrow, "longrightarrow": .rightArrow,
    "gets": .leftArrow, "leftarrow": .leftArrow, "longleftarrow": .leftArrow,
    "leftrightarrow": .leftRightArrow, "longleftrightarrow": .leftRightArrow,
    "Rightarrow": .Rightarrow, "Longrightarrow": .Rightarrow, "implies": .Rightarrow,
    "Leftarrow": .Leftarrow, "Longleftarrow": .Leftarrow,
    "Leftrightarrow": .iff, "Longleftrightarrow": .iff, "iff": .iff,
    "mapsto": .mapsto, "longmapsto": .mapsto,
    "uparrow": .uparrow, "downarrow": .downarrow,
    "nearrow": .uparrow, "searrow": .downarrow,   // approximate

    // ── Binary operators ──────────────────────────────────────────────────
    "cdot": .cdot, "times": .times, "div": .div,
    "pm": .pm, "mp": .mp,
    "oplus": .oplus, "otimes": .otimes, "ominus": .ominus,
    "circ": .circ, "bullet": .bullet,

    // ── Miscellaneous ─────────────────────────────────────────────────────
    "cdots": .cdots, "ldots": .ldots, "dots": .ldots,
    "vdots": .vdots, "ddots": .ddots,
    "hbar": .hbar, "ell": .ell,
    "aleph": .aleph,
    "therefore": .therefore, "because": .because,
    "angle": .angle,
    "dagger": .dagger, "ddagger": .ddagger,
    "star": .cdot,    // approximate — no star in MathSymbol yet

    // ── Number sets (single-letter fallback; \mathbb handles the rest) ────
    // These come up when someone writes \Re, \Im, etc.
    "Re": .reals,     // approximate
    "Im": .reals,     // approximate
]
