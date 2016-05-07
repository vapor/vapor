/**
     This protocol defines a type of data received.
     these variables are used to access underlying
     values
*/
public protocol Node {
    var isNull: Bool { get }
    var bool: Bool? { get }
    var float: Float? { get }
    var double: Double? { get }
    var int: Int? { get }
    var uint: UInt? { get }
    var string: String? { get }
    var array: [Node]? { get }
    var object: [String : Node]? { get }
    var json: Json? { get }
}

public enum NodeError: ErrorProtocol {

    /**
         When converting to a value from Json, if there is a type conflict, this will throw an error

         - param Json   the json that was unable to map
         - param String a string description of the type that was attempting to map
    */
    case UnableToConvert(node: Node, toType: String)
}

extension Extractable where Wrapped == Node {
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
    public var uint: UInt? {
        return extract()?.uint
    }
    public var string: String? {
        return extract()?.string
    }
    public var array: [Node]? {
        return extract()?.array
    }
    public var object: [String : Node]? {
        return extract()?.object
    }
    public var json: Json? {
        return extract()?.json
    }
}
