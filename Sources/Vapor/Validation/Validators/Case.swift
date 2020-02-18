extension Validator {
    /// Validates that the data can be converted to a value of an enum type with iterable cases.
    public static func `case`<E>(of enum: E.Type) -> Validator<T>
        where E: RawRepresentable & CaseIterable, E.RawValue == T, T: CustomStringConvertible
    {
        .init {
            ValidatorResults.Case(enumType: E.self, rawValue: $0)
        }
    }

}

extension ValidatorResults {
    /// `ValidatorResult` of a validator thaat validates whether the data can be represented as a specific Enum case.
    public struct Case<T, E> where E: RawRepresentable & CaseIterable, E.RawValue == T, T: CustomStringConvertible {
        /// The type of the enum to check.
        let enumType: E.Type
        /// The raw value that would be tested agains the enum type.
        let rawValue: T
    }
}

extension ValidatorResults.Case: ValidatorResult {
    public var isFailure: Bool {
        return enumType.init(rawValue: rawValue) == nil
    }

    public var successDescription: String? {
        "is \(E.self)"
    }

    public var failureDescription: String? {
        let message: String
        var cases = E.allCases.map { "\($0.rawValue)" }
        var suffix = ""
        if cases.count > 1 {
            suffix = " or \(cases.removeLast())"
        }
        message = "is not \(cases.joined(separator: ", "))\(suffix)."
        return message
    }
}
