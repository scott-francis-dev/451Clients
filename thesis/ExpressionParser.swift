import Foundation

// MARK: - Public API

struct ParsedExpression: Sendable {
    fileprivate let root: _Node
    let variables: Set<String>
    let source: String

    nonisolated func evaluate(_ bindings: [String: Double]) -> Double {
        _evaluateMulti(root, bindings: bindings)
    }

    var prettyString: String {
        _prettyPrint(root)
    }
}

enum ExpressionParser {

    static func parse(_ input: String) -> (@Sendable (Double) -> Double)? {
        guard let expr = parseExpression(input) else { return nil }
        let nonX = expr.variables.subtracting(["x"])
        guard nonX.isEmpty else { return nil }
        return { x in expr.evaluate(["x": x]) }
    }

    static func parseExpression(_ input: String) -> ParsedExpression? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard let tokens = _tokenize(trimmed) else { return nil }
        var slice = tokens[...]
        guard let node = _parseExpression(&slice), slice.isEmpty else { return nil }
        return ParsedExpression(
            root: node,
            variables: _extractVariables(node),
            source: trimmed
        )
    }
}

// MARK: - AST

private enum _BinaryOp: Sendable {
    case add, subtract, multiply, divide, power
}

private indirect enum _Node: Sendable {
    case constant(Double)
    case namedVariable(String)
    case binary(_Node, _BinaryOp, _Node)
    case unaryMinus(_Node)
    case function(String, _Node)
}

// MARK: - Tokens

private enum _Token: Equatable {
    case number(Double)
    case namedVariable(String)
    case plus, minus, multiply, divide, power
    case leftParen, rightParen
    case function(String)
}

// MARK: - Tokenizer

private let _knownFunctions: Set<String> = [
    "sin", "cos", "tan", "sqrt", "abs", "log", "ln", "exp", "asin", "acos", "atan"
]

private let _knownConstants: [String: Double] = [
    "pi": .pi,
    "e": M_E
]

private func _tokenize(_ input: String) -> [_Token]? {
    var tokens: [_Token] = []
    let chars = Array(input)
    var i = 0

    func shouldInsertMultiply() -> Bool {
        guard let last = tokens.last else { return false }
        switch last {
        case .number, .namedVariable, .rightParen: return true
        default: return false
        }
    }

    while i < chars.count {
        let c = chars[i]

        if c.isWhitespace { i += 1; continue }

        if c.isNumber || (c == "." && i + 1 < chars.count && chars[i + 1].isNumber) {
            if shouldInsertMultiply() { tokens.append(.multiply) }
            var numStr = String(c)
            i += 1
            while i < chars.count && (chars[i].isNumber || chars[i] == ".") {
                numStr.append(chars[i])
                i += 1
            }
            guard let value = Double(numStr) else { return nil }
            tokens.append(.number(value))
            continue
        }

        if c.isLetter {
            if shouldInsertMultiply() { tokens.append(.multiply) }
            var name = String(c)
            i += 1
            while i < chars.count && (chars[i].isLetter || chars[i].isNumber || chars[i] == "_") {
                name.append(chars[i])
                i += 1
            }
            let lower = name.lowercased()
            if let val = _knownConstants[lower] {
                tokens.append(.number(val))
            } else if _knownFunctions.contains(lower) {
                tokens.append(.function(lower))
            } else {
                tokens.append(.namedVariable(name))
            }
            continue
        }

        if c == "(" {
            if shouldInsertMultiply() { tokens.append(.multiply) }
            tokens.append(.leftParen)
            i += 1
            continue
        }

        switch c {
        case "+": tokens.append(.plus)
        case "-": tokens.append(.minus)
        case "*": tokens.append(.multiply)
        case "/": tokens.append(.divide)
        case "^": tokens.append(.power)
        case ")": tokens.append(.rightParen)
        default: return nil
        }
        i += 1
    }
    return tokens
}

// MARK: - Recursive Descent Parser

private func _parseExpression(_ tokens: inout ArraySlice<_Token>) -> _Node? {
    guard var left = _parseTerm(&tokens) else { return nil }
    while let next = tokens.first, next == .plus || next == .minus {
        tokens = tokens.dropFirst()
        guard let right = _parseTerm(&tokens) else { return nil }
        left = .binary(left, next == .plus ? .add : .subtract, right)
    }
    return left
}

private func _parseTerm(_ tokens: inout ArraySlice<_Token>) -> _Node? {
    guard var left = _parsePower(&tokens) else { return nil }
    while let next = tokens.first, next == .multiply || next == .divide {
        tokens = tokens.dropFirst()
        guard let right = _parsePower(&tokens) else { return nil }
        left = .binary(left, next == .multiply ? .multiply : .divide, right)
    }
    return left
}

