public class StaticDataBuffer {
    private var localBuffer: [Byte] = []
    private var buffer: IndexingIterator<[Byte]>

    public convenience init(data: Data) {
        self.init(bytes: data.bytes)
    }

    public init(bytes: [Byte]) {
        self.buffer = bytes.makeIterator()
    }

    // MARK: Next

    public func next() throws -> Byte? {
        /*
         local buffer is used to maintain last bytes while still interacting w/ byte buffer
         */
        guard localBuffer.isEmpty else {
            return localBuffer.removeFirst()
        }
        return buffer.next()
    }

    // MARK: Discard Extranneous Tokens

    public func discardNext(_ count: Int) throws {
        _ = try collect(next: count)
    }

    // MARK: Check Tokens

    public func checkLeadingBuffer(matches: Byte...) throws -> Bool {
        return try checkLeadingBuffer(matches: matches)
    }

    public func checkLeadingBuffer(matches: [Byte]) throws -> Bool {
        let leading = try collect(next: matches.count)
        localBuffer.append(contentsOf: leading)
        return leading == matches
    }

    // MARK: Collection

    public func collect(next count: Int) throws -> [Byte] {
        guard count > 0 else { return [] }

        var body: [Byte] = []
        try (1...count).forEach { _ in
            guard let next = try next() else { return }
            body.append(next)
        }
        return body
    }

    public func collect(until delimitters: Byte...) throws -> [Byte] {
        var collected: [Byte] = []
        while let next = try next() {
            if delimitters.contains(next) {
                // If the delimitter is also a token that identifies
                // a particular section of the URI
                // then we may want to return that byte to the buffer
                localBuffer.append(next)
                break
            }

            collected.append(next)
        }
        return collected
    }

    public func collectRemaining() throws -> [Byte] {
        var complete: [Byte] = []
        while let next = try next() {
            complete.append(next)
        }
        return complete
    }

}

public class BaseURIParser: StaticDataBuffer {
    public override func next() throws -> Byte? {
        guard let next = try super.next() else { return nil }
        guard !next.isWhitespace else { return try self.next() }
        guard next.isValidUriCharacter else {
            throw "found invalid uri character: \(Character(next))"
        }
        return next
    }
}

extension URIParser {
}

extension URIParser {
    // Temporary until C7 is updated
    public struct URI {
        public struct UserInfo {
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
    static func parse(uri: [Byte]) throws -> URI {
        let parser = URIParser(bytes: uri)
        return try parser.parse()
    }
}

public func percentDecoded(_ input: [Byte]) throws -> [Byte] {
    var idx = 0
    var group: [Byte] = []
    while idx < input.count {
        let next = input[idx]
        if next.equals(any: .percentSign) {
            // %  2  A
            // i +1 +2
            let firstHex = idx + 1
            let secondHex = idx + 2
            idx = secondHex + 1

            guard secondHex < input.count else { throw "invalid percent encoding" }
            let bytes = input[firstHex...secondHex].array
            let str = try bytes.toString()
            guard let encodedByte = Byte(str, radix: 16) else { throw "invalid percent encoding" }
            group.append(encodedByte)
        } else {
            group.append(next)
            idx += 1
        }
    }
    return group
}

public func percentEncoded(_ input: [Byte], shouldEncode: (Byte) throws -> Bool) throws -> [Byte] {
    var group: [Byte] = []
    try input.forEach { byte in
        if try shouldEncode(byte) {
            let hex = String(byte, radix: 16).utf8
            group.append(.percentSign)
            if hex.count == 1 {
                group.append(.zeroCharacter)
            }
            group.append(contentsOf: hex)
//            let char = Character(byte)
//            "\(char)".utf8.forEach { utf8Byte in
//                let hex = String(utf8Byte, radix: 16).utf8
//                group.append(.percentSign)
//                if utf8Byte > 16 {
//                    group.append(0)
//                }
//                group.append(contentsOf: hex)
//            }
        } else {
            group.append(byte)
        }
    }
    return group
}

public func TEST_PERCENT_DECODING() {
    let string = "%7E".utf8.array
    print("Bytes: \(string)")
    let decoded = try! percentDecoded(string)
    print("Decoded: \(decoded)")
    let back = try! decoded.toString()
    print("Back: \(back)")
}

public final class URIParser: StaticDataBuffer {
    // TODO: Move to internal to force static func
    public func parse() throws -> URI {
        let (scheme, authority, path, query, fragment) = try parse()
        let (username, auth, host, port) = try parse(authority: authority)
        print(port)

        let userInfo = try URI.UserInfo(username: username?.toString() ?? "",
                                        password: auth?.toString() ?? "")
        let uri = try URI(scheme: scheme.toString(),
                          userInfo: userInfo,
                          host: host.toString(),
                          port: port.flatMap { try $0.toString() } .flatMap { Int($0) },
                          path: path.toString(),
                          query: query?.toString(),
                          fragment: fragment?.toString())
        return uri
    }

    private func parse() throws -> (scheme: [Byte], authority: [Byte], path: [Byte], query: [Byte]?, fragment: [Byte]?) {
        // ordered calls
        let scheme = try parseScheme()
        let authority = try parseAuthority() ?? []
        let path = try parsePath()
        let query = try parseQuery()
        let fragment = try parseFragment()
        return (scheme, authority, path, query, fragment)
    }

    /**
     Filter out white space and throw on invalid characters
     */
    public override func next() throws -> Byte? {
        guard let next = try super.next() else { return nil }
        guard !next.isWhitespace else { return try self.next() }
        guard next.isValidUriCharacter else {
            throw "found invalid uri character: \(Character(next))"
        }
        return next
    }

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
    func parseScheme() throws -> [Byte] {
        let scheme = try collect(until: .colon, .forwardSlash)
        let colon = try checkLeadingBuffer(matches: .colon)
        guard colon else { return scheme }
        // if matches ':', then we have a scheme
        // clear ':' delimitter and continue we don't use this for further parsing
        try discardNext(1)
        return scheme
    }

    /*
     https://tools.ietf.org/html/rfc3986#section-3.2

     The authority component is preceded by a double slash ("//") and is
     terminated by the next slash ("/"), question mark ("?"), or number
     sign ("#") character, or by the end of the URI.

     authority   = [ userinfo "@" ] host [ ":" port ]
     */
    func parseAuthority() throws -> [Byte]? {
        guard try checkLeadingBuffer(matches: .forwardSlash, .forwardSlash) else { return nil }
        try discardNext(2) // discard '//'
        return try collect(until: .forwardSlash, .questionMark, .numberSign)
    }

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

    /*
     https://tools.ietf.org/html/rfc3986#section-3.4

     The query component is indicated by the first question
     mark ("?") character and terminated by a number sign ("#") character
     or by the end of the URI.
     */
    private func parseQuery() throws -> [Byte]? {
        guard try checkLeadingBuffer(matches: .questionMark) else { return nil }
        try discardNext(1) // discard '?'
        return try collect(until: .numberSign)
    }


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

extension URIParser {
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

        host = chunk
        return (host, port)
    }

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
