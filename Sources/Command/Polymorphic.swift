import Console

extension String {
    public func assertString() throws -> String {
        guard let string = string else {
            throw ConsoleError(
                identifier: "unableToConvert",
                reason: "\(self) is not a String"
            )
        }

        return string
    }


    public func assertInt() throws -> Int {
        guard let int = int else {
            throw ConsoleError(
                identifier: "unableToConvert",
                reason: "\(self) is not an Int"
            )
        }

        return int
    }

    public func requireDouble() throws -> Double {
        guard let double = double else {
            throw ConsoleError(
                identifier: "unableToConvert",
                reason: "\(self) is not a Double"
            )
        }

        return double
    }

    public func requireBool() throws -> Bool {
        guard let bool = bool else {
            throw ConsoleError(
                identifier: "unableToConvert",
                reason: "\(self) is not a Bool"
            )
        }

        return bool
    }
}

extension String {
    public var string: String? { return self }
    public var int: Int? { return Int(self) }
    public var double: Double? { return Double(self) }
}

extension String {
    /// Converts the string to a bool.
    /// Returns nil if the string could not be converted.
    public var bool: Bool? {
        switch self {
        case "1", "true", "yes": return true
        case "0", "false", "no": return false
        default: return nil
        }
    }
}
