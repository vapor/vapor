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
    public static func characterSet(_ characterSet: CharacterSet) -> Validator<String> {
        CharacterSetValidator(characterSet: characterSet).validator()
    }
}

/// Unions two character sets.
///
///     .characterSet(.alphanumerics + .whitespaces)
///
public func +(lhs: CharacterSet, rhs: CharacterSet) -> CharacterSet {
    lhs.union(rhs)
}

public struct CharacterSetValidatorFailure: ValidatorFailure {
    public let characterSet: CharacterSet
    public let invalidSlice: Substring
}

/// Validates that a `String` contains characters in a given `CharacterSet`
struct CharacterSetValidator: ValidatorType {

    /// `CharacterSet` to validate against.
    let characterSet: CharacterSet

    /// See `Validator`
    func validate(_ s: String) -> CharacterSetValidatorFailure? {
        if let range = s.rangeOfCharacter(from: characterSet.inverted) {
            return .init(
                characterSet: characterSet,
                invalidSlice: s[range]
            )
        } else {
            return nil
        }
    }
}

private extension CharacterSet {
    /// ASCII (byte 0..<128) character set.
    static var ascii: CharacterSet {
        CharacterSet(charactersIn: Unicode.Scalar(0)..<Unicode.Scalar(128))
    }
}
