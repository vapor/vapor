public protocol RequestParser {
    init(stream: Stream)
    func parse() throws -> Request
}

public protocol RequestSerializer {
    init(stream: Stream)
    func serialize(_ request: Request)  throws
}

public final class HTTPRequestSerializer: RequestSerializer {
    enum Error: ErrorProtocol {
        case unsupportedBody
    }

    let stream: Stream
    private let crlf: Bytes = [.carriageReturn, .newLine]

    public init(stream: Stream) {
        self.stream = stream
    }

    public func serialize(_ request: Request) throws {
        // https://tools.ietf.org/html/rfc7230#section-3.1.2
        // status-line = HTTP-version SP status-code SP reason-phrase CRL
        // TODO: Prefix w/ `/` MUST
        var path = request.uri.path ?? "/"
        if let q = request.uri.query {
            path += "?\(q)"
        }
        if let f = request.uri.fragment {
            path += "#\(f)"
        }

        let version = "HTTP/\(request.version.major).\(request.version.minor)"
        let statusLine = "\(request.method) \(path) \(version)"
        print("STATUSLINE: \(statusLine)")
        try stream.send(statusLine.bytes)
        try stream.send(crlf)
        // TODO: Setup Content Length or Transfer Encoding
        var headers = request.headers
        headers["Host"] = request.uri.host
//        headers["Content-Length"] = "0"
        headers["Connection"] = "close"
        try serialize(headers)
        try serialize(request.body)

        let buf = stream as! StreamBuffer
        buf.TEMPORARY_REMOVE_LOG_BUFFER()
        try stream.flush()
    }

    /*
     3.2.2.  Field Order

     The order in which header fields with differing field names are
     received is not significant.  However, it is good practice to send
     header fields that contain control data first, such as Host on
     requests and Date on responses, so that implementations can decide
     when not to handle a message as early as possible.  A server MUST NOT
     apply a request to the target resource until the entire request



     Fielding & Reschke           Standards Track                   [Page 23]

     RFC 7230           HTTP/1.1 Message Syntax and Routing         June 2014


     header section is received, since later header fields might include
     conditionals, authentication credentials, or deliberately misleading
     duplicate header fields that would impact request processing.

     A sender MUST NOT generate multiple header fields with the same field
     name in a message unless either the entire field value for that
     header field is defined as a comma-separated list [i.e., #(values)]
     or the header field is a well-known exception (as noted below).

     A recipient MAY combine multiple header fields with the same field
     name into one "field-name: field-value" pair, without changing the
     semantics of the message, by appending each subsequent field value to
     the combined field value in order, separated by a comma.  The order
     in which header fields with the same field name are received is
     therefore significant to the interpretation of the combined field
     value; a proxy MUST NOT change the order of these field values when
     forwarding a message.

     Note: In practice, the "Set-Cookie" header field ([RFC6265]) often
     appears multiple times in a response message and does not use the
     list syntax, violating the above requirements on multiple header
     fields with the same name.  Since it cannot be combined into a
     single field-value, recipients ought to handle "Set-Cookie" as a
     special case while processing header fields.  (See Appendix A.2.3
     of [Kri2001] for details.)
     */
    private func serialize(_ headers: Headers) throws {
        print("Got headers: \(headers)")
        var headerSection = Bytes()

        /*
        // TODO: Ordered in future: https://tools.ietf.org/html/rfc7230#section-3.2.2
         
         Order is NOT enforced, but suggested, we will implement in future
         */
        headers.forEach { field, value in
            let headerLine = "\(field): \(value)"
            print("headerLine: \(headerLine)")
            headerSection += headerLine.bytes
            headerSection += crlf
        }
        headerSection += crlf // Trailing CRLF on headers section
        try stream.send(headerSection)
    }

    private func serialize(_ body: Body) throws {
        switch body {
        case .buffer(let buffer):
            guard !buffer.isEmpty else { return }
            try stream.send(buffer.bytes)
        case .sender(let closure):
            try closure(Sender(stream: stream))
        default:
            throw Error.unsupportedBody
        }
    }


}
