extension Byte {
    static let forwardSlash: Byte = 0x2F // '/'
    static let atSign: Byte = 0x40 // '@'
    static let colon: Byte = 0x3A // ':'
    static let leftSquareBracket: Byte = 0x5B // '['
    static let rightSquareBracket: Byte = 0x5D // ']'
    static let period: Byte = 0x2E // '.' -- Full Stop
    static let questionMark: Byte = 0x3F // '?'
    static let numberSign: Byte = 0x23 // '#'
    static let percentSign: Byte = 0x25 // '%'
    static let plusSign: Byte = 0x2B // '+'
    static let minusSign: Byte = 0x2D // '-' -- Hyphen Minus
    static let zeroCharacter: Byte = 0x30
    static let space: Byte = 0x20
    static let carriageReturn: Byte = 0x0D
    static let lineFeed: Byte = 0x0A
    static let horizontalTab: Byte = 0x09
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
