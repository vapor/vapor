public struct XCTHTTPRequest {
    public var method: HTTPMethod
    public var uri: URI
    public var headers: HTTPHeaders
    public var body: ByteBuffer
}

extension XCTHTTPRequest {
    private struct _ContentContainer: ContentContainer {
        var body: ByteBuffer
        var headers: HTTPHeaders

        var contentType: HTTPMediaType? {
            return self.headers.contentType
        }

        mutating func encode<E>(_ encodable: E, using encoder: ContentEncoder) throws
            where E: Encodable
        {
            try encoder.encode(encodable, to: &self.body, headers: &self.headers)
        }

        func decode<D>(_ decodable: D.Type, using decoder: ContentDecoder) throws -> D
            where D: Decodable
        {
            fatalError("Decoding from test request is not supported")
        }
    }

    public var content: ContentContainer {
        get {
            _ContentContainer(body: self.body, headers: self.headers)
        }
        set {
            let container = (newValue as! _ContentContainer)
            self.body = container.body
            self.headers = container.headers
        }
    }
}
