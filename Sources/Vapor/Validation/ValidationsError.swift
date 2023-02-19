import NIOHTTP1

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
        self.failures.compactMap { $0.customFailureDescription ?? $0.failureDescription }
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
