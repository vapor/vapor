#if compiler(>=5.5)
import _NIOConcurrency

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
public extension ViewRenderer {
    func render<E>(_ name: String, _ context: E) async throws -> View where E: Encodable {
        try await self.render(name, context).get()
    }

    func render(_ name: String) async throws -> View {
        try await self.render(name).get()
    }
}

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
public extension View {
    func encodeResponse(for request: Request) async throws -> Response {
        try await self.encodeResponse(for: request).get()
    }
}

#endif
