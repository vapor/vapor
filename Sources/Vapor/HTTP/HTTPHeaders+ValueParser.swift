extension HTTPHeaders {
    public struct ValueParser {
        var current: Substring

        public init<S>(string: S)
            where S: StringProtocol
        {
            self.current = .init(string)
        }

        public mutating func nextValue() -> String? {
            guard !self.current.isEmpty else {
                return nil
            }
            let value: Substring
            if let semicolon = self.nextSemicolon() {
                if let doubleQuote = self.nextDoubleQuote(), doubleQuote < semicolon {
                    guard let nextDoubleQuote = self.nextDoubleQuote(skip: 1) else {
                        return nil
                    }
                    value = self.pop(to: nextDoubleQuote)
                    self.pop()
                } else {
                    value = self.pop(to: semicolon)
                    self.pop()
                }
            } else {
                value = self.current
                self.current = ""
            }
            return value.trimmingCharacters(in: .whitespaces)
                .removingDoubleQuotes()
                .unescapingQuotes()
        }

        public mutating func nextParameter() -> (key: String, value: String)? {
            let key: Substring
            let value: Substring
            if let equals = self.nextEquals() {
                if let doubleQuote = self.nextDoubleQuote(), doubleQuote < equals {
                    // quoted keys not supported
                    return nil
                }

                key = self.pop(to: equals)
                self.pop()

                if let semicolon = self.nextSemicolon() {
                    if let doubleQuote = self.nextDoubleQuote(), doubleQuote < semicolon {
                        // quoted value
                        guard let nextDoubleQuote = self.nextDoubleQuote(skip: 1) else {
                            return nil
                        }
                        value = self.pop(to: nextDoubleQuote)
                        self.pop()
                    } else {
                        value = self.pop(to: semicolon)
                        self.pop()
                    }
                } else {
                    value = self.pop(to: self.current.endIndex)
                }
            } else {
                return nil
            }
            return (
                key: key.trimmingCharacters(in: .whitespaces)
                    .removingDoubleQuotes()
                    .unescapingQuotes(),
                value: value.trimmingCharacters(in: .whitespaces)
                    .removingDoubleQuotes()
                    .unescapingQuotes()
            )
        }

        private mutating func pop() {
            if self.current.startIndex == self.current.endIndex {
                return
            } else {
                self.current = self.current[self.current.index(after: self.current.startIndex)...]
            }
        }

        private mutating func pop(to index: Substring.Index) -> Substring {
            let value = self.current[..<index]
            self.current = self.current[index...]
            return value
        }

        private func nextDoubleQuote(skip: Int = 0) -> Substring.Index? {
            var startIndex = self.current.startIndex
            var current = skip
            while current >= 0 {
                guard let nextQuote = self.current[startIndex...].firstIndex(of: .doubleQuote) else {
                    return nil
                }
                startIndex = self.current.index(after: nextQuote)
                if
                    nextQuote == self.current.startIndex
                    || self.current[self.current.index(before: nextQuote)] != #"\"#
                {
                    current -= 1
                }
            }
            return startIndex
        }

        private func nextSemicolon() -> Substring.Index? {
            self.current.firstIndex(of: ";")
        }

        private func nextEquals() -> Substring.Index? {
            self.current.firstIndex(of: "=")
        }
    }

}
