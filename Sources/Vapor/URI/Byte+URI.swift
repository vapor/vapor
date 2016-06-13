
extension Byte {
    internal var isValidUriCharacter: Bool {
        return isUnreservedUriCharacter
            || isGeneralDelimiter
            || isSubDelimiter
            || self == .percent
    }
}

/*
    RESERVED CHARACTERS

    https://tools.ietf.org/html/rfc3986#section-2.2

        gen-delims  = ":" / "/" / "?" / "#" / "[" / "]" / "@"

        sub-delims  = "!" / "$" / "&" / "'" / "(" / ")"
                      "*" / "+" / "," / ";" / "="
*/
extension Byte {
    static let generalDelimiters: [Byte] = [
        .colon,
        .forwardSlash,
        .questionMark,
        .numberSign,
        .leftSquareBracket,
        .rightSquareBracket,
        .at
    ]

    /**
        gen-delims  = ":" / "/" / "?" / "#" / "[" / "]" / "@"
    */
    internal var isGeneralDelimiter: Bool {
        return Byte.generalDelimiters.contains(self)
    }

    static let subDelimiters: [Byte] = [
        .exclamation,
        .dollar,
        .ampersand,
        .apostrophe,
        .leftParenthesis,
        .rightParenthesis,
        .asterisk,
        .plus,
        .comma,
        .semicolon,
        .equals
    ]

    /**
        sub-delims  = "!" / "$" / "&" / "'" / "(" / ")"
        "*" / "+" / "," / ";" / "="
    */
    internal var isSubDelimiter: Bool {
        return Byte.subDelimiters.contains(self)
    }
}

// TODO: Test all of these character booleans

/*
    UNRESERVED CHARACTERS

    https://tools.ietf.org/html/rfc3986#section-2.2


    Characters that are allowed in a URI but do not have a reserved
    purpose are called unreserved.  These include uppercase and lowercase
    letters, decimal digits, hyphen, period, underscore, and tilde.

    unreserved  = ALPHA / DIGIT / "-" / "." / "_" / "~"
*/
extension Byte {
    /**
        unreserved  = ALPHA / DIGIT / "-" / "." / "_" / "~"
    */
    internal var isUnreservedUriCharacter: Bool {
        switch self {
        case .a ... .z:
            return true
        case .A ... .z:
            return true
        case .zero ... .nine:
            return true
        case Byte.hyphen, Byte.period, Byte.underscore, Byte.tilda:
            return true
        default:
            return false
        }
    }
}
