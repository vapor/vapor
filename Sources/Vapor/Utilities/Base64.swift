/// IMPORTANT:
///
/// These APIs are `internal` rather than `public` on purpose - specifically due to the high risk of name collisions
/// in the extensions and the extreme awkwardness of vendor prefixing for this use case.

import struct Foundation.Data

extension BaseNEncoding {
    /// Specialization of ``encode(_:base:pad:using:)`` for Base64.
    @inlinable
    internal static func encode64<C>(_ decoded: C, pad: UInt8?, using tab: [UInt8]) -> [UInt8] where C: RandomAccessCollection, C.Element == UInt8, C.Index == Int {
        assert(tab.count == 64, "Mapping table must have exactly 64 elements.")
        guard !decoded.isEmpty else { return [] }
        let outlen = sizeEnc(for: 6, count: decoded.count), padding = self.padding(for: 6, count: outlen), inp = decoded
        
        return .init(unsafeUninitializedCapacity: outlen + padding) { p, n in
            var idx = inp.startIndex, b00 = 0, b01 = 0; func get(_ offset: Int) -> Int { Int(truncatingIfNeeded: inp[idx &+ offset]) }
            while inp.endIndex &- idx >= 3 {
                let b0 = get(0), b1 = get(1), b2 = get(2)
                p[n &+ 0] = tab[((b0 & 0xfc) &>> 2)             ]; p[n &+ 1] = tab[((b0 & 0x03) &<< 4) | (b1 &>> 4)]
                p[n &+ 2] = tab[((b1 & 0x0f) &<< 2) | (b2 &>> 6)]; p[n &+ 3] = tab[((b2 & 0x3f)      )             ]
                (idx, n) = (idx &+ 3, n &+ 4)
            }
            switch padding {
                case 1: b01 = get(1); p[n &+ 2] = tab[((b01 & 0x0f) &<< 2)              ]; fallthrough
                case 2: b00 = get(0); p[n &+ 1] = tab[((b00 & 0x03) &<< 4) | (b01 &>> 4)]
                                      p[n &+ 0] = tab[((b00 & 0xfc) &>> 2)              ]
                case 0: return; default: fatalError("unreachable")
            }
            n &+= 4 &- padding
            if let pad = pad, padding > 0 { p.baseAddress!.advanced(by: n).assign(repeating: pad, count: padding); n &+= padding }
        }
    }

    /// Specialization of ``decode(_:base:using:)`` for Base64 with no ignores and optional padding.
    @inlinable
    internal static func decode64<C>(_ encoded: C, using mapping: [UInt8]) -> [UInt8]?
        where C: RandomAccessCollection, C.Element == UInt8, C.Index == Int
    {
        guard !encoded.isEmpty else { return [] }
        let outlen = self.sizeDec(for: 6, count: encoded.count)
        
        return try? [UInt8].init(unsafeUninitializedCapacity: outlen) { p, n in // N.B.: throwing is the only correct way to signal failure
            var idx = encoded.startIndex, w = 0 as UInt32
            func get(_ offset: Int) -> UInt32 { UInt32(truncatingIfNeeded: mapping[Int(truncatingIfNeeded: encoded[idx &+ offset])]) &<< (24 &- (offset &<< 3)) }
            while encoded.endIndex &- idx >= 4 {
                w = get(0) | get(1) | get(2) | get(3)
                if w & 0b11000000_11000000_11000000_11000000 == 0 {
                    p[n &+ 0] = UInt8(truncatingIfNeeded: (w &>> 22) | ((w &>> 20) & 0x3))
                    p[n &+ 1] = UInt8(truncatingIfNeeded: ((w &>> 12) & 0xf0) | ((w &>> 10) & 0x0f))
                    p[n &+ 2] = UInt8(truncatingIfNeeded: ((w &>>  2) & 0xc0) | (w & 0x3f))
                    (n, idx) = (n &+ 3, idx &+ 4)
                } else if w & 0b11000000_11000000_11000000_11000000 == 0b00000000_00000000_00000000_10000000, idx &+ 4 == encoded.endIndex {
                    p[n &+ 0] = UInt8(truncatingIfNeeded: (w &>> 22) | ((w &>> 20) & 0x3))
                    p[n &+ 1] = UInt8(truncatingIfNeeded: ((w &>> 12) & 0xf0) | ((w &>> 10) & 0x0f))
                    (n, idx) = (n &+ 2, idx &+ 4)
                } else if w & 0b11000000_11000000_11000000_11000000 == 0b00000000_00000000_10000000_10000000, idx &+ 4 == encoded.endIndex {
                    p[n &+ 0] = UInt8(truncatingIfNeeded: (w &>> 22) | ((w &>> 20) & 0x3))
                    (n, idx) = (n &+ 1, idx &+ 4)
                } else {
                    throw BreakLoopError()
                }
            }
            switch encoded.endIndex &- idx {
                case 3:
                    w = get(0) | get(1) | get(2)
                    guard w & 0b11000000_11000000_11000000_11111111 == 0 else { throw BreakLoopError() }
                    p[n &+ 0] = UInt8(truncatingIfNeeded: (w &>> 22) | ((w &>> 20) & 0x3))
                    p[n &+ 1] = UInt8(truncatingIfNeeded: ((w &>> 12) & 0xf0) | ((w &>> 10) & 0x0f))
                    n &+= 2
                case 2:
                    w = get(0) | get(1)
                    guard w & 0b11000000_11000000_11111111_11111111 == 0 else { throw BreakLoopError() }
                    p[n &+ 0] = UInt8(truncatingIfNeeded: (w &>> 22) | ((w &>> 20) & 0x3))
                    n &+= 1
                case 0:
                    break
                default: throw BreakLoopError()
            }
        }
    }
}

