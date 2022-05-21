/// IMPORTANT:
///
/// These APIs are `internal` rather than `public` on purpose - specifically due to the high risk of name collisions
/// in the extensions and the extreme awkwardness of vendor prefixing for this use case.

internal enum Base64 {
    static let baseAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    static let baseIgnores = Set<Character>()

    /// Canonical Base64 encoding per [RFC 4648 §4](https://datatracker.ietf.org/doc/html/rfc4648#section-4)
    static let canonical: BaseNInstance = {
        return .init(
            bits: 6/*64.trailingZeroBitCount*/,
            pad: "=",
            lookupTable: .init(Self.baseAlphabet),
            reverseTable: .init(uniqueKeysWithValues: Self.baseAlphabet.enumerated().map { ($1, numericCast($0)) }),
            reverseIgnores: Self.baseIgnores
        )
    }()
    
    /// The variant Base64 encoding used by BCrypt, using `.` instead of `/` for value 62 and ignoring padding.
    static let bcrypt: BaseNInstance = {
        let bcryptAlphabet = Self.baseAlphabet.map { $0 == "+" ? "." : $0 }
        
        return .init(
            bits: 6/*64.trailingZeroBitCount*/,
            lookupTable: bcryptAlphabet,
            reverseTable: .init(uniqueKeysWithValues: bcryptAlphabet.enumerated().map { ($1, numericCast($0)) }),
            reverseIgnores: Self.baseIgnores
        )
    }()
}

extension Array where Element == UInt8 {
    internal init?(base64: String) {
        guard let decoded = Base64.canonical.decodeString(base64) else { return nil }
        self = decoded
    }
    
    internal init?<S>(base64: S) where S: Sequence, S.Element == UInt8 {
        guard let decoded = Base64.canonical.decodeBytes(base64) else { return nil }
        self = decoded
    }

    internal init?(bcryptBase64: String) {
        guard let decoded = Base64.bcrypt.decodeString(bcryptBase64) else { return nil }
        self = decoded
    }
    
    internal init?<S>(bcryptBase64: S) where S: Sequence, S.Element == UInt8 {
        guard let decoded = Base64.bcrypt.decodeBytes(bcryptBase64) else { return nil }
        self = decoded
    }
}

extension Sequence where Element == UInt8 {
    internal var base64Bytes: [UInt8] { Base64.canonical.encodeBytes(self) }
    internal var base64String: String { Base64.canonical.encodeString(self) }

    internal var bcryptBase64Bytes: [UInt8] { Base64.bcrypt.encodeBytes(self) }
    internal var bcryptBase64String: String { Base64.bcrypt.encodeString(self) }
}

extension StringProtocol {
    internal var base64Bytes: [UInt8] { self.utf8.base64Bytes }
    internal var base64String: String { self.utf8.base64String }

    internal var bcryptBase64Bytes: [UInt8] { self.utf8.bcryptBase64Bytes }
    internal var bcryptBase64String: String { self.utf8.bcryptBase64String }
}
