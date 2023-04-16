/// IMPORTANT:
///
/// These APIs are `internal` rather than `public` on purpose - specifically due to the high risk of name collisions
/// in the extensions and the extreme awkwardness of vendor prefixing for this use case.

import struct Foundation.Data

extension BaseNEncoding {
    /// Specialization of ``encode(_:base:pad:using:)`` for Base32.
    @inlinable
    internal static func encode32<C>(_ decoded: C, pad: UInt8?, using tab: [UInt8]) -> [UInt8] where C: RandomAccessCollection, C.Element == UInt8, C.Index == Int {
        assert(tab.count == 32, "Mapping table must have exactly 32 elements.")
        guard !decoded.isEmpty else { return [] }
        let outlen = sizeEnc(for: 5, count: decoded.count), padding = self.padding(for: 5, count: outlen), inp = decoded
        
        return .init(unsafeUninitializedCapacity: outlen + padding) { p, n in
            var idx = inp.startIndex, b00 = 0, b01 = 0; func get(_ offset: Int) -> Int { Int(truncatingIfNeeded: inp[idx &+ offset]) }
            while inp.endIndex &- idx >= 5 {
                let b0 = get(0), b1 = get(1), b2 = get(2), b3 = get(3), b4 = get(4)
                
                p[n &+ 0] = tab[((b0 & 0xf8) &>> 3)             ]; p[n &+ 1] = tab[((b0 & 0x07) &<< 2) | (b1 &>> 6)]
                p[n &+ 2] = tab[((b1 & 0x3e) &>> 1)             ]; p[n &+ 3] = tab[((b1 & 0x01) &<< 4) | (b2 &>> 4)]
                p[n &+ 4] = tab[((b2 & 0x0f) &<< 1) | (b3 &>> 7)]; p[n &+ 5] = tab[((b3 & 0x7c) &>> 2)             ]
                p[n &+ 6] = tab[((b3 & 0x03) &<< 3) | (b4 &>> 5)]; p[n &+ 7] = tab[((b4 & 0x1f)      )             ]
                (idx, n) = (idx &+ 5, n &+ 8)
            }
            switch padding {
                case 1: (b01, b00) = (b00, get(3)); p[n &+ 6] = tab[((b00 & 0x03) &<< 3)              ]; p[n &+ 5] = tab[(b00 & 0x7c) &>> 2]; fallthrough
                case 3: (b01, b00) = (b00, get(2)); p[n &+ 4] = tab[((b00 & 0x0f) &<< 1) | (b01 &>> 7)]                                   ; fallthrough
                case 4: (b01, b00) = (b00, get(1)); p[n &+ 3] = tab[((b00 & 0x01) &<< 4) | (b01 &>> 4)]; p[n &+ 2] = tab[(b00 & 0x3e) &>> 1]; fallthrough
                case 6: (b01, b00) = (b00, get(0)); p[n &+ 1] = tab[((b00 & 0x07) &<< 2) | (b01 &>> 6)]; p[n &+ 0] = tab[(b00 & 0xf8) &>> 3]
                case 0: return; default: fatalError("unreachable")
            }
            n &+= 8 &- padding
            if let pad = pad, padding > 0 {
                let pn = p.baseAddress!.advanced(by: n)
#if swift(<5.8)
                pn.assign(repeating: pad, count: padding)
#else
                pn.update(repeating: pad, count: padding)
#endif
                n &+= padding
            }
        }
    }
}

public enum Base32: Sendable {
    private static let baseAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

    /// Corresponds to Base32 as implemented by the C code that was previously used for this functionality.
    /// Certain commonly mistyped characters are treated as their visual equivalents, whitespace and hyphens
    /// are ignored, and decoding is case-insensitive.
    ///
    /// [RFC 4648 § 3.3](https://datatracker.ietf.org/doc/html/rfc4648#section-3.3) correctly considers the
    /// semantics provided by this form of Base32 insecure (in short, it permits multiple easily-exploited
    /// side channels). The public APIs below unfortunately have to use these semantics to remain consistent
    /// with the previous implementation.
    public static let relaxed: BaseNEncoding = {
        var reverse = [Character: UInt8]()
        
        Self.baseAlphabet.enumerated().forEach {
            reverse[$1] = numericCast($0)
            reverse[$1.uppercased().first!] = numericCast($0)
        }
        reverse["0"] = reverse["O"]
        reverse["1"] = reverse["L"]
        reverse["8"] = reverse["B"]
        return .init(
            bits: 5,
            lookupTable: .init(Self.baseAlphabet),
            reverseTable: reverse,
            ignores: [" ", "-", "\t", "\r", "\n"]
        )
    }()

