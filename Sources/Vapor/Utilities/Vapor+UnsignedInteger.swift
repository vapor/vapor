extension UnsignedInteger {
    /*
     [0b1111_1011, 0b0000_1111]
     =>
     0b1111_1011_0000_1111
     */
    init(_ bytes: [Byte]) throws {
        // 8 bytes in UInt64
        guard bytes.count <= sizeof(Self) else {
            throw "626: WebSockets.Swift: UnsignedInteger"
        }
        var value: UIntMax = 0
        bytes.forEach { byte in
            value <<= 8 // 1 byte is 8 bits
            value |= byte.toUIntMax()
        }

        self.init(value)
    }

    func bytes() -> [Byte] {
        let byteMask: Self = 0b1111_1111
        let size = sizeof(Self)
        var copy = self
        var bytes: [Byte] = []
        (1...size).forEach { _ in
            let next = copy & byteMask
            let byte = Byte(next.toUIntMax())
            bytes.insert(byte, at: 0)
            copy.shiftRight(8)
        }
        return bytes
    }
}

extension UnsignedInteger {
    // TODO: not unit tested
    public func containsMask(_ mask: Self) -> Bool {
        return (self & mask) == mask
    }
}

extension UnsignedInteger {
    mutating func shiftRight(_ places: Int) {
        (1...places).forEach { _ in
            self /= 2
        }
    }
}

