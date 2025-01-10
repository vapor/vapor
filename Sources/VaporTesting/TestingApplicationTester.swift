import NIOHTTP1
import NIOCore
#if compiler(>=6.0)
import Testing
#endif

public protocol TestingApplicationTester: Sendable {
    func performTest(request: TestingHTTPRequest) async throws -> TestingHTTPResponse
}

extension Application.Live: TestingApplicationTester {}
extension Application.InMemory: TestingApplicationTester {}

extension Application: TestingApplicationTester {
    public func testing(method: Method = .inMemory) throws -> TestingApplicationTester {
        try self.boot()
        switch method {
        case .inMemory:
            return try InMemory(app: self)
        case let .running(hostname, port):
            return try Live(app: self, hostname: hostname, port: port)
        }
    }

    public func performTest(request: TestingHTTPRequest) async throws -> TestingHTTPResponse {
        try await self.testing().performTest(request: request)
    }
}

#if compiler(>=6.0)
extension TestingApplicationTester {
    @discardableResult
    public func test(
        _ method: HTTPMethod,
        _ path: String,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil,
        fileID: String = #fileID,
        filePath: String = #filePath,
        line: Int = #line,
        column: Int = #column,
        afterResponse: (TestingHTTPResponse) async throws -> ()
    ) async throws -> TestingApplicationTester {
        try await self.test(
            method,
            path,
            headers: headers,
            body: body,
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column,
            beforeRequest: { _ in },
            afterResponse: afterResponse
        )
    }

    @discardableResult
    public func test(
        _ method: HTTPMethod,
        _ path: String,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil,
        fileID: String = #fileID,
        filePath: String = #filePath,
        line: Int = #line,
        column: Int = #column,
        beforeRequest: (inout TestingHTTPRequest) async throws -> () = { _ in },
        afterResponse: (TestingHTTPResponse) async throws -> () = { _ in }
    ) async throws -> TestingApplicationTester {
        var request = TestingHTTPRequest(
            method: method,
            url: .init(path: path),
            headers: headers,
            body: body ?? ByteBufferAllocator().buffer(capacity: 0)
        )
        try await beforeRequest(&request)
        do {
            let response = try await self.performTest(request: request)
            try await afterResponse(response)
        } catch {
            let sourceLocation = Testing.SourceLocation(
                fileID: fileID,
                filePath: filePath,
                line: line,
                column: column
            )
            Issue.record("\(String(reflecting: error))", sourceLocation: sourceLocation)
            throw error
        }
        return self
    }

    public func sendRequest(
        _ method: HTTPMethod,
        _ path: String,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil,
        fileID: String = #fileID,
        filePath: String = #filePath,
        line: Int = #line,
        column: Int = #column,
        beforeRequest: (inout TestingHTTPRequest) async throws -> () = { _ in }
    ) async throws -> TestingHTTPResponse {
        VaporTestingContext.warnIfNotInSwiftTestingContext(
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
        
        var request = TestingHTTPRequest(
            method: method,
            url: .init(path: path),
            headers: headers,
            body: body ?? ByteBufferAllocator().buffer(capacity: 0)
        )
        try await beforeRequest(&request)
        do {
            return try await self.performTest(request: request)
        } catch {
            let sourceLocation = Testing.SourceLocation(
                fileID: fileID,
                filePath: filePath,
                line: line,
                column: column
            )
            Issue.record("\(String(reflecting: error))", sourceLocation: sourceLocation)
            throw error
        }
    }
}
#endif
