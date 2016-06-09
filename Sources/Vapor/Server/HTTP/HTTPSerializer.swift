final class HTTPSerializer: StreamSerializer {
    private static let clrf = Data("\r\n")
    private static let headerSeparator = Data(": ")
    
    enum Error: ErrorProtocol {
        case unsupportedBody
    }
    
    let stream: Stream
    init(stream: Stream) {
        self.stream = stream
    }

    func serialize(_ response: Response) throws {
        // Start Serialization
        var serialized: Data = []

        // Status line
        let version = response.version
        let status = response.status
        serialized.bytes += "HTTP/\(version.major).\(version.minor) \(status.statusCode) \(status.reasonPhrase)\r\n".data.bytes

        // Headers
        let headers = response.headers.sorted { a, b in
            return a.key.string < b.key.string
        }
        headers.forEach { (key, value) in
            serialized.bytes += key.string.data.bytes + HTTPSerializer.headerSeparator + value.data.bytes + HTTPSerializer.clrf
//            serialized.bytes += "\(key.string): \(value)\r\n".data.bytes
        }
        serialized.bytes += "\r\n".data.bytes

        // Body
        switch response.body {
        case .buffer(let buffer):
            serialized.bytes += buffer.bytes
            try stream.send(serialized)
        case .sender(let closure):
            try stream.send(serialized)
            try closure(stream)
        default:
            throw Error.unsupportedBody
        }
    }
}
