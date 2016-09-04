import JSON
import HTTP

extension JSON: ResponseRepresentable {
    public func makeResponse() throws -> Response {
        return try Response(status: .ok, json: self)
    }
}
