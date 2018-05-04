/// Less verbose typealias for `HTTPResponseStatus`.
public typealias HTTPStatus = HTTPResponseStatus

extension HTTPStatus: ResponseEncodable {
    /// See `ResponseEncodable`.
    public func encode(for req: Request) throws -> Future<Response> {
        let res = Response(http: .init(status: self), using: req)
        return req.eventLoop.newSucceededFuture(result: res)
    }
}
