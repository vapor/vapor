private let crlf: Bytes = [.carriageReturn, .newLine]

public final class HTTPSerializer<Message: HTTPMessage>: TransferSerializer {
    public typealias MessageType = Message

    let stream: Stream

    public init(stream: Stream) {
        self.stream = stream
    }

    public func serialize(_ message: MessageType) throws {
        let startLine = message.startLine
        try stream.send(startLine)
        try stream.send(crlf)
        // mutable
        var headers = message.headers
        headers.appendMetadata(for: message.body)

        try serialize(headers)
        try serialize(message.body)

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
        /*
         // TODO: Ordered in future, but not necessary now: https://tools.ietf.org/html/rfc7230#section-3.2.2

         Order is NOT enforced, but suggested, we will implement in future
         */
        try headers.forEach { field, value in
            let headerLine = "\(field): \(value)"
            try stream.send(headerLine.bytes)
            try stream.send(crlf)
        }

        // trailing CRLF to end header section
        try stream.send(crlf)
    }

    private func serialize(_ body: HTTPBody) throws {
        switch body {
        case .data(let buffer):
            guard !buffer.isEmpty else { return }
            try stream.send(buffer)
        case .chunked(let closure):
            let chunkStream = ChunkStream(stream: stream)
            try closure(chunkStream)
        }
    }
}
