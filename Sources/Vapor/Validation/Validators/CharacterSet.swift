extension Validator {

    /// Validates that all characters in a `String` are ASCII (bytes 0..<128).
    public static var ascii: Validator<String> {
        .characterSet(.ascii)
    }

    /// Validates that all characters in a `String` are alphanumeric (a-z,A-Z,0-9).
    public static var alphanumeric: Validator<String> {
        .characterSet(.alphanumerics)
    }

    /// Validates that all characters in a `String` are in the supplied `CharacterSet`.
    public static func characterSet(_ characterSet: Foundation.CharacterSet) -> Validator<String> {
        CharacterSet(characterSet: characterSet).validator()
    }

    /// Validates that a `String` contains characters in a given `CharacterSet`.
    public struct CharacterSet: ValidatorType {
        public struct Result: ValidatorResult {
            public let characterSet: Foundation.CharacterSet
            public let invalidSlice: Substring?

            /// See `CustomStringConvertible`.
            public var description: String {
                var string: String
                if let invalidSlice = invalidSlice {
                    string = "contains an invalid character: '\(invalidSlice)'"
                } else {
                    string = "contains valid characters"
                }
                if !characterSet.traits.isEmpty {
                    string += " (allowed: \(characterSet.traits.joined(separator: ", ")))"
                }
                return string
            }

            /// See `ValidatorResult`.
            public var failed: Bool { invalidSlice != nil }
        }

        /// `CharacterSet` to validate against.
        let characterSet: Foundation.CharacterSet

        public init(characterSet: Foundation.CharacterSet) {
            self.characterSet = characterSet
        }

        /// See `Validator`.
        public func validate(_ s: String) -> Result {
            .init(
                characterSet: characterSet,
                invalidSlice: s.rangeOfCharacter(from: characterSet.inverted).map { s[$0] }
            )
        }
    }
}

/// Unions two character sets.
///
///     .characterSet(.alphanumerics + .whitespaces)
///
public func +(lhs: CharacterSet, rhs: CharacterSet) -> CharacterSet {
    lhs.union(rhs)
}

private extension Foundation.CharacterSet {

    /// ASCII (byte 0..<128) character set.
    static var ascii: CharacterSet {
        CharacterSet(charactersIn: Unicode.Scalar(0)..<Unicode.Scalar(128))
    }

    /// Returns an array of strings describing the contents of this `CharacterSet`.
    var traits: [String] {
        var desc: [String] = []
        if isSuperset(of: .newlines) {
            desc.append("newlines")
        }
        if isSuperset(of: .whitespaces) {
            desc.append("whitespace")
        }
        if isSuperset(of: .capitalizedLetters) {
            desc.append("A-Z")
        }
        if isSuperset(of: .lowercaseLetters) {
            desc.append("a-z")
        }
        if isSuperset(of: .decimalDigits) {
            desc.append("0-9")
        }
        return desc
    }
}
