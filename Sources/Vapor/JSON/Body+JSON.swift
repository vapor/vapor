extension HTTPBody {
    public init(_ json: JSON) throws {
        let bytes = try JSON.serializer(json: json)
        self.init(bytes)
    }
}

extension JSON: HTTPBodyRepresentable {
    public func makeBody() -> HTTPBody {
        if let body = try? HTTPBody(self) { return body }
        else { return .data([]) }
    }
}
