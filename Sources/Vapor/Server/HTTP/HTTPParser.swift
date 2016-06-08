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

        var headers: [CaseInsensitiveString: String] = [:]

        while true {
            let headerLine = try nextLine()
            if headerLine.isEmpty {
                break
            }

            let comps = headerLine.components(separatedBy: ": ")

            guard comps.count == 2 else {
                continue
            }

            headers[CaseInsensitiveString(comps[0])] = comps[1]
        }

        var body: Data = []
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
}

// http://www.w3schools.com/charsets/ref_utf_basic_latin.asp
let Map: [Character: Byte] = [
    "/": Byte.forwardSlash
]

extension Byte {
    var isForwardSlash: Bool { return self == 0x2F }
}


/*
 The generic URI syntax consists of a hierarchical sequence of
 components referred to as the scheme, authority, path, query, and
 fragment.

 URI         = scheme ":" hier-part [ "?" query ] [ "#" fragment ]

 hier-part   = "//" authority path-abempty
 / path-absolute
 / path-rootless
 / path-empty

 The scheme and path components are required, though the path may be
 empty (no characters).  When authority is present, the path must
 either be empty or begin with a slash ("/") character.  When
 authority is not present, the path cannot begin with two slash
 characters ("//").  These restrictions result in five different ABNF
 rules for a path (Section 3.3), only one of which will match any
 given URI reference.

 The following are two example URIs and their component parts:

 foo://example.com:8042/over/there?name=ferret#nose
 \_/   \______________/\_________/ \_________/ \__/
  |           |            |            |        |
 scheme     authority       path        query   fragment
  |   _____________________|__
 / \ /                        \
 urn:example:animal:ferret:nose
 */

//URI         = scheme ":" hier-part [ "?" query ] [ "#" fragment ]
public struct ALT_URI {
    public let scheme: String?
    public let hierPart: String
    public let query: String?
    public let fragment: String?
}
//public enum Delimitter: Character {
//    case colon = ":"
//    case forwardSlash = "/"
//    case questionMark = "?"
//    case hashtag = "#"
//    case leftSquareBracket = "["
//    case rightSquareBracket = "]"
//    case atSign = "@"
//}
//
//public enum SubDelimitter: Character {
//    case exclamationPoint = "!"
//    case moneySign = "$"
//    //        case
//}
public final class ALT_URIParser {
    private var localBuffer: [Byte] = []
    private var buffer: IndexingIterator<[Byte]>


    public convenience init(data: Data) {
        self.init(bytes: data.bytes)
    }

    public init(bytes: [Byte]) {
        self.buffer = bytes.makeIterator()
    }

    public func parse() throws {
        let (scheme, authority, path, query, fragment) = try parse()

    }

    // TODO: Validate that scheme is _not_ empty?
    private func parse() throws -> (scheme: [Byte], authority: [Byte]?, path: [Byte], query: [Byte]?, fragment: [Byte]?) {
        /*
         The scheme and path components are required, though the path may be
         empty (no characters).  When authority is present, the path must
         either be empty or begin with a slash ("/")
         */
        let scheme = try parseScheme() // if we have relative scheme, we don't need to
        // hier part: start
        let authority = try parseAuthority()
        let path = try parsePath(uriContainsAuthority: authority != nil)
        // hier part: end
        let query = try parseQuery()
        let fragment = try parseFragment()

        /*
         The following are two example URIs and their component parts:

         foo://example.com:8042/over/there?name=ferret#nose
         \_/   \______________/\_________/ \_________/ \__/
         |           |            |            |        |
         scheme     authority       path        query   fragment
         |   _____________________|__
         / \ /                        \
         urn:example:animal:ferret:nose
         */
        return (scheme, authority, path, query, fragment)
    }

