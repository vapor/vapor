extension HTTPHeaders {
    struct Directive: Equatable, CustomStringConvertible {
        var value: Substring
        var parameter: Substring?

        var description: String {
            if let parameter = self.parameter {
                return "Directive(value: \(self.value.debugDescription), parameter: \(parameter.debugDescription))"
            } else {
                return "Directive(value: \(self.value.debugDescription))"
            }
        }
        
        init(value: String, parameter: String? = nil) {
            self.value = .init(value)
            self.parameter = parameter.flatMap { .init($0) }
        }

        init(value: Substring, parameter: Substring? = nil) {
            self.value = value
            self.parameter = parameter
        }
    }

    func parseDirectives(name: Name) -> [[Directive]] {
        let headers = self[name]
        var values: [[Directive]] = []
        for header in headers {
            var parser = DirectiveParser(string: header)
            while let directives = parser.nextDirectives() {
                values.append(directives)
            }
        }
        return values
    }

    mutating func serializeDirectives(_ directives: [[Directive]], name: Name) {
        let serializer = DirectiveSerializer(directives: directives)
        self.replaceOrAdd(name: name, value: serializer.serialize())
    }

    struct DirectiveParser {
        var current: Substring

        init<S>(string: S)
            where S: StringProtocol
        {
            self.current = .init(string)
        }

        mutating func nextDirectives() -> [Directive]? {
            guard !self.current.isEmpty else {
                return nil
            }
            var directives: [Directive] = []
            while let directive = self.nextDirective() {
                directives.append(directive)
            }
            return directives
        }

        private mutating func nextDirective() -> Directive? {
            self.popWhitespace()
            guard !self.current.isEmpty else {
                return nil
            }

            if self.current.first == .comma {
                self.pop()
                return nil
            }

            let value: Substring
            let parameter: Substring?
            if let equals = self.firstParameterToken() {
                value = self.pop(to: equals)
                self.pop()
                parameter = self.nextDirectiveValue()
            } else {
                value = self.nextDirectiveValue()
                parameter = nil
            }
            return .init(
                value: value.trimLinearWhitespace(),
                parameter: parameter?.trimLinearWhitespace()
                    .unescapingDoubleQuotes()
            )
        }

        private mutating func nextDirectiveValue() -> Substring {
            let value: Substring
            self.popWhitespace()
            if self.current.first == .doubleQuote {
                self.pop()
                guard let nextDoubleQuote = self.firstUnescapedDoubleQuote() else {
                    return self.pop(to: self.current.endIndex)
                }
                value = self.pop(to: nextDoubleQuote).unescapingDoubleQuotes()
                self.pop()
                self.popWhitespace()
                if self.current.first == .semicolon {
                    self.pop()
                }
            } else if let semicolon = self.current.firstIndex(of: .semicolon) {
                value = self.pop(to: semicolon)
                self.pop()
            } else if let comma = self.current.firstIndex(of: .comma) {
                value = self.pop(to: comma)
            } else {
                value = self.pop(to: self.current.endIndex)
            }
            return value
        }

        private mutating func popWhitespace() {
            if let nonWhitespace = self.current.firstIndex(where: { !$0.isLinearWhitespace }) {
                self.current = self.current[nonWhitespace...]
            } else {
                self.current = ""
            }
        }

        private mutating func pop() {
            self.current = self.current.dropFirst()
        }

        private mutating func pop(to index: Substring.Index) -> Substring {
            let value = self.current[..<index]
            self.current = self.current[index...]
            return value
        }

        private func firstParameterToken() -> Substring.Index? {
            for index in self.current.indices {
                let character = self.current[index]
                if character == .equals {
                    return index
                } else if !character.isDirectiveKey {
                    return nil
                }
            }
            return nil
        }

        private func firstUnescapedDoubleQuote() -> Substring.Index? {
            var startIndex = self.current.startIndex
            var nextDoubleQuote: Substring.Index?
            while nextDoubleQuote == nil {
                guard let possibleDoubleQuote = self.current[startIndex...].firstIndex(of: "\"") else {
                    return nil
                }
                // Check if quote is escaped.
                if self.current.startIndex == possibleDoubleQuote || self.current[self.current.index(before: possibleDoubleQuote)] != "\\" {
                    nextDoubleQuote = possibleDoubleQuote
                } else if possibleDoubleQuote < self.current.endIndex {
                    startIndex = self.current.index(after: possibleDoubleQuote)
                } else {
                    return nil
                }
            }
            return nextDoubleQuote
        }
    }

    struct DirectiveSerializer {
        let directives: [[Directive]]

        init(directives: [[Directive]]) {
            self.directives = directives
        }

        func serialize() -> String {
            var main: [String] = []

            for directives in self.directives {
                var sub: [String] = []
                for directive in directives {
                    let string: String
                    if let parameter = directive.parameter {
                        string = "\(directive.value)=\(parameter)"
                    } else {
                        string = .init(directive.value)
                    }
                    sub.append(string)
                }
                main.append(sub.joined(separator: "; "))
            }

            return main.joined(separator: ", ")
        }
    }
}

private extension Substring {
    /// Converts all `\"` to `"`.
    func unescapingDoubleQuotes() -> Substring {
        return self.lazy.split(separator: "\\").reduce(into: "") { (result, part) in
            if result.isEmpty || part.first == "\"" {
                result += part
            } else {
                result += "\\" + part
            }
        }
    }
}


private extension Character {
    static var doubleQuote: Self {
        .init(Unicode.Scalar(0x22))
    }
    static var semicolon: Self {
        .init(";")
    }
    static var equals: Self {
        .init("=")
    }
    static var dash: Self {
        .init("-")
    }
    static var comma: Self {
        .init(",")
    }
    static var underscore: Self {
        .init("_")
    }
    static var period: Self {
        .init(".")
    }

    var isDirectiveKey: Bool {
        self.isLetter || self.isNumber || self == .dash || self == .underscore || self == .period
    }
}


private extension Character {
    var isLinearWhitespace: Bool {
        self == " " || self == "\t"
    }
}

private extension Substring {
    func trimLinearWhitespace() -> Substring {
        var me = self
        while me.first?.isLinearWhitespace == .some(true) {
            me = me.dropFirst()
        }
        while me.last?.isLinearWhitespace == .some(true) {
            me = me.dropLast()
        }
        return me
    }
}