public enum Base64 {
    private static let baseAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    /// Canonical Base64 encoding per [RFC 4648 §4](https://datatracker.ietf.org/doc/html/rfc4648#section-4)
    public static let canonical: BaseNEncoding = .init(
        bits: 6/*64.trailingZeroBitCount*/,
        pad: "=",
        lookupTable: .init(Self.baseAlphabet)
    )
    
    /// Alias for ``canonical``.
    public static let `default`: BaseNEncoding = Self.canonical
    
    /// The variant Base64 encoding used by BCrypt, using `.` instead of `/` for value 62 and ignoring padding.
    public static let bcrypt: BaseNEncoding = .init(
        bits: 6/*64.trailingZeroBitCount*/,
        lookupTable: Self.baseAlphabet.map { $0 == "+" ? "." : $0 }
    )
}

extension Array where Element == UInt8 {
    /// Decode a string in canonical Base32-encoded representation.
    @inlinable
    public init?(decodingBase64 str: String) {
        guard let decoded = str.utf8.withContiguousStorageIfAvailable({ Array(decodingBase64: $0) }) ?? Array(decodingBase64: Array(str.utf8)) else { return nil }
        self = decoded
    }
    
    /// Decode a string in Bcrypt-flavored Base64-encoded representation.
    @inlinable
    public init?(decodingBcryptBase64 str: String) {
        guard let decoded = str.utf8.withContiguousStorageIfAvailable({ Array(decodingBcryptBase64: $0) }) ?? Array(decodingBcryptBase64: Array(str.utf8)) else { return nil }
        self = decoded
    }
    
    @inlinable
    public init?<C>(decodingBase64 bytes: C) where C: RandomAccessCollection, C.Element == UInt8, C.Index == Int {
        guard let decoded = Base64.default.decode(bytes) else { return nil }
        self = decoded
    }

    @inlinable
    public init?<C>(decodingBcryptBase64 bytes: C) where C: RandomAccessCollection, C.Element == UInt8, C.Index == Int {
        guard let decoded = Base64.bcrypt.decode(bytes) else { return nil }
        self = decoded
    }
}

extension RandomAccessCollection where Element == UInt8, Index == Int {
    @inlinable
    public func base64Bytes() -> [UInt8] { Base64.default.encode(self) }
    @inlinable
    public func base64String() -> String { .init(decoding: self.base64Bytes(), as: Unicode.ASCII.self) }

    @inlinable
    public func bcryptBase64Bytes() -> [UInt8] { Base64.bcrypt.encode(self) }
    @inlinable
    public func bcryptBase64String() -> String { .init(decoding: self.bcryptBase64Bytes(), as: Unicode.ASCII.self) }
}

extension String {
    @inlinable
    public func base64Bytes() -> [UInt8] { self.utf8.withContiguousStorageIfAvailable { $0.base64Bytes() } ?? Array(self.utf8).base64Bytes() }
    @inlinable
    public func base64String() -> String { .init(decoding: self.base64Bytes(), as: Unicode.ASCII.self) }

    @inlinable
    public func bcryptBase64Bytes() -> [UInt8] { self.utf8.withContiguousStorageIfAvailable { $0.bcryptBase64Bytes() } ?? Array(self.utf8).bcryptBase64Bytes() }
    @inlinable
    public func bcryptBase64String() -> String { .init(decoding: self.bcryptBase64Bytes(), as: Unicode.ASCII.self) }
}

extension Substring {
    @inlinable
    public func base64Bytes() -> [UInt8] { self.utf8.withContiguousStorageIfAvailable { $0.base64Bytes() } ?? Array(self.utf8).base64Bytes() }
    @inlinable
    public func base64String() -> String { .init(decoding: self.base64Bytes(), as: Unicode.ASCII.self) }

    @inlinable
    public func bcryptBase64Bytes() -> [UInt8] { self.utf8.withContiguousStorageIfAvailable { $0.bcryptBase64Bytes() } ?? Array(self.utf8).bcryptBase64Bytes() }
    @inlinable
    public func bcryptBase64String() -> String { .init(decoding: self.bcryptBase64Bytes(), as: Unicode.ASCII.self) }
}
