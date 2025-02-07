import XCTest

public func XCTAssertContent<D>(
    _ type: D.Type,
    _ res: XCTHTTPResponse,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ closure: (D) throws -> Void
) rethrows where D: Decodable {
    XCTVaporContext.warnIfInSwiftTestingContext(file: file, line: line)

    guard let contentType = res.headers.contentType else {
        XCTFail("response does not contain content type", file: file, line: line)
        return
    }

    let content: D

    do {
        let decoder = try ContentConfiguration.global.requireDecoder(for: contentType)
        content = try decoder.decode(D.self, from: res.body, headers: res.headers)
    } catch {
        XCTFail("could not decode body: \(error)", file: file, line: line)
        return
    }

    try closure(content)
}

public func XCTAssertContains(_ haystack: String?, _ needle: String?, file: StaticString = #filePath, line: UInt = #line) {
    XCTVaporContext.warnIfInSwiftTestingContext(file: file, line: line)

    let file = (file)
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

public func XCTAssertEqualJSON<T>(_ data: String?, _ test: T, file: StaticString = #filePath, line: UInt = #line)
where T: Codable & Equatable {
    XCTVaporContext.warnIfInSwiftTestingContext(file: file, line: line)

    guard let data = data else {
        XCTFail("nil does not equal \(test)", file: file, line: line)
        return
    }
    do {
        let decoded = try JSONDecoder().decode(T.self, from: Data(data.utf8))
        XCTAssertEqual(decoded, test, file: (file), line: line)
    } catch {
        XCTFail("could not decode \(T.self): \(error)", file: (file), line: line)
    }
}
