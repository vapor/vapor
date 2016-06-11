public typealias Bytes = [Byte]

extension Int {
    var hex: String {
        return String(self, radix: 16).uppercased()
    }
}

extension String {
    var bytes: Bytes {
        return utf8.array
    }
}

extension String {
    var bytesSlice: BytesSlice {
        return BytesSlice(utf8)
    }
}

func +=(lhs: inout Bytes, rhs: Byte) {
    lhs.append(rhs)
}

func ~=(pattern: Bytes, value: Bytes) -> Bool {
    return pattern == value
}

extension Sequence where Iterator.Element == Byte {
    /**
        Converts a slice of bytes to
        string. Courtesy of Socks by @Czechboy0
    */
    public var string: String {
        var utf = UTF8()
        var gen = makeIterator()
        var str = String()
        while true {
            switch utf.decode(&gen) {
            case .emptyInput:
                return str
            case .error:
                break
            case .scalarValue(let unicodeScalar):
                str.append(unicodeScalar)
            }
        }
    }

    /**
        Converts a byte representation
        of a hex value into an `Int`.
    */
    var int: Int {
        var int: Int = 0

        for byte in self {
            int = int * 10

            if byte >= .zero && byte <= .nine {
                int += Int(byte - .zero)
            } else if byte >= .A && byte <= .F {
                int += Int(byte - .A) + 10
            } else if byte >= .a && byte <= .f {
                int += Int(byte - .a) + 10
            }
        }

        return int
    }
    
}
