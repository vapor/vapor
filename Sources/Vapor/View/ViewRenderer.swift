public protocol ViewRenderer {
    func render<E>(_ name: String, _ context: E) -> EventLoopFuture<View>
        where E: Encodable
}

extension ViewRenderer {
    public func render(_ name: String) -> EventLoopFuture<View> {
        return self.render(name, [String: String]())
    }
}
