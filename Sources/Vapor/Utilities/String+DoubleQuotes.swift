extension String {
    func removingDoubleQuotes() -> Self {
        switch (self.first, self.last) {
        case (Character.doubleQuote, Character.doubleQuote):
            return .init(self.dropFirst().dropLast())
        default:
            return self
        }
    }

    func unescapingQuotes() -> Self {
        self.components(separatedBy: #"\""#).joined(separator: "\"")
    }
}

extension Character {
    static var doubleQuote: Self {
        .init(Unicode.Scalar(0x22))
    }
}
