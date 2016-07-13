public protocol JSONRepresentable: ResponseRepresentable {
    func makeJSON() -> JSON
}

extension JSON: ResponseRepresentable {
    public func makeResponse(for: Request) throws -> Response {
        return try Response(status: .ok, json: self)
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
    public func makeResponse(for request: Request) throws -> Response {
        return try makeJSON().makeResponse(for: request)
    }
}
