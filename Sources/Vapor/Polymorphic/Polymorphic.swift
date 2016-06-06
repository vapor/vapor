/**
     This protocol defines a type of data received.
     these variables are used to access underlying
     values
*/
public protocol Polymorphic {
    var isNull: Bool { get }
    var bool: Bool? { get }
    var float: Float? { get }
    var double: Double? { get }
    var int: Int? { get }
    var string: String? { get }
    var array: [Polymorphic]? { get }
    var object: [String : Polymorphic]? { get }
}

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
