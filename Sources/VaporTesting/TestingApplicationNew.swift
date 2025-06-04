import Vapor
import HTTPTypes
import NIOCore
import Testing

extension Application {
    public func test(method: Method = .inMemory, testBlock: (any VaporTestingRunner) async throws -> Void) async throws {
        switch method {
        case .inMemory:
            fatalError()
        case .running(let hostname, let port):
            self.serverConfiguration.hostname = hostname
            self.serverConfiguration.port = port
            try await withRunningApp(app: self) { allocatedPort in
                let tester = try LiveTestRunner(hostname: hostname, port: allocatedPort, app: self)
                try await testBlock(tester)
            }
        }
    }
}

public protocol VaporTestingRunner {
    var tester: any TestingApplicationTester { get }
}

extension VaporTestingRunner {
    public func sendRequest(
        _ method: HTTPRequest.Method,
        _ path: String,
        hostname: String = "localhost",
        port: Int? = nil,
        headers: HTTPFields = [:],
        body: ByteBuffer? = nil,
        sourceLocation: SourceLocation = #_sourceLocation,
        beforeRequest: (inout TestingHTTPRequest) async throws -> () = { _ in }
    ) async throws -> TestingHTTPResponse {
        var request = TestingHTTPRequest(
            method: method,
            url: .init(scheme: "http", host: hostname, port: port, path: path),
            headers: headers,
            body: body ?? ByteBufferAllocator().buffer(capacity: 0),
            contentConfigurtion: .default()
        )
        try await beforeRequest(&request)
        do {
            return try await self.tester.makeRequest(request)
        } catch {
            Issue.record("\(String(reflecting: error))", sourceLocation: sourceLocation)
            throw error
        }
    }
}

public struct LiveTestRunner: VaporTestingRunner {
    let port: Int
    public var tester: any TestingApplicationTester

    init(hostname: String, port: Int, app: Application) throws {
        self.port = port
        self.tester = try Application.Live(app: app, hostname: hostname, port: port)
    }

}
