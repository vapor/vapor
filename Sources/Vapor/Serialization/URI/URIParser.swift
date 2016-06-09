
extension URIParser {
    // Temporary until C7 is updated
    public struct URI {
        public struct UserInfo {
            // TODO: Should auth and username be non-optional? There's a difference between "" and nil
            public var username: String
            public var password: String

            public init(username: String, password: String) {
                self.username = username
                self.password = password
            }
        }

        public var scheme: String?
        public var userInfo: UserInfo?
        public var host: String?
        public var port: Int?
        public var path: String?
        public var query:  String?
        public var fragment: String?

        public init(scheme: String? = nil,
                    userInfo: UserInfo? = nil,
                    host: String? = nil,
                    port: Int? = nil,
                    path: String? = nil,
                    query: String? = nil,
                    fragment: String? = nil) {
            self.scheme = scheme
            self.userInfo = userInfo
            self.host = host
            self.port = port
            self.path = path
            self.query = query
            self.fragment = fragment
        }
    }
}

extension URIParser {
    public static func parse(uri: [Byte]) throws -> URI {
        let parser = URIParser(bytes: uri)
        return try parser.parse()
    }
}

public final class URIParser: StaticDataBuffer {

    // MARK: Paser URI

    internal func parse() throws -> URI {
        let (schemeBytes, authorityBytes, pathBytes, queryBytes, fragmentBytes) = try parse()
        let (usernameBytes, authBytes, hostBytes, portBytes) = try parse(authority: authorityBytes)

        /*
         ***** [WARNING] *****

         do NOT attempt to percent decode before THIS point
         */
        let scheme = try percentDecodedString(schemeBytes)
        let username = try percentDecodedString(usernameBytes)
        let auth = try percentDecodedString(authBytes)
        let userInfo = URI.UserInfo(username: username ?? "",
                                    password: auth ?? "")


        // port MUST convert to string, THEN to Int
        let host = try percentDecodedString(hostBytes)
        let port = try percentDecodedString(portBytes).flatMap { Int($0) }
        let path = try percentDecodedString(pathBytes)
        let query = try percentDecodedString(queryBytes)
        let fragment = try percentDecodedString(fragmentBytes)
        let uri = URI(scheme: scheme,
                      userInfo: userInfo,
                      host: host,
                      port: port,
                      path: path,
                      query: query,
                      fragment: fragment)

        return uri
    }

    // MARK: Component Parse

    private func parse() throws -> (scheme: [Byte], authority: [Byte], path: [Byte], query: [Byte]?, fragment: [Byte]?) {
        // ordered calls
        let scheme = try parseScheme()
        let authority = try parseAuthority() ?? []
        let path = try parsePath()
        let query = try parseQuery()
        let fragment = try parseFragment()
        return (
            scheme,
            authority,
            path,
            query,
            fragment
        )
    }

    // MARK: Percent Decoding

    private func percentDecodedString(_ input: [Byte]) throws -> String {
        let decoded = try percentDecoded(input)
        return try decoded.toString()
    }

    private func percentDecodedString(_ input: [Byte]?) throws -> String? {
        guard let i = input else { return nil }
        return try percentDecodedString(i)
    }

    // MARK: Next

    /**
     Filter out white space and throw on invalid characters
     */
    public override func next() throws -> Byte? {
        guard let next = try super.next() else { return nil }
        guard !next.isWhitespace else { return try self.next() }
        guard next.isValidUriCharacter else {
            throw "found invalid uri character: \(Character(next))"
        }

        // MUST run through percent filter
        // SOME characters are encoded during parsing
        // ALL OTHERS MUST wait until AFTER component
        // parsing
        return try percentFiltered(next: next)
    }

