import Core
import Foundation

/// Parses leaf templates into a cacheable AST
/// that can be later combined with Leaf Data to
/// serialized a View.
public final class Parser {
    let scanner: ByteScanner

    /// Creates a new Leaf parser with the supplied bytes.
    public init(data: Data) {
        self.scanner = ByteScanner(data: data)
    }

    /// Parses the AST.
    /// throws `RenderError`. 
    public func parse() throws -> [Syntax] {
        var ast: [Syntax] = []

        ast.append(Syntax(kind: .raw(.empty), source: Source(line: 0, column: 0, range: 0..<1)))
        while let syntax = try extractSyntax(indent: 0, previous: &ast[ast.count - 1]) {
            ast.append(syntax)
        }

        return ast
    }

    // MARK: Private

    // base level extraction. checks for `#` or extracts raw
    private func extractSyntax(untilUnescaped signalBytes: Bytes = [], indent: Int, previous: inout Syntax) throws -> Syntax? {
        guard let byte = scanner.peek() else {
            return nil
        }

        let syntax: Syntax

        if byte == .numberSign {
            if try shouldExtractTag() {
                try expect(.numberSign)
                syntax = try extractTag(indent: indent, previous: &previous)
            } else {
                let byte = try scanner.requirePop()
                let start = scanner.makeSourceStart()
                let bytes = try Data(bytes: [byte]) + extractRaw(untilUnescaped: signalBytes)
                let source = scanner.makeSource(using: start)
                syntax = Syntax(kind: .raw(bytes), source: source)
            }
        } else {
            let start = scanner.makeSourceStart()
            let bytes = try extractRaw(untilUnescaped: signalBytes)
            let source = scanner.makeSource(using: start)
            syntax = Syntax(kind: .raw(bytes), source: source)
        }

        return syntax
    }

    // checks ahead to see if a tag should be parsed.
    // avoids parsing if like `#foo`.
    // must be in format `#tag()`
    private func shouldExtractTag() throws -> Bool {
        var i = 1
        var previous: Byte?
        while let byte = scanner.peek(by: i) {
            if byte == .forwardSlash || byte == .asterisk {
                if previous == .forwardSlash {
                    return true
                }
            } else if byte == .leftParenthesis {
                return true
            } else if !byte.isAllowedInIdentifier {
                return false
            }
            previous = byte
            i += 1
        }
        return false
    }

    // checks ahead to see if a body should be parsed.
    // fixme: should fix `\{`
    private func shouldExtractBody() throws -> Bool {
        var i = 0
        while let byte = scanner.peek(by: i) {
            if byte == .leftCurlyBracket {
                return true
            }
            if byte != .space {
                return false
            }
            i += 1
        }
        return false
    }

    // checks ahead to see if a chained tag `##if` should be parsed.
    private func shouldExtractChainedTag() throws -> Bool {
        var i = 1
        var previous: Byte?
        while let byte = scanner.peek(by: i) {
            if byte == .numberSign && previous == .numberSign {
                return true
            }
            if byte != .space && byte != .numberSign {
                return false
            }
            previous = byte
            i += 1
        }
        return false
    }

