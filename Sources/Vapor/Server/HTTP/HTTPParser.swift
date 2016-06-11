//final class HTTPParser: StreamParser {
//    enum Error: ErrorProtocol {
//        case streamEmpty
//    }
//
//    let buffer: StreamBuffer
//
//    /**
//        Creates a new HTTP Parser that will
//        receive serialized request data from
//        the supplied stream.
//    */
//    init(stream: Stream) {
//        self.buffer = StreamBuffer(stream)
//    }
//
//    /**
//        Reads and filters non-valid ASCII characters
//        from the stream until a new line character is returned.
//    */
//    func nextLine() throws -> Data {
//        var line: Data = []
//
//        while let byte = try buffer.next() where byte != .newLine {
//            // Skip over any non-valid ASCII characters
//            if byte > .carriageReturn {
//                line.append(byte)
//            }
//        }
//
//        return line
//    }
//
//    /**
//        Parses serialized request data from
//        the stream following HTTP/1.0 or HTTP/1.1
//        protocol.
//    */
//    func parse() throws -> Request {
//        let requestLineString = try nextLine()
//        Log.info("Requestline:\n\t\(requestLineString)")
//        guard !requestLineString.isEmpty else {
//            // If the stream is empty, close connection immediately
//            throw Error.streamEmpty
//        }
//
//        // TODO: Actually parse
//        let requestLine = try RequestLine(requestLineString)
//
//        var headers: [Request.Headers.Key: String] = [:]
//
//        while true {
//            let headerLine = try nextLine()
//            Log.info("Header:\n\t\(headerLine)")
//            if headerLine.isEmpty {
//                // We've reached the end of the headers
//                break
//            }
//
//            // TODO: Check is line has leading white space
//            // This should be converted to values for the
//            // previous header
//
//            let comps = headerLine.split(separator: .colon)
//
//            guard comps.count == 2 else {
//                continue
//            }
//
//            let key = Request.Headers.Key(Data(comps[0]).string)
//
//            // TODO: Trim header value from excess whitespace
//
//            let val = Data(comps[1]).string
//
//            headers[key] = val.trim()
//        }
//
//        let body: Data
//
//        // TODO: Support transfer-encoding: chunked
//
//        if let contentLength = headers["content-length"]?.int {
//            body = try buffer.next(chunk: contentLength)
//        } else if
//            let transferEncoding = headers["transfer-encoding"]?.string
//            where transferEncoding.lowercased() == "chunked"
//        {
//            var buffer: Data = []
//
//            while true {
//                let lengthData = try nextLine()
//
//                // size must be sent
//                guard lengthData.count > 0 else {
//                    break
//                }
//
//                // convert hex length data to int
//                let length = lengthData.int
//
//                // end of chunked encoding
//                if length == 0 {
//                    break
//                }
//
//                let content = try self.buffer.next(chunk: length + 2)
//                buffer.bytes += content.bytes
//            }
//
//            body = buffer
//        } else {
//            body = []
//        }
//
//        return Request(
//            method: requestLine.method,
//            uri: requestLine.uri,
//            version: requestLine.version,
//            headers: Request.Headers(headers),
//            body: .buffer(body)
//        )
//    }
//}



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

    private let stream: Stream

    /**
     Creates a new HTTP Parser that will
     receive serialized request data from
     the supplied stream.
     */
    init(stream: Stream) {
        self.stream = StreamBuffer(stream)
    }

    func parse() throws -> Request {
        let (methodSlice, uriSlice, versionSlice) = try parseRequestLine()

        // Header parsing will ensure no whitespace
        let headers = try Request.Headers(stream: stream)

        // Request-URI    = "*" | absoluteURI | abs_path | authority
        let uri: URI

        // URI can never be empty
        if uriSlice.first == .forwardSlash {
            // abs_path

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
            */

            let host: String
            let port: Int

            if let hostHeader = headers["host"] {
                let comps = hostHeader.data.split(separator: .colon, maxSplits: 1)
                host = comps[0].string

                if comps.count > 1 {
                    port = comps[1].int
                } else {
                    port = 80
                }
            } else {
                host = "*"
                port = 80
            }

            let comps = uriSlice.split(separator: .questionMark)

            let path = comps[0].string

            let query: String?
            if comps.count > 1 {
                query = comps[1].string
            } else {
                query = nil
            }

            uri = URI(scheme: nil, userInfo: nil, host: host, port: port, path: path, query: query, fragment: nil)
        } else {
            // absoluteURI

            /*
                To allow for transition to absoluteURIs in all requests in future
                versions of HTTP, all HTTP/1.1 servers MUST accept the absoluteURI
                form in requests, even though HTTP/1.1 clients will only generate
                them in requests to proxies.
             
                An example Request-Line would be:

                    GET http://www.w3.org/pub/WWW/TheProject.html HTTP/1.1
            */

            uri = try URIParser.parse(uri: uriSlice)
        }

        let body = try Request.Body(headers: headers, stream: stream)

        // HTTP-Version   = "HTTP" "/" 1*DIGIT "." 1*DIGIT
        let version = Request.Version(versionSlice)

        return Request(
            method: Request.Method(uppercase: methodSlice),
            uri: uri,
            version: version,
            headers: headers,
            body: body
        )
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
        let line = try stream.nextLine()
        guard !line.isEmpty else { return ([], [], []) }

        let comps = line.split(separator: .space, omittingEmptySubsequences: true)
        guard comps.count == 3 else {
            print("line: \(line.string)")
            throw "invalid request line"
        }

        return (comps[0], comps[1], comps[2])
    }
}
