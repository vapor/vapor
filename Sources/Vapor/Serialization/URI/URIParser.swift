public class BaseURIParser {
    private var localBuffer: [Byte] = []
    private var buffer: IndexingIterator<[Byte]>

    public convenience init(data: Data) {
        self.init(bytes: data.bytes)
    }

    public init(bytes: [Byte]) {
        self.buffer = bytes.makeIterator()
    }

    // MARK: Next

    // wrapping next to omit white space characters and throw on invalid

    internal func next() throws -> Byte? {
        /*
         local buffer is used to maintain last bytes while still interacting w/ byte buffer
         */
        guard localBuffer.isEmpty else {
            return localBuffer.removeFirst()
        }

        while let next = buffer.next() {
            guard !next.isWhitespace else { continue }
            guard next.isValidUriCharacter else {
                throw "found invalid uri character: \(Character(next))"
            }
            return next
        }
        
        return nil
    }

    func discardNext(_ count: Int) throws {
        _ = try collect(next: count)
    }

    func checkLeadingBuffer(matches: Byte...) throws -> Bool {
        return try checkLeadingBuffer(matches: matches)
    }
    func checkLeadingBuffer(matches: [Byte]) throws -> Bool {
        let leading = try collect(next: matches.count)
        localBuffer.append(contentsOf: leading)
        return leading == matches
    }

    func collect(next count: Int) throws -> [Byte] {
        guard count > 0 else { return [] }

        var body: [Byte] = []
        try (1...count).forEach { _ in
            guard let next = try next() else { return }
            body.append(next)
        }
        return body
    }

    func collect(until delimitters: Byte...) throws -> [Byte] {
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

    func finish() throws -> [Byte] {
        var complete: [Byte] = []
        while let next = try next() {
            complete.append(next)
        }
        return complete
    }
}
//
//public final class URIParser {
//    private var localBuffer: [Byte] = []
//    private var buffer: IndexingIterator<[Byte]>
//
//    public convenience init(data: Data) {
//        self.init(bytes: data.bytes)
//    }
//
//    public init(bytes: [Byte]) {
//        self.buffer = bytes.makeIterator()
//    }
//
//    public func parse() throws {
//        let (scheme, authority, path, query, fragment) = try parse()
//        // scheme -- ok
//        // authority -- needs parsing
//        // path -- ok
//        // query -- ok
//        // fragment --ok
//        
//        print("Scheme \(try scheme.toString())")
//        print("Authority \(try authority?.toString())")
//        print("Path \(try path.toString())")
//        print("Query \(try query?.toString())")
//        print("Fragment \(try fragment?.toString())")
//        print("\n------------------------------------------------------\n")
//    }
//
//    /*
//     The scheme and path components are required, though the path may be
//     empty (no characters).  When authority is present, the path must
//     either be empty or begin with a slash ("/")
//     */
//    private func parse() throws -> (scheme: [Byte], authority: [Byte]?, path: [Byte], query: [Byte]?, fragment: [Byte]?) {
//        let scheme = try parseScheme()
//
//        // hier part: start
//        let authority = try parseAuthority()
//        let path = try parsePath(uriContainsAuthority: authority != nil)
//        // hier part: end
//
//        let query = try parseQuery()
//        let fragment = try parseFragment()
//
//        let trailing = try next()
//        guard trailing == nil else { throw "found unexpected trailing byte" }
//
//        /*
//         The following are two example URIs and their component parts:
//
//         foo://example.com:8042/over/there?name=ferret#nose
//         \_/   \______________/\_________/ \_________/ \__/
//         |           |            |            |        |
//         scheme     authority       path        query   fragment
//         |   _____________________|__
//         / \ /                        \
//         urn:example:animal:ferret:nose
//         */
//        return (scheme, authority, path, query, fragment)
//    }
//
//    // MARK: Next
//
//    private func next() throws -> Byte? {
//        /*
//         local buffer is used to maintain last bytes while still interacting w/ byte buffer
//         */
//        guard localBuffer.isEmpty else {
//            return localBuffer.removeFirst()
//        }
//        
//        while let next = buffer.next() {
//            // whitespace is ok at any point according to RFC
//            guard !next.isWhitespace else { continue }
//            guard next.isValidUriCharacter else {
//                throw "found invalid uri character: \(Character(next))"
//            }
//            return next
//        }
//        
//        return nil
//    }
//}
//
//// MARK: Scheme
//
//extension URIParser {
//    /*
//     https://tools.ietf.org/html/rfc3986#section-3.1
//
//     Scheme names consist of a sequence of characters beginning with a
//     letter and followed by any combination of letters, digits, plus
//     ("+"), period ("."), or hyphen ("-").  Although schemes are case-
//     insensitive, the canonical form is lowercase and documents that
//     specify schemes must do so with lowercase letters.  An implementation
//     should accept uppercase letters as equivalent to lowercase in scheme
//     names (e.g., allow "HTTP" as well as "http") for the sake of
//     robustness but should only produce lowercase scheme names for
//     consistency.
//
//     scheme      = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
//     */
//    private func parseScheme() throws -> [Byte] {
//        guard let first = try next() else { throw "missing byte" }
//        guard first.isLetter else { throw "first character in scheme must be letter" }
//
//        var scheme: [Byte] = [first]
//        while let byte = try next() where byte != .colon { // discard colon as delimitter
//            guard byte.isValidSchemeCharacter else {
//                throw "invalid scheme character"
//            }
//            scheme.append(byte)
//        }
//        return scheme
//    }
//}
//
///*
//
// The generic URI syntax consists of a hierarchical sequence of
// components referred to as the scheme, authority, path, query, and
// fragment.
//
// URI         = scheme ":" hier-part [ "?" query ] [ "#" fragment ]
//
// hier-part   = "//" authority path-abempty
// / path-absolute
// / path-rootless
// / path-empty
//
// The scheme and path components are required, though the path may be
// empty (no characters).  When authority is present, the path must
// either be empty or begin with a slash ("/") character.  When
// authority is not present, the path cannot begin with two slash
// characters ("//").  These restrictions result in five different ABNF
// rules for a path (Section 3.3), only one of which will match any
// given URI reference.
//
// The following are two example URIs and their component parts:
//
// foo://example.com:8042/over/there?name=ferret#nose
// \_/   \______________/\_________/ \_________/ \__/
// |           |            |            |        |
// scheme     authority       path        query   fragment
// |   _____________________|__
// / \ /                        \
// urn:example:animal:ferret:nose
// */
//extension URIParser {
//    func discardNext(_ count: Int) throws {
//        _ = try collect(next: count)
//    }
//
//    func checkLeadingBuffer(matches: Byte...) throws -> Bool {
//        return try checkLeadingBuffer(matches: matches)
//    }
//    func checkLeadingBuffer(matches: [Byte]) throws -> Bool {
//        let leading = try collect(next: matches.count)
//        // preserve position of items
//        localBuffer.append(contentsOf: leading)
//        return leading == matches
//    }
//
//    func collect(next count: Int) throws -> [Byte] {
//        guard count > 0 else { return [] }
//
//        var body: [Byte] = []
//        try (1...count).forEach { _ in
//            guard let next = try next() else { return }
//            body.append(next)
//        }
//        return body
//    }
//
//    func collect(until delimitters: Byte...) throws -> [Byte] {
//        var collected: [Byte] = []
//        while let next = try next() {
//            if delimitters.contains(next) {
//                // If the delimitter is also a token that identifies
//                // a particular section of the URI
//                // then we may want to return that byte to the buffer
//                localBuffer.append(next)
//                break
//            }
//
//            collected.append(next)
//        }
//        return collected
//    }
//
//    func finish() throws -> [Byte] {
//        var complete: [Byte] = []
//        while let next = try next() {
//            complete.append(next)
//        }
//        return complete
//    }
//
//    public func asdfasdfsadf() throws {
//        // ordered calls
//        let scheme = try _parseScheme()
//        let authority = try _parseAuthority()
//        let path = try _parsePath()
//        let query = try _parseQuery()
//        let fragment = try _parseFragment()
//
//        print("Scheme \(try scheme.toString())")
//        print("Authority \(try authority?.toString())")
//        print("Path \(try path.toString())")
//        print("Query \(try query?.toString())")
//        print("Fragment \(try fragment?.toString())")
//    }
//
//    /*
//     https://tools.ietf.org/html/rfc3986#section-3.1
//
//     Scheme names consist of a sequence of characters beginning with a
//     letter and followed by any combination of letters, digits, plus
//     ("+"), period ("."), or hyphen ("-").  Although schemes are case-
//     insensitive, the canonical form is lowercase and documents that
//     specify schemes must do so with lowercase letters.  An implementation
//     should accept uppercase letters as equivalent to lowercase in scheme
//     names (e.g., allow "HTTP" as well as "http") for the sake of
//     robustness but should only produce lowercase scheme names for
//     consistency.
//
//     scheme      = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
//     */
//    func _parseScheme() throws -> [Byte] {
//        let scheme = try collect(until: .colon)
//        try discardNext(1) // clear ':' delimitter. We don't use this for further parsing
//        return scheme
//    }
//
//    /*
//     https://tools.ietf.org/html/rfc3986#section-3.2
//
//     The authority component is preceded by a double slash ("//") and is
//     terminated by the next slash ("/"), question mark ("?"), or number
//     sign ("#") character, or by the end of the URI.
//     
//     authority   = [ userinfo "@" ] host [ ":" port ]
//     */
//    func _parseAuthority() throws -> [Byte]? {
//        guard try checkLeadingBuffer(matches: .forwardSlash, .forwardSlash) else { return nil }
//        try discardNext(2) // discard the forward slashes
//        return try collect(until: .forwardSlash, .questionMark, .numberSign)
//    }
//
//    /*
//     https://tools.ietf.org/html/rfc3986#section-3.3
//     
//     The path is terminated
//     by the first question mark ("?") or number sign ("#") character, or
//     by the end of the URI.
//     
//     If a URI contains an authority component, then the path component
//     must either be empty or begin with a slash ("/") character.
//     */
//    func _parsePath() throws -> [Byte] {
//        // don't remove trailing token, it's used to delimmit query or fragment
//        return try collect(until: .questionMark, .numberSign)
//    }
//
//    /*
//     https://tools.ietf.org/html/rfc3986#section-3.4
//
//     The query component is indicated by the first question
//     mark ("?") character and terminated by a number sign ("#") character
//     or by the end of the URI.
//     */
//    func _parseQuery() throws -> [Byte]? {
//        guard try checkLeadingBuffer(matches: .questionMark) else { return nil }
//        try discardNext(1) // discard '?'
//        return try collect(until: .numberSign)
//    }
//
//
//    /*
//     https://tools.ietf.org/html/rfc3986#section-3.5
//
//     A
//     fragment identifier component is indicated by the presence of a
//     number sign ("#") character and terminated by the end of the URI.
//     */
//    func _parseFragment() throws -> [Byte]? {
//        guard try checkLeadingBuffer(matches: .numberSign) else { return nil }
//        try discardNext(1) // discard '#'
//        return try finish()
//    }
//}
//
//import C7
//
public final class URIParser: BaseURIParser {
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

    public func parse() throws -> URI {
        // ordered calls
        let scheme = try parseScheme()

        let authority = try parseAuthority() ?? []
        let (username, auth, host, port) = try parse(authority: authority)

        let path = try parsePath()
        let query = try parseQuery()
        let fragment = try parseFragment()

        let userInfo = try URI.UserInfo(username: username?.toString() ?? "",
                                        password: auth?.toString() ?? "")
        let uri = try URI(scheme: scheme.toString(),
                          userInfo: userInfo,
                          host: host.toString(),
                          port: port.flatMap { UInt($0) } .map { Int($0) },
                          path: path.toString(),
                          query: query?.toString(),
                          fragment: fragment?.toString())
        return uri
    }


    func parse(authority: [Byte]) throws -> (username: [Byte]?, auth: [Byte]?, host: [Byte], port: [Byte]?) {
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
     https://tools.ietf.org/html/rfc3986#section-3.2
     
     // TODO: Flush out documentatino here
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
    func parsePath() throws -> [Byte] {
        return try collect(until: .questionMark, .numberSign)
    }

    /*
     https://tools.ietf.org/html/rfc3986#section-3.4

     The query component is indicated by the first question
     mark ("?") character and terminated by a number sign ("#") character
     or by the end of the URI.
     */
    func parseQuery() throws -> [Byte]? {
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
    func parseFragment() throws -> [Byte]? {
        guard try checkLeadingBuffer(matches: .numberSign) else { return nil }
        try discardNext(1) // discard '#'
        return try finish()
    }
}

extension Array where Element: Equatable {
    func prefix(throughMatching matching: Element) -> Array {
        guard let index = index(of: matching) else { return [] }
        return self[0...index].array
    }
}

// MARK: Authority

//extension URIParser {
//    /**
//     https://tools.ietf.org/html/rfc3986#section-3.2
//
//     The authority component is preceded by a double slash ("//") and is
//     terminated by the next slash ("/"), question mark ("?"), or number
//     sign ("#") character, or by the end of the URI.
//
//     authority   = [ userinfo "@" ] host [ ":" port ]
//     */
//    private func parseAuthority() throws -> [Byte]? {
//        /*
//         If first two characters are NOT `//` then we return them back to buffer
//         and continue next parsing since they don't apply to an authority
//         */
//        guard let first = try next() else {
//            return nil
//        }
//        guard first == .forwardSlash else {
//            localBuffer.append(first)
//            return nil
//        }
//        guard let second = try next() else {
//            localBuffer.append(first)
//            return nil
//        }
//        guard second == .forwardSlash else {
//            localBuffer.append(first)
//            localBuffer.append(second)
//            return nil
//        }
//
//        var authority: [Byte] = []
//        while let next = try next() {
//            if next.equals(any: .forwardSlash, .questionMark, .numberSign) {
//                // return token to buffer so we know how to parse next section
//                localBuffer.append(next)
//                break
//            } else {
//                authority.append(next)
//            }
//        }
//
//        return authority
//    }
//}

// MARK: Path

//extension URIParser {
//
//    /*
//     https://tools.ietf.org/html/rfc3986#section-3.3
//
//     -- ends w/ '#' || '?' || end of data
//     -- if uri contains authority, first line MUST be '/'
//        • we won't leave authority scope w/o this delimitter, so don't need to account here. breaking bug
//          that will manifest in weird ways. Future investigate better way to direct user where to look
//          for this, but we don't need to account for it here
//
//     -- if NO authority, first 2 must NOT be '//'
//        • if first two ARE `//` then we'll parse as authority so no need to account for this here.
//
//     -- path MUST exist, but CAN be empty
//     
//         // TODO: Further Future Validation
//         path          = path-abempty    ; begins with "/" or is empty
//         / path-absolute   ; begins with "/" but not "//"
//         / path-noscheme   ; begins with a non-colon segment
//         / path-rootless   ; begins with a segment
//         / path-empty      ; zero characters
//
//         path-abempty  = *( "/" segment )
//         path-absolute = "/" [ segment-nz *( "/" segment ) ]
//         path-noscheme = segment-nz-nc *( "/" segment )
//         path-rootless = segment-nz *( "/" segment )
//         path-empty    = 0<pchar>
//
//
//
//
//         Berners-Lee, et al.         Standards Track                    [Page 22]
//
//         RFC 3986                   URI Generic Syntax               January 2005
//
//
//         segment       = *pchar
//         segment-nz    = 1*pchar
//         segment-nz-nc = 1*( unreserved / pct-encoded / sub-delims / "@" )
//         ; non-zero-length segment without any colon ":"
//
//         pchar         = unreserved / pct-encoded / sub-delims / ":" / "@"
//     */
//    private func parsePath(uriContainsAuthority: Bool) throws -> [Byte] {
//        guard let first = try next() else { return [] } // ok for path to be empty
//        if first.equals(any: .numberSign, .questionMark) {
//            // path is empty, we should parse query or fragment -- return token to buffer
//            localBuffer.append(first)
//            return []
//        }
//
//        var path: [Byte]
//
//        if first == .forwardSlash {
//            path = []
//        } else {
//            path = [first]
//        }
//
//        while let next = try next() {
//            if next.equals(any: .numberSign, .questionMark) {
//                // return identification token to buffer
//                localBuffer.append(next)
//                break
//            } else {
//                path.append(next)
//            }
//        }
//        
//        return path
//    }
//
////    enum Component
//}

// MARK: Query

//extension URIParser {
//    /**
//     // TODO: Reference RFC
//
//     -- starts at '?' -- runs to '#' || end of bytes
//     */
//    private func parseQuery() throws -> [Byte]? { // query can be `nil`
//        guard let first = try next() else { return nil }
//        guard first == .questionMark else {
//            // This byte isn't for us, return it to buffer
//            localBuffer.append(first)
//            return nil
//        }
//
//        var query: [Byte] = []
//        while let next = try next() {
//            if next.equals(any: .numberSign) {
//                // return identification token to buffer
//                localBuffer.append(next)
//                break
//            } else if next.isValidQueryCharacter {
//                query.append(next)
//            } else {
//                throw "invalid query character: \(next)"
//            }
//        }
//        return query
//    }
//}

// MARK: Fragment

//extension URIParser {
//    /*
//     https://tools.ietf.org/html/rfc3986#section-3.3
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
//    private func parseFragment() throws -> [Byte]? {
//        guard let first = try next() else { return nil }
//        guard first == .numberSign else {
//            // expected to parse fragment, but unable to. return token for next section
//            localBuffer.append(first)
//            return nil
//        }
//
//        var fragment: [Byte] = []
//        while let next = try next() {
//            if next.isValidFragmentCharacter {
//                fragment.append(next)
//            } else {
//                throw "invalid fragment character: \(next)"
//            }
//        }
//        return fragment
//    }
//}
