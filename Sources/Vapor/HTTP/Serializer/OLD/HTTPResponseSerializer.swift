public final class HTTPResponseSerializer: ResponseSerializer {
    enum Error: ErrorProtocol {
        case unsupportedBody
    }

    let stream: Stream

    public init(stream: Stream) {
        self.stream = stream
    }

    /**
        Serializes the supplied Response
        to the stream following HTTP/1.1 protocol.
     
        Throws `Error.unsupportedBody` if the
        body is not a buffer or a sending stream.
    */
    public func serialize(_ response: Response) throws {
        let version = response.version
        let status = response.status

        // Status line
        try stream.send("HTTP/\(version.major).\(version.minor) \(status.statusCode) \(status.reasonPhrase)".bytes)

        try stream.sendLine()

        // Headers
        try response.headers.forEach { key, value in
            try stream.send(key.string)
            try stream.send(.colon)
            try stream.send(.space)
            try stream.send(value)
            try stream.sendLine()
        }
        try stream.sendLine()

        // Body
        switch response.body {
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