private func _parsePower(_ tokens: inout ArraySlice<_Token>) -> _Node? {
    guard let base = _parseUnary(&tokens) else { return nil }
    if tokens.first == .power {
        tokens = tokens.dropFirst()
        guard let exponent = _parsePower(&tokens) else { return nil }
        return .binary(base, .power, exponent)
    }
    return base
}

private func _parseUnary(_ tokens: inout ArraySlice<_Token>) -> _Node? {
    if tokens.first == .minus {
        tokens = tokens.dropFirst()
        guard let operand = _parseUnary(&tokens) else { return nil }
        return .unaryMinus(operand)
    }
    return _parseAtom(&tokens)
}

private func _parseAtom(_ tokens: inout ArraySlice<_Token>) -> _Node? {
    guard let token = tokens.first else { return nil }
    switch token {
    case .number(let v):
        tokens = tokens.dropFirst()
        return .constant(v)
    case .namedVariable(let name):
        tokens = tokens.dropFirst()
        return .namedVariable(name)
    case .function(let name):
        tokens = tokens.dropFirst()
        guard tokens.first == .leftParen else { return nil }
        tokens = tokens.dropFirst()
        guard let arg = _parseExpression(&tokens) else { return nil }
        guard tokens.first == .rightParen else { return nil }
        tokens = tokens.dropFirst()
        return .function(name, arg)
    case .leftParen:
        tokens = tokens.dropFirst()
        guard let expr = _parseExpression(&tokens) else { return nil }
        guard tokens.first == .rightParen else { return nil }
        tokens = tokens.dropFirst()
        return expr
    default:
        return nil
    }
}

// MARK: - Variable Extraction

private func _extractVariables(_ node: _Node) -> Set<String> {
    switch node {
    case .constant: return []
    case .namedVariable(let name): return [name]
    case .unaryMinus(let n): return _extractVariables(n)
    case .binary(let l, _, let r):
        return _extractVariables(l).union(_extractVariables(r))
    case .function(_, let arg):
        return _extractVariables(arg)
    }
}

// MARK: - Multi-Variable Evaluator

nonisolated private func _evaluateMulti(_ node: _Node, bindings: [String: Double]) -> Double {
    switch node {
    case .constant(let v): return v
    case .namedVariable(let name): return bindings[name] ?? .nan
    case .unaryMinus(let n): return -_evaluateMulti(n, bindings: bindings)
    case .binary(let l, let op, let r):
        let lv = _evaluateMulti(l, bindings: bindings)
        let rv = _evaluateMulti(r, bindings: bindings)
        switch op {
        case .add: return lv + rv
        case .subtract: return lv - rv
        case .multiply: return lv * rv
        case .divide: return rv != 0 ? lv / rv : .nan
        case .power: return pow(lv, rv)
        }
    case .function(let name, let arg):
        let a = _evaluateMulti(arg, bindings: bindings)
        switch name {
        case "sin":  return sin(a)
        case "cos":  return cos(a)
        case "tan":  return tan(a)
        case "asin": return asin(a)
        case "acos": return acos(a)
        case "atan": return atan(a)
        case "sqrt": return sqrt(a)
        case "abs":  return abs(a)
        case "log":  return log10(a)
        case "ln":   return log(a)
        case "exp":  return exp(a)
        default:     return .nan
        }
    }
}

// MARK: - Pretty Printer

