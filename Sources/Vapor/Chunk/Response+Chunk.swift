extension Response {
    /**
        Send chunked data with the 
        `Transfer-Encoding: Chunked` header.
    */
    public init(
        status: Status = .ok,
        headers: Headers = [:],
        cookies: Cookies = [],
        chunked closure: ((ChunkStream) throws -> Void)
    ) {
        var headers = headers
        headers["Transfer-Encoding"] = "chunked"

        self.init(version:
            Version(major: 1, minor: 1),
            status: status,
            headers: headers,
            cookies: cookies,
            body: .sender({ stream in
                let chunkStream = ChunkStream(stream: stream)
                try closure(chunkStream)
            })
        )
    }
}
