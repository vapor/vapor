public import Vapor
import HTTPTypes

extension Response.Body {
    public func requireString(max: Int? = nil) async throws -> String {
        guard let string = try await self.string(max: max) else {
            throw Abort(.unprocessableContent)
        }
        return string
    }
}
