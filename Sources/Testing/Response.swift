import HTTP
import Foundation
import Node
import Vapor

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
        let desired = try b.testMakeBytes(file: file, line: line)
        let body = try testBody(file: file, line: line)

        if !body.contains(desired) {
            onFail(
                message ?? "Body assertion failed. '\(body.makeString())' does not contain '\(desired.makeString())'",
                file,
                line
            )
        }
        return self
    }
    
    /// Asserts the response body contains a
    /// desired byte array.
    @discardableResult
    public func assertJSON(
        _ key: String,
        file: StaticString = #file,
        line: UInt = #line,
        errorReason: String = "does not pass test",
        passes: (JSON) -> (Bool)
    ) throws -> Response {
        guard let json = json else {
            onFail(
                "JSON assertion failed. No JSON found in response",
                file,
                line
            )
            return self
        }
        
        let got = json[key] ?? JSON(.null)
        guard passes(got) else {
            onFail(
                "JSON assertion failed. '\(got.wrapped)' \(errorReason).",
                file,
                line
            )
            return self
        }
        
        return self
    }
    
    /// Asserts the response body contains a
    /// desired byte array.
    @discardableResult
    public func assertJSON(
        _ key: String,
        equals value: NodeRepresentable?,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> Response {
        let desired = try value?.makeNode(in: nil).wrapped ?? StructuredData.null
        
        return try assertJSON(
            key,
            file: file,
            line: line,
            errorReason: "does not equal '\(desired)'"
        ) { json in
            return json.wrapped == desired
        }
    }
    
    /// Asserts the response body contains a
    /// desired byte array.
    @discardableResult
    public func assertJSON(
        _ key: String,
        fuzzyEquals value: NodeRepresentable?,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> Response {
        let desired = try value?.makeNode(in: nil).wrapped ?? StructuredData.null
        
        return try assertJSON(
            key,
            file: file,
            line: line,
            errorReason: "does not fuzzy equal '\(desired)'"
        ) { json in
            return json.wrapped.string == desired.string
        }
    }
    
    /// Asserts the response body contains a
    /// desired byte array.
    @discardableResult
    public func assertJSON(
        _ key: String,
        contains value: NodeRepresentable,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> Response {
        let desired = try value.makeNode(in: nil).wrapped
        
        return try assertJSON(
            key,
            file: file,
            line: line,
            errorReason: "does not contain '\(desired)'"
        ) { json in
            guard let des = desired.string else {
                return false
            }
            guard let got = json.string else {
                return false
            }
            
            return got.contains(des)
        }
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
        if status.statusCode != desired.statusCode {
            onFail(
                message ?? "Status assertion failed. '\(status.statusCode)' does not equal '\(desired.statusCode)'",
                file,
                line
            )
        }

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

        if header?.contains(desired) != true {
            onFail(
                message ?? "\(key) header assertion failed. '\(header ?? "nil")' does not contain '\(desired)'",
                file,
                line
            )
        }
        
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
            onFail(
                "Failed to convert response body to bytes.",
                file,
                line
            )
            throw TestingError.noBodyBytes
        }

        return bytes
    }
}

// http://stackoverflow.com/questions/37410649/array-contains-a-complete-subarray
extension Array where Element: Equatable {
    func contains(_ subarray: [Element]) -> Bool {
        var found = 0
        for element in self where found < subarray.count {
            if element == subarray[found] {
                found += 1
            } else {
                found = element == subarray[0] ? 1 : 0
            }
        }

        return found == subarray.count
    }
}
