public protocol URLContent: Codable, RequestDecodable { }

extension URLContent {
    public static func decodeRequest(_ req: HTTPRequest, using ctx: Context) -> EventLoopFuture<Self> {
        do {
            let content = try req.query.decode(Self.self)
            return ctx.eventLoop.makeSucceededFuture(content)
        } catch {
            return ctx.eventLoop.makeFailedFuture(error)
        }
    }
}
