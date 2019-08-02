internal struct Base64 {
    let lookupTable: [Character]

    init(lookupTable: String) {
        self.lookupTable = .init(lookupTable)
        assert(self.lookupTable.count == 64, "lookup table must be 64 chars")
    }

    public static var bcrypt: Base64 {
        return .init(lookupTable: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789./")
    }

    public func encode(_ decoded: [UInt8]) -> String {
        var encoded = ""
        func push(_ code: UInt8) {
            encoded.append(self.lookupTable[numericCast(code)])
        }

        var iterator = decoded.makeIterator()
        while let one = iterator.next() {
            push((one & 0b11111100) >> 2)
            if let two = iterator.next() {
                if let three = iterator.next() {
                    push(((one & 0b00000011) << 4) | ((two & 0b11110000) >> 4))
                    push(((two & 0b00001111)) << 2 | ((three & 0b11000000)) >> 6)
                    push(three & 0b00111111)
                } else {
                    push(((one & 0b00000011) << 4) | ((two & 0b11110000) >> 4))
                    push((two & 0b00001111) << 2)
                }
            } else {
                push((one & 0b00000011) << 4)
            }
        }
        return encoded
    }

    public func decode(_ encoded: String) -> [UInt8]? {
        var decoded = [UInt8]()

        func index(_ char: Character) -> UInt8? {
            guard let index = self.lookupTable.firstIndex(of: char) else {
                return nil
            }
            return numericCast(index)
        }

        var iterator = encoded.makeIterator()
        while let one = iterator.next() {
            if let two = iterator.next() {
                guard let a = index(one), let b = index(two) else {
                    return nil
                }
                decoded.append(((a & 0b00111111) << 2) | ((b & 0b00110000) >> 4))

                if let three = iterator.next() {
                    guard let c = index(three) else {
                        return nil
                    }
                    decoded.append(((b & 0b00001111) << 4) | ((c & 0b00111100) >> 2))

                    if let four = iterator.next() {
                        guard let d = index(four) else {
                            return nil
                        }
                        decoded.append(((c & 0b00000011) << 6) | ((d & 0b00111111)))
                    }
                }
            }
        }

        return decoded
    }
}
