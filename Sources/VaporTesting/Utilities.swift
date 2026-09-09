public import Vapor
import HTTPTypes
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
public import Testing

extension Response.Body {
    public func requireString(max: Int? = nil) async throws -> String {
        guard let string = try await self.string(max: max) else {
            throw Abort(.unprocessableContent)
        }
        return string
    }
}

public func expectJSONEquals<T>(
    _ data: String?,
    _ test: T,
    sourceLocation: SourceLocation = #_sourceLocation
)
where T: Codable & Equatable
{
    guard let data = data else {
        Issue.record("nil does not equal \(test)", sourceLocation: sourceLocation)
        return
    }
    do {
        let decoded = try JSONDecoder().decode(T.self, from: Data(data.utf8))
        #expect(decoded == test, sourceLocation: sourceLocation)
    } catch {
        Issue.record("could not decode \(T.self): \(error)", sourceLocation: sourceLocation)
    }
}