    /*
     Scheme names consist of a sequence of characters beginning with a
     letter and followed by any combination of letters, digits, plus
     ("+"), period ("."), or hyphen ("-").  Although schemes are case-
     insensitive, the canonical form is lowercase and documents that
     specify schemes must do so with lowercase letters.  An implementation
     should accept uppercase letters as equivalent to lowercase in scheme
     names (e.g., allow "HTTP" as well as "http") for the sake of
     robustness but should only produce lowercase scheme names for
     consistency.
     */
    private func parseScheme() throws -> [Byte] {
        guard let first = next() else { throw "missing byte" }
        guard first.isLetter else { throw "first character in scheme must be letter" }
        var scheme: [Byte] = [first]

        while let byte = next() where byte != .colon {
            guard byte.isValidSchemeCharacter else {
                throw "invalid scheme character" // rfc says throw errors for everything malformed to prevent malicious attacks
            }
            scheme.append(byte)
        }
        return scheme
    }

    /**
     https://tools.ietf.org/html/rfc3986#section-3.2

     The authority component is preceded by a double slash ("//") and is
     terminated by the next slash ("/"), question mark ("?"), or number
     sign ("#") character, or by the end of the URI.
     
     authority   = [ userinfo "@" ] host [ ":" port ]
    */
    private func parseAuthority() throws -> [Byte]? {
        /*
         The authority component is preceded by a double slash ("//") and is
         terminated by the next slash ("/"), question mark ("?"), or number
         sign ("#") character, or by the end of the URI.
         
         If first two characters are NOT `//` then we return them back to buffer
         and continue next parsing since they don't apply to an authority
         */
        guard let first = next() else {
            return nil
        }
        guard first == .forwardSlash else {
            localBuffer.append(first)
            return nil
        }
        guard let second = next() else {
            localBuffer.append(first)
            return nil
        }
        guard second == .forwardSlash else {
            localBuffer.append(first)
            localBuffer.append(second)
            return nil
        }

        var authority: [Byte] = []
        while let next = next() {
            if next.equals(any: .forwardSlash, .questionMark, .numberSign) {
                // return token to buffer so we know how to parse next section
                localBuffer.append(next)
                break
            } else if next.isValidUriCharacter {
                // this allows general delimitters to be included aside from '/', '?', and '#' mentioned explicitly above
                authority.append(next)
            } else {
                throw "found invalid authority character: \(Character(next))"
            }
        }
        return authority
    }

    /*
     // TODO: Reference RFC
     
     -- ends w/ '#' || '?' || end of line
     -- if authority, first line MUST be '/'

     RFC: path MUST exist, but CAN be empty
     */
    private func parsePath(uriContainsAuthority: Bool) throws -> [Byte] {
        guard let first = next() else { return [] } // ok for path to be empty
        if first.equals(any: .numberSign, .questionMark) {
            // path is empty, we should parse query or fragment -- return token to buffer
            localBuffer.append(first)
            return []
        }

        /*
         If a URI contains an authority component, then the path component
         must either be empty or begin with a slash ("/") character.
         */
        if uriContainsAuthority && first != .forwardSlash {
            throw "path following authority MUST begin with forwardSlash"
        }

        var path: [Byte]

        if first == .forwardSlash {
            path = []
        } else if first.isUnreservedUriCharacter {
            path = [first]
        } else {
            throw "path"
        }

        while let next = next() {
            if next.equals(any: .numberSign, .questionMark) {
                // return identification token to buffer
                localBuffer.append(next)
                break
            } else if next.isValidUriCharacter { // anything but '#', and '?'
                path.append(next)
            } else {
                throw "found invalid path character: \(next)"
            }
        }

        return path
    }

    /**
     // TODO: Reference RFC
     
     -- starts at '?' -- runs to '#' || end of bytes
     */
    private func parseQuery() throws -> [Byte]? { // query can be `nil`
        guard let first = next() else { return nil }
        guard first == .questionMark else {
            // This byte isn't for us, return it to buffer
            localBuffer.append(first)
            return nil
        }

        var query: [Byte] = []
        while let next = next() {
            if next.equals(any: .numberSign) {
                // return identification token to buffer
                localBuffer.append(next)
                break
            } else if next.isValidUriCharacter {
                query.append(next)
            } else {
                throw "found invalid query character: \(next)"
            }
        }
        return query
    }

