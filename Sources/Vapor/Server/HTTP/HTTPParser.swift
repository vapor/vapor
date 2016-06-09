final class HTTPParser: StreamParser {
    enum Error: ErrorProtocol {
        case streamEmpty
    }

    static let headerEndOfLine = "\r\n"
    static let newLine: Byte = 10
    static let carriageReturn: Byte = 13
    static let minimumValidAsciiCharacter: Byte = 13 + 1

    let buffer: StreamBuffer

    init(stream: Stream) {
        self.buffer = StreamBuffer(stream, buffer: 1024)
    }

    func nextLine() throws -> String {
        var line: String = ""

        func append(byte: Byte) {
            guard byte >= HTTPParser.minimumValidAsciiCharacter else {
                return
            }

            line.append(Character(byte))
        }

        while let byte = try buffer.next() where byte != HTTPParser.newLine {
            append(byte: byte)
        }

        return line
    }

    func parse() throws -> Request {
        let requestLineString = try nextLine()
        guard !requestLineString.isEmpty else {
            throw Error.streamEmpty
        }

        let requestLine = try RequestLine(requestLineString)

        var headers: [Request.Headers.Key: String] = [:]

        while true {
            let headerLine = try nextLine()
            if headerLine.isEmpty {
                break
            }

            let comps = headerLine.components(separatedBy: ": ")

            guard comps.count == 2 else {
                continue
            }

            headers[Request.Headers.Key(comps[0])] = comps[1]
        }

        var body: Data = []

        // TODO: Support transfer-encoding: chunked

        if let contentLength = headers["content-length"]?.int {
            for _ in 0..<contentLength {
                if let byte = try buffer.next() {
                    body.append(byte)
                }
            }
        }

        return Request(
            method: requestLine.method,
            uri: requestLine.uri,
            version: requestLine.version,
            headers: Request.Headers(headers),
            body: .buffer(body)
        )
    }
}

// MARK: URI WORK, WILL MOVE

/* 
 ************** [WARNING DO NOT DELET] *****************
 Important shit that _needs_ to happen:
 
 ///////////////

 https://tools.ietf.org/html/rfc3986#section-2.3

 Some characters that ARE allowed are still percent encoded, these should
 be unencoded BEFORE parsing out URI.

 URIs that differ in the replacement of an unreserved character with
 its corresponding percent-encoded US-ASCII octet are equivalent: they
 identify the same resource.  However, URI comparison implementations
 do not always perform normalization prior to comparison (see Section
 6).  For consistency, percent-encoded octets in the ranges of ALPHA
 (%41-%5A and %61-%7A), DIGIT (%30-%39), hyphen (%2D), period (%2E),
 underscore (%5F), or tilde (%7E) should not be created by URI
 producers and, when found in a URI, should be decoded to their
 corresponding unreserved characters by URI normalizers.
 
 ////////////

 */
extension String: ErrorProtocol {}

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

}

extension Equatable {
    func equals(any: Self...) -> Bool {
        return any.contains(self)
    }
}


/*
 RESERVED CHARACTERS

 https://tools.ietf.org/html/rfc3986#section-2.2
 
 //    gen-delims  = ":" / "/" / "?" / "#" / "[" / "]" / "@"
 //
 //    sub-delims  = "!" / "$" / "&" / "'" / "(" / ")"
 //    / "*" / "+" / "," / ";" / "="
 */
extension Byte {
    var isGeneralDelimitter: Bool {
        let char = Character(self)
        switch char {
        case ":", "/", "?", "#", "[", "]", "@":
            return true
        default:
            return false
        }
    }

    var isSubDelimitter: Bool {
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
}

extension Byte {
    var isAuthorityTerminator: Bool {
        /*
         The authority component is preceded by a double slash ("//") and is
         terminated by the next slash ("/"), question mark ("?"), or number
         sign ("#") character, or by the end of the URI.
         */
        let char = Character(self)
        switch char {
        case "/", "?", "#":
            return true
        default:
            return false
        }
    }
    var isLetter: Bool {
        /*
         Capital and lowercase for: https://tools.ietf.org/html/rfc3986#section-3.1
         
         An implementation
         should accept uppercase letters as equivalent to lowercase in scheme
         names (e.g., allow "HTTP" as well as "http") for the sake of
         robustness but should only produce lowercase scheme names for
         consistency.
         */
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
}

extension Byte {
    /*
     https://tools.ietf.org/html/rfc3986#section-3.1

     Scheme names consist of a sequence of characters beginning with a
     letter and followed by any combination of letters, digits, plus
     ("+"), period ("."), or hyphen ("-").

     scheme      = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
     */
    var isValidSchemeCharacter: Bool {
        // case insensitive, should be lowercased. RFC specifies should handle capital for robustness
        return isLetter
            || isDigit
            || equals(any: .plusSign, .minusSign, .period)
    }

    /*
     userinfo      = *( unreserved / pct-encoded / sub-delims / ":" )
     */
    var isValidUserInfoCharacter: Bool {
        return isUnreservedUriCharacter
            || isSubDelimitter
            || equals(any: .colon, .percentSign)
    }

    /*
     https://tools.ietf.org/html/rfc3986#section-3.3

     The path is terminated
     by the first question mark ("?") or number sign ("#") character, or
     by the end of the URI.
     */
    var isValidPathCharacter: Bool {
        return isPchar || equals(any: .forwardSlash)
    }

    /*
     https://tools.ietf.org/html/rfc3986#section-3.4

     The query component is indicated by the first question
     mark ("?") character and terminated by a number sign ("#") character
     or by the end of the URI.
     
     query       = *( pchar / "/" / "?" )
     */
    var isValidQueryCharacter: Bool {
        return isPchar || equals(any: .forwardSlash, .questionMark)
    }

    /**
     https://tools.ietf.org/html/rfc3986#section-3.5
     
     The fragment identifier component of a URI allows indirect
     identification of a secondary resource by reference to a primary
     resource and additional identifying information.  The identified
     secondary resource may be some portion or subset of the primary
     resource, some view on representations of the primary resource, or
     some other resource defined or described by those representations.  A
     fragment identifier component is indicated by the presence of a
     number sign ("#") character and terminated by the end of the URI.

     fragment    = *( pchar / "/" / "?" )
     */
    var isValidFragmentCharacter: Bool {
        return isPchar || equals(any: .forwardSlash, .questionMark)
    }

    /**
     https://tools.ietf.org/html/rfc3986#section-3.3

     pchar         = unreserved / pct-encoded / sub-delims / ":" / "@"
     */
    var isPchar: Bool {
        return isUnreservedUriCharacter
            || isSubDelimitter
            || equals(any: .colon, .atSign, .percentSign)
    }
}


extension Sequence {
    var array: [Iterator.Element] {
        return Array(self)
    }
}

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

private func parse(userInfo: [Byte]) throws -> (user: [Byte], auth: [Byte]?) {
    fatalError()
}

extension Byte {

}

