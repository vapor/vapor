import NIOCore

public protocol ViewRenderer: Sendable {
    func `for`(_ request: Request) -> ViewRenderer
    func render<E>(_ name: String, _ context: E) async throws -> View
        where E: Encodable
}

extension ViewRenderer {
    public func render(_ name: String) async throws -> View {
        return try await self.render(name, [String: String]())
    }
}
