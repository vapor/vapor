import JSON
import Engine

extension JSON: HTTPResponseRepresentable {
    public func makeResponse(for request: HTTPRequest) throws -> HTTPResponse {
        return try HTTPResponse(status: .ok, json: self)
    }
}
