import Engine

public protocol JSONRepresentable: HTTPResponseRepresentable {
    func makeJSON() -> JSON
}

extension JSON: HTTPResponseRepresentable {
    public func makeResponse(for: HTTPResponse) throws -> HTTPResponse {
        return try HTTPResponse(status: .ok, json: self)
    }
}

extension JSON: JSONRepresentable {
    public func makeJSON() -> JSON {
        return self
    }
}

extension Bool: JSONRepresentable {
    public func makeJSON() -> JSON {
        return .bool(self)
    }
}

extension String: JSONRepresentable {
    public func makeJSON() -> JSON {
        return .string(self)
    }
}

extension Int: JSONRepresentable {
    public func makeJSON() -> JSON {
        return .number(.integer(self))
    }
}

extension JSONRepresentable {
    ///Allows any JsonRepresentable to be returned through closures
    public func makeResponse(for request: HTTPRequest) throws -> HTTPResponse {
        return try makeJSON().makeResponse(for: request)
    }
}
