/// IMPORTANT:
///
/// These APIs are `internal` rather than `public` on purpose - partially because using them correctly is non-trivial,
/// partially because the APIs that build on them are also non-`public` for their own reasons.

internal struct BaseN {
    /// For a given number of bits per encoded value, return the number of values to which encoded data must be padded
    /// in canonical form. The mathematical formulation of this value is admittedly not quite known to this author at
    /// the time of this writing - something about the next highest power of two which yields an integer power of two
    /// when divided by the bits per value - but it yields the correct answer nonetheless.
    private static func calculatePadMultiple(for bits: UInt) -> Int {
        return bits.nonzeroBitCount > 1 ? 1 << (3 - Int(bits).trailingZeroBitCount) : 1
    }

    /// Fundamental encode: Transform any given byte sequence into a BaseN-encoded sequence of a specific type
    /// described by a count of bits per input values and mapping table relating input bytes to elements of the
    /// output type. Each element of the output type describes N bits of input.
    internal static func encode<S: Sequence, R: RangeReplaceableCollection, T: RandomAccessCollection>(
        _ decoded: S,
        as _: R.Type = R.self,
        base elementBits: UInt,
        pad: R.Element?,
        using table: T
    ) -> R where S.Element == UInt8, T.Element == R.Element, T.Index: BinaryInteger {
        precondition(elementBits > 0 && elementBits < 8, "Bases less than 2 or greater than 128 are not supported.")
        assert(table.count == (1 << elementBits), "Mapping table must have exactly \(1 << elementBits) elements.")
        
        var encoded = R.init(), iter = decoded.makeIterator(), bufBits = 0 as UInt, buf = 0 as UInt16
        let mask = ((1 as UInt16) << elementBits) - 1
        let padMultiple = self.calculatePadMultiple(for: elementBits)
        
        while let next = iter.next() {
            (buf, bufBits) = ((buf << 8) | numericCast(next), bufBits + 8)
            while bufBits >= elementBits {
                bufBits -= elementBits
                encoded.append(table[numericCast((buf >> bufBits) & mask)])
            }
        }
        if bufBits > 0 {
            encoded.append(table[numericCast((buf << (elementBits - bufBits)) & mask)])
        }
        if let pad = pad, padMultiple > 1, let remainder = Int?.some(encoded.count & (padMultiple - 1)), remainder != 0 {
            encoded.append(contentsOf: repeatElement(pad, count: padMultiple - remainder))
        }
        return encoded
    }

    /// Fundamental decode: Transform any given sequence of input elements into a byte sequence, described by a
    /// table mapping input elements to output bytes. Each element of the input is assumed to describe N bits of
    /// output. A set of input elements to ignore may be provided. Inputs that are neither mapped nor ignored
    /// cause decoding to fail. Excess bits of input are ignored.
    internal static func decode<S: Sequence>(
        _ encoded: S,
        base elementBits: UInt,
        pad: S.Element?,
        using mapping: [S.Element: UInt16],
        ignores: Set<S.Element>
    ) -> [UInt8]? {
        precondition(elementBits > 0 && elementBits < 8, "Bases less than 2 or greater than 128 are not supported.")
        assert(mapping.count >= (1 << elementBits), "Mapping table must contain at least \(1 << elementBits) mappings.")
    
        var decoded = [UInt8](), iter = encoded.makeIterator(), bufBits = 0 as UInt, buf = 0 as UInt16

        while let c = iter.next() {
            guard !ignores.contains(c) else { continue }
            if c == pad {
                while let d = iter.next() { guard d == pad else { return nil } } // Non-pad after seeing pad is invalid input
                break
            }
            guard let i = mapping[c] else { return nil } // Checked separately so invalid input is treated as decode failure
            (buf, bufBits) = ((buf << elementBits) | i, bufBits + elementBits)
            assert(bufBits < buf.bitWidth)
            while bufBits >= 8 {
                bufBits -= 8
                decoded.append(numericCast((buf >> bufBits) & 0x00ff))
            }
        }
        // Excess buffered bits are ignored
        return decoded
    }
}

/// A convenience wrapper around the common logic used for BaseN coding in practice. Only supports `Sequence<UInt8>` and
/// `StringProtocol`, rather than the arbitrary sequence and collection types the baseline routines accept.
///
/// It is _strongly_ recommended that instances of this type be created statically and lazily, as the initialization is
/// relatively expensive. See the ``Base32`` and ``Base64`` enums for examples.
internal struct BaseNInstance {
    let bits: UInt
    let pad: Character?
    let bytePad: UInt8?
    let lookupTable: [Character]
    let byteLookupTable: [UInt8]
    let reverseTable: [Character: UInt16]
    let byteReverseTable: [UInt8: UInt16]
    let reverseIgnores: Set<Character>
    let byteReverseIgnores: Set<UInt8>

    init(bits: UInt, pad: Character? = nil, lookupTable: [Character], reverseTable: [Character: UInt16], reverseIgnores: Set<Character>) {
        assert(pad?.isASCII ?? true, "pad must be ASCII if specified")
        assert(lookupTable.count == (1 << bits), "lookup table must be \(bits) chars")
        assert(Set(lookupTable).count == lookupTable.count, "lookup table must not contain duplicates")
        assert(lookupTable.allSatisfy { $0.isASCII }, "lookup table must contain only ASCII characters")
        assert(lookupTable.allSatisfy { reverseTable.keys.contains($0) }, "reverse table must contain all forward table entries")
        assert(reverseTable.values.allSatisfy { $0 < (1 << bits) } , "reverse table must not contain out of range values")
        
        self.bits = bits
        
        self.pad = pad
        self.bytePad = pad.flatMap(\.asciiValue)
        
        self.lookupTable = lookupTable
        self.byteLookupTable = lookupTable.map { $0.asciiValue! }

        self.reverseTable = reverseTable
        self.byteReverseTable = .init(reverseTable.compactMap { k, v in k.asciiValue.map { ($0, v) } }, uniquingKeysWith: { $1 })

        self.reverseIgnores = reverseIgnores
        self.byteReverseIgnores = .init(reverseIgnores.compactMap(\.asciiValue))
    }

    public func encodeString<S: Sequence>(_ decoded: S) -> String where S.Element == UInt8 {
        return BaseN.encode(decoded, base: self.bits, pad: self.pad, using: self.lookupTable)
    }

    public func encodeBytes<S: Sequence>(_ decoded: S) -> [UInt8] where S.Element == UInt8 {
        return BaseN.encode(decoded, base: self.bits, pad: self.bytePad, using: self.byteLookupTable)
    }
    
    public func decodeString<S: StringProtocol>(_ encoded: S) -> [UInt8]? {
        return BaseN.decode(encoded, base: self.bits, pad: self.pad, using: self.reverseTable, ignores: self.reverseIgnores)
    }
    
    public func decodeBytes<S: Sequence>(_ encoded: S) -> [UInt8]? where S.Element == UInt8 {
        return BaseN.decode(encoded, base: self.bits, pad: self.bytePad, using: self.byteReverseTable, ignores: self.byteReverseIgnores)
    }
}
