import HTTPServerNew
import NIOCore

extension HTTPServer: Server {
    public func start() async throws {
        try await self.run()
    }

    public func shutdown() async throws {
        try await self.shutdownGracefully()
    }
}
