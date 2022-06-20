//
// Created by flofriday on 31.05.22.
//

import Foundation

enum Precendence: Int {
    case Lowest
    case OpDefault
    case Equals
    case LessGreater
    case Sum
    case Product
    case Prefix
    case Postfix
    case Call
    case Index
}

class Parser {
    typealias prefixParseFn = () throws -> Expression
    typealias infixParseFn = (Expression) throws -> Expression
    typealias postfixParseFn = (Expression) throws -> Expression

    private let tokens: [Token]
    private var current = 0
    private var errors: [CompileErrorMessage] = []

    var prefixParseFns = [TokenType: prefixParseFn]()
    var infixParseFns = [TokenType: infixParseFn]()
    var postfixParseFns = [TokenType: postfixParseFn]()

    // precendences by type
    let typePrecendences: [TokenType: Precendence] = [
        .Operator(pos: .Prefix, assign: false): .Prefix,
        .Operator(pos: .Postfix, assign: false): .Postfix,
    ]

    let opPrecendences: [String: Precendence] = [
        "==": .Equals,
        "<": .LessGreater,
        ">": .LessGreater,
        "<=": .LessGreater,
        ">=": .LessGreater,
        "+": .Sum,
        "-": .Sum,
        "*": .Product,
        "/": .Product,
    ]

    init(tokens: [Token]) {
        self.tokens = tokens

        // TODO: add parse functions
        prefixParseFns[.Identifier] = parseIdentifier
        prefixParseFns[.Int] = parseIntegerLiteral
        prefixParseFns[.Operator(pos: .Prefix, assign: false)] = parsePrefixExpression
        prefixParseFns[.Operator(pos: .Prefix, assign: true)] = parsePrefixExpression
        prefixParseFns[.Boolean(true)] = parseBoolean
        prefixParseFns[.Boolean(false)] = parseBoolean
        prefixParseFns[.LParen] = parseGroupedExpression

        infixParseFns[.Operator(pos: .Infix, assign: false)] = parseInfixExpression

        postfixParseFns[.Operator(pos: .Postfix, assign: true)] = parsePostfixExpression
        postfixParseFns[.Operator(pos: .Postfix, assign: false)] = parsePostfixExpression
    }

    func parse() throws -> Program {
        var statements: [Statement] = []

        while !isAtEnd() {
            do {
                let stmt = try parseStatement()
                statements.append(stmt)
            } catch let e as CompileErrorMessage {
                // We are inside an error and got confused during parsing.
                // Let's skip to the next thing we recognize so that we can continue parsing.
                // Continuing parsing is important so that we can catch all parsing errors at once.
                errors.append(e)
                synchronize()
            }
        }

        if errors.count > 0 {
            throw CompileError(messages: errors)
        }

        return Program(statements: statements)
    }

    private func synchronize() {
        _ = advance()
        while !isAtEnd() {
            if previous().type == .NLine || previous().type == .SemiColon {
                return
            }

            // TODO: maybe we need more a check of the type of token just like jLox has.
            _ = advance()
        }
    }

    func parseStatement() throws -> Statement {
        // TODO: the assign doesn't work for arrays
        if match(types: .Mut) || peek2().type.isAssign || peek2().type == .Colon {
            // parse AssignStatement
            return try parseAssignStatement()
        } else if match(types: .Ret) {
            // pase ReturnStatement
            return try parseReturnStatement()
        } else {
            // parse ExpressionStatement
            return try parseExpressionStatement()
        }
    }

    func parseAssignStatement() throws -> AssignStatement {
        let mutable = (current >= 1) && previous().type == .Mut

        let identifierToken = try consume(type: .Identifier, message: "You can only assign values to identifiers.")
        let ident = Identifier(token: identifierToken, value: identifierToken.lexeme)

        var type: Identifier?
        if check(type: .Colon) {
            _ = advance()
            type = try parseIdentifier()
        }

        // do not consume since it could be the operator of assign operator such as +: 3
        var token = peek()

        var expr: Expression = ident
        if case .Operator(pos: .Infix, assign: true) = token.type {
            expr = try parseInfixExpression(left: ident)
        } else {
            token = try consume(oneOf: [.Assign], message: "I expected a '=' after a variable decleration.")
            expr = try parseExpression(.Lowest)
        }

        try consumeStatementEnd()
        return AssignStatement(token: token, name: ident, value: expr, mutable: mutable, type: type)
    }

    func parseReturnStatement() throws -> ReturnStatement {
        let token = previous()
        let val = try parseExpression(.Lowest)
        try consumeStatementEnd()
        return ReturnStatement(token: token, returnValue: val)
    }

    func parseExpressionStatement() throws -> ExpressionStatement {
        let token = peek()
        let val = try parseExpression(.Lowest)
        // TODO: skip end of statement
        try consumeStatementEnd()
        return ExpressionStatement(token: token, expression: val)
    }

