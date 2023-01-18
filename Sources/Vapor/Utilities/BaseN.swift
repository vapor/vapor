import Algorithms

/// IMPORTANT:
///
/// These APIs are `internal` rather than `public` on purpose - partially because using them correctly is non-trivial,
/// partially because the APIs that build on them are also non-`public` for their own reasons.

import struct Foundation.Data

public struct BaseNEncoding {
    /// For a given base and count, calculate the number of values needed to encode the given count of bytes.
    @inlinable
    internal static func sizeEnc(for bits: Int, count: Int) -> Int {
        let outputs = 8 >> bits.trailingZeroBitCount, inputs = bits >> bits.trailingZeroBitCount // number of output values per input bytes
        return ((count * outputs - 1) / inputs) + 1 // Integer divsion rounding away from zero
    }
    
    /// For a given base and count, calculate the number of bytes encoded by a given count of values. Does not
    /// compensate for padding or ignored values.
    @inlinable
    internal static func sizeDec(for bits: Int, count: Int) -> Int {
        let outputs = 8 >> bits.trailingZeroBitCount, inputs = bits >> bits.trailingZeroBitCount // number of output values per input bytes
        return count * inputs / outputs
    }
    
    /// For a given base and count, assume the count is of encoded values and calculate the number of padding
    /// values, if any, that need to be added to result in an aligned value count.
    @inlinable
    internal static func padding(for bits: Int, count: Int) -> Int {
        let outputs = 8 >> bits.trailingZeroBitCount
        return (outputs - count) & (outputs - 1)
    }
    
    /// Fundamental encode: Transform any given byte sequence into a BaseN-encoded sequence of bytes described
    /// by a count of bits per input values and mapping table relating input bytes to output values. Each element
    /// of the output type describes N bits of input.
    @inlinable
    internal static func encode<C>(
        _ decoded: C, base bits: Int, pad: UInt8?, using table: [UInt8]
    ) -> [UInt8] where C: RandomAccessCollection, C.Element == UInt8, C.Index == Int {
        assert(table.count == (1 << bits), "Mapping table must have exactly \(1 << bits) elements.")
        guard !decoded.isEmpty else { return [] }
        
        let mask = (1 << bits) - 1, outlen = self.sizeEnc(for: bits, count: decoded.count), padding = self.padding(for: bits, count: outlen)
        
        return .init(unsafeUninitializedCapacity: outlen + padding) { p, n in
            var bufBits = 0, buf = 0
            
            for next in decoded {
                (buf, bufBits) = ((buf &<< 8) | Int(next), bufBits &+ 8)
                while bufBits >= bits { bufBits &-= bits; p[n] = table[(buf &>> bufBits) & mask]; n &+= 1 }
            }
            if padding > 0 {
                assert((1..<bits).contains(bufBits))
                p[n] = table[(buf &<< (bits &- bufBits)) & mask]; n &+= 1
                if let pad = pad { p.baseAddress!.advanced(by: n).assign(repeating: pad, count: padding); n &+= padding }
            }
        }
    }

    /// Fundamental decode: Transform any given byte sequence encoded with BaseN to an unencoded byte sequence,
    /// described by a table mapping input elements to output bytes. Each element of the input is assumed to
    /// describe N bits of output. A list of input elements to ignore may be provided. Inputs that are neither
    /// mapped nor ignored cause decoding to fail. If a pad is specified, the input must be correctly padded
    /// decoding will fail.
    @inlinable
    internal static func decode<C>(
        _ encoded: C, base bits: Int, using mapping: [UInt8], checkPad: Bool
    ) -> [UInt8]? where C: RandomAccessCollection, C.Element == UInt8, C.Index == Int {
        guard !encoded.isEmpty else { return [] }
        let outlen = self.sizeDec(for: bits, count: encoded.count)
        
        return try? [UInt8].init(unsafeUninitializedCapacity: outlen) { p, n in // N.B.: throwing is the only correct way to signal failure
            var buf = 0, bufBits = 0, seenPad = 0
            
            for next in encoded {
                switch mapping[numericCast(next)] {
                    case BaseNEncoding.ignoredByte: break
                    case BaseNEncoding.paddingByte: seenPad &+= 1
                    case BaseNEncoding.invalidByte,
                        _ where seenPad > 0: throw BreakLoopError()
                    case let moreBits:
                        (buf, bufBits) = ((buf &<< bits) | Int(truncatingIfNeeded: moreBits), bufBits &+ bits)
                        while bufBits >= 8 { bufBits &-= 8; (p[n], n) = (UInt8(truncatingIfNeeded: buf &>> bufBits), n &+ 1) }
                }
            }
            guard !checkPad || seenPad == self.padding(for: bits, count: self.sizeEnc(for: bits, count: n)) else { throw BreakLoopError() } // require exact padding
            guard bufBits == 0 || (buf & ((1 &<< bufBits) &- 1)) == 0 else { throw BreakLoopError() } // require pad bits to be zero per spec
        }
    }
    
