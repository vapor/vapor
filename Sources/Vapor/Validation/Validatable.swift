/// This is an API driven protocol 
/// and any type that might need to be validated
/// can be conformed independently
public protocol Validatable {}

extension Validatable {
    /// Validate an individual validator
    public func validated<V: Validator>(by validator: V) throws where V.Input == Self {
        let list = ValidatorList(validator)
        try validated(by: list)
    }

    /// Push validation to list level for more consistent error lists
    public func validated(by list: ValidatorList<Self>) throws {
        try list.validate(self)
    }
}

extension Validatable {
    /// Tests a value with a given validator, upon passing, returns self
    /// or throws
    public func tested<V: Validator>(by v: V) throws -> Self where V.Input == Self {
        try v.validate(self)
        return self
    }

    /// Converts validation to a boolean indicating success/failure
    public func passes<V: Validator>(_ v: V) -> Bool where V.Input == Self {
        do {
            try validated(by: v)
            return true
        } catch {
            return false
        }
    }
}

// MARK: Conformance

extension String: Validatable {}

extension Set: Validatable {}
extension Array: Validatable {}
extension Dictionary: Validatable {}

extension Bool: Validatable {}

extension Int: Validatable {}
extension Int8: Validatable {}
extension Int16: Validatable {}
extension Int32: Validatable {}
extension Int64: Validatable {}

extension UInt: Validatable {}
extension UInt8: Validatable {}
extension UInt16: Validatable {}
extension UInt32: Validatable {}
extension UInt64: Validatable {}

extension Float: Validatable {}
extension Double: Validatable {}