    /*
     // TODO: Reference RFC -- starts at `#` goes to end of bytes
     */
    private func parseFragment() throws -> [Byte]? {
        guard let first = next() else {
            return nil
        }
        guard first == .numberSign else {
            localBuffer.append(first)
            return nil
        }

        var fragment: [Byte] = [first]
        while let next = next() {
            if next.isValidUriCharacter {
                fragment.append(next)
            } else {
                throw "found invlid fragment character: \(next)"
            }
        }
        return fragment
    }

    // MARK: Next

    // wrapping next to omit white space characters -- allowed to inject whitespace in url

    private func next() -> Byte? {
        /*
         local buffer is used to maintain last bytes while still interacting w/ byte buffer
         */
        guard localBuffer.isEmpty else {
            return localBuffer.removeFirst()
        }

        while let next = buffer.next() {
            guard !next.isWhitespace else { continue }
            return next
        }

        return nil
    }
}

extension Equatable {
    func equals(any: Self...) -> Bool {
        return any.contains(self)
    }
}


// [WARNING] *********
// TODO: When authority is present, the path must either be empty or begin with a slash ("/") character.
// When authority is NOT present, the path cannot begin with two slash characters ("//")
// *************

public final class URIParser {
    // TODO: Take Stream instead of streambuffer so can be used externally?
    private let buffer: StreamBuffer
    public init(_ stream: Stream) {
        self.buffer = StreamBuffer(stream, buffer: 1024)
    }

    // MARK: Parse

    public func parse() throws -> URI {
        _ = try parseScheme()
        _ = try parseAuthority()
        throw ""
    }

    // MARK: Private

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

     - begin with letter
     - followed by any combination of letter, digit, '+', '.', '-'
     - parse case insensitive (for robustness), schemes are case insensitive
     - serialize lowercase ALWAYS

     */
    private func parseScheme() throws -> String {
        /*
         scheme      = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
         */
        var scheme: [Byte] = []

        // TODO: Skip whitespace?

        /*
         All failures to adhere to protocol MUST throw errors for security concerns
        
         When presented with a URI that violates one or more scheme-specific
         restrictions, the scheme-specific resolution process should flag the
         reference as an error rather than ignore the unused parts; doing so
         reduces the number of equivalent URIs and helps detect abuses of the
         generic syntax, which might indicate that the URI has been
         constructed to mislead the user
         */
        guard let first = try buffer.next() where first.isLetter else {
            throw "first byte must be letter"
        }
        scheme.append(first)
        // TODO:
        // last letter is delimitter and can be discarded?
        // Scheme does NOT support percent encoding
        while let nextLetter = try buffer.next() where nextLetter.isValidSchemeCharacter {
            scheme.append(nextLetter)
        }

        // Scheme does NOT support percent encoding, nothing to do here
        return try scheme.toString()
    }

    private func _parseAuthoritySegment() throws -> (authoritySegment: [Byte], terminator: Byte) {
        /*
         The authority component is preceded by a double slash ("//") and is
         terminated by the next slash ("/"), question mark ("?"), or number
         sign ("#") character, or by the end of the URI.

         authority   = [ userinfo "@" ] host [ ":" port ]
         */
        let slashes = try buffer.chunk(size: 2)
        guard slashes.count == 2 && slashes.first == .forwardSlash && slashes.last == .forwardSlash else {
            throw "must lead with two forward slashes"
        }

        var terminator: Byte = .forwardSlash
        var authorityBytes: [Byte] = []
        while let next = try buffer.next() {
            if next.isAuthorityTerminator {
                terminator = next
                break
            } else {
                authorityBytes.append(next)
            }
        }

        return (authorityBytes, terminator)
    }

