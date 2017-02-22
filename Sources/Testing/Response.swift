import HTTP

// MARK: Assertions

extension Response {
    /// Asserts the response body contains a
    /// desired byte array.
    @discardableResult
    public func assertBody(
        contains b: BytesConvertible,
        _ message: String? = nil,
        file: StaticString = #file,
        line: UInt = #line
        ) throws -> Response {
        let bytes = try b.testMakeBytes(file: file, line: line)
        let body = try testBody(file: file, line: line)

        XCTAssert(
            body.string.contains(bytes.string),
            message ?? "Body assertion failed. '\(body.string)' does not contain '\(bytes.string)'",
            file: file,
            line: line
        )

        return self
    }

    /// Asserts the response status code equals
    /// a desired status code
    @discardableResult
    public func assertStatus(
        is desired: HTTP.Status,
        _ message: String? = nil,
        file: StaticString = #file,
        line: UInt = #line
        ) -> Response {
        XCTAssert(
            status.statusCode == desired.statusCode,
            message ?? "Status assertion failed. '\(status.statusCode)' does not equal '\(desired.statusCode)'",
            file: file,
            line: line
        )

        return self
    }

    /// Asserts a response header at a given key
    /// contains a desired string
    @discardableResult
    public func assertHeader(
        _ key: HeaderKey,
        contains desired: String,
        _ message: String? = nil,
        file: StaticString = #file,
        line: UInt = #line
        ) -> Response {
        let header = headers[key]
        XCTAssert(
            header?.contains(desired) == true,
            message ?? "\(key) header assertion failed. '\(header ?? "nil")' does not contain '\(desired)'",
            file: file,
            line: line
        )
        
        return self
    }

}

// MARK: Convenience

extension Response {
    public func testBody(
        file: StaticString = #file,
        line: UInt = #line
        ) throws -> Bytes {
        guard let bytes = body.bytes else {
            XCTFail(
                "Failed to convert response body to bytes.",
                file: file,
                line: line
            )
            throw TestingError.noBodyBytes
        }

        return bytes
    }
}
