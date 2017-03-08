public protocol _Validatable {}

extension _Validatable {
    public func validated<V: _Validator>(by validator: V) throws where V.Input == Self {
        let list = _ValidatorList(validator)
        try validated(by: list)
    }

    public func validated(by list: _ValidatorList<Self>) throws {
        try list.validate(self)
    }
}

extension _Validatable {
    public func tested<V: _Validator>(by v: V) throws -> Self where V.Input == Self {
        try v.validate(self)
        return self
    }

    public func passes<V: _Validator>(_ v: V) -> Bool where V.Input == Self {
        do {
            try validated(by: v)
            return true
        } catch {
            return false
        }
    }
}

// MARK: Conformance

extension String: _Validatable {}

extension Set: _Validatable {}
extension Array: _Validatable {}
extension Dictionary: _Validatable {}

extension Bool: _Validatable {}

extension Int: _Validatable {}
extension Int8: _Validatable {}
extension Int16: _Validatable {}
extension Int32: _Validatable {}
extension Int64: _Validatable {}

extension UInt: _Validatable {}
extension UInt8: _Validatable {}
extension UInt16: _Validatable {}
extension UInt32: _Validatable {}
extension UInt64: _Validatable {}

extension Float: _Validatable {}
extension Double: _Validatable {}