    // https://tools.ietf.org/html/rfc3986#section-3.2
    private func parseAuthority() throws -> [Byte] {
        // TODO: Skip whitespace?

        /*
         The authority component is preceded by a double slash ("//") and is
         terminated by the next slash ("/"), question mark ("?"), or number
         sign ("#") character, or by the end of the URI.
         
         authority   = [ userinfo "@" ] host [ ":" port ]
         */
        let slashes = try buffer.chunk(size: 2)
        guard slashes.count == 2 && slashes.first == .forwardSlash && slashes.last == .forwardSlash else {
            throw "must lead with two forward slashes"
        }

        var authorityBytes: [Byte] = []
        while let next = try buffer.next() where !next.isAuthorityTerminator {
            authorityBytes.append(next)
        }

        let authorityComponents = authorityBytes.split(separator: .atSign)
        guard 1...2 ~= authorityComponents.count else {
            throw "unexpected number of authority components"
        }

        var userInfo: Authority.UserInfo? = nil
        if authorityComponents.count == 2, let rawInfo = authorityComponents.first {
            userInfo = try parseUserInfo(from: Array(rawInfo))
        }

//        var host


        // hostAndPort is always last component regardless of whether user info exists
        guard let hostAndPort = authorityComponents.last else {
            throw "must be at least one component for host in authority"
        }

        let (host, port) = try parseHostAndPort(from: Array(hostAndPort))

        /*
         The userinfo subcomponent may consist of a user name and, optionally,
         scheme-specific information about how to gain authorization to access
         the resource
         */
//        var userInfo: [Byte]? = nil
//        if authorityComponents.count == 2 {
//            let rawInfo = try authorityComponents[0]
//            let info = parseUserInfo(from: Array(rawInfo))
//        }
//        if authorityComponents.count == 2,
//            let userInfo = authorityComponents.first,
//            let hostAndPort = authorityComponents.last {
//
//        }

        return authorityBytes
        // TODO: this can be end of URI, needs to be supported if so
    }

    private func parseUserInfo(from bytes: [Byte]) throws -> Authority.UserInfo {
        /*
         Applications should not render as clear text any data
         after the FIRST colon (":")
         */
        let split = bytes.split(separator: .colon, maxSplits: 1, omittingEmptySubsequences: true)
        guard split.count <= 2 else {
            throw "w/ max splits at 1, don't see how possible to be > 2, perhaps remove"
        }

        guard let name = try split.first?.toString() else {
            throw "unable to gather username"
        }

        var auth: String? = nil
        if split.count == 2 {
            auth = try split.last?.toString()
        }

        // *******
        // TODO: Does Not account for PCT encoding!!!
        // *******
        return Authority.UserInfo(userName: name, auth: auth)
    }

    private func parseHostAndPort(from bytes: [Byte]) throws -> (host: Host, port: Int) {
        guard let firstCharacter = try buffer.next() else { throw "missing byte" }


        // Square brackets are ONLY applicable to host
        if firstCharacter == .leftSquareBracket {
            // is IPv6 or IPvFuture
            var ipv6orFuture: [Byte] = []
            while let next = try buffer.next() where next != .rightSquareBracket {
                ipv6orFuture.append(next)
            }
        } else {
            /*
             // is IPv4 or regular name
             
             RFC:
             In order to
             disambiguate the syntax, we apply the "first-match-wins" algorithm:
             If host matches the rule for IPv4address, then it should be
             considered an IPv4 address literal and not a reg-name.
             */
            var hostBytes: [Byte] = []
            while let next = try buffer.next() where next != .colon {

            }

        }


        fatalError()
    }
}

/*
// TODO: A scheme may define a default port.  For example, the "http" scheme
defines a default port of "80", corresponding to its reserved TCP
port number.  The type of port designated by the port number (e.g.,
TCP, UDP, SCTP) is defined by the URI scheme.  URI producers and
normalizers should omit the port component and its ":" delimiter if
port is empty or if its value would be the same as that of the
scheme's default.
 */

extension Byte {

}

/*
 -- The URI reference is parsed into the five URI components
 --
 (R.scheme, R.authority, R.path, R.query, R.fragment) = parse(R);
 */

/**
 // TODO: The whitespace should be ignored when the URI is extracted.
 also: Using <> angle brackets around each URI is especially recommended as
 a delimiting style for a reference that contains embedded whitespace.
 
 so trailing and leading whitespace " or <>
 and intermittently, whitespace can be added wherever. it should be ignored
 */
// TEST CASES

/*
 PCT Encoding all over
 
 https://@google.com // empty user info
 https://usename:@google.com // empty auth

 */

