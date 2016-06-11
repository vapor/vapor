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
extension Request {
    enum Error: ErrorProtocol {
        case streamEmpty
    }

    init(stream: Stream) throws {
        let (methodSlice, uriSlice, versionSlice) = try Request.parseRequestLine(stream: stream)

        // Header parsing will ensure no whitespace
        let headers = try Headers(stream: stream)

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

        let body = try Body(headers: headers, stream: stream)

        // HTTP-Version   = "HTTP" "/" 1*DIGIT "." 1*DIGIT
        let version = Version(versionSlice)

        self = Request(
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
    static func parseRequestLine(stream: Stream) throws -> (method: ArraySlice<Byte>, uri: ArraySlice<Byte>, httpVersion: ArraySlice<Byte>) {
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
