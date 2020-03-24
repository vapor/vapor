extension Sequence where Element == UInt8 {
    public var hex: String {
        self.hexEncodedString()
    }

    public func hexEncodedString(uppercase: Bool = false) -> String {
        return String(decoding: self.hexEncodedBytes(uppercase: uppercase), as: Unicode.UTF8.self)
    }

    public func hexEncodedBytes(uppercase: Bool = false) -> [UInt8] {
        let table: [UInt8] = uppercase ? radix16table_uppercase : radix16table_lowercase
        var result: [UInt8] = []

        result.reserveCapacity(self.underestimatedCount * 2) // best guess
        return self.reduce(into: result) { output, byte in
            output.append(table[numericCast(byte / 16)])
            output.append(table[numericCast(byte % 16)])
        }
    }
}

extension Collection where Element == UInt8 {
    public func hexEncodedBytes(uppercase: Bool = false) -> [UInt8] {
        let table: [UInt8] = uppercase ? radix16table_uppercase : radix16table_lowercase
        
        return .init(unsafeUninitializedCapacity: self.count * 2) { buffer, outCount in
            for byte in self {
                let nibs = byte.quotientAndRemainder(dividingBy: 16)
                
                buffer[outCount + 0] = table[numericCast(nibs.quotient)]
                buffer[outCount + 1] = table[numericCast(nibs.remainder)]
                outCount += 2
            }
        }
    }
}

fileprivate let radix16table_uppercase: [UInt8] = [
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46
]

fileprivate let radix16table_lowercase: [UInt8] = [
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66
]