struct Authority {
    /*
    Many URI schemes include a hierarchical element for a naming
    authority so that governance of the name space defined by the
    remainder of the URI is delegated to that authority (which may, in
    turn, delegate it further).  The generic syntax provides a common
    means for distinguishing an authority based on a registered name or
    server address, along with optional port and user information.

    The authority component is preceded by a double slash ("//") and is
    terminated by the next slash ("/"), question mark ("?"), or number
    sign ("#") character, or by the end of the URI.

        authority   = [ userinfo "@" ] host [ ":" port ]
     */

}

extension Authority {
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
    struct UserInfo {
        let userName: String
        /**
         User info may OPTIONALLY include auth metadata, but use of this field as a password is DEPRECATED.
         
         should NOT be displayed to end user
         */
        let auth: String?
    }
}

extension Authority {
    /*
     // TODO: Host should be further parsed out
     // Handle IPv4, IPv6, and reg-name
     // IP-Future -- throw unsupported error for "address mechanism not supported".

     https://tools.ietf.org/html/rfc3986#section-3.2.2
     
     The host subcomponent of authority is identified by an IP literal
     encapsulated within square brackets, an IPv4 address in dotted-
     decimal form, or a registered name.
     
     Note on IPv4 vs NAME:

     The syntax rule for host is ambiguous because it does not completely
     distinguish between an IPv4address and a reg-name.  In order to
     disambiguate the syntax, we apply the "first-match-wins" algorithm:
     If host matches the rule for IPv4address, then it should be
     considered an IPv4 address literal and not a reg-name.
     
     host        = IP-literal / IPv4address / reg-name
     */
    enum Host {
        // TODO:
        // literal encompasses v6 and vFuture -- not handling right now
        case ipLiteral(String)
        case ipV4(String)
        case name(String)
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
    var isValidFragmentCharacter: Bool {
        // TODO: Fragment runs to end, should General delimitter throw error after that?
        return isValidPathCharacter
    }

    var isValidPathCharacter: Bool {
        /*
         // TODO: Be more accurate to RFC:
         
         https://tools.ietf.org/html/rfc3986#section-3.3
         
         path          = path-abempty    ; begins with "/" or is empty
         / path-absolute   ; begins with "/" but not "//"
         / path-noscheme   ; begins with a non-colon segment
         / path-rootless   ; begins with a segment
         / path-empty      ; zero characters

         path-abempty  = *( "/" segment )
         path-absolute = "/" [ segment-nz *( "/" segment ) ]
         path-noscheme = segment-nz-nc *( "/" segment )
         path-rootless = segment-nz *( "/" segment )
         path-empty    = 0<pchar>




         Berners-Lee, et al.         Standards Track                    [Page 22]

         RFC 3986                   URI Generic Syntax               January 2005


         segment       = *pchar
         segment-nz    = 1*pchar
         segment-nz-nc = 1*( unreserved / pct-encoded / sub-delims / "@" )
         ; non-zero-length segment without any colon ":"

         pchar         = unreserved / pct-encoded / sub-delims / ":" / "@"
         */
        return isUnreservedUriCharacter || isSubDelimitter || self.equals(any: .colon, .atSign) // TODO: ? can this be in path?
    }
    var isValidQueryCharacter: Bool {
        return isUnreservedUriCharacter || isSubDelimitter
    }

    var isValidUriCharacter: Bool {
        return isUnreservedUriCharacter || isGeneralDelimitter || isSubDelimitter
    }

    // TODO: This will break on Percent Encoding
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
        // TODO: Look into this
        // removing it WILL break the parser as currently implemented
        case "%": // Allows percent encoding to not fail our test???
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

    /*
     Scheme names consist of a sequence of characters beginning with a
     letter and followed by any combination of letters, digits, plus
     ("+"), period ("."), or hyphen ("-").
    */
    var isValidSchemeCharacter: Bool {
        let char = Character(self)
        switch char {
        case "a"..."z":
            return true
        // case insensitive, should be lowercased. RFC specifies should handle capital for robustness
        case "A"..."Z":
            return true
        case "+", ".", "-":
            return true
        default:
            return false
        }
    }
}
