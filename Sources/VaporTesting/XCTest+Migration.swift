import VaporTestUtils

@available(*, unavailable, renamed: "expectContent(_:_:fileID:filePath:line:column:_:)")
public func XCTAssertContent<D>(
    _ type: D.Type,
    _ res: TestingHTTPResponse,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ closure: (D) throws -> ()
) rethrows where D: Decodable {
    fatalError("Renamed to 'expectContent(_:_:fileID:filePath:line:column:_:)'")
}

@available(*, unavailable, renamed: "expectContains(_:_:fileID:filePath:line:column:)")
public func XCTAssertContains(_ haystack: String?, _ needle: String?, file: StaticString = #filePath, line: UInt = #line) {
    fatalError("Renamed to 'expectContains(_:_:fileID:filePath:line:column:)'")
}

@available(*, unavailable, renamed: "expectJSONEquals(_:_:fileID:filePath:line:column:)")
public func XCTAssertEqualJSON<T>(_ data: String?, _ test: T, file: StaticString = #filePath, line: UInt = #line)
where T: Codable & Equatable
{
    fatalError("Renamed to 'expectEqualJSON(_:_:fileID:filePath:line:column:)'")
}

@available(*, unavailable, renamed: "TestingHTTPRequest")
public typealias XCTHTTPRequest = TestingHTTPRequest
@available(*, unavailable, renamed: "TestingHTTPResponse")
public typealias XCTHTTPResponse = TestingHTTPResponse
@available(*, unavailable, renamed: "TestingApplicationTester")
public typealias XCTApplicationTester = TestingApplicationTester