    /// Corresponds to canonical Base32, per [RFC 4648 § 6](https://datatracker.ietf.org/doc/html/rfc4648#section-6).
    /// No non-alphabet characters are permitted, padding is required, and the alphabet is uppercase.
    public static let canonical: BaseNEncoding = .init(
        bits: 5,
        pad: "=",
        lookupTable: .init(Self.baseAlphabet)
    )
    
    /// Alias for ``canonical``.
    public static let `default`: BaseNEncoding = Self.canonical
    
    /// Identical to ``canonical``, except the alphabet is lowercase.
    public static let lowercasedCanonical: BaseNEncoding = .init(
        bits: 5,
        pad: "=",
        lookupTable: .init(Self.baseAlphabet.lowercased())
    )
}

extension Array where Element == UInt8 {
    /// Decode a string in canonical Base32-encoded representation.
    @inlinable
    public init?(decodingBase32 str: String) {
        guard let decoded = str.utf8.withContiguousStorageIfAvailable({ Array(decodingBase32: $0) }) ?? Array(decodingBase32: Array(str.utf8))
        else { return nil }
        self = decoded
    }
    
    @inlinable
    public init?<C>(decodingBase32 bytes: C) where C: RandomAccessCollection, C.Element == UInt8, C.Index == Int {
        guard let decoded = Base32.default.decode(bytes) else { return nil }
        self = decoded
    }
}

extension RandomAccessCollection where Element == UInt8, Index == Int {
    @inlinable
    public func base32Bytes() -> [UInt8] { Base32.default.encode(self) }

    @inlinable
    public func base32String() -> String { .init(decoding: self.base32Bytes(), as: Unicode.ASCII.self) }
}

extension String {
    @inlinable
    public func base32Bytes() -> [UInt8] { self.utf8.withContiguousStorageIfAvailable { $0.base32Bytes() } ?? Array(self.utf8).base32Bytes() }

    @inlinable
    public func base32String() -> String { .init(decoding: self.base32Bytes(), as: Unicode.ASCII.self) }
}

extension Substring {
    @inlinable
    public func base32Bytes() -> [UInt8] { self.utf8.withContiguousStorageIfAvailable { $0.base32Bytes() } ?? Array(self.utf8).base32Bytes() }

    @inlinable
    public func base32String() -> String { .init(decoding: self.base32Bytes(), as: Unicode.ASCII.self) }
}

/// This API remains public because it already was at the time when this code was revised, so we're stuck with it.
extension Data {
    /// Decodes a relaxed-Base32-encoded `String`. Returns `nil` if the input is not valid relaxed-Base32.
    @inlinable
    public init?(base32Encoded str: String) {
        guard let decoded = str.utf8.withContiguousStorageIfAvailable({ Base32.relaxed.decode($0) }) ?? Base32.relaxed.decode(Array(str.utf8))
        else { return nil }
        self.init(decoded)
    }

    /// Decodes relaxed-Base32-encoded `Data`. Returns `nil` if the input is not valid relaxed-Base32.
    @inlinable
    public init?(base32Encoded: Data) {
        guard let decoded = Base32.relaxed.decode(base32Encoded) else { return nil }
        self.init(decoded)
    }

    /// Return this `Data` encoded with relaxed-Base32 as a `String`.
    @inlinable
    public func base32EncodedString() -> String { .init(decoding: Base32.relaxed.encode(self), as: Unicode.ASCII.self) }

    /// Return this `Data` encoded with relaxed-Base32 as `Data`.
    @inlinable
    public func base32EncodedData() -> Data { .init(Base32.relaxed.encode(self)) }
}
