struct HTTPHeaderValueParser {
    var current: Substring
    init(string: String) {
        self.current = .init(string)
    }

    mutating func nextValue() -> String? {
        guard !self.current.isEmpty else {
            return nil
        }
        let value: Substring
        if let separator = self.nextSeparator() {
            if let doubleQuote = self.nextDoubleQuote(), doubleQuote < separator {
                guard let nextDoubleQuote = self.nextDoubleQuote(skip: 1) else {
                    return nil
                }
                value = self.pop(to: nextDoubleQuote)
                self.pop()
            } else {
                value = self.pop(to: separator)
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

    mutating func nextParameter() -> (key: String, value: String)? {
        let key: Substring
        let value: Substring
        if let equals = self.nextEquals() {
            if let doubleQuote = self.nextDoubleQuote(), doubleQuote < equals {
                // quoted keys not supported
                return nil
            }

            key = self.pop(to: equals)
            self.pop()

            if let separator = self.nextSeparator() {
                if let doubleQuote = self.nextDoubleQuote(), doubleQuote < separator {
                    // quoted value
                    guard let nextDoubleQuote = self.nextDoubleQuote(skip: 1) else {
                        return nil
                    }
                    value = self.pop(to: nextDoubleQuote)
                    self.pop()
                } else {
                    value = self.pop(to: separator)
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

    private func nextSeparator() -> Substring.Index? {
        let semicolon = self.current.firstIndex(of: ";")
        let comma = self.current.firstIndex(of: ",")
        switch (semicolon, comma) {
        case (.none, .none):
            return nil
        case (.some(let semicolon), .none):
            return semicolon
        case (.none, .some(let comma)):
            return comma
        case (.some(let semicolon), .some(let comma)):
            if semicolon < comma {
                return semicolon
            } else {
                return comma
            }
        }
    }

    private func nextEquals() -> Substring.Index? {
        self.current.firstIndex(of: "=")
    }
}
