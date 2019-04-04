public final class XCTHTTPResponse {
    public let response: HTTPResponse
    public init(response: HTTPResponse) {
        self.response = response
    }
    
    @discardableResult
    public func assertStatus(is status: HTTPStatus, file: StaticString = #file, line: UInt = #line) -> XCTHTTPResponse {
        XCTAssertEqual(self.response.status, status, file: file, line: line)
        return self
    }
    
    @discardableResult
    public func assertBody(equals string: String, file: StaticString = #file, line: UInt = #line) -> XCTHTTPResponse {
        let bodyString = self.response.body.description
        XCTAssertEqual(bodyString, string, file: file, line: line)
        return self
    }
    
    @discardableResult
    public func assertBody(contains string: String, file: StaticString = #file, line: UInt = #line) -> XCTHTTPResponse {
        let bodyString = self.response.body.description
        if !bodyString.contains(string) {
            XCTFail("body contains check: (\(string.debugDescription)) does not appear in (\(bodyString.debugDescription))", file: file, line: line)
        }
        return self
    }
    
    @discardableResult
    public func assertBody(isEmpty: Bool, file: StaticString = #file, line: UInt = #line) -> XCTHTTPResponse {
        if isEmpty != self.response.body.isEmpty {
            XCTFail("body empty check: body.isEmpty = \(self.response.body.isEmpty)", file: file, line: line)
        }
        return self
    }
}

extension HTTPBody {
    var isEmpty: Bool {
        switch self.count {
        case .none: return true
        case .some(let count): return count == 0
        }
    }
}
