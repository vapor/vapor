extension Collection where Element == UInt8 {
    public var hex: String {
        self.hexEncodedString()
    }

    public func hexEncodedString(uppercase: Bool = false) -> String {
        return String(decoding: self.hexEncodedBytes(uppercase: uppercase), as: Unicode.UTF8.self)
    }

    func hexEncodedBytes(uppercase: Bool = false) -> [UInt8] {
        var bytes = [UInt8]()
        bytes.reserveCapacity(count * 2)

        let table: [UInt8]
        if uppercase {
            table = radix16table_uppercase
        } else {
            table = radix16table_lowercase
        }

        for byte in self {
            bytes.append(table[Int(byte / 16)])
            bytes.append(table[Int(byte % 16)])
        }

        return bytes
    }
}

fileprivate let radix16table_uppercase: [UInt8] = [
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46
]

fileprivate let radix16table_lowercase: [UInt8] = [
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66
]
