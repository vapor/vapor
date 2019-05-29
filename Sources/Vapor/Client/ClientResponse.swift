public struct ClientResponse: CustomStringConvertible {
    public var status: HTTPStatus
    public var headers: HTTPHeaders
    public var body: ByteBuffer?

    public var description: String {
        var desc = ["HTTP/1.1 \(status.code) \(status.reasonPhrase)"]
        desc += self.headers.map { "\($0.name): \($0.value)" }
        if var body = self.body {
            let string = body.readString(length: body.readableBytes) ?? ""
            desc += ["", string]
        }
        return desc.joined(separator: "\n")
    }

    // MARK: Content

    private struct _ContentContainer: ContentContainer {
        var body: ByteBuffer?
        var headers: HTTPHeaders

        var contentType: HTTPMediaType? {
            return self.headers.contentType
        }

        mutating func encode<E>(_ encodable: E, using encoder: ContentEncoder) throws where E : Encodable {
            var body = ByteBufferAllocator().buffer(capacity: 0)
            try encoder.encode(encodable, to: &body, headers: &self.headers)
            self.body = body
        }

        func decode<D>(_ decodable: D.Type, using decoder: ContentDecoder) throws -> D where D : Decodable {
            guard let body = self.body else {
                throw Abort(.lengthRequired)
            }
            return try decoder.decode(D.self, from: body, headers: self.headers)
        }
    }

    public var content: ContentContainer {
        get {
            return _ContentContainer(body: self.body, headers: self.headers)
        }
        set {
            let container = (newValue as! _ContentContainer)
            self.body = container.body
            self.headers = container.headers
        }
    }

    public init(status: HTTPStatus = .ok, headers: HTTPHeaders = [:], body: ByteBuffer? = nil) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}
