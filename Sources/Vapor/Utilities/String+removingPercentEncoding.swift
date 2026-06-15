#if canImport(FoundationEssentials)
extension String {
    var removingPercentEncoding: String? {
        let source = self.utf8
        var bytes: [UInt8] = []
        bytes.reserveCapacity(source.count)

        var i = source.startIndex
        let end = source.endIndex
        while i < end {
            let byte = source[i]
            if byte == 0x25 { // '%'
                let j = source.index(after: i)
                guard j < end else { return nil }
                let k = source.index(after: j)
                guard 
                    k < end,
                    let hi = Self.hexNibble(source[j]),
                    let lo = Self.hexNibble(source[k])
                else { return nil }
                bytes.append((hi << 4) | lo)
                i = source.index(after: k)
            } else {
                bytes.append(byte)
                i = source.index(after: i)
            }
        }
        return String(validating: bytes, as: UTF8.self)
    }

    private static func hexNibble(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 0x30...0x39: return byte - 0x30        // 0–9
        case 0x41...0x46: return byte - 0x41 + 10   // A–F
        case 0x61...0x66: return byte - 0x61 + 10   // a–f
        default: return nil
        }
    }
}
#endif
