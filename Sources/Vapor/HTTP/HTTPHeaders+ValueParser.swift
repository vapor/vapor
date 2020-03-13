extension HTTPHeaders {
    public struct ValueParser {
        var current: Substring

        public init<S>(string: S)
            where S: StringProtocol
        {
            self.current = .init(string)
        }

        public mutating func nextValue() -> Substring? {
            guard !self.current.isEmpty else {
                return nil
            }
            self.popWhitespace()
            let value: Substring
            if self.current.first == .doubleQuote {
                self.pop()
                guard let nextDoubleQuote = self.firstUnescapedDoubleQuote() else {
                    return nil
                }
                value = self.pop(to: nextDoubleQuote)
                self.pop()
                self.popWhitespace()
                if self.current.first == .semicolon {
                    self.pop()
                }
            } else if let semicolon = self.current.firstIndex(of: .semicolon) {
                value = self.pop(to: semicolon)
                self.pop()
            } else {
                value = self.current
                self.current = ""
            }
            return value.trimLinearWhitespace().unescapingDoubleQuotes()
        }

        public mutating func nextParameter() -> (key: Substring, value: Substring)? {
            guard let equals = self.current.firstIndex(of: .equals) else {
                return nil
            }
            if let doubleQuote = self.firstUnescapedDoubleQuote(), doubleQuote < equals {
                // quoted keys not supported
                return nil
            }
            let key = self.pop(to: equals)
            self.pop()
            self.popWhitespace()
            guard let value = self.nextValue() else {
                return nil
            }
            return (
                key: key.trimLinearWhitespace(),
                value: value.trimLinearWhitespace()
                    .unescapingDoubleQuotes()
            )
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
