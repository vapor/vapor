extension String: Error { }

public protocol Polymorphic {
    var string: String? { get }
    var int: Int? { get }
    var double: Double? { get }
}

extension Polymorphic {
    public func assertString() throws -> String {
        guard let string = string else {
            throw "\(self) is not a String"
        }

        return string
    }


    public func assertInt() throws -> Int {
        guard let int = int else {
            throw "\(self) is not an int"
        }

        return int
    }

    public func assertDouble() throws -> Double {
        guard let double = double else {
            throw "\(self) is not a double"
        }

        return double
    }
}

extension String: Polymorphic {
    public var string: String? { return self }
    public var int: Int? { return Int(self) }
    public var double: Double? { return Double(self) }
}
