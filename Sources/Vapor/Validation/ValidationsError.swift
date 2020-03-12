public struct ValidationsResult {
    public let results: [ValidationResult]
    
    public var error: ValidationsError? {
        let failures = self.results.filter { $0.result.isFailure }
        if !failures.isEmpty {
            return ValidationsError(failures: failures)
        } else {
            return nil
        }
    }
    
    public func assert() throws {
        if let error = self.error {
            throw error
        }
    }
}

public struct ValidationsError: Error {
    public let failures: [ValidationResult]
}

extension ValidationsError: CustomStringConvertible {
    public var description: String {
        self.failures.compactMap { $0.failureDescription }
            .joined(separator: ", ")
    }
}

extension ValidationsError: AbortError {
    public var status: HTTPResponseStatus {
        .badRequest
    }

    public var reason: String {
        self.description
    }
}

extension ValidationsError: CustomErrorResponseConvertible {
    internal struct ErrorResponse: Codable {
        var error: Bool
        var reason: String
        var validationErrors: [String: String]
    }
    
    public func customResponse() -> Response {
        // collect validationErrors
        var validationErrors: [String: String] = [:]
        
        self.failures.forEach { failure in
            validationErrors = validationErrors.merging([failure.key.description: failure.failureDescription ?? ""]) {
                return $0 + ", " + $1
            }
        }
        
        // create a Response with appropriate status
        let response = Response(status: status, headers: headers)
        
        // attempt to serialize the error to json
        do {
            let errorResponse = ErrorResponse(error: true, reason: reason, validationErrors: validationErrors)
            response.body = try .init(data: JSONEncoder().encode(errorResponse))
            response.headers.replaceOrAdd(name: .contentType, value: "application/json; charset=utf-8")
        } catch {
            response.body = .init(string: "Oops: \(error)")
            response.headers.replaceOrAdd(name: .contentType, value: "text/plain; charset=utf-8")
        }
        return response
    }
}