    // extracts a tag, recursively extracting chained tags and tag parameters and bodies.
    private func extractTag(indent: Int, previous: inout Syntax) throws -> Syntax {
        let start = scanner.makeSourceStart()

        trim: if case .raw(var bytes) = previous.kind {
            var offset = 0

            skipwhitespace: for i in (0..<bytes.count).reversed() {
                offset = i
                switch bytes[i] {
                case .space:
                    break
                case .newLine:
                    break skipwhitespace
                default:
                    break trim
                }
            }

            if offset == 0 {
                bytes = .empty
            } else {
                bytes = Data(bytes[0..<offset])
            }
            previous = Syntax(kind: .raw(bytes), source: previous.source)
        }

        // NAME
        let id = try extractTagName()
        
        // verify tag names containg / or * are comment tag names
        if id.contains(where: { $0 == .forwardSlash || $0 == .asterisk }) {
            switch id {
            case Data(bytes: [.forwardSlash, .forwardSlash]), Data(bytes: [.forwardSlash, .asterisk]):
                break
            default:
                throw ParserError.expectationFailed(
                    expected: "Valid tag name",
                    got: String(data: id, encoding: .utf8) ?? "n/a",
                    source: scanner.makeSource(using: start)
                )
            }
        }

        // PARAMS
        let params: [Syntax]
        guard let name = String(data: id, encoding: .utf8) else {
            throw ParserError.expectationFailed(
                expected: "UTF8 string",
                got: id.description,
                source: scanner.makeSource(using: start)
            )
        }

        switch name {
        case "for":
            try expect(.leftParenthesis)
            let key = try extractIdentifier()
            try expect(.space)
            try expect(.i)
            try expect(.n)
            try expect(.space)
            guard let val = try extractParameter() else {
                throw ParserError.expectationFailed(
                    expected: "right parameter",
                    got: "nil",
                    source: scanner.makeSource(using: start)
                )
            }

            switch val.kind {
            case .identifier, .tag:
                break
            default:
                throw ParserError.expectationFailed(
                    expected: "identifier or tag",
                    got: "\(val)",
                    source: scanner.makeSource(using: start)
                )
            }

            try expect(.rightParenthesis)

            guard case .identifier(let name) = key.kind else {
                throw ParserError.expectationFailed(
                    expected: "key name",
                    got: "\(key)",
                    source: scanner.makeSource(using: start)
                )
            }

            guard name.count == 1 else {
                throw ParserError.expectationFailed(
                    expected: "single key",
                    got: "\(name)",
                    source: scanner.makeSource(using: start)
                )
            }

            guard let data = name[0].data(using: .utf8) else {
                throw ParserError.expectationFailed(
                    expected: "utf8 string",
                    got: name[0],
                    source: scanner.makeSource(using: start)
                )
            }

            let raw = Syntax(
                kind: .raw(data),
                source: key.source
            )

            let keyConstant = Syntax(
                kind: .constant(.string([raw])),
                source: key.source
            )

            params = [
                val,
                keyConstant
            ]
        case "//", "/*":
            params = []
        default:
            params = try extractParameters()
        }

        // BODY
        let body: [Syntax]?
        if name == "//" {
            let s = scanner.makeSourceStart()
            let bytes = try extractBytes(untilUnescaped: [.newLine])
            // pop the newline
            try scanner.requirePop()
            body = [Syntax(
                kind: .raw(bytes),
                source: scanner.makeSource(using: s)
            )]
        } else if name == "/*" {
            let s = scanner.makeSourceStart()
            var i = 0
            var previous: Byte?
            while let byte = scanner.peek(by: i) {
                if byte == .forwardSlash && previous == .asterisk {
                    break
                }
                previous = byte
                i += 1
            }

            // pop comment text, w/o trailing */
            try scanner.requirePop(n: i - 1)

            let bytes = scanner.data[s.rangeStart..<scanner.offset]

            // pop */
            try scanner.requirePop(n: 2)

            body = [Syntax(
                kind: .raw(bytes),
                source: scanner.makeSource(using: s)
            )]
        } else {
            if try shouldExtractBody() {
                try extractSpaces()
                let rawBody = try extractBody(indent: indent + 4)
                body = try correctIndentation(rawBody, to: indent)
            } else {
                body = nil
            }
        }

        // KIND

        let kind: SyntaxKind

        switch name {
        case "if":
            let chained = try extractIfElse(indent: indent)
            kind = .tag(
                name: "ifElse",
                parameters: params,
                body: body,
                chained: chained
            )
        case "for":
            kind = .tag(
                name: "loop",
                parameters: params,
                body: body,
                chained: nil
            )
        case "//", "/*":
            kind = .tag(
                name: "comment",
                parameters: params,
                body: body,
                chained: nil
            )
        default:
            var chained: Syntax?

            if try shouldExtractChainedTag() {
                try extractSpaces()
                try expect(.numberSign)
                try expect(.numberSign)
                chained = try extractTag(indent: indent, previous: &previous)
            }

            kind = .tag(
                name: name,
                parameters: params,
                body: body,
                chained: chained
            )
        }

        let source = scanner.makeSource(using: start)
        return Syntax(kind: kind, source: source)
    }

