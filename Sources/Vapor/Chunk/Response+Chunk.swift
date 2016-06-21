extension Response {
    /**
        Send chunked data with the
        `Transfer-Encoding: Chunked` header.

        Chunked uses the Transfer-Encoding HTTP header in
        place of the Content-Length header.

        https://en.wikipedia.org/wiki/Chunked_transfer_encoding
    */
    public convenience init(status: Status = .ok, headers: Headers = [:], chunked closure: ((ChunkStream) throws -> Void)) {
        var headers = headers
        headers.setTransferEncodingChunked()
        self.init(status: status, headers: headers, body: .chunked(closure))
    }
}