    /*
     ************** [WARNING DO NOT DELET] *****************

     SOME percent encodings are parsed during component parsing
     ALL OTHER percent encoding MUST wait until AFTER
     components have been parsed

     **************
     IMPORTANT NOTE REGARDING PERCENT ENCODING
     **************

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
     */
    private func percentFiltered(next: Byte) throws -> Byte? {
        guard next == .percentSign else { return next }
        let bytes = try collect(next: 2)
        let encoding = try percentDecoded([.percentSign] + bytes)
        guard encoding.count == 1 else { throw "unexpected error that should never happen" }
        let encodedByte = encoding[0]
        let char = Character(encodedByte)
        switch char {
        case "a"..."z":
            fallthrough
        case "A"..."Z":
            fallthrough
        case "0"..."9":
            fallthrough
        case "-", ".", "_", "~":
            /*
             Generally with percent encoding, we WAIT until AFTER
             the components have been broken out.

             However, with the above character set, encoding MUST happen BEFORE uri parsing
             */
            return encodedByte
        default:
            // return encoded bytes to buffer
            returnToBuffer(bytes)
            return next
        }
    }

    // MARK: Scheme

    /*
     https://tools.ietf.org/html/rfc3986#section-3.1

     Scheme names consist of a sequence of characters beginning with a
     letter and followed by any combination of letters, digits, plus
     ("+"), period ("."), or hyphen ("-").  Although schemes are case-
     insensitive, the canonical form is lowercase and documents that
     specify schemes must do so with lowercase letters.  An implementation
     should accept uppercase letters as equivalent to lowercase in scheme
     names (e.g., allow "HTTP" as well as "http") for the sake of
     robustness but should only produce lowercase scheme names for
     consistency.

     scheme      = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
     */
    private func parseScheme() throws -> [Byte] {
        let scheme = try collect(until: .colon, .forwardSlash)
        let colon = try checkLeadingBuffer(matches: .colon)
        guard colon else { return scheme }
        // if matches ':', then we have a scheme
        // clear ':' delimitter and continue we don't use this for further parsing
        try discardNext(1)
        return scheme
    }

    // MARK: Authority

    /*
     https://tools.ietf.org/html/rfc3986#section-3.2

     The authority component is preceded by a double slash ("//") and is
     terminated by the next slash ("/"), question mark ("?"), or number
     sign ("#") character, or by the end of the URI.

     authority   = [ userinfo "@" ] host [ ":" port ]
     */
    private func parseAuthority() throws -> [Byte]? {
        guard try checkLeadingBuffer(matches: .forwardSlash, .forwardSlash) else { return nil }
        try discardNext(2) // discard '//'
        return try collect(until: .forwardSlash, .questionMark, .numberSign)
    }

    // MARK: Path

    /*
     https://tools.ietf.org/html/rfc3986#section-3.3

     The path is terminated
     by the first question mark ("?") or number sign ("#") character, or
     by the end of the URI.

     If a URI contains an authority component, then the path component
     must either be empty or begin with a slash ("/") character.
     */
    private func parsePath() throws -> [Byte] {
        return try collect(until: .questionMark, .numberSign)
    }

    // MARK: Query

    /*
     https://tools.ietf.org/html/rfc3986#section-3.4

     The query component is indicated by the first question
     mark ("?") character and terminated by a number sign ("#") character
     or by the end of the URI.
     */
    private func parseQuery() throws -> [Byte]? {
        guard try checkLeadingBuffer(matches: .questionMark) else { return nil }
        try discardNext(1) // discard '?'
        
        /*
         Query strings, by convention parse '+' as ' ' spaces
         */
        return try collect(until: .numberSign) { input in
            guard input == .plusSign else { return input }
            return .space
        }
    }

    // MARK: Fragment

    /*
     https://tools.ietf.org/html/rfc3986#section-3.5

     A
     fragment identifier component is indicated by the presence of a
     number sign ("#") character and terminated by the end of the URI.
     */
    private func parseFragment() throws -> [Byte]? {
        guard try checkLeadingBuffer(matches: .numberSign) else { return nil }
        try discardNext(1) // discard '#'
        return try collectRemaining()
    }

}

// MARK: Sub Parsing

extension URIParser {

    // MARK: Authority Parse

