#if compiler(>=6.0)
import NIOHTTP1
import NIOCore
import Testing

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

    @available(*, noasync, message: "Use the async method instead.")
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
        afterResponse: (TestingHTTPResponse) throws -> ()
    ) throws -> TestingApplicationTester {
        try self.test(
            method,
            path,
            headers: headers,
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column,
            beforeRequest: { _ in },
            afterResponse: afterResponse
        )
    }

    @available(*, noasync, message: "Use the async method instead.")
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
        beforeRequest: (inout TestingHTTPRequest) throws -> () = { _ in },
        afterResponse: (TestingHTTPResponse) throws -> () = { _ in }
    ) throws -> TestingApplicationTester {
        var request = TestingHTTPRequest(
            method: method,
            url: .init(path: path),
            headers: headers,
            body: body ?? ByteBufferAllocator().buffer(capacity: 0)
        )
        try beforeRequest(&request)
        do {
            let response = try self.performTest(request: request)
            try afterResponse(response)
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

    @available(*, noasync, message: "Use the async method instead.")
    public func sendRequest(
        _ method: HTTPMethod,
        _ path: String,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil,
        fileID: String = #fileID,
        filePath: String = #filePath,
        line: Int = #line,
        column: Int = #column,
        beforeRequest: (inout TestingHTTPRequest) throws -> () = { _ in }
    ) throws -> TestingHTTPResponse {
        var request = TestingHTTPRequest(
            method: method,
            url: .init(path: path),
            headers: headers,
            body: body ?? ByteBufferAllocator().buffer(capacity: 0)
        )
        try beforeRequest(&request)
        do {
            return try self.performTest(request: request)
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
