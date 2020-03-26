public struct XCTHTTPResponse {
    public var status: HTTPStatus
    public var headers: HTTPHeaders
    public var body: ByteBuffer
}

extension XCTHTTPResponse {
    private struct _ContentContainer: ContentContainer {
        var body: ByteBuffer
        var headers: HTTPHeaders

        var contentType: HTTPMediaType? {
            return self.headers.contentType
        }

        mutating func encode<E>(_ encodable: E, using encoder: ContentEncoder) throws where E : Encodable {
            fatalError("Encoding to test response is not supported")
        }

        func decode<D>(_ decodable: D.Type, using decoder: ContentDecoder) throws -> D where D : Decodable {
            try decoder.decode(D.self, from: self.body, headers: self.headers)
        }

        func decode<C>(_ content: C.Type, using decoder: ContentDecoder) throws -> C where C : Content {
            var decoded = try decoder.decode(C.self, from: self.body, headers: self.headers)
            try decoded.afterDecode()
            return decoded
        }
    }

    public var content: ContentContainer {
        _ContentContainer(body: self.body, headers: self.headers)
    }
}

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
    guard let contentType = res.headers.contentType else {
        XCTFail("response does not contain content type", file: file, line: line)
        return
    }
    do {
        let decoder = try ContentConfiguration.global.requireDecoder(for: contentType)
        let content = try decoder.decode(D.self, from: res.body, headers: res.headers)
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

