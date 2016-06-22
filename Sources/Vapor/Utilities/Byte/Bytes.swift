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
        string. Courtesy of Socks by @czechboy0
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
    var hexInt: Int? {
        var int: Int = 0

        for byte in self {
            int = int * 16

            if byte >= .zero && byte <= .nine {
                int += Int(byte - .zero)
            } else if byte >= .A && byte <= .F {
                int += Int(byte - .A) + 10
            } else if byte >= .a && byte <= .f {
                int += Int(byte - .a) + 10
            } else {
                return nil
            }
        }

        return int
    }

    /**
        Converts a byte representation
        of a decimal value into an `Int`.
    */
    var decimalInt: Int? {
        var int: Int = 0

        for byte in self {
            int = int * 10

            if byte >= .zero && byte <= .nine {
                int += Int(byte - .zero)
            } else {
                return nil
            }
        }

        return int
    }

    /**
        Transforms anything between Byte.A ... Byte.Z
        into the range Byte.a ... Byte.z
     */
    var lowercased: Data {
        var data = Data()

        for byte in self {
            if (.A ... .Z).contains(byte) {
                data.append(byte + (.a - .A))
            } else {
                data.append(byte)
            }
        }

        return data
    }

    /**
        Transforms anything between Byte.a ... Byte.z
        into the range Byte.A ... Byte.Z
    */
    var uppercased: Bytes {
        var bytes = Bytes()

        for byte in self {
            if (.a ... .z).contains(byte) {
                bytes.append(byte - (.a - .A))
            } else {
                bytes.append(byte)
            }
        }

        return bytes
    }
}


extension Byte {
    /**
        Defines the `crlf` used to denote
        line breaks in HTTP.
     */
    static let crlf: Bytes = [
        .carriageReturn,
        .newLine
    ]
}

extension Array where Element: Hashable {
    /**
        This function is intended to be as performant as possible, which is part of the reason
        why some of the underlying logic may seem a bit more tedious than is necessary
    */
    func trimmed(_ elements: [Element]) -> SubSequence {
        guard !isEmpty else { return [] }

        let lastIdx = self.count - 1
        var leadingIterator = self.indices.makeIterator()
        var trailingIterator = leadingIterator

        var leading = 0
        var trailing = lastIdx
        while let next = leadingIterator.next() where elements.contains(self[next]) {
            leading += 1
        }
        while let next = trailingIterator.next() where elements.contains(self[lastIdx - next]) {
            trailing -= 1
        }

        return self[leading...trailing]
    }
}
