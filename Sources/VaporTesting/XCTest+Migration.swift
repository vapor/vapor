@available(*, unavailable, renamed: "expectContent(_:_:sourceLocation:_:)")
public func XCTAssertContent<D>(
    _ type: D.Type,
    _ res: TestingHTTPResponse,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ closure: (D) throws -> ()
) rethrows where D: Decodable {
    fatalError("Renamed to 'expectContent(_:_:sourceLocation:_:)'")
}

@available(*, unavailable, renamed: "expectContains(_:_:sourceLocation:)")
public func XCTAssertContains(_ haystack: String?, _ needle: String?, file: StaticString = #filePath, line: UInt = #line) {
    fatalError("Renamed to 'expectContains(_:_:sourceLocation:)'")
}

@available(*, unavailable, renamed: "expectJSONEquals(_:_:sourceLocation:)")
public func XCTAssertEqualJSON<T>(_ data: String?, _ test: T, file: StaticString = #filePath, line: UInt = #line)
where T: Codable & Equatable
{
    fatalError("Renamed to 'expectEqualJSON(_:_:sourceLocation:)'")
}
