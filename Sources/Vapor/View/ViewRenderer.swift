import NIOCore

public protocol ViewRenderer {
    func `for`(_ request: Request) -> ViewRenderer
    func render<E>(_ name: String, _ context: E) -> EventLoopFuture<View>
    where E: Encodable
}

extension ViewRenderer {
    public func render(_ name: String) -> EventLoopFuture<View> {
        return self.render(name, [String: String]())
    }
}
