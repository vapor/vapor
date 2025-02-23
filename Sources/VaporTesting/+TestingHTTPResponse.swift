import Foundation
import Testing
import Vapor

public func expectContent<D>(
    _ type: D.Type,
    _ res: TestingHTTPResponse,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ closure: (D) throws -> ()
) rethrows where D: Decodable {
    guard let contentType = res.headers.contentType else {
        Issue.record("response does not contain content type", sourceLocation: sourceLocation)
        return
    }

    let content: D

    do {
        let decoder = try ContentConfiguration.global.requireDecoder(for: contentType)
        content = try decoder.decode(D.self, from: res.body, headers: res.headers)
    } catch {
        Issue.record("could not decode body: \(error)", sourceLocation: sourceLocation)
        return
    }

    try closure(content)
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
