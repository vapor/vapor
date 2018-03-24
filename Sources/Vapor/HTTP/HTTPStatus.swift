/// Less verbose typealias for `HTTPResponseStatus`.
public typealias HTTPStatus = HTTPResponseStatus

extension HTTPStatus: ResponseEncodable {
    /// See `ResponseEncodable.encode(for:)`
    public func encode(for req: Request) throws -> Future<Response> {
        return Future.map(on: req) { Response(http: .init(status: self), using: req) }
    }
}
