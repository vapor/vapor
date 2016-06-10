extension Response {
    /**
        Send chunked data with the
        `Transfer-Encoding: Chunked` header.
     
        Chunked uses the Transfer-Encoding HTTP header in
        place of the Content-Length header.
     
        https://en.wikipedia.org/wiki/Chunked_transfer_encoding
    */
    public init(
        status: Status = .ok,
        headers: Headers = [:],
        cookies: Cookies = [],
        chunked closure: ((ChunkStream) throws -> Void)
    ) {
        var headers = headers
        headers["Transfer-Encoding"] = "chunked"

        self.init(
            version: Version(major: 1, minor: 1),
            status: status,
            headers: headers,
            cookieHeaders: [],
            body: .sender({ stream in
                let chunkStream = ChunkStream(stream: stream)
                try closure(chunkStream)
            })
        )
    }
}
