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
    
    public var metadata: Metadata {
        return ["validationErrors" : self.failures.metadataValue]
    }
}

extension Array where Element == ValidationResult {
    internal var metadataValue: MetadataValue {
        var validationErrors: [String: MetadataValue] = [:]
        
        self.forEach { failure in
            let key = "\(failure.key)"
            let value: MetadataValue
            
            switch failure.result {
            case let nestedFailure as ValidatorResults.Nested where nestedFailure.results is [ValidationResult]:
                value = (nestedFailure.results as! [ValidationResult]).metadataValue
            default:
                value = .init(failure.failureDescription ?? "")
            }
            
            validationErrors.merge([key: value]) {
                if var arrayMetadata = $0.value as? [MetadataValue] {
                    arrayMetadata.append($1)
                    return .init(arrayMetadata)
                } else {
                    return .init([$0, $1])
                }
            }
        }
        
        return .init(validationErrors)
    }
}