private func _prettyPrint(_ node: _Node) -> String {
    switch node {
    case .constant(let v):
        if abs(v - .pi) < 1e-15 { return "\u{03C0}" }
        if abs(v - M_E) < 1e-15 { return "e" }
        if v == v.rounded(.towardZero) && abs(v) < 1e15 && v >= 0 {
            return "\(Int(v))"
        }
        if v < 0 && v == v.rounded(.towardZero) && abs(v) < 1e15 {
            return "(\(Int(v)))"
        }
        let s = String(format: "%g", v)
        return v < 0 ? "(\(s))" : s

    case .namedVariable(let name):
        return name

    case .unaryMinus(let child):
        switch child {
        case .constant, .namedVariable:
            return "\u{2212}\(_prettyPrint(child))"
        default:
            return "\u{2212}(\(_prettyPrint(child)))"
        }

    case .binary(let l, .add, let r):
        let ls = _prettyPrint(l)
        if case .unaryMinus(let inner) = r {
            return "\(ls) \u{2212} \(_prettyPrintMaybeParenAddSub(inner))"
        }
        if case .constant(let v) = r, v < 0 {
            return "\(ls) \u{2212} \(String(format: "%g", -v))"
        }
        return "\(ls) + \(_prettyPrint(r))"

    case .binary(let l, .subtract, let r):
        let ls = _prettyPrint(l)
        let rs = _prettyPrintWrapForAddSub(r)
        return "\(ls) \u{2212} \(rs)"

    case .binary(let l, .multiply, let r):
        let ls = _prettyPrintWrapForMulDiv(l)
        let rs = _prettyPrintWrapForMulDiv(r)
        if case .constant = l {
            switch r {
            case .namedVariable, .function:
                return "\(ls)\(rs)"
            case .binary(_, .power, _):
                return "\(ls)\(rs)"
            default: break
            }
        }
        return "\(ls) \u{00B7} \(rs)"

    case .binary(let l, .divide, let r):
        let ls = _prettyPrintWrapForMulDiv(l)
        let rs: String
        switch r {
        case .constant, .namedVariable: rs = _prettyPrint(r)
        default: rs = "(\(_prettyPrint(r)))"
        }
        return "\(ls)/\(rs)"

    case .binary(let l, .power, let r):
        let ls: String
        switch l {
        case .constant, .namedVariable: ls = _prettyPrint(l)
        default: ls = "(\(_prettyPrint(l)))"
        }
        if case .constant(let v) = r,
           v == v.rounded(.towardZero), v >= 0, v <= 20 {
            return ls + _toSuperscript(Int(v))
        }
        if case .unaryMinus(.constant(let v)) = r,
           v == v.rounded(.towardZero), v > 0, v <= 20 {
            return ls + "\u{207B}" + _toSuperscript(Int(v))
        }
        return "\(ls)^\(_prettyPrint(r))"

    case .function(let name, let arg):
        let a = _prettyPrint(arg)
        if name == "sqrt" { return "\u{221A}(\(a))" }
        return "\(name)(\(a))"
    }
}

private func _prettyPrintWrapForMulDiv(_ node: _Node) -> String {
    switch node {
    case .binary(_, .add, _), .binary(_, .subtract, _):
        return "(\(_prettyPrint(node)))"
    default:
        return _prettyPrint(node)
    }
}

private func _prettyPrintWrapForAddSub(_ node: _Node) -> String {
    switch node {
    case .binary(_, .add, _), .binary(_, .subtract, _):
        return "(\(_prettyPrint(node)))"
    default:
        return _prettyPrint(node)
    }
}

private func _prettyPrintMaybeParenAddSub(_ node: _Node) -> String {
    switch node {
    case .binary(_, .add, _), .binary(_, .subtract, _):
        return "(\(_prettyPrint(node)))"
    default:
        return _prettyPrint(node)
    }
}

private func _toSuperscript(_ n: Int) -> String {
    let digits: [Character] = [
        "\u{2070}", "\u{00B9}", "\u{00B2}", "\u{00B3}", "\u{2074}",
        "\u{2075}", "\u{2076}", "\u{2077}", "\u{2078}", "\u{2079}"
    ]
    if n < 0 { return "\u{207B}" + _toSuperscript(-n) }
    return String(String(n).map { digits[Int(String($0))!] })
}

// MARK: - MathNode Bridge

extension ParsedExpression {
    /// Lifts this expression into a MathNode for use with MathView / MathLayout.
    /// Old documents round-trip cleanly: expressionSource parses through
    /// ExpressionParser as before, then bridges here for 2D rendering.
    public var mathNode: MathNode {
        _nodeToMathNode(root)
    }
}

private func _nodeToMathNode(_ node: _Node) -> MathNode {
    switch node {
    case .constant(let v):
        if abs(v - .pi) < 1e-12 { return .symbol(.pi) }
        if abs(v - M_E)  < 1e-12 { return .symbol(.varepsilon) }
        return .number(v)
    case .namedVariable(let name):
        return .variable(name)
    case .unaryMinus(let child):
        return .negate(_nodeToMathNode(child))
    case .binary(let l, let op, let r):
        let lm = _nodeToMathNode(l)
        let rm = _nodeToMathNode(r)
        switch op {
        case .add:      return .add(lm, rm)
        case .subtract: return .subtract(lm, rm)
        case .multiply: return .multiply(lm, rm)
        case .divide:   return .divide(lm, rm)
        case .power:    return .power(base: lm, exp: rm)
        }
    case .function(let name, let arg):
        return .apply(name, _nodeToMathNode(arg))
    }
}
