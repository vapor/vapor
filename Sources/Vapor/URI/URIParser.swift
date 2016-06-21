extension URIParser {
    public static func parse(uri: Bytes) throws -> URI {
        let parser = URIParser(bytes: uri) // TODO: Retain splice format
        return try parser.parse()
    }
}

extension URI {
    public typealias Scheme = String
    // TODO: Find RFC list of other defaults, implement and link source
    static let defaultPorts: [Scheme: Int] = [
        "http": 80,
        "https": 443,
        "ws": 80,
        "wss": 443
    ]

    // The default port associated with the scheme
    public var schemePort: Int? {
        return scheme.flatMap { scheme in URI.defaultPorts[scheme] }
    }

    public init(_ str: String) throws {
        self = try URIParser.parse(uri: str.utf8.array)
        guard port == nil else { return }
        // if no port, try scheme default if possible
        port = schemePort
    }
    
}
// ************************************

public final class URIParser: StaticDataBuffer {

    public enum Error: ErrorProtocol {
        case invalidPercentEncoding
        case unsupportedURICharacter(Byte)
    }

    // If we have authority, we should also have scheme?
    let existingHost: Bytes?

    /*
     The most common form of Request-URI is that used to identify a
     resource on an origin server or gateway. In this case the absolute
     path of the URI MUST be transmitted (see section 3.2.1, abs_path) as
     the Request-URI, and the network location of the URI (authority) MUST
     be transmitted in a Host header field. For example, a client wishing
     to retrieve the resource above directly from the origin server would
     create a TCP connection to port 80 of the host "www.w3.org" and send
     the lines:

     GET /pub/WWW/TheProject.html HTTP/1.1
     Host: www.w3.org
     
     If host exists, and scheme exists, use those
     */
    public init(bytes: Bytes, existingHost: String? = nil) {
        self.existingHost = existingHost?.bytes
        super.init(bytes: bytes)
    }

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
        let userInfo = URI.UserInfo(
            username: username ?? "",
            password: auth ?? ""
        )


        // port MUST convert to string, THEN to Int
        let host = try percentDecodedString(hostBytes)
        let port = try percentDecodedString(portBytes).flatMap { Int($0) }
        let path = try percentDecodedString(pathBytes)
        let query = try percentDecodedString(queryBytes)
        let fragment = try percentDecodedString(fragmentBytes)
        let uri = URI(
            scheme: scheme,
            userInfo: userInfo,
            host: host,
            port: port,
            path: path,
            query: query,
            fragment: fragment
        )

        return uri
    }

    // MARK: Component Parse

    private func parse() throws -> (
        scheme: [Byte],
        authority: [Byte],
        path: [Byte],
        query: [Byte]?,
        fragment: [Byte]?
    ) {
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
        guard let decoded = percentDecoded(input) else { throw Error.invalidPercentEncoding }
        return decoded.string
    }

    private func percentDecodedString(_ input: [Byte]?) throws -> String? {
        guard let i = input else { return nil }
        return try percentDecodedString(i)
    }

    private func percentDecodedString(_ input: ArraySlice<Byte>) throws -> String {
        guard let decoded = percentDecoded(input) else { throw Error.invalidPercentEncoding }
        return decoded.string
    }

    private func percentDecodedString(_ input: ArraySlice<Byte>?) throws -> String? {
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
        guard next.isValidUriCharacter else { throw Error.unsupportedURICharacter(next) }
        return next
    }

    // MARK: Scheme

    /**
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
        // MUST begin with letter
        guard try next(matches: { $0.isLetter } ) else { return [] }

        let scheme = try collect(until: .colon, .forwardSlash)
        let colon = try checkLeadingBuffer(matches: .colon)
        guard colon else { return scheme }
        // if matches ':', then we have a scheme
        // clear ':' delimitter and continue we don't use this for further parsing
        try discardNext(1)
        return scheme
    }

    // MARK: Authority

    /**
        https://tools.ietf.org/html/rfc3986#section-3.2

        The authority component is preceded by a double slash ("//") and is
        terminated by the next slash ("/"), question mark ("?"), or number
        sign ("#") character, or by the end of the URI.

        authority   = [ userinfo "@" ] host [ ":" port ]
    */
    private func parseAuthority() throws -> [Byte]? {
        if let existingHost = existingHost { return existingHost.array }
        guard try checkLeadingBuffer(matches: .forwardSlash, .forwardSlash) else { return nil }
        try discardNext(2) // discard '//'
        return try collect(until: .forwardSlash, .questionMark, .numberSign)
    }

    // MARK: Path

    /**
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

    /**
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
            guard input == .plus else { return input }
            return .space
        }
    }

    // MARK: Fragment

    /**
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
    private func parse(authority: [Byte]) throws -> (
        username: ArraySlice<Byte>?,
        auth: ArraySlice<Byte>?,
        host: ArraySlice<Byte>,
        port: ArraySlice<Byte>?
    ) {
        let comps = authority.split(
            separator: .at,
            maxSplits: 1,
            omittingEmptySubsequences: false
        )

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
    private func parse(hostAndPort: [Byte]) throws -> (host: ArraySlice<Byte>, port: ArraySlice<Byte>?) {
        /**
            move in reverse looking for ':' or ']' or end of line

            if ':' then we have found a port, take bytes we have seen and add to port reference
            if ']' then we have IP Literal -- scan to end of string // TODO: Validate `[` closing?
            if end of line, then we have no port, just host. assign chunk of bytes to host
        */

        let hostStart = hostAndPort.startIndex
        let hostEnd = hostAndPort.endIndex - 1
        guard hostStart < hostEnd else { return ([], nil) }
        for i in (hostStart...hostEnd).lazy.reversed() {
            let byte = hostAndPort[i]
            if byte == .colon {
                // going reverse, if we found a colon BEFORE we found a ']' then it's a port
                let host = hostAndPort[hostStart..<i]
                // TODO: Check what happens w/ `example.com:` ... it MUST not crash
                let port = hostAndPort[(i + 1)...hostEnd]
                return (host, port)
            } else if byte == .rightSquareBracket {
                // square brackets ONLY for IP Literal
                // if we found right square bracket first, just complete to end
                // return remaining bytes to standard orientation
                // if we found a colon before this
                // the port would have been collected
                return (hostAndPort[hostStart...i], nil)
            }
        }

        return (hostAndPort[hostStart...hostEnd], nil)
    }

    // MARK: UserInfo Parse

    /**
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
    private func parse(userInfo: [Byte]) throws -> (username: ArraySlice<Byte>, auth: ArraySlice<Byte>?) {
        /**
            Iterate as 'username' until we find `:`, then give `auth` remaining bytes
        */
        let split = userInfo.split(separator: .colon, maxSplits: 1)
        guard !split.isEmpty else { return ([], nil) }
        let username = split[0]
        guard split.count == 2 else { return (username, nil) }
        return (username, split[1])
    }
}
