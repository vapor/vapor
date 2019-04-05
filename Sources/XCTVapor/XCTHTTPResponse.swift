public struct XCTHTTPResponse {
    public var status: HTTPStatus
    public var headers: HTTPHeaders
    public var body: Response.Body
}
    
//    @discardableResult
//    public func assertStatus(is status: HTTPStatus, file: StaticString = #file, line: UInt = #line) -> XCTHTTPResponse {
//        XCTAssertEqual(self.response.status, status, file: file, line: line)
//        return self
//    }
//
//    @discardableResult
//    public func assertBody(equals string: String, file: StaticString = #file, line: UInt = #line) -> XCTHTTPResponse {
//        let bodyString = self.response.body.description
//        XCTAssertEqual(bodyString, string, file: file, line: line)
//        return self
//    }
//
//    @discardableResult
//    public func assertBody(contains string: String, file: StaticString = #file, line: UInt = #line) -> XCTHTTPResponse {
//        let bodyString = self.response.body.description
//        if !bodyString.contains(string) {
//            XCTFail("body contains check: (\(string.debugDescription)) does not appear in (\(bodyString.debugDescription))", file: file, line: line)
//        }
//        return self
//    }
//
//    @discardableResult
//    public func assertBody(isEmpty: Bool, file: StaticString = #file, line: UInt = #line) -> XCTHTTPResponse {
//        if isEmpty != self.response.body.isEmpty {
//            XCTFail("body empty check: body.isEmpty = \(self.response.body.isEmpty)", file: file, line: line)
//        }
//        return self
//    }

extension Response.Body {
    var isEmpty: Bool {
        return self.count == 0
    }
}

public func XCTAssertContains(_ haystack: String?, _ needle: String?, file: StaticString = #file, line: UInt = #line) {
    switch (haystack, needle) {
    case (.some(let haystack), .some(let needle)):
        XCTAssert(haystack.contains(needle), "\(haystack) does not contain \(needle)", file: file, line: line)
    case (.some(let haystack), .none):
        XCTFail("\(haystack) does not contain nil", file: file, line: line)
    case (.none, .some(let needle)):
        XCTFail("nil does not contain \(needle)", file: file, line: line)
    case (.none, .none):
        XCTFail("nil does not contain nil", file: file, line: line)
    }
}

