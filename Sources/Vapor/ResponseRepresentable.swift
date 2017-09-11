import HTTP

/// String can be represented as an HTTP body.
extension String: ResponseRepresentable {
    // See `ResponseRepresentable.makeResponse()`
    public func makeResponse() throws -> Response {
        return try Response(body: self)
    }
}

