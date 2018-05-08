/// A container representing `Data` with a specific content type (used for returning as a `Response`).
private struct TypedDataResponse: ResponseEncodable {
    /// The data held by this container.
    let data: Data

    /// The type of the data held by this container.
    let contentType: MediaType
    
    /// See `ResponseEncodable`.
    public func encode(for req: Request) throws -> EventLoopFuture<Response> {
        let res = req.makeResponse()
        res.http.body = data.convertToHTTPBody()
        res.http.contentType = contentType
        return try res.encode(for: req)
    }
}

extension Data: ResponseEncodable {
    /// See `ResponseEncodable`.
    public func encode(for req: Request) throws -> EventLoopFuture<Response> {
        return try response(type: .any).encode(for: req)
    }
    
    /// Get a `ResponseEncodable` container holding this data with your provided contentType.
    ///
    ///     data.response(type: .html)
    ///
    /// - parameters:
    ///     - type: The type of data to return the container with.
    public func response(type: MediaType) -> ResponseEncodable {
        return TypedDataResponse(data: self, contentType: type)
    }
}