    // corrects body indentation by splitting on newlines
    // and stitching toogether w/ supplied indent level
    func correctIndentation(_ ast: [Syntax], to indent: Int) throws -> [Syntax] {
        var corrected: [Syntax] = []

        let indent = indent + 4
        
        for syntax in ast {
            switch syntax.kind {
            case .raw(let bytes):
                let scanner = ByteScanner(data: Data(bytes))
                var chunkStart = scanner.offset
                while let byte = scanner.peek() {
                    switch byte {
                    case .newLine:
                        // pop the new line
                        try scanner.requirePop()

                        // break off the previous raw chunk
                        // and remove indentation from following chunk
                        let data = Data(bytes[chunkStart..<scanner.offset])
                        let new = Syntax(kind: .raw(data), source: syntax.source)
                        corrected.append(new)

                        var spacesSkipped = 0
                        while scanner.peek() == .space {
                            try scanner.requirePop()
                            spacesSkipped += 1
                            if spacesSkipped >= indent {
                                break
                            }
                        }

                        chunkStart = scanner.offset
                    default:
                        try scanner.requirePop()
                    }
                }

                // append any remaining bytes
                if chunkStart < bytes.count {
                    let data = Data(bytes[chunkStart..<bytes.count])
                    let new = Syntax(kind: .raw(data), source: syntax.source)
                    corrected.append(new)
                }
            default:
                corrected.append(syntax)
            }
        }

        return Array(corrected)
    }

    // extracts if/else syntax sugar
    private func extractIfElse(indent: Int) throws -> Syntax? {
        try extractSpaces()
        let start = scanner.makeSourceStart()

        if scanner.peekMatches([.e, .l, .s, .e]) {
            try scanner.requirePop(n: 4)
            try extractSpaces()

            let params: [Syntax]
            if scanner.peekMatches([.i, .f]) {
                try scanner.requirePop(n: 2)
                try extractSpaces()
                params = try extractParameters()
            } else {
                let syntax = Syntax(
                    kind: .constant(.bool(true)),
                    source: Source(line: scanner.line, column: scanner.column, range: scanner.offset..<scanner.offset + 1
                ))
                params = [syntax]
            }
            try extractSpaces()
            let elseBody = try extractBody(indent: indent)

            let kind: SyntaxKind = .tag(
                name: "ifElse",
                parameters: params,
                body: elseBody,
                chained: try extractIfElse(indent: indent)
            )

            let source = scanner.makeSource(using: start)
            return Syntax(kind: kind, source: source)
        }

        return nil
    }

    // extracts a tag body { to }
    private func extractBody(indent: Int) throws -> [Syntax] {
        try expect(.leftCurlyBracket)

        var ast: [Syntax] = []
        ast.append(Syntax(kind: .raw(.empty), source: Source(line: 0, column: 0, range: 0..<1)))
        while let syntax = try extractSyntax(untilUnescaped: [.rightCurlyBracket], indent: indent, previous: &ast[ast.count - 1]) {
            ast.append(syntax)
            if scanner.peek() == .rightCurlyBracket {
                break
            }
        }

        trim: if let last = ast.last, case .raw(var bytes) = last.kind {
            var offset = 0

            skipwhitespace: for i in (0..<bytes.count).reversed() {
                offset = i
                switch bytes[i] {
                case .space:
                    break
                case .newLine:
                    break skipwhitespace
                default:
                    break trim
                }
            }

            if offset == 0 {
                bytes = .empty
            } else {
                bytes = Data(bytes[0..<offset])
            }
            ast[ast.count - 1] = Syntax(kind: .raw(bytes), source: last.source)
        }

        try expect(.rightCurlyBracket)
        return ast
    }

    // extracts a raw chunk of text (until unescaped number sign)
    private func extractRaw(untilUnescaped signalBytes: [Byte]) throws -> Data {
        return try extractBytes(untilUnescaped: signalBytes + [.numberSign])
    }

