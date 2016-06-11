final class HTTPParser: StreamParser {
    enum Error: ErrorProtocol {
        case streamEmpty
    }

    let buffer: StreamBuffer

    /**
        Creates a new HTTP Parser that will
        receive serialized request data from
        the supplied stream.
    */
    init(stream: Stream) {
        self.buffer = StreamBuffer(stream)
    }

    /**
        Reads and filters non-valid ASCII characters
        from the stream until a new line character is returned.
    */
    func nextLine() throws -> Data {
        var line: Data = []

        while let byte = try buffer.next() where byte != .newLine {
            // Skip over any non-valid ASCII characters
            if byte > .carriageReturn {
                line.append(byte)
            }
        }

        return line
    }

    /**
        Parses serialized request data from
        the stream following HTTP/1.0 or HTTP/1.1
        protocol.
    */
    func parse() throws -> Request {
        let requestLineString = try nextLine()
        Log.info("Requestline:\n\t\(requestLineString)")
        guard !requestLineString.isEmpty else {
            // If the stream is empty, close connection immediately
            throw Error.streamEmpty
        }

        // TODO: Actually parse
        let requestLine = try RequestLine(requestLineString)

        var headers: [Request.Headers.Key: String] = [:]

        while true {
            let headerLine = try nextLine()
            Log.info("Header:\n\t\(headerLine)")
            if headerLine.isEmpty {
                // We've reached the end of the headers
                break
            }

            // TODO: Check is line has leading white space
            // This should be converted to values for the
            // previous header

            let comps = headerLine.split(separator: .colon)

            guard comps.count == 2 else {
                continue
            }

            let key = Request.Headers.Key(Data(comps[0]).string)

            // TODO: Trim header value from excess whitespace

            let val = Data(comps[1]).string

            headers[key] = val.trim()
        }

        let body: Data

        // TODO: Support transfer-encoding: chunked

        if let contentLength = headers["content-length"]?.int {
            body = try buffer.next(chunk: contentLength)
        } else if
            let transferEncoding = headers["transfer-encoding"]?.string
            where transferEncoding.lowercased() == "chunked"
        {
            var buffer: Data = []

            while true {
                let lengthData = try nextLine()

                // size must be sent
                guard lengthData.count > 0 else {
                    break
                }

                // convert hex length data to int
                guard let length = lengthData.int else {
                    break
                }

                // end of chunked encoding
                if length == 0 {
                    break
                }

                let content = try self.buffer.next(chunk: length + 2)
                buffer.bytes += content.bytes
            }

            body = buffer
        } else {
            body = []
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



extension Array where Element: Hashable {
    /**
     This function is intended to be as performant as possible, which is part of the reason 
     why some of the underlying logic may seem a bit more tedious than is necessary
     */
    func trimmed(_ elements: [Element]) -> SubSequence {
        guard !isEmpty else { return [] }

        let lastIdx = self.count - 1
        var leadingIterator = self.indices.makeIterator()
        var trailingIterator = leadingIterator

        var leading = 0
        var trailing = lastIdx
        while let next = leadingIterator.next() where elements.contains(self[next]) {
            leading += 1
        }
        while let next = trailingIterator.next() where elements.contains(self[lastIdx - next]) {
            trailing -= 1
        }

        return self[leading...trailing]
    }
}


extension ArraySlice where Element: Hashable {
    /**
     This function is intended to be as performant as possible, which is part of the reason
     why some of the underlying logic may seem a bit more tedious than is necessary
     */
    func trimmed(_ elements: [Element]) -> SubSequence {
        guard !isEmpty else { return [] }

        let firstIdx = startIndex
        let lastIdx = endIndex - 1// self.count - 1

        var leadingIterator = self.indices.makeIterator()
        var trailingIterator = leadingIterator

        var leading = firstIdx
        var trailing = lastIdx
        while let next = leadingIterator.next() where elements.contains(self[next]) {
            leading += 1
        }
        while let next = trailingIterator.next() where elements.contains(self[lastIdx - next]) {
            trailing -= 1
        }

        return self[leading...trailing]
    }
}

private let GET = "GET".bytesSlice
private let POST = "POST".bytesSlice
private let PUT = "PUT".bytesSlice
private let PATCH = "PATCH".bytesSlice
private let DELETE = "DELETE".bytesSlice
private let OPTIONS = "OPTIONS".bytesSlice
private let HEAD = "HEAD".bytesSlice
private let CONNECT = "CONNECT".bytesSlice
private let TRACE = "TRACE".bytesSlice


extension Request.Method {
    init(uppercase method: BytesSlice) {
        switch method {
        case GET:
            self = .get
        case POST:
            self = .post
        case PUT:
            self = .put
        case PATCH:
            self = .patch
        case DELETE:
            self = .delete
        case OPTIONS:
            self = .options
        case HEAD:
            self = .head
        case CONNECT:
            self = .connect
        case TRACE:
            self = .trace
        default:
            self = .other(method: method.string)
        }
    }
}


// MARK: RObustness 

/*
 
 ******* ##################### **********
 *                                      *
 *                                      *
 *                                      *
 *            robustness                *
 *                                      *
 *                                      *
 *                                      *
 ******* ##################### **********

 3.5.  Message Parsing Robustness

 Older HTTP/1.0 user agent implementations might send an extra CRLF
 after a POST request as a workaround for some early server
 applications that failed to read message body content that was not
 terminated by a line-ending.  An HTTP/1.1 user agent MUST NOT preface
 or follow a request with an extra CRLF.  If terminating the request
 message body with a line-ending is desired, then the user agent MUST
 count the terminating CRLF octets as part of the message body length.

 In the interest of robustness, a server that is expecting to receive
 and parse a request-line SHOULD ignore at least one empty line (CRLF)
 received prior to the request-line.




 Fielding & Reschke           Standards Track                   [Page 34]

 RFC 7230           HTTP/1.1 Message Syntax and Routing         June 2014


 Although the line terminator for the start-line and header fields is
 the sequence CRLF, a recipient MAY recognize a single LF as a line
 terminator and ignore any preceding CR.

 Although the request-line and status-line grammar rules require that
 each of the component elements be separated by a single SP octet,
 recipients MAY instead parse on whitespace-delimited word boundaries
 and, aside from the CRLF terminator, treat any form of whitespace as
 the SP separator while ignoring preceding or trailing whitespace;
 such whitespace includes one or more of the following octets: SP,
 HTAB, VT (%x0B), FF (%x0C), or bare CR.  However, lenient parsing can
 result in security vulnerabilities if there are multiple recipients
 of the message and each has its own unique interpretation of
 robustness (see Section 9.5).

 When a server listening only for HTTP request messages, or processing
 what appears from the start-line to be an HTTP request message,
 receives a sequence of octets that does not match the HTTP-message
 grammar aside from the robustness exceptions listed above, the server
 SHOULD respond with a 400 (Bad Request) response.
 */

extension String: ErrorProtocol {}
/**
 
 ****************************** WARNING ******************************
 
 (reminders)
 
 ******************************
 
 A
 server MUST reject any received request message that contains
 whitespace between a header field-name and colon with a response code
 of 400 (Bad Request).
 
 ******************************
 
 A proxy or gateway that receives an obs-fold in a response message
 that is not within a message/http container MUST either discard the
 message and replace it with a 502 (Bad Gateway) response, preferably
 with a representation explaining that unacceptable line folding was
 received, or replace each received obs-fold with one or more SP
 octets prior to interpreting the field value or forwarding the
 message downstream.
 
 ******************************

 The presence of a message body in a response depends on both the
 request method to which it is responding and the response status code
 (Section 3.1.2).  Responses to the HEAD request method (Section 4.3.2
 of [RFC7231]) never include a message body because the associated
 response header fields (e.g., Transfer-Encoding, Content-Length,
 etc.), if present, indicate only what their values would have been if
 the request method had been GET (Section 4.3.1 of [RFC7231]). 2xx
 (Successful) responses to a CONNECT request method (Section 4.3.6 of
 [RFC7231]) switch to tunnel mode instead of having a message body.
 All 1xx (Informational), 204 (No Content), and 304 (Not Modified)
 responses do not include a message body.  All other responses do
 include a message body, although the body might be of zero length.

 ******************************
 
 A server MAY send a Content-Length header field in a response to a
 HEAD request (Section 4.3.2 of [RFC7231]); a server MUST NOT send
 Content-Length in such a response unless its field-value equals the
 decimal number of octets that would have been sent in the payload
 body of a response if the same request had used the GET method.
 
 *****************************
 
 If a message is received that has multiple Content-Length header
 fields with field-values consisting of the same decimal value, or a
 single Content-Length header field with a field value containing a
 list of identical decimal values (e.g., "Content-Length: 42, 42"),
 indicating that duplicate Content-Length header fields have been
 generated or combined by an upstream message processor, then the
 recipient MUST either reject the message as invalid or replace the
 duplicated field-values with a single valid Content-Length field
 containing that decimal value prior to determining the message body
 length or forwarding the message.
 
 ******************************

 A recipient MUST ignore unrecognized chunk extensions.

 ******************************
 */

/*
All HTTP/1.1 messages consist of a start-line followed by a sequence
of octets in a format similar to the Internet Message Format
[RFC5322]: zero or more header fields (collectively referred to as
the "headers" or the "header section"), an empty line indicating the
end of the header section, and an optional message body.

HTTP-message   = start-line
*( header-field CRLF )
CRLF
[ message-body ]
*/
final class RequestParser {
    enum Error: ErrorProtocol {
        case streamEmpty
    }

    private var localBuffer: [Byte] = []
    private let buffer: StreamBuffer

    /**
     Creates a new HTTP Parser that will
     receive serialized request data from
     the supplied stream.
     */
    init(stream: Stream) {
        self.buffer = StreamBuffer(stream)
    }

    func parse() throws -> Request {
        let (method, uri, httpVersion) = try parseRequestLine()
//        print("Got request line:\n\t\(method.string) \(uri.string) \(httpVersion.string)")
//        guard try !next(equalsAny: .space, .carriageReturn, .lineFeed, .horizontalTab) else {
//            throw "line after request line must not begin with whitespace"
//        }


        let headers = try parseHeaders()
//        let style = BodyStyle(headers)
        let body = try parseBody(headers: headers) // TODO:

        let u = try URIParser.parse(uri: uri)
        //let u = URI(scheme: nil, userInfo: nil, host: nil, port: nil, path: "plaintext", query: nil, fragment: nil)
        return Request(
            method: Request.Method(uppercase: method),
            uri: u,
            version: Request.Version(major: 1, minor: 1), // TODO:
            headers: headers,
            body: .buffer(Data(body))
        )
//        return Request(method: .get, path: "/", host: "*", headers: h, data: Data([]))
    }

    private func parseBody(headers: Request.Headers) throws -> Bytes {
        let body: Bytes

        // TODO: Support transfer-encoding: chunked

        if let contentLength = headers["content-length"]?.int {
            body = try next(chunk: contentLength)
        } else if
            let transferEncoding = headers["transfer-encoding"]?.string
            where transferEncoding.lowercased() == "chunked"
        {
            var buffer: Bytes = []

            while true {
                let lengthData = try nextLine()

                // size must be sent
                guard lengthData.count > 0 else {
                    break
                }

                // convert hex length data to int
                guard let length = lengthData.int else {
                    break
                }

                // end of chunked encoding
                if length == 0 {
                    break
                }

                let content = try next(chunk: length + 2)
                buffer += content
            }
            
            body = buffer
        } else {
            body = []
        }

        return body
    }


    /*
     https://tools.ietf.org/html/rfc2616#section-5.1

     The Request-Line begins with a method token, followed by the
     Request-URI and the protocol version, and ending with CRLF. The
     elements are separated by SP characters. No CR or LF is allowed
     except in the final CRLF sequence.

     Request-Line   = Method SP Request-URI SP HTTP-Version CRLF

     *** [WARNING] ***
     Recipients of an invalid request-line SHOULD respond with either a
     400 (Bad Request) error or a 301 (Moved Permanently) redirect with
     the request-target properly encoded.  A recipient SHOULD NOT attempt
     to autocorrect and then process the request without a redirect, since
     the invalid request-line might be deliberately crafted to bypass
     security filters along the request chain.
     */
    func parseRequestLine() throws -> (method: ArraySlice<Byte>, uri: ArraySlice<Byte>, httpVersion: ArraySlice<Byte>) {
        let line = try nextLine()

        let comps = line.split(separator: .space)

        guard comps.count == 3 else {
            throw "invalid request line"
        }

        return (comps[0], comps[1], comps[2])
    }

//    /*
//     HTTP-message   = start-line
//     *( header-field CRLF )
//     CRLF
//     [ message-body ]
//     */
//    func parseHeaders() throws -> [String: String] {
//        let headerSection = try collect(untilMatches: [.carriageReturn, .lineFeed, .carriageReturn, .lineFeed])
//        try discardNext(4)
//
//        var headers: [String: String] = [:]
//        let lines = headerSection.split(separator: .lineFeed, omittingEmptySubsequences: true)
//        try lines.forEach { line in
//            let comps = line.split(separator: .colon, maxSplits: 1, omittingEmptySubsequences: false)
//            /*
//             // TODO: assert header has no trailing or leading space!
//             RFC:
//             No whitespace is allowed between the header field-name and colon.
//             Might just be fIrst header line can't have leading, but I think it's all
//             */
//            guard comps.count == 2 else { throw "invalid header field" }
//            let field = comps[0].string
//            let value = comps[1].trimmed([.space, .carriageReturn, .lineFeed, .horizontalTab]).string
//            headers[field] = value
//        }
//        return headers
//    }

    /*
        HTTP-message   = start-line
        *( header-field CRLF )
        CRLF
        [ message-body ]
    */
    func parseHeaders() throws -> Request.Headers {
        var headers: Request.Headers = [:]

        var lastField: Request.Headers.Key? = nil

        while true {
            let line = try nextLine()

            if line.isEmpty {
                break
            }

            if line[0].isWhitespace {
                guard let lastField = lastField else {
                    throw "Cannot have leading white space on the first line"
                }

                let value = parseHeaderValue(line)
                headers[lastField]?.append(value)
            } else {
                let comps = line.split(separator: .colon, maxSplits: 1)
                guard comps.count == 2 else {
                    print(line.string)
                    continue
                }

                /*
                    // TODO: assert header has no trailing or leading space!
                    RFC:

                    No whitespace is allowed between the header field-name and colon.
                    Might just be fIrst header line can't have leading, but I think it's all
                */
                let field = Request.Headers.Key(comps[0].string)
                let value = parseHeaderValue(comps[1])
                
                headers[field] = value
                
                lastField = field
            }
        }

        return headers
    }

    func parseHeaderValue(_ bytes: Bytes) -> String {
        return bytes.trimmed([.space, .horizontalTab]).string
    }

    func parseHeaderValue(_ bytes: BytesSlice) -> String {
        return bytes.trimmed([.space, .horizontalTab]).string
    }

//    /*
//     HTTP-message   = start-line
//     *( header-field CRLF )
//     CRLF
//     [ message-body ]
//     */
//    func parseHeaders() throws -> [(field: [Byte], value: [Byte])] {
//        var headers: [(field: [Byte], value: [Byte])] = []
//        // Header fields section is terminated by a leading CRLF
//        while try !next(matches: [.carriageReturn, .lineFeed]) {
//            guard let (header, value) = try parseNextHeader() else { return headers }
//            headers.append((header, value))
//        }
//        try discardNext(2) // discard CRLF
//        return headers
//    }

    /*
     HTTP-message   = start-line
     *( header-field CRLF )
     CRLF
     [ message-body ]
     */
    func __parseHeaders() throws -> [String: String] {
        var headers: [String: String] = [:]
        // Header fields section is terminated by a leading CRLF
        while try !next(matches: [.carriageReturn, .newLine]) {
            guard let fieldBytes = try __parseHeaderField() else { return headers }
            let valueBytes = try __parseHeaderValue()
            let field = try fieldBytes.toString()
            let value = try valueBytes.trimmed([.space, .carriageReturn, .horizontalTab, .newLine]).toString()
            headers[field] = value
        }
        try discardNext(2) // discard CRLF
        return headers
    }


    func __parseHeaderField() throws -> [Byte]? {
        let field = try collect(until: .colon, discardDelimitterIfFound: true)
        /*
         No whitespace is allowed between the header field-name and colon.  In
         the past, differences in the handling of such whitespace have led to
         security vulnerabilities in request routing and response handling.  A
         server MUST reject any received request message that contains
         whitespace between a header field-name and colon with a response code
         of 400 (Bad Request).
         */
        guard !field.isEmpty else { return nil } // empty is ok
        guard field.last?.isWhitespace == false else { throw "must not be space between header field and ':' \(field)" }
        return field
    }

    func __parseHeaderValue() throws -> [Byte] {
        try skipWhiteSpace()
        let value = try collect(untilMatches: [.carriageReturn, .newLine])
        try discardNext(2)// discard 'CRLF'

        /*
         Historically, HTTP header field values could be extended over
         multiple lines by preceding each extra line with at least one space
         or horizontal tab (obs-fold).  This specification deprecates such
         line folding except within the message/http media type
         (Section 8.3.1).  A sender MUST NOT generate a message that includes
         line folding (i.e., that has any field-value that contains a match to
         the obs-fold rule) unless the message is intended for packaging
         within the message/http media type.

         Although deprecated and we MUST NOT generate, it is POSSIBLE for older
         systems to use this style of communication and we need to support it
         */
        guard try next(equalsAny: .space, .horizontalTab) else { return value }
        /**
         Suggestion to clients when generating is to convert obs-fold to space, we'll do same in parsing.
         */
        return try value + [.space] + parseHeaderValue()
    }

    /**
     https://tools.ietf.org/html/rfc7230#section-3

     ******* [WARNING] ********

     A sender MUST NOT send whitespace between the start-line and the
     first header field.  A recipient that receives whitespace between the
     start-line and the first header field MUST either reject the message
     as invalid or consume each whitespace-preceded line without further
     processing of it (i.e., ignore the entire line, along with any
     subsequent lines preceded by whitespace, until a properly formed
     header field is received or the header section is terminated).

     The presence of such whitespace in a request might be an attempt to
     trick a server into ignoring that field or processing the line after
     it as a new request, either of which might result in a security
     vulnerability if other implementations within the request chain
     interpret the same message differently.  Likewise, the presence of
     such whitespace in a response might be ignored by some clients or
     cause others to cease parsing.
     */
    func renameAndClarifyButThisIsNecessaryToSkipLeadingWhitespaceLinesFollowingRequestLine() throws {
        guard let next = try next() else { return }
        if next.isWhitespace { throw "can throw or skip lines w/ leading spaces: \(Character(next))" }
        else { returnToBuffer(next) }
    }

    /*
     https://tools.ietf.org/html/rfc7230#section-3.2

     Each header field consists of a case-insensitive field name followed
     by a colon (":"), optional leading whitespace, the field value, and
     optional trailing whitespace.

     header-field   = field-name ":" OWS field-value OWS

     field-name     = token
     field-value    = *( field-content / obs-fold )
     field-content  = field-vchar [ 1*( SP / HTAB ) field-vchar ]
     field-vchar    = VCHAR / obs-text

     obs-fold       = CRLF 1*( SP / HTAB )
     ; obsolete line folding
     ; see Section 3.2.4

     The field-name token labels the corresponding field-value as having
     the semantics defined by that header field.  For example, the Date
     header field is defined in Section 7.1.1.2 of [RFC7231] as containing
     the origination timestamp for the message in which it appears.
     
     HTTP-message   = start-line
     *( header-field CRLF )
     CRLF
     [ message-body ]
     */
    func parseNextHeader() throws -> (field: [Byte], value: [Byte])? {
        guard let field = try parseHeaderField() else { return nil }
        let value = try parseHeaderValue()
        return (field, value)
    }

    func parseHeaderField() throws -> [Byte]? {
        let field = try collect(until: .colon, discardDelimitterIfFound: true)
        /*
         No whitespace is allowed between the header field-name and colon.  In
         the past, differences in the handling of such whitespace have led to
         security vulnerabilities in request routing and response handling.  A
         server MUST reject any received request message that contains
         whitespace between a header field-name and colon with a response code
         of 400 (Bad Request).
         */
        guard !field.isEmpty else { return nil } // empty is ok
        guard field.last?.isWhitespace == false else { throw "must not be space between header field and ':' \(field)" }
        return field
    }

    func parseHeaderValue() throws -> [Byte] {
        try skipWhiteSpace()
        let value = try collect(untilMatches: [.carriageReturn, .newLine])
        try discardNext(2)// discard 'CRLF'

        /*
         Historically, HTTP header field values could be extended over
         multiple lines by preceding each extra line with at least one space
         or horizontal tab (obs-fold).  This specification deprecates such
         line folding except within the message/http media type
         (Section 8.3.1).  A sender MUST NOT generate a message that includes
         line folding (i.e., that has any field-value that contains a match to
         the obs-fold rule) unless the message is intended for packaging
         within the message/http media type.
         
         Although deprecated and we MUST NOT generate, it is POSSIBLE for older 
         systems to use this style of communication and we need to support it
         */
        guard try next(equalsAny: .space, .horizontalTab) else { return value }
        /**
         Suggestion to clients when generating is to convert obs-fold to space, we'll do same in parsing.
         */
        return try value + [.space] + parseHeaderValue()
    }

    // TODO: This assumes line termination is ok -- other functions do as well. I _believe_ this is the appropriate handling, but double check
    func collect(untilMatches expectation: [Byte]) throws -> [Byte] {
        guard !expectation.isEmpty else { return [] }
        var collection: [Byte] = []
        while try !next(matches: expectation), let byte = try next() {
            collection.append(byte)
        }
        return collection
    }

    private func next(equalsAny expectations: Byte...) throws -> Bool {
        guard let next = try next() else { return false }
        returnToBuffer(next)
        return next.equals(any: expectations)
    }

    private func next(matches expectations: [Byte]) throws -> Bool {
        let next = try collect(next: expectations.count)
        returnToBuffer(next)
        return next == expectations
    }

    /**
        Reads and filters non-valid ASCII characters
        from the stream until a new line character is returned.
    */
    func nextLine() throws -> Bytes {
        var line: Bytes = []

        var lastByte: Byte? = nil

        while let byte = try buffer.next() {
            // Continues until a `crlf` sequence is found
            if byte == .newLine && lastByte == .carriageReturn {
                break
            }

            // Skip over any non-valid ASCII characters
            if byte > .carriageReturn {
                line += byte
            }

            lastByte = byte
        }

        return line
    }

    func next(chunk size: Int) throws -> Bytes {
        var bytes: Bytes = []

        for _ in 0 ..< size {
            if let byte = try next() {
                bytes += byte
            }
        }

        return bytes
    }

    private func skipWhiteSpace() throws {
        while let next = try next() {
            if next.isWhitespace { continue }

            /*
             Found first non whitespace, return to buffer
             */
            returnToBuffer(next)
            break
        }
    }

    /**
     // TODO: Merge Overlapping Behavior w/ Static Buffer
     */
    // MARK: - ##########

    // MARK: Next

    func next() throws -> Byte? {
        /*
         local buffer is used to maintain last bytes while still interacting w/ byte buffer
         */
        guard localBuffer.isEmpty else {
            return localBuffer.removeFirst()
        }
        return try buffer.next()
    }

    // MARK:

    func returnToBuffer(_ byte: Byte) {
        returnToBuffer([byte])
    }

    func returnToBuffer(_ bytes: [Byte]) {
        localBuffer.append(contentsOf: bytes)
    }

    // MARK: Discard Extranneous Tokens

    func discardNext(_ count: Int) throws {
        try (0 ..< count).forEach { _ in
            _ = try next()
        }
    }

    // MARK: Check Tokens

    func checkLeadingBuffer(matches: Byte...) throws -> Bool {
        return try checkLeadingBuffer(matches: matches)
    }

    func checkLeadingBuffer(matches: [Byte]) throws -> Bool {
        let leading = try collect(next: matches.count)
        returnToBuffer(leading)
        return leading == matches
    }

    // MARK: Collection

    func collect(next count: Int) throws -> [Byte] {
        guard count > 0 else { return [] }

        var body: [Byte] = []
        try (1...count).forEach { _ in
            guard let next = try next() else { return }
            body.append(next)
        }
        return body
    }

    /*
     When in Query segment, `+` should be interpreted as ` ` (space), not sure useful outside of that point
     */
    func collect(until delimitters: Byte..., discardDelimitterIfFound: Bool = false, convertIfNecessary: (Byte) -> Byte = { $0 }) throws -> [Byte] {
        var collected: [Byte] = []
        while let next = try next() {
            if delimitters.contains(next) {
                if !discardDelimitterIfFound {
                    // If the delimitter is also a token that identifies
                    // a particular section of the URI
                    // then we may want to return that byte to the buffer
                    returnToBuffer(next)
                }
                // break regardless
                break
            }

            let converted = convertIfNecessary(next)
            collected.append(converted)
        }
        return collected
    }

        func collectRemaining() throws -> [Byte] {
            var complete: [Byte] = []
            while let next = try next() {
                print("NEXT: \(Character(next))")
                complete.append(next)
            }
            return complete
        }
}

private let transferEncoding = "Transfer-Encoding".utf8.array
private let contentLength = "Content-Length".utf8.array
private let chunkedCoding = "chunked".utf8.array

extension RequestParser {
    enum BodyStyle {
        case chunked
        case length(Int)
        case empty

        init(_ headers: Request.Headers) {
            if let encoding = headers["Transfer-Encoding"] where encoding.hasSuffix("chunked") {
                self = .chunked
            } else if let length = headers["Content-Length"]?.int {
                self = .length(length)
            } else {
                self = .empty
            }
        }
    }

    func parseBodyStyle(headers: [(field: [Byte], value: [Byte])]) throws -> BodyStyle {
        /*
         If a Transfer-Encoding header field is present and the chunked
         transfer coding (Section 4.1) is the final encoding
         
         chunk must be present AND last
         
         // TODO: Is this enforced by everyone? It's in RFC
        */
        if let encoding = headers[transferEncoding] where encoding.suffix(chunkedCoding.count).array == chunkedCoding {
//            print("Chunk encoding")
            return .chunked
        } else if let length = headers[contentLength] {
            // MARK: Convert to string BEFORE converting to Int
            let lengthString = try length.toString()
            // throw or 0 on wrong value
            let length = Int(lengthString) ?? 0
//            print("Length: \(length)")
            return .length(length)
        } else {
//            print("Unknown")
            return .empty
        }

    }
}

extension Sequence where Iterator.Element == (field: [Byte], value: [Byte]) {
    subscript(field: [Byte]) -> [Byte]? {
        for header in self where header.field == field {
            return header.value
        }
        return nil
    }
}

/*
 https://tools.ietf.org/html/rfc7230#section-3.3.3
 
 The length of a message body is determined by one of the following
 (in order of precedence):

 Response
 1.  Any response to a HEAD request and any response with a 1xx
 (Informational), 204 (No Content), or 304 (Not Modified) status
 code is always terminated by the first empty line after the
 header fields, regardless of the header fields present in the
 message, and thus cannot contain a message body.

 Response
 2.  Any 2xx (Successful) response to a CONNECT request implies that
 the connection will become a tunnel immediately after the empty
 line that concludes the header fields.  A client MUST ignore any
 Content-Length or Transfer-Encoding header fields received in
 such a message.

 3.  If a Transfer-Encoding header field is present and the chunked
 transfer coding (Section 4.1) is the final encoding, the message
 body length is determined by reading and decoding the chunked
 data until the transfer coding indicates the data is complete.

 If a Transfer-Encoding header field is present in a response and
 the chunked transfer coding is not the final encoding, the
 message body length is determined by reading the connection until
 it is closed by the server.  If a Transfer-Encoding header field
 is present in a request and the chunked transfer coding is not
 the final encoding, the message body length cannot be determined
 reliably; the server MUST respond with the 400 (Bad Request)
 status code and then close the connection.

 If a message is received with both a Transfer-Encoding and a
 Content-Length header field, the Transfer-Encoding overrides the
 Content-Length.  Such a message might indicate an attempt to
 perform request smuggling (Section 9.5) or response splitting
 (Section 9.4) and ought to be handled as an error.  A sender MUST
 remove the received Content-Length field prior to forwarding such
 a message downstream.

 4.  If a message is received without Transfer-Encoding and with
 either multiple Content-Length header fields having differing
 field-values or a single Content-Length header field having an
 invalid value, then the message framing is invalid and the
 recipient MUST treat it as an unrecoverable error.  If this is a
 request message, the server MUST respond with a 400 (Bad Request)
 status code and then close the connection.  If this is a response
 message received by a proxy, the proxy MUST close the connection
 to the server, discard the received response, and send a 502 (Bad
 Gateway) response to the client.  If this is a response message
 received by a user agent, the user agent MUST close the
 connection to the server and discard the received response.

 5.  If a valid Content-Length header field is present without
 Transfer-Encoding, its decimal value defines the expected message
 body length in octets.  If the sender closes the connection or
 the recipient times out before the indicated number of octets are
 received, the recipient MUST consider the message to be
 incomplete and close the connection.

 6.  If this is a request message and none of the above are true, then
 the message body length is zero (no message body is present).

 7.  Otherwise, this is a response message without a declared message
 body length, so the message body length is determined by the
 number of octets received prior to the server closing the
 connection.

 Since there is no way to distinguish a successfully completed,
 close-delimited message from a partially received message interrupted
 by network failure, a server SHOULD generate encoding or
 length-delimited messages whenever possible.  The close-delimiting
 feature exists primarily for backwards compatibility with HTTP/1.0.

 A server MAY reject a request that contains a message body but not a
 Content-Length by responding with 411 (Length Required).

 Unless a transfer coding other than chunked has been applied, a
 client that sends a request containing a message body SHOULD use a
 valid Content-Length header field if the message body length is known
 in advance, rather than the chunked transfer coding, since some
 existing services respond to chunked with a 411 (Length Required)
 status code even though they understand the chunked transfer coding.
 This is typically because such services are implemented via a gateway
 that requires a content-length in advance of being called and the
 server is unable or unwilling to buffer the entire request before
 processing.

 A user agent that sends a request containing a message body MUST send
 a valid Content-Length header field if it does not know the server
 will handle HTTP/1.1 (or later) requests; such knowledge can be in
 the form of specific user configuration or by remembering the version
 of a prior received response.

 If the final response to the last request on a connection has been
 completely received and there remains additional data to read, a user
 agent MAY discard the remaining data or attempt to determine if that
 data belongs as part of the prior response body, which might be the
 case if the prior message's Content-Length value is incorrect.  A
 client MUST NOT process, cache, or forward such extra data as a
 separate response, since such behavior would be vulnerable to cache
 poisoning.
 */
