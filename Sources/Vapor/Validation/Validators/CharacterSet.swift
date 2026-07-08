#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct ValidationCharacterSet: Sendable {
    @usableFromInline let _contains: @Sendable (Unicode.Scalar) -> Bool

    /// Human-readable description of the allowed characters, e.g. "a-z, 0-9".
    public let description: String

    public init(description: String, contains: @escaping @Sendable (Unicode.Scalar) -> Bool) {
        self.description = description
        self._contains = contains
    }

    /// An explicit set of allowed characters.
    public init(charactersIn string: String) {
        let scalars = Set(string.unicodeScalars)
        self.init(description: "one of \"\(string)\"") { scalars.contains($0) }
    }

    @inlinable
    public func contains(_ scalar: Unicode.Scalar) -> Bool { _contains(scalar) }
}

extension ValidationCharacterSet {
    public func union(_ other: Self) -> Self {
        Self(description: "\(description), \(other.description)") {
            self.contains($0) || other.contains($0)
        }
    }

    public func intersection(_ other: Self) -> Self {
        Self(description: "\(description) and \(other.description)") {
            self.contains($0) && other.contains($0)
        }
    }

    public var inverted: Self {
        Self(description: "not \(description)") { !self.contains($0) }
    }
}

/// Unions two character sets.
///
///     .characterSet(.alphanumerics + .whitespaces)
///
public func + (lhs: ValidationCharacterSet, rhs: ValidationCharacterSet) -> ValidationCharacterSet {
    lhs.union(rhs)
}

// Classification uses `Unicode.Scalar.Properties` / general categories, which
// are backed by the stdlib's bundled Unicode tables.
extension ValidationCharacterSet {
    /// ASCII (scalar value < 128).
    public static let ascii = Self(description: "ASCII") { $0.isASCII }

    /// Unicode letters, marks, and numbers.
    public static let alphanumerics = Self(description: "letters and digits") {
        switch $0.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .nonspacingMark, .spacingMark, .enclosingMark,
             .decimalNumber, .letterNumber, .otherNumber:
            true
        default:
            false
        }
    }

    /// Strict ASCII a-z / A-Z / 0-9.
    public static let asciiAlphanumerics = Self(description: "a-z, A-Z, 0-9") {
        switch $0.value {
        case 0x30...0x39, 0x41...0x5A, 0x61...0x7A: true
        default: false
        }
    }

    /// Decimal digits of any script.
    public static let decimalDigits = Self(description: "decimal digits") {
        $0.properties.generalCategory == .decimalNumber
    }

    /// Lowercase + uppercase letters.
    public static let letters = Self(description: "a-z, A-Z") {
        $0.properties.generalCategory == .lowercaseLetter || $0.properties.generalCategory == .uppercaseLetter
    }

    /// Lowercase letters.
    public static let lowercaseLetters = Self(description: "a-z") {
        $0.properties.generalCategory == .lowercaseLetter
    }

    /// Uppercase letters.
    public static let uppercaseLetters = Self(description: "A-Z") {
        switch $0.properties.generalCategory {
        case .uppercaseLetter, .titlecaseLetter: true
        default: false
        }
    }

    /// Horizontal whitespace.
    /// Does not include newlines.
    public static let whitespaces = Self(description: "whitespace") {
        $0.value == 0x09 || $0.properties.generalCategory == .spaceSeparator
    }

    /// Newlines: U+000A–U+000D, U+0085, U+2028, U+2029.
    public static let newlines = Self(description: "newlines") {
        switch $0.value {
        case 0x0A...0x0D, 0x85, 0x2028, 0x2029: true
        default: false
        }
    }
}

extension Validator where T == String {
    /// Validates that all characters in a `String` are ASCII (scalars 0..<128).
    public static var ascii: Validator { .characterSet(.ascii) }

    /// Validates that all characters in a `String` are alphanumeric.
    public static var alphanumeric: Validator { .characterSet(.alphanumerics) }

    /// Validates that all characters in a `String` are in the supplied set.
    public static func characterSet(_ characterSet: ValidationCharacterSet) -> Validator {
        .init { ValidatorResults.CharacterSet(string: $0, characterSet: characterSet) }
    }
}

extension ValidatorResults {
    /// Result of a validator checking that a `String` contains only allowed characters.
    public struct CharacterSet {
        public let string: String
        public let characterSet: ValidationCharacterSet

        /// The first scalar not in `characterSet`, as a range, if any.
        var invalidRange: Swift.Range<String.Index>? {
            let scalars = self.string.unicodeScalars
            guard let idx = scalars.firstIndex(where: { !self.characterSet.contains($0) }) else {
                return nil
            }
            return idx ..< scalars.index(after: idx)
        }

        public var invalidSlice: String? {
            self.invalidRange.map { String(self.string[$0]) }
        }

        var allowedCharacterString: String { self.characterSet.description }
    }
}

extension ValidatorResults.CharacterSet: ValidatorResult {
    public var isFailure: Bool { self.invalidRange != nil }

    public var successDescription: String? {
        "contains only \(self.allowedCharacterString)"
    }

    public var failureDescription: String? {
        self.invalidSlice.map {
            "contains '\($0)' (allowed: \(self.allowedCharacterString))"
        }
    }
}

// MARK: - Validators ([String])

extension Validator where T == [String] {
    public static var ascii: Validator { .characterSet(.ascii) }

    public static var alphanumeric: Validator { .characterSet(.alphanumerics) }

    public static func characterSet(_ characterSet: ValidationCharacterSet) -> Validator {
        .init { ValidatorResults.CollectionCharacterSet(strings: $0, characterSet: characterSet) }
    }
}

extension ValidatorResults {
    /// Result of a validator checking that every element of a `[String]`
    /// contains only allowed characters.
    public struct CollectionCharacterSet {
        public let strings: [String]
        public let characterSet: ValidationCharacterSet

        var invalidRanges: [(Int, Swift.Range<String.Index>)] {
            self.strings.enumerated().compactMap { offset, string in
                let scalars = string.unicodeScalars
                guard let idx = scalars.firstIndex(where: { !self.characterSet.contains($0) }) else {
                    return nil
                }
                return (offset, idx ..< scalars.index(after: idx))
            }
        }

        var allowedCharacterString: String { self.characterSet.description }
    }
}

extension ValidatorResults.CollectionCharacterSet: ValidatorResult {
    public var isFailure: Bool { !self.invalidRanges.isEmpty }

    public var successDescription: String? {
        "contains only \(self.allowedCharacterString)"
    }

    public var failureDescription: String? {
        let disallowed = self.invalidRanges.map { offset, range in
            "string at index \(offset) contains '\(String(self.strings[offset][range]))'"
        }
        return "\(disallowed.joined(separator: ", ")) (allowed: \(self.allowedCharacterString))"
    }
}
