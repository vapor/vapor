public struct ValidatorResults: Sendable {
    public struct Nested: Sendable {
        public let results: [ValidatorResult]
    }

    public struct NestedEach: Sendable {
        public let results: [[ValidatorResult]]
    }
    
    public struct Skipped: Sendable { }

    public struct Missing: Sendable { }

    public struct NotFound: Sendable { }

    public struct Codable: Sendable {
        public let error: Error
    }

    public struct Invalid: Sendable {
        public let reason: String
    }

    public struct TypeMismatch: Sendable {
        public let type: Any.Type
    }
}

extension ValidatorResults.Nested: ValidatorResult {
    public var isFailure: Bool {
        !self.results.filter { $0.isFailure }.isEmpty
    }
    
    public var successDescription: String? {
        self.results.filter { !$0.isFailure }
            .compactMap { $0.successDescription }
            .joined(separator: " and ")
    }
    
    public var failureDescription: String? {
        self.results.filter { $0.isFailure }
            .compactMap { $0.failureDescription }
            .joined(separator: " and ")
    }
}

extension ValidatorResults.NestedEach: ValidatorResult {
    public var isFailure: Bool {
        !self.results.flatMap { $0 }
            .filter { $0.isFailure }.isEmpty
    }
    
    public var successDescription: String? {
        self.results.enumerated().compactMap { (index, results) -> String? in
            let successes = results.filter { !$0.isFailure }
            guard !successes.isEmpty else {
                return nil
            }
            let description = successes.compactMap { $0.successDescription }
                .joined(separator: " and ")
            return "at index \(index) \(description)"
        }.joined(separator: " and ")
    }
    
    public var failureDescription: String? {
        self.results.enumerated().compactMap { (index, results) -> String? in
            let failures = results.filter { $0.isFailure }
            guard !failures.isEmpty else {
                return nil
            }
            let description = failures.compactMap { $0.failureDescription }
                .joined(separator: " and ")
            return "at index \(index) \(description)"
        }.joined(separator: " and ")
    }
}

extension ValidatorResults.Skipped: ValidatorResult {
    public var isFailure: Bool {
        false
    }
    
    public var successDescription: String? {
        nil
    }
    
    public var failureDescription: String? {
        nil
    }
}

extension ValidatorResults.Missing: ValidatorResult {
    public var isFailure: Bool {
        true
    }
    
    public var successDescription: String? {
        nil
    }
    
    public var failureDescription: String? {
        "is required"
    }
}

extension ValidatorResults.Invalid: ValidatorResult {
    public var isFailure: Bool {
        true
    }

    public var successDescription: String? {
        nil
    }

    public var failureDescription: String? {
        "is invalid: \(self.reason)"
    }
}

extension ValidatorResults.NotFound: ValidatorResult {
    public var isFailure: Bool {
        true
    }

    public var successDescription: String? {
        nil
    }

    public var failureDescription: String? {
        "cannot be null"
    }
}


extension ValidatorResults.TypeMismatch: ValidatorResult {
    public var isFailure: Bool {
        true
    }

    public var successDescription: String? {
        nil
    }

    public var failureDescription: String? {
        "is not a(n) \(self.type)"
    }
}

extension ValidatorResults.Codable: ValidatorResult {
    public var isFailure: Bool {
        true
    }
    
    public var successDescription: String? {
        nil
    }
    
    public var failureDescription: String? {
        "failed to decode: \(error)"
    }
}

public protocol ValidatorResult: Sendable {
    var isFailure: Bool { get }
    var successDescription: String? { get }
    var failureDescription: String? { get }
}
