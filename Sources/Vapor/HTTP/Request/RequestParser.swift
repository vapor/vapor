public final class RequestParser {
    enum Error: ErrorProtocol {
        case streamEmpty
        case invalidRequestLine
        case invalidRequest
        case invalidKeyWhitespace
    }

    let stream: Stream
    init(stream: Stream) {
        self.stream = stream
    }

    func parseNext() throws -> Request {
        let (methodSlice, uriSlice, httpVersionSlice) = try parseRequestLine()
        let headers = try parseHeaders()
        let body = try parseBody(with: headers)
        let uri = try parseURI(with: uriSlice, host: headers["host"])
        let version = try parseVersion(httpVersionSlice)
        let method = Request.Method(uppercase: methodSlice)
        return Request(
            method: method,
            uri: uri,
            version: version,
            headers: headers,
            body: .buffer(Data(body))
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
    private func parseRequestLine() throws -> (method: ArraySlice<Byte>, uri: ArraySlice<Byte>, httpVersion: ArraySlice<Byte>) {
        let line = try stream.receiveLine()
        guard !line.isEmpty else { return ([], [], []) }

        let comps = line.split(separator: .space, omittingEmptySubsequences: true)
        guard comps.count == 3 else {
            throw Error.invalidRequestLine
        }

        return (comps[0], comps[1], comps[2])
    }

    private func parseHeaders() throws -> Headers {
        var whitespaceCheck: Bool = false
        var headers: Headers = [:]
        while true {
            let line = try stream.receiveLine()
            guard !line.isEmpty else { break }
            /*
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
            guard whitespaceCheck || !line[0].isWhitespace else { throw Error.invalidRequest }
            whitespaceCheck = true

            /*
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
            */
            let comps = line.split(separator: .colon, maxSplits: 1)
            guard comps.count == 2 else { continue }

            /*
                 No whitespace is allowed between the header field-name and colon.  In
                 the past, differences in the handling of such whitespace have led to
                 security vulnerabilities in request routing and response handling.  A
                 server MUST reject any received request message that contains
                 whitespace between a header field-name and colon with a response code
                 of 400 (Bad Request).
            */
            guard comps[0].last?.isWhitespace == false else { throw Error.invalidKeyWhitespace }
            let field = comps[0].string
            let value = comps[1].array
                .trimmed([.horizontalTab, .space])
                .string

            headers[field] = value
        }

        return headers
    }

    private func parseBody(with headers: Headers) throws -> Bytes {
        let body: Bytes

        if let contentLength = headers["content-length"]?.int {
            body = try stream.receive(max: contentLength)
        } else if
            let transferEncoding = headers["transfer-encoding"]
            where transferEncoding.lowercased().hasSuffix("chunked") // chunked MUST be last component
        {
            /*
                 3.6.1 Chunked Transfer Coding

                 The chunked encoding modifies the body of a message in order to
                 transfer it as a series of chunks, each with its own size indicator,
                 followed by an OPTIONAL trailer containing entity-header fields. This
                 allows dynamically produced content to be transferred along with the
                 information necessary for the recipient to verify that it has
                 received the full message.
            */
            var buffer: Bytes = []

            while true {
                let lengthData = try stream.receiveLine()

                // size must be sent
                guard lengthData.count > 0 else {
                    break
                }

                // convert hex length data to int
                guard let length = lengthData.hexInt where length > 0 else { break }

                let content = try stream.receive(max: length + 2)
                buffer += content
            }

            body = buffer
        } else {
            body = []
        }
        return body
    }

    private func parseURI(with uriSlice: BytesSlice, host hostHeader : String?) throws -> URI {
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

            if let hostHeader = hostHeader {
                let comps = hostHeader.data.split(separator: .colon, maxSplits: 1)
                host = comps[0].string

                if comps.count > 1 {
                    guard let int = comps[1].decimalInt else {
                        throw Error.invalidRequest
                    }
                    port = int
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

            uri = URI(
                scheme: nil,
                userInfo: nil,
                host: host,
                port: port,
                path: path,
                query: query,
                fragment: nil
            )
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
        return uri
    }

    /**
         HTTP uses a "<major>.<minor>" numbering scheme to indicate versions
         of the protocol. The protocol versioning policy is intended to allow
         the sender to indicate the format of a message and its capacity for
         understanding further HTTP communication, rather than the features
         obtained via that communication. No change is made to the version
         number for the addition of message components which do not affect
         communication behavior or which only add to extensible field values.
         The <minor> number is incremented when the changes made to the
         protocol add features which do not change the general message parsing
         algorithm, but which may add to the message semantics and imply
         additional capabilities of the sender. The <major> number is
         incremented when the format of a message within the protocol is
         changed. See RFC 2145 [36] for a fuller explanation.

         The version of an HTTP message is indicated by an HTTP-Version field
         in the first line of the message.

         HTTP-Version   = "HTTP" "/" 1*DIGIT "." 1*DIGIT
    */
    private func parseVersion(_ slice: BytesSlice) throws -> Version {

        // ["HTTP", "1.1"]
        let comps = slice.split(separator: .forwardSlash, maxSplits: 1)

        var major = 0
        var minor = 0

        if comps.count == 2 {
            // ["1", "1"]
            let version = comps[1].split(separator: .period, maxSplits: 1)

            guard let maj = version[0].decimalInt else { throw Error.invalidRequest }
            major = maj

            if version.count == 2 {
                guard let min = version[1].decimalInt else { throw Error.invalidRequest }
                minor = min
            }
        }

        return Version(major: major, minor: minor)
    }
}

/*
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