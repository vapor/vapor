import NIOCore

public protocol ViewRenderer: Sendable {
    func `for`(_ request: Request) -> any ViewRenderer
    func render(_ name: String, _ context: some Encodable) async throws -> View
}

extension ViewRenderer {
    public func render(_ name: String) async throws -> View {
        try await self.render(name, [String: String]())
    }
}
