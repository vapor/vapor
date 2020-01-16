public struct XCTHTTPResponse {
    public var status: HTTPStatus
    public var headers: HTTPHeaders
    public var body: Response.Body
}

extension XCTHTTPResponse {
    private struct _ContentContainer: ContentContainer {
        var body: String
        var headers: HTTPHeaders

        var contentType: HTTPMediaType? {
            return self.headers.contentType
        }

        mutating func encode<E>(_ encodable: E, using encoder: ContentEncoder) throws where E : Encodable {
            fatalError("Encoding to test response is not supported")
        }

        func decode<D>(_ decodable: D.Type, using decoder: ContentDecoder) throws -> D where D : Decodable {
            var body = ByteBufferAllocator().buffer(capacity: 0)
            body.writeString(self.body)
            return try decoder.decode(D.self, from: body, headers: self.headers)
        }
    }

    public var content: ContentContainer {
        _ContentContainer(body: self.body.string ?? "", headers: self.headers)
    }
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

public func XCTAssertContent<D>(
    _ type: D.Type,
    _ res: XCTHTTPResponse,
    file: StaticString = #file,
    line: UInt = #line,
    _ closure: (D) -> ()
)
    where D: Decodable
{
    guard let body = res.body.buffer else {
        XCTFail("response does not contain body", file: file, line: line)
        return
    }
    guard let contentType = res.headers.contentType else {
        XCTFail("response does not contain content type", file: file, line: line)
        return
    }
    do {
        let decoder = try ContentConfiguration.global.requireDecoder(for: contentType)
        let content = try decoder.decode(D.self, from: body, headers: res.headers)
        closure(content)
    } catch {
        XCTFail("could not decode body: \(error)", file: file, line: line)
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

public func XCTAssertEqualJSON<T>(_ data: String?, _ test: T, file: StaticString = #file, line: UInt = #line)
    where T: Codable & Equatable
{
    guard let data = data else {
        XCTFail("nil does not equal \(test)", file: file, line: line)
        return
    }
    do {
        let decoded = try JSONDecoder().decode(T.self, from: Data(data.utf8))
        XCTAssertEqual(decoded, test, file: file, line: line)
    } catch {
        XCTFail("could not decode \(T.self): \(error)", file: file, line: line)
    }
}

