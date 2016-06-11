extension Request.Headers {
    /*
        HTTP-message   = start-line
        *( header-field CRLF )
        CRLF
        [ message-body ]
    */
    init(stream: Stream) throws {
        var headers: Request.Headers = [:]

        var lastField: Request.Headers.Key? = nil

        while true {
            let line = try stream.nextLine()

            if line.isEmpty {
                break
            }

            if line[0].isWhitespace {
                guard let lastField = lastField else {
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
                    throw "Cannot have leading white space on the first line"
                }

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
                let value = Request.Headers.parseHeaderValue(line)
                headers[lastField]?.append(value)
            } else {
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
                guard comps.count == 2 else {
                    continue
                }

                /*
                 No whitespace is allowed between the header field-name and colon.  In
                 the past, differences in the handling of such whitespace have led to
                 security vulnerabilities in request routing and response handling.  A
                 server MUST reject any received request message that contains
                 whitespace between a header field-name and colon with a response code
                 of 400 (Bad Request).
                 */
                if comps[0].last?.isWhitespace == true {
                    throw "No white space between header and colon allowed, throw 400"
                }

                let field = Request.Headers.Key(comps[0].string)
                let value = Request.Headers.parseHeaderValue(comps[1])

                headers[field] = value

                lastField = field
            }
        }

        self = headers
    }

    static func parseHeaderValue(_ bytes: Bytes) -> String {
        return bytes.trimmed([.space, .horizontalTab]).string
    }

    static func parseHeaderValue(_ bytes: BytesSlice) -> String {
        return bytes.trimmed([.space, .horizontalTab]).string
    }
}
