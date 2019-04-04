public protocol URLContent: Codable, RequestDecodable { }

extension URLContent {
    public static func decodeRequest(_ request: Request) -> EventLoopFuture<Self> {
        do {
            let content = try request.http.query.decode(Self.self)
            return request.eventLoop.makeSucceededFuture(content)
        } catch {
            return request.eventLoop.makeFailedFuture(error)
        }
    }
}