    /**
     https://tools.ietf.org/html/rfc3986#section-3.2

     authority   = [ userinfo "@" ] host [ ":" port ]
     */
    private func parse(authority: [Byte]) throws -> (username: [Byte]?, auth: [Byte]?, host: [Byte], port: [Byte]?) {
        let comps = authority.split(separator: .atSign,
                                    maxSplits: 1,
                                    omittingEmptySubsequences: false)

        // 1 or 2, Host and Port is ALWAYS last component, otherwise empty which is ok
        guard let hostAndPort = comps.last else { return (nil, nil, [], nil) }
        let (host, port) = try parse(hostAndPort: hostAndPort.array)

        guard comps.count == 2, let userinfo = comps.first else { return (nil, nil, host, port) }
        let (username, auth) = try parse(userInfo: userinfo.array)
        return (username, auth, host, port)
    }

    // MARK: HostAndPort Parse

    /*
     Host:
     https://tools.ietf.org/html/rfc3986#section-3.2.2
     Port:
     https://tools.ietf.org/html/rfc3986#section-3.2.3
     */
    private func parse(hostAndPort: [Byte]) throws -> (host: [Byte], port: [Byte]?) {
        /*
         move in reverse looking for ':' or ']' or end of line

         if ':' then we have found a port, take bytes we have seen and add to port reference
         if ']' then we have IP Literal -- scan to end of string // TODO: Validate `[` closing?
         if end of line, then we have no port, just host. assign chunk of bytes to host
         */
        var host: [Byte] = []
        var port: [Byte]? = nil

        var chunk: [Byte] = []
        // Parsing backwards because it makes logic surrounding ':' and IP Literal considerably easier
        var reverseIterator = hostAndPort.reversed().makeIterator()
        while let byte = reverseIterator.next() {
            if byte.equals(any: .colon) {
                // going reverse, if we found a colon BEFORE we found a ']' then it's a port
                port = chunk.reversed()
                host = reverseIterator.reversed()
                return (host, port)
            } else if byte.equals(any: .rightSquareBracket) {
                // square brackets ONLY for IP Literal
                // if we found right square bracket first, just complete to end
                // return remaining bytes to standard orientation
                // if we found a colon before this
                // the port would have been collected
                port = port?.reversed()
                host = reverseIterator.reversed() + [.rightSquareBracket] // replace trailing AFTER reversing
                return (host, port)
            }

            chunk.append(byte)
        }

        host = chunk.reversed()
        return (host, port)
    }

    // MARK: UserInfo Parse

    /*
     https://tools.ietf.org/html/rfc3986#section-3.2.1

     The userinfo subcomponent may consist of a user name and, optionally,
     scheme-specific information about how to gain authorization to access
     the resource.  The user information, if present, is followed by a
     commercial at-sign ("@") that delimits it from the host.

     userinfo    = *( unreserved / pct-encoded / sub-delims / ":" )

     Use of the format "user:password" in the userinfo field is
     deprecated.  Applications should not render as clear text any data
     after the first colon (":") character found within a userinfo
     subcomponent unless the data after the colon is the empty string
     (indicating no password).  Applications may choose to ignore or
     reject such data when it is received as part of a reference and
     should reject the storage of such data in unencrypted form.  The
     passing of authentication information in clear text has proven to be
     a security risk in almost every case where it has been used.
     */
    private func parse(userInfo: [Byte]) throws -> (username: [Byte], auth: [Byte]?) {
        /*
         Iterate as 'username' until we find `:`, then give `auth` remaining bytes
         */
        var username: [Byte] = []
        var auth: [Byte]? = nil
        var iterator = userInfo.makeIterator()
        while let next = iterator.next() {
            if next.equals(any: .colon) {
                auth = iterator.array // collect remaining post colon
                break
            }
            username.append(next)
        }
        
        return (username, auth)
    }
}

// TODO: Remove
extension String: ErrorProtocol {}

// TODO: => new file
extension Equatable {
    func equals(any: Self...) -> Bool {
        return any.contains(self)
    }
}

// TODO: => new file
extension Sequence {
    var array: [Iterator.Element] {
        return Array(self)
    }
}

// TODO: Some no longer necessary

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
