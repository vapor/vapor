final class HTTPSerializer: StreamSerializer {
    let stream: Stream
    init(stream: Stream) {
        self.stream = stream
    }

    func serialize(_ response: Response) throws {
        var response = response

        var cookies: [String] = []
        for cookie in response.cookies {
            cookies.append("\(cookie.name)=\(cookie.value)")
        }
        if cookies.count >= 1 {
            response.headers["Set-Cookie"] = cookies.joined(separator: ";")
        }

        var serialized: Data = []

        let version = response.version
        let status = response.status

        serialized.bytes += "HTTP/\(version.major).\(version.minor) \(status.statusCode) \(status.reasonPhrase)\r\n".data.bytes

        let headers = response.headers.sorted { a, b in
            return a.key.string < b.key.string
        }



        headers.forEach { (key, value) in
            serialized.bytes += "\(key.string): \(value)\r\n".data.bytes
        }

        serialized.bytes += "\r\n".data.bytes

        var body = response.body
        let data = try body.becomeBuffer()
        serialized.bytes += data

        try stream.send(serialized)
    }
}