    func parseExpression(_ prec: Precendence) throws -> Expression {
        // parse prefix expression
        let prefix = prefixParseFns[peek().type]
        guard let prefix = prefix else {
            throw noPrefixParseFnError(t: peek())
        }
        var leftExpr = try prefix()

        // -----

        // parse postfix expression
        if case .Operator(pos: .Postfix, assign: _) = peek().type {
            guard let postfix = postfixParseFns[peek().type] else {
                throw error(message: "could not find postfix function for postfix operator \(String(describing: peek()))", token: peek())
            }
            leftExpr = try postfix(leftExpr)
        }

        // -----

        // parse infix expression
        while !isAtEnd(), prec.rawValue < curPrecedence.rawValue {
            let infix = infixParseFns[peek().type]
            guard let infix = infix else {
                return leftExpr
            }
            leftExpr = try infix(leftExpr)
        }
        return leftExpr
    }

    func parseIdentifier() throws -> Identifier {
//        let ident = advance()
        let ident = try consume(type: .Identifier, message: "Identifier was expected")
        return Identifier(token: ident, value: ident.literal as! String)
    }

    func parseIntegerLiteral() throws -> Expression {
        guard let literal = advance().literal as? Int64 else {
            throw genLiteralTypeError(t: previous(), expected: "Int64")
        }
        return IntegerLiteral(token: previous(), value: literal)
    }

    func parseBoolean() throws -> Expression {
        guard let literal = advance().literal as? Bool else {
            throw genLiteralTypeError(t: previous(), expected: "Bool")
        }
        return Boolean(token: previous(), value: literal)
    }

    func parseGroupedExpression() throws -> Expression {
        _ = advance()
        let exp = try parseExpression(.Lowest)
        _ = try consume(type: .RParen, message: "I expected a closing parenthesis here.")
        return exp
    }

    func parsePrefixExpression() throws -> Expression {
        let token = advance()
        let rightExpr = try parseExpression(.Prefix)
        return PrefixExpression(token: token, op: token.lexeme, right: rightExpr)
    }

    func parseInfixExpression(left: Expression) throws -> Expression {
        let prec = curPrecedence
        let token = advance()
        let right = try parseExpression(prec)
        return InfixExpression(token: token, left: left, op: token.lexeme, right: right)
    }

    func parsePostfixExpression(left: Expression) throws -> Expression {
        let token = advance()
        return PostfixExpression(token: token, left: left, op: token.lexeme)
    }
}

extension Parser {
    private func consumeStatementEnd() throws {
        if !isAtEnd(), !match(types: .SemiColon, .NLine) {
            throw error(message: "I expected, the statement to end with a newline or semicolon, but ended with '\(peek().lexeme)'", token: peek())
        }
    }

    private func match(types: TokenType...) -> Bool {
        for type in types {
            if check(type: type) {
                _ = advance()
                return true
            }
        }
        return false
    }

    private func consume(type: TokenType, message: String) throws -> Token {
        try consume(oneOf: [type], message: message)
    }

    private func consume(oneOf types: [TokenType], message: String) throws -> Token {
        guard check(oneOf: types) else {
            throw error(message: message, token: peek())
        }
        return advance()
    }

    private func check(type: TokenType) -> Bool {
        return check(oneOf: type)
    }

    private func check(oneOf types: TokenType...) -> Bool {
        return check(oneOf: types)
    }

    private func check(oneOf types: [TokenType]) -> Bool {
        if isAtEnd() {
            return false
        }
        return types.contains(peek().type)
    }

    private func isAtEnd() -> Bool {
        peek().type == .EOF
    }

    private func advance() -> Token {
        if !isAtEnd() {
            current += 1
        }
        return previous()
    }

    private func peek2() -> Token {
        tokens[current + 1]
    }

    private func peek() -> Token {
        tokens[current]
    }

    private func previous() -> Token {
        tokens[current - 1]
    }
}

extension Parser {
    private func error(message: String, token: Token) -> CompileErrorMessage {
        CompileErrorMessage(
            line: token.line,
            startCol: token.column,
            endCol: token.column + token.lexeme.count,
            message: message
        )
    }

    func peekError(expected: TokenType, got: TokenType) -> CompileErrorMessage {
        let msg = "I expected next to be \(expected), got \(got) instead"
        return error(message: msg, token: peek2())
    }

    func curError(expected: TokenType, got: TokenType) -> CompileErrorMessage {
        let msg = "I expected token to be \(expected), got \(got) instead"
        return error(message: msg, token: peek())
    }

    func noPrefixParseFnError(t: Token) -> CompileErrorMessage {
        let msg = "I couldn't find any prefix parse function for \(t.type)"
        return error(message: msg, token: peek())
    }

    func genLiteralTypeError(t: Token, expected: String) -> CompileErrorMessage {
        let msg = "I expected literal '\(t.lexeme)' (literal: \(t.literal)) to be of type \(expected)"
        return error(message: msg, token: peek())
    }
}

extension Parser {
    private func getPrecedence(of t: Token) -> Precendence {
        // in case of assign statement a *: 3 + 2. this should be evaluated as a *: (3 + 2)
        if case .Operator(pos: .Infix, assign: true) = t.type {
            return .Lowest
        } else if case .Operator = t.type {
            guard let prec = opPrecendences[t.lexeme] else {
                return .OpDefault
            }
            return prec
        } else {
            guard let prec = typePrecendences[peek2().type] else {
                return .Lowest
            }
            return prec
        }
    }

    var peekPrecedence: Precendence {
        getPrecedence(of: peek2())
    }

    var curPrecedence: Precendence {
        getPrecedence(of: peek())
    }
}
