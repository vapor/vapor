extension Byte {
    /// '\n'
    static let newLine: Byte = 0xA

    /// '\r'
    static let carriageReturn: Byte = 0xD

    /// ' '
    static let space: Byte = 0x20

    ///  '\n'
    static let lineFeed: Byte = 0x0A

    /// '\t'
    static let horizontalTab: Byte = 0x09

    /// #
    static let numberSign: Byte = 0x23

    /// %
    static let percent: Byte = 0x25

    /// &
    static let ampersand: Byte = 0x26

    /// +
    static let plus: Byte = 0x2B

    /// -
    static let hyphen: Byte = 0x2D

    /// .
    static let period: Byte = 0x2E

    /// /
    static let forwardSlash: Byte = 0x2F

    /// 0
    static let zero: Byte = 0x30

    /// 9
    static let nine: Byte = 0x39

    /// :
    static let colon: Byte = 0x3A

    /// ;
    static let semicolon: Byte = 0x3B

    /// =
    static let equals: Byte = 0x3D

    /// ?
    static let questionMark: Byte = 0x3F

    /// @
    static let at: Byte = 0x40

    /// A
    static let A: Byte = 0x41

    /// B
    static let B: Byte = 0x42

    /// C
    static let C: Byte = 0x43

    /// D
    static let D: Byte = 0x44

    /// E
    static let E: Byte = 0x45

    /// F
    static let F: Byte = 0x46

    /// Z
    static let Z: Byte = 0x5A

    /// [
    static let leftSquareBracket: Byte = 0x5B

    /// ]
    static let rightSquareBracket: Byte = 0x5D

    /// a
    static let a: Byte = 0x61

    /// f
    static let f: Byte = 0x66

    /// z
    static let z: Byte = 0x7A
}



extension Byte {
    var isWhitespace: Bool {
        let char = Character(self)
        switch char {
        case " ", "\n", "\r", "\t":
            return true
        default:
            return false
        }
    }
    var isLetter: Bool {
        let char = Character(self)
        switch char {
        case "a"..."z":
            return true
        case "A"..."Z":
            return true
        default:
            return false
        }
    }
    var isDigit: Bool {
        let char = Character(self)
        switch char {
        case "0"..."9":
            return true
        default:
            return false
        }
    }
    var isAlphanumeric: Bool {
        return isLetter || isDigit
    }
    var isHexDigit: Bool {
        let char = Character(self)
        switch char {
        case "a"..."f", "A"..."F", "0"..."9":
            return true
        default:
            return false
        }
    }
}


// MARK: Bytes

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
    var int: Int? {
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


// MARK: ByteSlice

public typealias BytesSlice = ArraySlice<Byte>

func ~=(pattern: Bytes, value: BytesSlice) -> Bool {
    return BytesSlice(pattern) == value
}

func ~=(pattern: BytesSlice, value: BytesSlice) -> Bool {
    return pattern == value
}