    // extracts bytes until an unescaped signal byte is found.
    // note: escaped bytes have the leading `\` removed
    private func extractBytes(untilUnescaped signalBytes: [Byte]) throws -> Data {
        // needs to be an array for the time being b/c we may skip
        // bytes
        var bytes: Data = Data()

        var onlySpacesExtracted = true

        // continue to peek until we fine a signal byte, then exit!
        // the inner loop takes care that we will not hit any
        // properly escaped signal bytes
        while let byte = scanner.peek(), !signalBytes.contains(byte) {
            // pop the byte we just peeked at
            try scanner.requirePop()

            // if the current byte is a backslash, then
            // we need to check if next byte is a signal byte
            if byte == .backSlash {
                // check if the next byte is a signal byte
                // note: special case, any raw leading with a left curly must
                // be properly escaped (have the \ removed)
                if let next = scanner.peek(), signalBytes.contains(next) || onlySpacesExtracted && next == .leftCurlyBracket {
                    // if it is, it has been properly escaped.
                    // add it now, skipping the backslash and popping
                    // so the next iteration of this loop won't see it
                    bytes.append(next)
                    try scanner.requirePop()
                } else {
                    // just a normal backslash
                    bytes.append(byte)
                }
            } else {
                // just a normal byte
                bytes.append(byte)
            }

            if byte != .space {
                onlySpacesExtracted = false
            }
        }

        return bytes
    }

    // extracts a string of characters allowed in identifier
    private func extractIdentifier() throws -> Syntax {
        let start = scanner.makeSourceStart()

        var path: [String] = []
        var current: String = ""

        while let byte = scanner.peek(), byte.isAllowedInIdentifier {
           try scanner.requirePop()
            switch byte {
            case .period:
                path.append(current)
                current = ""
            default:
                current.append(byte.string)
            }
        }
        path.append(current)
        
        let kind: SyntaxKind = .identifier(path: path)
        let source = scanner.makeSource(using: start)
        return Syntax(kind: kind, source: source)
    }

    // extracts a string of characters allowed in tag names
    private func extractTagName() throws -> Data {
        let start = scanner.offset

        while let byte = scanner.peek(), byte.isAllowedInTagName {
            try scanner.requirePop()
        }

        return scanner.data[start..<scanner.offset]
    }

    // extracts parameters until closing right parens is found
    private func extractParameters() throws -> [Syntax] {
        try expect(.leftParenthesis)

        var params: [Syntax] = []
        repeat {
            if params.count > 0 {
                try expect(.comma)
            }

            if let param = try extractParameter() {
                params.append(param)
            }
        } while scanner.peek() == .comma

        try expect(.rightParenthesis)

        return params
    }

    // extracts a raw number
    private func extractNumber() throws -> Constant {
        let start = scanner.makeSourceStart()

        while let byte = scanner.peek(), byte.isDigit || byte == .period || byte == .hyphen {
            try scanner.requirePop()
        }

        let bytes = scanner.data[start.rangeStart..<scanner.offset]
        guard let string = String(data: bytes, encoding: .utf8) else {
            throw ParserError.expectationFailed(
                expected: "UTF8 string",
                got: bytes.description,
                source: scanner.makeSource(using: start)
            )
        }
        if bytes.contains(.period) {
            guard let double = Double(string) else {
                throw ParserError.expectationFailed(
                    expected: "double",
                    got: string,
                    source: scanner.makeSource(using: start)
                )
            }
            return .double(double)
        } else {
            guard let int = Int(string) else {
                throw ParserError.expectationFailed(
                    expected: "integer",
                    got: string,
                    source: scanner.makeSource(using: start)
                )
            }
            return .int(int)
        }

    }

