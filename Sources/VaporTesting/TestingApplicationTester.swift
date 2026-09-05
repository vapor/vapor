#warning("This should be internal")
public import NIOCore
public import Testing
public import Vapor
public import HTTPTypes
import ServiceLifecycle
import AsyncHTTPClient

public protocol TestingApplicationTester: Sendable {

}

extension Application.Live: TestingApplicationTester {}
extension Application.InMemory: TestingApplicationTester {}

extension Application: TestingApplicationTester {



    public func testing<T>(_ method: Method = .inMemory, options: LiveTestOptions = .live, _ body: (any TestClient) async throws -> T) async throws -> T {
        try await self.boot()
        switch method {
        case .inMemory:
            return try await inMemoryTesting(body)
        case .running:
            return try await liveTesting(hostname: options.hostname, port: options.port, options: options.clientOptions, body)
        }
    }

    private func inMemoryTesting<T>(_ body: (any TestClient) async throws -> T) async throws -> T {
        let client = InMemoryTestClient(app: self, responder: self.makeResponder())
        let result = try await body(client)
        // Drain any unread bodies to avoid disconnects
        try await client.unreadBodies.drain()
        return result
    }

    private func liveTesting<T>(hostname: String, port: Int, options: LiveClientOptions, _ body: (any TestClient) async throws -> T) async throws -> T {
        self.serverConfiguration.hostname = hostname
        self.serverConfiguration.port = port
        return try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.server.run()
            }
            let address = try await self.server.listeningAddress
            guard address.port != nil else {
                group.cancelAll()
#warning("Pass location")
                Issue.record(TestErrors.missingPort, "Port was not acquired")
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
