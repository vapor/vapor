public protocol Content: Codable {
    static var defaultMediaType: MediaType { get }
}

extension Message {
    public func content<C: Content>(_ content: C, as mediaType: MediaType = C.defaultMediaType) {

    }
}

extension String: Content {
    /// See Content.defaultMediaType
    public static var defaultMediaType: MediaType {
        return .html
    }
}

extension String: ResponseRepresentable {
    /// See ResponseRepresentable.makeResponse
    public func makeResponse(for request: Request) throws -> Response {
        let res = Response(status: .ok)
        res.content(self)
        return res
    }
}
