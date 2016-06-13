extension Byte {
    /// '\t'
    static let horizontalTab: Byte = 0x9

    /// '\n'
    static let newLine: Byte = 0xA

    /// '\r'
    static let carriageReturn: Byte = 0xD

    /// ' '
    static let space: Byte = 0x20

    /// !
    static let exclamation: Byte = 0x21

    /// "
    static let quote: Byte = 0x22

    /// #
    static let numberSign: Byte = 0x23

    /// $
    static let dollar: Byte = 0x24

    /// %
    static let percent: Byte = 0x25

    /// &
    static let ampersand: Byte = 0x26

    /// '
    static let apostrophe: Byte = 0x27

    /// (
    static let leftParenthesis: Byte = 0x28

    /// )
    static let rightParenthesis: Byte = 0x29

    /// *
    static let asterisk: Byte = 0x2A

    /// +
    static let plus: Byte = 0x2B

    /// ,
    static let comma: Byte = 0x2C

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

    /// \
    static let backSlash: Byte = 0x5C

    /// ]
    static let rightSquareBracket: Byte = 0x5D

    /// _
    static let underscore: Byte = 0x5F

    /// a
    static let a: Byte = 0x61

    /// f
    static let f: Byte = 0x66

    /// z
    static let z: Byte = 0x7A

    /// ~
    static let tilda: Byte = 0x7E
}

func ~=(pattern: Byte, value: Byte) -> Bool {
    return pattern == value
}

extension Byte {
    var isWhitespace: Bool {
        return self == .space || self == .newLine || self == .carriageReturn || self == .horizontalTab
    }

    var isLetter: Bool {
        return (.a ... .z).contains(self) || (.A ... .Z).contains(self)
    }

    var isDigit: Bool {
        return (.zero ... .nine).contains(self)
    }

    var isAlphanumeric: Bool {
        return isLetter || isDigit
    }

    var isHexDigit: Bool {
        return (.zero ... .nine).contains(self) || (.A ... .F).contains(self) || (.a ... .f).contains(self)
    }
}
