
extension Byte {
    internal var isValidUriCharacter: Bool {
        return isUnreservedUriCharacter
            || isGeneralDelimiter
            || isSubDelimiter
            || self == .percentSign
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
    /**
        gen-delims  = ":" / "/" / "?" / "#" / "[" / "]" / "@"
    */
    internal var isGeneralDelimiter: Bool {
        let char = Character(self)
        switch char {
        case ":", "/", "?", "#", "[", "]", "@":
            return true
        default:
            return false
        }
    }

    /**
        sub-delims  = "!" / "$" / "&" / "'" / "(" / ")"
        "*" / "+" / "," / ";" / "="
    */
    internal var isSubDelimiter: Bool {
        let char = Character(self)
        switch char {
        case "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "=":
            return true
        default:
            return false
        }
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
        let char = Character(self)
        switch char {
        case "a"..."z":
            return true
        case "A"..."Z":
            return true
        case "0"..."9":
            return true
        case "-", ".", "_", "~":
            return true
        default:
            return false

        }
    }
}
