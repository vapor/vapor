/*
 RESERVED CHARACTERS

 https://tools.ietf.org/html/rfc3986#section-2.2

 //    gen-delims  = ":" / "/" / "?" / "#" / "[" / "]" / "@"
 //
 //    sub-delims  = "!" / "$" / "&" / "'" / "(" / ")"
 //    / "*" / "+" / "," / ";" / "="
 */
extension Byte {
    internal var isGeneralDelimitter: Bool {
        let char = Character(self)
        switch char {
        case ":", "/", "?", "#", "[", "]", "@":
            return true
        default:
            return false
        }
    }

    internal var isSubDelimitter: Bool {
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
    var isValidUriCharacter: Bool {
        return isUnreservedUriCharacter
            || isGeneralDelimitter
            || isSubDelimitter
            || self == .percentSign
    }

    /*
     unreserved  = ALPHA / DIGIT / "-" / "." / "_" / "~"
     */
    var isUnreservedUriCharacter: Bool {
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

//extension Byte {
//    var isAuthorityTerminator: Bool {
//        /*
//         The authority component is preceded by a double slash ("//") and is
//         terminated by the next slash ("/"), question mark ("?"), or number
//         sign ("#") character, or by the end of the URI.
//         */
//        let char = Character(self)
//        switch char {
//        case "/", "?", "#":
//            return true
//        default:
//            return false
//        }
//    }
//}
//
//extension Byte {
//    /*
//     https://tools.ietf.org/html/rfc3986#section-3.1
//
//     Scheme names consist of a sequence of characters beginning with a
//     letter and followed by any combination of letters, digits, plus
//     ("+"), period ("."), or hyphen ("-").
//
//     scheme      = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
//     */
//    var isValidSchemeCharacter: Bool {
//        // case insensitive, should be lowercased. RFC specifies should handle capital for robustness
//        return isLetter
//            || isDigit
//            || equals(any: .plusSign, .minusSign, .period)
//    }
//
//    /*
//     userinfo      = *( unreserved / pct-encoded / sub-delims / ":" )
//     */
//    var isValidUserInfoCharacter: Bool {
//        return isUnreservedUriCharacter
//            || isSubDelimitter
//            || equals(any: .colon, .percentSign)
//    }
//
//    /*
//     https://tools.ietf.org/html/rfc3986#section-3.3
//
//     The path is terminated
//     by the first question mark ("?") or number sign ("#") character, or
//     by the end of the URI.
//     */
//    var isValidPathCharacter: Bool {
//        return isPchar || equals(any: .forwardSlash)
//    }
//
//    /*
//     https://tools.ietf.org/html/rfc3986#section-3.4
//
//     The query component is indicated by the first question
//     mark ("?") character and terminated by a number sign ("#") character
//     or by the end of the URI.
//
//     query       = *( pchar / "/" / "?" )
//     */
//    var isValidQueryCharacter: Bool {
//        return isPchar || equals(any: .forwardSlash, .questionMark)
//    }
//
//    /**
//     https://tools.ietf.org/html/rfc3986#section-3.5
//
//     The fragment identifier component of a URI allows indirect
//     identification of a secondary resource by reference to a primary
//     resource and additional identifying information.  The identified
//     secondary resource may be some portion or subset of the primary
//     resource, some view on representations of the primary resource, or
//     some other resource defined or described by those representations.  A
//     fragment identifier component is indicated by the presence of a
//     number sign ("#") character and terminated by the end of the URI.
//
//     fragment    = *( pchar / "/" / "?" )
//     */
//    var isValidFragmentCharacter: Bool {
//        return isPchar || equals(any: .forwardSlash, .questionMark)
//    }
//
//    /**
//     https://tools.ietf.org/html/rfc3986#section-3.3
//
//     pchar         = unreserved / pct-encoded / sub-delims / ":" / "@"
//     */
//    var isPchar: Bool {
//        return isUnreservedUriCharacter
//            || isSubDelimitter
//            || equals(any: .colon, .atSign, .percentSign)
//    }
//}

extension Byte {
    // port          = *DIGIT
    var isValidPortCharacter: Bool {
        return isDigit
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
}
