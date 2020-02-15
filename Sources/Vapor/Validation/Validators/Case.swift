extension Validator {
    /// Validates that the data can be converted to a value of an enum type.
    public static func `case`<E>(of enum: E.Type) -> Validator<T>
        where E: RawRepresentable, E.RawValue == T
    {
        .init {
            ValidatorResults.Case(enumType: E.self, rawValue: $0, possibleCases: nil)
        }
    }

    /// Validates that the data can be converted to a value of an enum type with iterable cases.
    public static func `case`<E>(of enum: E.Type) -> Validator<T>
        where E: RawRepresentable & CaseIterable, E.RawValue == T, T: CustomStringConvertible
    {
        .init {
            ValidatorResults.Case(enumType: E.self, rawValue: $0, possibleCases: E.allCases.map { $0.rawValue })
        }
    }

}

extension ValidatorResults {
    /// `ValidatorResult` of a validator thaat validates whether the data can be represented as a specific Enum case.
    public struct Case<T, E> where E: RawRepresentable, E.RawValue == T {
        /// The type of the enum to check.
        let enumType: E.Type
        /// The raw value that would be tested agains the enum type.
        let rawValue: T
        /// Helps Generate better failure description.
        let possibleCases: [CustomStringConvertible]?
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
        if var cases = self.possibleCases {
            var suffix = ""
            if cases.count > 1, let lastCase = cases.last {
                suffix = " or \(lastCase)"
                cases = cases.dropLast()
            }
            message = "is not \(cases.map { "\($0)" }.joined(separator: ", "))\(suffix)."
        } else {
            message = "has an invalid value."
        }
        return message
    }
}
