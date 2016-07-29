import JSON
import HTTP

public protocol JSONRepresentable {
    func makeJSON() -> JSON
}

extension JSON: HTTPResponseRepresentable {
    public func makeResponse(for request: Request) throws -> HTTPResponse {
        return try HTTPResponse(status: .ok, json: self)
    }
}
