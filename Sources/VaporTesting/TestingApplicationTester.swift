public import Testing
public import Vapor
import ServiceLifecycle
import AsyncHTTPClient

extension Application {
    public func testing<T>(_ method: Method = .inMemory, options: LiveTestOptions = .live, sourceLocation: SourceLocation = #_sourceLocation, _ body: (any TestClient) async throws -> T) async throws -> T {
        try await self.boot()
        switch method {
        case .inMemory:
            return try await inMemoryTesting(body)
        case .running:
            return try await liveTesting(hostname: options.hostname, port: options.port, options: options.clientOptions, sourceLocation: sourceLocation, body)
        }
    }

    private func inMemoryTesting<T>(_ body: (any TestClient) async throws -> T) async throws -> T {
        let client = InMemoryTestClient(app: self, responder: self.makeResponder())
        let result = try await body(client)
        // Drain any unread bodies to avoid disconnects
        try await client.unreadBodies.drain()
        return result
    }

    private func liveTesting<T>(
        hostname: String,
        port: Int,
        options: LiveClientOptions,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ body: (any TestClient) async throws -> T
    ) async throws -> T {
        self.serverConfiguration.hostname = hostname
        self.serverConfiguration.port = port
        return try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.server.run()
            }
            let address = try await self.server.listeningAddress
            guard address.port != nil else {
                group.cancelAll()
                Issue.record(TestErrors.missingPort, "Port was not acquired", sourceLocation: sourceLocation)
                throw TestErrors.missingPort
            }
            let client = LiveTestClient(app: self, address: address, options: options, http: HTTPClient.shared)

            let result: T
            do {
                result = try await body(client)
                // Drain any unread bodies to avoid disconnects
                try await client.unreadBodies.drain()
            } catch {
                group.cancelAll()
                throw error
            }

            group.cancelAll()
            do {
                try await group.waitForAll()
            } catch is CancellationError {}
            return result
        }
    }
}
