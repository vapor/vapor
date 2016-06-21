extension HTTPBody {
    public init(_ json: JSON) {
        let bytes = json.serialize().utf8
        self.init(bytes)
    }
}

extension JSON: HTTPBodyConvertible {
    public func makeBody() -> HTTPBody {
        return HTTPBody(self)
    }
}
