final class HTTPSerializer: StreamSerializer {
    enum Error: ErrorProtocol {
        case unsupportedBody
    }

    /**
        The sending stream.
    */
    let stream: Stream

    /**
        Creates a new HTTP Serializer that will
        send serialized data to the supplied stream.
    */
    init(stream: Stream) {
        self.stream = stream
    }

    /**
        Serializes the supplied Response
        to the stream following HTTP/1.1 protocol.
     
        Throws `Error.unsupportedBody` if the
        body is not a buffer or a sending stream.
    */
    func serialize(_ response: Response) throws {
        // Start Serialization
        var serialized: Data = []

        // Status line
        let version = response.version
        let status = response.status
        serialized.bytes += "HTTP/\(version.major).\(version.minor) \(status.statusCode) \(status.reasonPhrase)".data.bytes

        serialized += .crlf

        // Headers
        response.headers.forEach { key, value in
            serialized += key.string.data
            serialized += .colon
            serialized += .space
            serialized += value.data
            serialized += .crlf
        }
        serialized += .crlf

        // Body
        switch response.body {
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
