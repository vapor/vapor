import protocol Core.Extractable
@_exported import Polymorphic

extension Extractable where Wrapped == Polymorphic {
    public var isNull: Bool {
        return extract()?.isNull ?? false
    }
    public var bool: Bool? {
        return extract()?.bool
    }
    public var float: Float? {
        return extract()?.float
    }
    public var double: Double? {
        return extract()?.double
    }
    public var int: Int? {
        return extract()?.int
    }
    public var string: String? {
        return extract()?.string
    }
    public var array: [Polymorphic]? {
        return extract()?.array
    }
    public var object: [String : Polymorphic]? {
        return extract()?.object
    }
}
