import JSON
import HTTP

extension JSON: ResponseRepresentable {
    public func makeResponse() throws -> Response {
        return try Response(status: .ok, json: self)
    }
}

extension Double: JSONRepresentable {
    public func makeJSON() -> JSON {
        return .number(.double(self))
    }
}

extension String: JSONRepresentable {
    public func makeJSON() -> JSON {
        return .string(self)
    }
}

extension Int: JSONRepresentable {
    public func makeJSON() -> JSON {
        return .number(.int(self))
    }
}

extension Bool: JSONRepresentable {
    public func makeJSON() -> JSON {
        return .bool(self)
    }
}
