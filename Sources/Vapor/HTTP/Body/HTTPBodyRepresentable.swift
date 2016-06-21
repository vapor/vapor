public protocol HTTPBodyRepresentable {
    func makeBody() -> HTTPBody
}

extension String: HTTPBodyRepresentable {
    public func makeBody() -> HTTPBody {
        return HTTPBody(self)
    }
}
