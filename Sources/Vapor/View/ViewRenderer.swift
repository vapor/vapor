import NIOCore

public protocol ViewRenderer {
    func `for`(_ request: Request) -> ViewRenderer
    func render<E>(_ name: String, _ context: E) async throws -> View where E: Encodable
    func render(_ name: String) async throws -> View
}
