/// IMPORTANT:
///
/// These APIs are `internal` rather than `public` on purpose - specifically due to the high risk of name collisions
/// in the extensions and the extreme awkwardness of vendor prefixing for this use case.

import struct Foundation.Data

internal enum Base32 {
    static let baseAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    static let baseIgnores = Set<Character>([" ", "-", "\t", "\r", "\n"])

    /// Corresponds to Base32 as implemented by the C code that was previously used for this functionality.
    /// Tolerates certain commonly mistyped characters, ignores whitespace and hyphens, is case-insensitive, and does not use padding.
    static let `default`: BaseNInstance = {
        var reverse = [Character: UInt16]()
        
        // N.B.: Matches the old C implementation's handling for lowercase and the characters zero, one, and eight.
        Self.baseAlphabet.enumerated().forEach {
            reverse[$1] = numericCast($0)
            reverse[$1.uppercased().first!] = numericCast($0)
        }
        reverse["0"] = reverse["O"]
        reverse["1"] = reverse["L"]
        reverse["8"] = reverse["B"]
        return .init(bits: 5/*32.trailingZeroBitCount*/, lookupTable: .init(Self.baseAlphabet), reverseTable: reverse, reverseIgnores: Self.baseIgnores)
    }()

    /// A strict interpretation of Base32 (uppercase only, no whitespace tolerance, no special numeral handling, padding required).
    static let strict: BaseNInstance = {
        return .init(
            bits: 5/*32.trailingZeroBitCount*/,
            pad: "=",
            lookupTable: .init(Self.baseAlphabet),
            reverseTable: .init(uniqueKeysWithValues: Self.baseAlphabet.enumerated().map { ($1, numericCast($0)) }),
            reverseIgnores: Self.baseIgnores
        )
    }()
}

extension Array where Element == UInt8 {
    internal init?(base32: String) {
        guard let decoded = Base32.default.decodeString(base32) else { return nil }
        self = decoded
    }
    
    internal init?<S>(base32: S) where S: Sequence, S.Element == UInt8 {
        guard let decoded = Base32.default.decodeBytes(base32) else { return nil }
        self = decoded
    }
}

extension Sequence where Element == UInt8 {
    internal var base32Bytes: [UInt8] { Base32.default.encodeBytes(self) }
    internal var base32String: String { Base32.default.encodeString(self) }
}

extension StringProtocol {
    internal var base32Bytes: [UInt8] { self.utf8.base32Bytes }
    internal var base32String: String { self.utf8.base32String }
}

/// This API remains public because it already was at the time when this code was revised, so we're stuck with it.
extension Data {
    /// Backwards-compatibility wrapper for ``Array<UInt8>.init?(base32:)``
    public init?(base32Encoded: String) {
        guard let decoded = [UInt8].init(base32: base32Encoded) else { return nil }
        self.init(decoded)
    }

    /// Backwards-compatibility wrapper for ``Array<UInt8>.init?(base32:)``
    public init?(base32Encoded: Data) {
        guard let decoded = [UInt8].init(base32: base32Encoded) else { return nil }
        self.init(decoded)
    }

    /// Backwards-compatibility wrapper for ``Sequence.base32String``
    public func base32EncodedString() -> String { self.base32String }

    /// Backwards-compatibility wrapper for ``Sequence.base32Bytes``
    public func base32EncodedData() -> Data { .init(self.base32Bytes) }
}
