extension Response {
    enum Error: ErrorProtocol {
        case unsupportedBody
    }

    /**
        Serializes the supplied Response
        to the stream following HTTP/1.1 protocol.
     
        Throws `Error.unsupportedBody` if the
        body is not a buffer or a sending stream.
    */
    func serialize(to stream: Stream) throws {
        // Start Serialization
        var serialized: Data = []

        // Status line
        serialized.bytes += "HTTP/\(version.major).\(version.minor) \(status.statusCode) \(status.reasonPhrase)".data.bytes

        serialized += .crlf

        // Headers
        headers.forEach { key, value in
            serialized += key.string.data
            serialized += .colon
            serialized += .space
            serialized += value.data
            serialized += .crlf
        }
        serialized += .crlf

        // Body
        switch body {
        case .buffer(let buffer):
            serialized += buffer
            try stream.send(serialized)
        case .sender(let closure):
            try stream.send(serialized)
            try closure(stream)
        default:
            throw Error.unsupportedBody
        }
    }
}
