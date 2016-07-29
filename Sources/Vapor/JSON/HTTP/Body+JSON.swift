import HTTP

extension Body {
    public init(_ json: JSON) throws {
        let bytes = try json.makeBytes()
        self.init(bytes)
    }
}

extension JSON: BodyRepresentable {
    public func makeBody() -> Body {
        if let body = try? Body(self) { return body }
        else { return .data([]) }
    }
}
