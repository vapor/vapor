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
