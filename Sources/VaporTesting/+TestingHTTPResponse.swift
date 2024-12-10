#if compiler(>=6.0)
import Testing

public func expectContent<D>(
    _ type: D.Type,
    _ res: TestingHTTPResponse,
    fileID: String = #fileID,
    filePath: String = #filePath,
    line: Int = #line,
    column: Int = #column,
    _ closure: (D) throws -> ()
) rethrows where D: Decodable {
    VaporTestingContext.warnIfNotInSwiftTestingContext(
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
    )
    
    guard let contentType = res.headers.contentType else {
        let sourceLocation = Testing.SourceLocation(
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
        Issue.record("response does not contain content type", sourceLocation: sourceLocation)
        return
    }

    let content: D

    do {
        let decoder = try ContentConfiguration.global.requireDecoder(for: contentType)
        content = try decoder.decode(D.self, from: res.body, headers: res.headers)
    } catch {
        let sourceLocation = Testing.SourceLocation(
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
        Issue.record("could not decode body: \(error)", sourceLocation: sourceLocation)
        return
    }

    try closure(content)
}

public func expectContains(
    _ haystack: String?,
    _ needle: String?,
    fileID: String = #fileID,
    filePath: String = #filePath,
    line: Int = #line,
    column: Int = #column
) {
    VaporTestingContext.warnIfNotInSwiftTestingContext(
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
    )

    let sourceLocation = Testing.SourceLocation(
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
    )
    switch (haystack, needle) {
    case (.some(let haystack), .some(let needle)):
        #expect(haystack.contains(needle), "\(haystack) does not contain \(needle)", sourceLocation: sourceLocation)
    case (.some(let haystack), .none):
        Issue.record("\(haystack) does not contain nil", sourceLocation: sourceLocation)
    case (.none, .some(let needle)):
        Issue.record("nil does not contain \(needle)", sourceLocation: sourceLocation)
    case (.none, .none):
        Issue.record("nil does not contain nil", sourceLocation: sourceLocation)
    }
}

public func expectJSONEquals<T>(
    _ data: String?,
    _ test: T,
    fileID: String = #fileID,
    filePath: String = #filePath,
    line: Int = #line,
    column: Int = #column
)
where T: Codable & Equatable
{
    VaporTestingContext.warnIfNotInSwiftTestingContext(
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
    )

    let sourceLocation = Testing.SourceLocation(
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
    )
    guard let data = data else {
        Issue.record("nil does not equal \(test)", sourceLocation: sourceLocation)
        return
    }
    do {
        let decoded = try JSONDecoder().decode(T.self, from: Data(data.utf8))
        #expect(decoded == test, sourceLocation: sourceLocation)
    } catch {
        Issue.record("could not decode \(T.self): \(error)", sourceLocation: sourceLocation)
    }
}
#endif
