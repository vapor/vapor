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
        // Status line
        try stream.send("HTTP/\(version.major).\(version.minor) \(status.statusCode) \(status.reasonPhrase)".bytes)

        try stream.sendLine()

        // Headers
        try headers.forEach { key, value in
            try stream.send(key.string)
            try stream.send(.colon)
            try stream.send(.space)
            try stream.send(value)
            try stream.sendLine()
        }
        try stream.sendLine()

        // Body
        switch body {
        case .buffer(let buffer):
            try stream.send(buffer.bytes)
        case .sender(let closure):
            try closure(Sender(stream: stream))
        default:
            throw Error.unsupportedBody
        }

        try stream.flush()
    }
}