    @usableFromInline
    internal struct BreakLoopError: Error { @inlinable internal init() {} }
    
    // N.B.: The values used for the invalid and padding byte representations are not arbitrarily chosen; they are
    // intended to be used in optimized versions of the algorithm to quickly distinguish the vairous cases.
    
    @usableFromInline
    internal static var invalidByte: UInt8 { 0b1111_1111 } // All bits set
    @usableFromInline
    internal static var ignoredByte: UInt8 { 0b1111_1110 } // All but lowest bit set
    @usableFromInline
    internal static var paddingByte: UInt8 { 0b1000_0000 } // Only high bit set

    public let bits: Int
    
    @usableFromInline
    internal let pad: UInt8?
    @usableFromInline
    internal let lookupTable: [UInt8]
    @usableFromInline
    internal let reverseTable: [UInt8]
    @usableFromInline
    internal let ignores: Set<UInt8>

    internal init(bits: Int, pad: UInt8? = nil, lookupTable: [UInt8], reverseTable: [UInt8: UInt8]? = nil, ignores: Set<UInt8> = []) {
        assert(bits > 0 && bits < 8, "Encoded bits must be between 1 and 7")
        assert(lookupTable.count == (1 << bits), "lookup table must be \(bits) chars")
        assert(Array(lookupTable.uniqued()) == lookupTable, "lookup table must not contain duplicates")
        
        let reverseTable = reverseTable ?? .init(uniqueKeysWithValues: lookupTable.indexed().map { ($1, numericCast($0)) })

        assert(Set(lookupTable).subtracting(reverseTable.keys).isEmpty, "reverse table must contain all forward table entries")
        assert(reverseTable.values.allSatisfy { $0 < (1 << bits) } , "reverse table must not contain out of range values")
        assert(pad.map { !reverseTable.keys.contains($0) } ?? true, "reverse table must not contain the padding byte")
        
        let realReverseTable = (UInt8.min ... .max).map { v -> UInt8 in
            if let b = reverseTable[v] { return b }
            else if ignores.contains(v) { return BaseNEncoding.ignoredByte }
            else if pad == v  { return BaseNEncoding.paddingByte }
            else { return BaseNEncoding.invalidByte }
        }
        
        self.bits = bits
        self.pad = pad
        self.lookupTable = lookupTable
        self.reverseTable = realReverseTable
        self.ignores = ignores
    }
    
    internal init(bits: Int, pad: Character? = nil, lookupTable: [Character], reverseTable: [Character: UInt8]? = nil, ignores: Set<Character> = []) {
        assert(pad?.isASCII ?? true, "pad must be ASCII if specified")
        assert(lookupTable.allSatisfy(\.isASCII), "lookup table must contain only ASCII characters")
        assert(reverseTable?.keys.allSatisfy(\.isASCII) ?? true, "reverse table can not contain non-ASCII lookup characters")
        assert(ignores.allSatisfy(\.isASCII), "ignored set must contain only ASCII characters")
        
        self.init(
            bits: bits,
            pad: pad.map(\.asciiValue!),
            lookupTable: lookupTable.map(\.asciiValue!),
            reverseTable: reverseTable.map { .init(uniqueKeysWithValues: $0.map { ($0.asciiValue!, $1) }) },
            ignores: .init(ignores.map(\.asciiValue!))
        )
    }
    
    // Generic byte collection interfaces
    
    @inlinable
    public func encode<C>(_ decoded: C) -> [UInt8] where C: RandomAccessCollection, C.Element == UInt8, C.Index == Int {
        switch self.bits {
        case 5: return BaseNEncoding.encode32(decoded, pad: self.pad, using: self.lookupTable)
        case 6: return BaseNEncoding.encode64(decoded, pad: self.pad, using: self.lookupTable)
        case let n: return BaseNEncoding.encode(decoded, base: n, pad: self.pad, using: self.lookupTable)
        }
    }
    
    @inlinable
    public func decode<C>(_ encoded: C) -> [UInt8]? where C: RandomAccessCollection, C.Element == UInt8, C.Index == Int {
        switch self.bits {
        case 6 where encoded.count > 512 && self.ignores.isEmpty: return BaseNEncoding.decode64(encoded, using: self.reverseTable)
        case let n: return BaseNEncoding.decode(encoded, base: n, using: self.reverseTable, checkPad: self.pad != nil)
        }
    }
}