    // extracts a single tag parameter. this is recursive.
    private func extractParameter() throws -> Syntax? {
        try extractSpaces()
        let start = scanner.makeSourceStart()

        guard let byte = scanner.peek() else {
            throw ParserError.expectationFailed(
                expected: "bytes",
                got: "EOF",
                source: scanner.makeSource(using: start)
            )
        }

        let kind: SyntaxKind

        switch byte {
        case .rightParenthesis:
            return nil
        case .quote:
            try expect(.quote)
            let bytes = try extractBytes(untilUnescaped: [.quote])
            try expect(.quote)
            let parser = Parser(data: bytes)
            let ast = try parser.parse()
            kind = .constant(
                .string(ast)
            )
        case .exclamation:
            try expect(.exclamation)
            guard let param = try extractParameter() else {
                throw ParserError.expectationFailed(
                    expected: "parameter",
                    got: "nil",
                    source: scanner.makeSource(using: start)
                )
            }
            kind = .not(param)
        default:
            if byte.isDigit || byte == .hyphen {
                // constant number
                let num = try extractNumber()
                kind = .constant(num)
            } else if scanner.peekMatches([.t, .r, .u, .e]) {
                try scanner.requirePop(n: 4)
                kind = .constant(.bool(true))
            } else if scanner.peekMatches([.f, .a, .l, .s, .e]) {
                try scanner.requirePop(n: 5)
                kind = .constant(.bool(false))
            } else if try shouldExtractTag() {
                var syntax = Syntax(kind: .raw(.empty), source: Source(line: 0, column: 0, range: 0..<1))
                kind = try extractTag(indent: 0, previous: &syntax).kind
            } else {
                let id = try extractIdentifier()
                kind = id.kind
            }
        }

        let syntax = Syntax(kind: kind, source: scanner.makeSource(using: start))

        try extractSpaces()

        let op: Operator?

        if let byte = scanner.peek() {
            switch byte {
            case .lessThan:
                op = .lessThan
            case .greaterThan:
                op = .greaterThan
            case .hyphen:
                op = .subtract
            case .plus:
                op = .add
            case .asterisk:
                op = .multiply
            case .forwardSlash:
                op = .divide
            case .equals:
                op = .equal
            case .exclamation:
                op = .notEqual
            case .pipe:
                op = .or
            case .ampersand:
                op = .and
            default:
                op = nil
            }
        } else {
            op = nil
        }

        if let op = op {
            try scanner.requirePop()

            // two byte operators must
            // expect their second byte
            switch op {
            case .equal, .notEqual:
                try expect(.equals)
            case .and:
                try expect(.ampersand)
            case .or:
                try expect(.pipe)
            default:
                break
            }

            guard let right = try extractParameter() else {
                throw ParserError.expectationFailed(
                    expected: "right parameter",
                    got: "nil",
                    source: scanner.makeSource(using: start)
                )
            }

            // FIXME: allow for () grouping and proper PEMDAS
            let exp: SyntaxKind = .expression(
                type: op,
                left: syntax,
                right: right
            )
            let source = scanner.makeSource(using: start)
            return Syntax(kind: exp, source: source)
        } else {
            return syntax
        }

    }

    // extracts all spaces. used for extracting: `#tag()__{`
    private func extractSpaces() throws {
        while let byte = scanner.peek(), byte == .space {
            try scanner.requirePop()
        }
    }

    // expects the supplied byte is current byte or throws an error
    private func expect(_ expect: Byte) throws {
        let start = scanner.makeSourceStart()

        guard let byte = scanner.peek() else {
            throw ParserError.unexpectedEOF(source: scanner.makeSource(using: start))
        }

        guard byte == expect else {
            throw ParserError.expectationFailed(
                expected: expect.string,
                got: byte.string,
                source: scanner.makeSource(using: start)
            )
        }

        try scanner.requirePop()
    }
}

// mark: file private scanner conveniences

extension ByteScanner {
    @discardableResult
    func requirePop() throws -> Byte {
        let start = makeSourceStart()
        guard let byte = pop() else {
            throw ParserError.unexpectedEOF(source: makeSource(using: start))
        }
        return byte
    }

    func requirePop(n: Int) throws {
        for _ in 0..<n {
            try requirePop()
        }
    }

    func peekMatches(_ bytes: [Byte]) -> Bool {
        var iterator = bytes.makeIterator()
        var i = 0
        while let next = iterator.next() {
            switch peek(by: i) {
            case next:
                i += 1
                continue
            default:
                return false
            }
        }

        return true
    }
}
