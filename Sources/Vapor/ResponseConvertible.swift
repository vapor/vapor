import HTTP

/// Free conformance to response convertible if you conform to
/// content codable
extension ContentEncodable where Self: ResponseRepresentable {
    /// See ResponseRepresentable.makeResponse
    public func makeResponse(for request: Request) throws -> Response {
        let response = Response()
        try encodeContent(to: response)
        return response
    }
}

extension ContentDecodable where Self: ResponseInitializable {
    /// See ResponseInitializable.init
    public init(response: Response) throws {
        guard let decoded = try Self.decodeContent(from: response) else {
            throw HTTP.Error.contentRequired(Self.self)
        }

        self = decoded
    }
}
