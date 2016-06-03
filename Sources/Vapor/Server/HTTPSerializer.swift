final class HTTPSerializer {
    init() {

    }

    func serialize(_ response: Response, keepAlive: Bool) -> Data {
        var serialized: Data = []

        let version = response.version
        let status = response.status

        serialized.bytes += "HTTP/\(version.major).\(version.minor) \(status.statusCode) \(status.reasonPhrase)\r\n".data.bytes

        if keepAlive {
            serialized.bytes += "Connection: keep-alive\r\n".data.bytes
        }

        let headers = response.headers.sorted { a, b in
            return a.key.string < b.key.string
        }

        headers.forEach { (key, value) in
            serialized.bytes += "\(key.string): \(value)\r\n".data.bytes
        }

        serialized.bytes += "\r\n".data.bytes

        //TODO: Support other body types
        if case .buffer(let data) = response.body {
            serialized.bytes += data
        }
        
        return serialized
    }
}
